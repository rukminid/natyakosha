/**
 * Natyakosha Cloud Functions.
 *
 * Deploy:  cd functions && npm install && firebase deploy --only functions
 * Region:  asia-south1 (Mumbai), matching API_BASE_URL in the app's .env files.
 */
const { onRequest } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();
setGlobalOptions({ region: 'asia-south1', maxInstances: 10 });

const db = admin.firestore();

/** Same mapping as lib/core/utils/mobile_number.dart. */
const authEmail = (tenDigits) => `91${tenDigits}@phone.natyakosha.app`;
const MOBILE_RE = /^[6-9]\d{9}$/;

/**
 * Simple fixed-window rate limiter stored in Firestore (`rateLimits/*`,
 * which security rules keep unreadable from the app).
 * Returns true when the caller is over the limit.
 */
async function overLimit(key, max, windowMs) {
  const ref = db.collection('rateLimits').doc(key);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    const data = snap.exists ? snap.data() : null;
    if (!data || now - data.windowStart > windowMs) {
      tx.set(ref, { count: 1, windowStart: now });
      return false;
    }
    if (data.count >= max) return true;
    tx.update(ref, { count: data.count + 1 });
    return false;
  });
}

/**
 * POST /resetPasswordByMobile  { mobile: "9876543210", newPassword: "..." }
 *
 * Forgot-password flow chosen for Natyakosha: the user enters their mobile
 * number and a new password, with no OTP. Because nothing proves the caller
 * owns the number, this function:
 *   - rate-limits per mobile number (3 per day) and per IP (10 per hour),
 *   - signs the account out on every device,
 *   - sends a push notification "your password was changed",
 *   - logs every reset.
 * To add OTP verification later, check a Firebase phone-auth ID token here
 * before changing the password.
 */
exports.resetPasswordByMobile = onRequest({ cors: false }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ message: 'Method not allowed.' });
    return;
  }

  const mobile = String((req.body && req.body.mobile) || '').replace(/\D/g, '').slice(-10);
  const newPassword = String((req.body && req.body.newPassword) || '');

  if (!MOBILE_RE.test(mobile)) {
    res.status(400).json({ message: 'Enter a valid 10-digit mobile number.' });
    return;
  }
  if (newPassword.length < 8 || !/[A-Za-z]/.test(newPassword) || !/\d/.test(newPassword)) {
    res.status(400).json({ message: 'Use at least 8 characters with letters and numbers.' });
    return;
  }

  const ip = (req.ip || 'unknown').replace(/[^\w.:-]/g, '_');
  try {
    if (
      (await overLimit(`reset_ip_${ip}`, 10, 60 * 60 * 1000)) ||
      (await overLimit(`reset_mobile_${mobile}`, 3, 24 * 60 * 60 * 1000))
    ) {
      res.status(429).json({ message: 'Too many attempts. Please try again later.' });
      return;
    }

    let user;
    try {
      user = await admin.auth().getUserByEmail(authEmail(mobile));
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        res.status(404).json({ message: 'No account found with this mobile number. Please sign up.' });
        return;
      }
      throw e;
    }

    await admin.auth().updateUser(user.uid, { password: newPassword });
    await admin.auth().revokeRefreshTokens(user.uid);
    logger.info('Password reset by mobile', { uid: user.uid, ip });

    // Tell the account owner, in case it wasn't them.
    const profile = await db.doc(`users/${user.uid}`).get();
    const tokens = (profile.exists && profile.get('fcmTokens')) || [];
    if (tokens.length) {
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: 'Your Natyakosha password was changed',
          body: "If this wasn't you, contact your guru straight away.",
        },
      });
    }

    res.status(200).json({ ok: true });
  } catch (e) {
    logger.error('resetPasswordByMobile failed', e);
    res.status(500).json({ message: 'Could not reset the password. Please try again.' });
  }
});

/**
 * POST /remindPendingEventFees  { schoolId, eventId }   (Bearer <Firebase ID token>)
 *
 * Staff only. Sends a push to every participant whose event fee is still
 * `pending` (and to their parents, found through `childIds`).
 */
exports.remindPendingEventFees = onRequest({ cors: false }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ message: 'Method not allowed.' });
    return;
  }
  try {
    const header = req.get('Authorization') || '';
    const idToken = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (!idToken) {
      res.status(401).json({ message: 'Please sign in again.' });
      return;
    }
    const caller = await admin.auth().verifyIdToken(idToken);
    const me = (await db.doc(`users/${caller.uid}`).get()).data() || {};

    const schoolId = String((req.body && req.body.schoolId) || '');
    const eventId = String((req.body && req.body.eventId) || '');
    const isStaff = ['guru', 'teacher'].includes(me.role) && (me.status || 'approved') === 'approved';
    if (!schoolId || !eventId || me.schoolId !== schoolId || !isStaff) {
      res.status(403).json({ message: 'Only your guru or teacher can send reminders.' });
      return;
    }
    if (await overLimit(`remind_${caller.uid}_${eventId}`, 5, 60 * 60 * 1000)) {
      res.status(429).json({ message: 'Reminders were just sent. Try again in a while.' });
      return;
    }

    const eventRef = db.doc(`schools/${schoolId}/events/${eventId}`);
    const event = await eventRef.get();
    if (!event.exists) {
      res.status(404).json({ message: 'Event not found.' });
      return;
    }
    const pending = await eventRef.collection('fees').where('status', '==', 'pending').get();
    if (pending.empty) {
      res.status(200).json({ ok: true, sent: 0 });
      return;
    }

    const fee = event.get('fee') || {};
    const due = fee.dueDate && fee.dueDate.toDate ? fee.dueDate.toDate() : null;
    const dueText = due
      ? ` by ${due.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', timeZone: 'Asia/Kolkata' })}`
      : '';

    let sent = 0;
    for (const doc of pending.docs) {
      const studentId = doc.id;
      const amount = doc.get('amount');
      // The student, plus any parent linked to them.
      const parents = await db.collection('users').where('childIds', 'array-contains', studentId).get();
      const tokens = new Set();
      const student = await db.doc(`users/${studentId}`).get();
      for (const t of (student.exists && student.get('fcmTokens')) || []) tokens.add(t);
      for (const p of parents.docs) for (const t of p.get('fcmTokens') || []) tokens.add(t);
      if (!tokens.size) continue;

      const r = await admin.messaging().sendEachForMulticast({
        tokens: [...tokens],
        notification: {
          title: `Fee reminder: ${event.get('title')}`,
          body: `₹${amount} is due${dueText}. Pay by UPI and upload the screenshot in the app.`,
        },
        data: { type: 'eventFeeReminder', eventId },
      });
      sent += r.successCount;
    }
    logger.info('Event fee reminders sent', { eventId, by: caller.uid, sent });
    res.status(200).json({ ok: true, sent });
  } catch (e) {
    logger.error('remindPendingEventFees failed', e);
    res.status(500).json({ message: 'Could not send reminders. Please try again.' });
  }
});
