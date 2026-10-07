# Natyakosha

*Every class, every stage, every step.*

Natyakosha is a Flutter app for classical dance schools. It covers attendance, monthly and event fees (pay by UPI, upload the screenshot, the guru verifies), events with their running order of songs, a photo, video and audio gallery, announcements, and theory notes.

This repository is the **boilerplate**. The architecture, configuration and core plumbing are in place. One feature, payment screenshot upload, is built end to end as the reference pattern. The dashboard, login, events list and announcements list also work.

---

## 1. Tech stack (React Native → Flutter)

| Need | React Native | Used here |
|---|---|---|
| Env config | react-native-config | `flutter_dotenv` + 3 entry points (dev / staging / prod) |
| Online / offline | @react-native-community/netinfo | `connectivity_plus` + `internet_connection_checker_plus` |
| Key-value storage | AsyncStorage | `shared_preferences` → `PrefsStorage` |
| Secure storage | react-native-keychain | `flutter_secure_storage` → `SecureStorage` |
| Local DB / cache | Realm / WatermelonDB | `hive_ce` → `LocalStore` |
| State | redux + react-redux + redux-thunk | `redux` + `flutter_redux` + in-house thunk middleware |
| HTTP | axios | `dio` → `DioClient` (interceptors: offline, auth token, logging) |
| Forms + validation | Formik + Yup | `flutter_form_builder` + `form_builder_validators` → `AppValidators` |
| Navigation | react-navigation | `go_router` (auth-aware redirects) |
| Backend | react-native-firebase | Firebase Auth, Firestore, Storage, Messaging |
| Images | image-picker, fast-image | `image_picker`, `flutter_image_compress`, `cached_network_image` |
| DI | — | `get_it` |
| Logging | redux-logger / Reactotron | `logger` + Redux logger middleware |

Models are hand-written (`fromMap` / `toMap` / `Equatable`) instead of `freezed`, so there is no code-generation step. You can switch to `freezed` later if you prefer.

---

## 2. Architecture: MVVM + Redux

```
 View (widget)  ──reads──▶  ViewModel  ◀──built from──  Redux Store (AppState)
      │                        │                               ▲
      │ user taps              │ calls a command               │ reducers
      ▼                        ▼                               │
   vm.submit(...)  ──▶  store.dispatch(thunk)  ──▶  actions ───┘
                              │
                              ▼
                        Repository  ──▶  Service (Firebase / Dio / Storage)
```

- **View**: widgets only. Each screen uses `StoreConnector<AppState, XViewModel>`.
- **ViewModel**: `XViewModel.fromStore(store)` exposes only the data the screen needs, plus commands (callbacks). It extends `Equatable`, so the screen rebuilds only when its own data changes.
- **Redux**: one `AppState` tree. Thunks (`lib/redux/thunks`) do async work and dispatch plain actions. Reducers are pure, and selectors derive data.
- **Repository**: business rules and error mapping (every error becomes an `AppException` with a friendly message).
- **Service**: thin wrappers over Firebase and Dio.

Local UI-only state, such as a selected filter chip or a picked image before upload, stays in the widget's `State`, not in Redux.

### Folder structure

```
lib/
  main.dart / main_dev.dart / main_staging.dart / main_prod.dart
  bootstrap.dart        env → Firebase → DI → store → runApp → connectivity
  app.dart              StoreProvider + MaterialApp.router + offline banner
  firebase_options.dart placeholder until you run `flutterfire configure`
  core/
    config/     Flavor, Env (typed .env access)
    di/         get_it locator
    network/    DioClient, ConnectivityService
    storage/    PrefsStorage, SecureStorage, LocalStore (Hive), StorageKeys
    router/     go_router + Routes
    theme/      maroon / gold / ivory theme
    validators/ AppValidators (email, Indian phone, ₹ amount, UPI ref…)
    errors/     AppException
    utils/      AppLogger
  data/
    models/       AppUser, Batch, AttendanceRecord, Payment, DanceEvent,
                  EventItem, EventFee, MediaItem, Announcement, TheoryNote
    services/     AuthService, StorageService, NotificationService, ApiService, paths
    repositories/ Auth, User, Payment, Event, Attendance, Announcement
  redux/
    state/ actions/ reducers/ middleware/ thunks/ selectors/  store.dart
  features/<feature>/views + view_models
  shared/widgets/  OfflineBanner, StatusChip, EmptyState, ErrorRetry, ComingSoonView
test/  reducer + validator tests
firestore.rules, storage.rules, firebase.json
```

---

## 3. First-time setup

**Requirements:** Flutter 3.29+ (Dart 3.7+), Android Studio or Xcode, and a Google account.

```bash
# 1. Generate the android/ and ios/ folders (lib/ is left untouched)
flutter create --platforms=android,ios --org com.natyakosha .

# 2. Get packages
flutter pub get

# 3. Connect Firebase (installs the CLI tools once)
dart pub global activate flutterfire_cli
npm install -g firebase-tools && firebase login
flutterfire configure            # overwrites lib/firebase_options.dart

# 4. Check everything compiles and the tests pass
flutter analyze
flutter test
```

**In the Firebase console:**
1. Upgrade the project to the **Blaze** plan. Cloud Storage requires it, but usage within the free tier still costs ₹0. Set a budget alert under Google Cloud Console → Billing → Budgets & alerts.
2. Enable **Authentication → Email/Password**. Mobile-number login uses this provider under the hood.
3. Create **Firestore** (region `asia-south1` Mumbai) and **Storage**.
4. Deploy the rules and the Cloud Function:
   ```bash
   cd functions && npm install && cd ..
   firebase deploy --only firestore:rules,storage,functions
   ```
   Put the function's base URL (`https://asia-south1-<project-id>.cloudfunctions.net`) in `API_BASE_URL` in your `.env.*` files.
5. Create the first guru **from the app**: open **Create account**, choose **Guru**, pick **"My institute isn't listed — register it"**, and fill in the details. The guru who registers an institute is approved automatically. Everyone who joins that institute afterwards waits for that guru's approval.
   - Parents (optional) are still added by hand: `users/<uid>` with `role: "parent"`, `status: "approved"`, `childIds: ["<studentUid>"]`.

**Android extras** (after `flutter create`):
- `android/app/build.gradle`: set `minSdk = 23` (needed by Firebase and secure storage).
- Camera and gallery permissions are handled by `image_picker`. On iOS, add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` to `ios/Runner/Info.plist`.

---

## 4. Environments

Each flavor has its own entry point and `.env` file:

| Flavor | Run | Env file |
|---|---|---|
| dev | `flutter run -t lib/main_dev.dart` | `.env.dev` |
| staging | `flutter run -t lib/main_staging.dart` | `.env.staging` |
| prod | `flutter run -t lib/main_prod.dart --release` | `.env.prod` |

Keys (see `.env.example`): `APP_NAME`, `ENV`, `API_BASE_URL`, `API_TIMEOUT_MS`, `ENABLE_LOGS`, `IMAGE_MAX_DIMENSION`, `IMAGE_QUALITY`. Read them through `Env.apiBaseUrl` and similar getters, never `dotenv` directly.

`.env` files are bundled into the app, so **never put server secrets in them**. Put secrets in Cloud Functions. Once your env files hold real values, uncomment them in `.gitignore`.

To install dev and prod side by side with different app IDs, add Android `productFlavors` / iOS schemes later. For a small team, separate Firebase projects per flavor plus these entry points are usually enough.

---

## 5. How things work

**Online / offline.** `ConnectivityService` pushes changes into Redux (`state.isOnline`). `OfflineBanner` shows a bar on every screen. `DioClient` fails fast when offline. Firestore offline persistence is on, so attendance marked without signal is queued and synced automatically. Screenshot upload is disabled while offline.

**Storage.**
- `PrefsStorage` holds settings.
- `SecureStorage` holds the FCM token.
- `LocalStore` (Hive) caches the user profile and announcements. This lets the app open instantly and work offline, and it is cleared on sign-out.

**Sign up.** The form asks: Guru or Student, full name, date of birth, gender, institute (dropdown of registered institutes), mobile number, then set and re-enter a password.
- Joining an **existing institute** creates the account as `pending`, and the user sees a "Waiting for approval" screen. Gurus of that institute see "N people want to join" on their dashboard and approve or reject each request under **Join requests**.
- A guru can pick **"My institute isn't listed"** to register a new institute. They become its owner and are approved immediately. Students can't register institutes.

**Login** uses mobile number + password. Firebase has no phone+password sign-in, so each number maps to a hidden id (`91XXXXXXXXXX@phone.natyakosha.app`, see `MobileNumber`) on Firebase's free Email/Password provider. Users only ever see their mobile number.

**Forgot password** asks for the mobile number (pre-filled from the login screen), the new password and the re-entered password. The Cloud Function `resetPasswordByMobile` changes it, because only the Admin SDK can change the password of a signed-out user. As chosen, there is **no OTP check**, so anyone who knows a mobile number can reset that account's password. To limit the damage, the function:
- allows at most 3 resets per number per day and 10 per IP per hour;
- signs the account out everywhere;
- pushes "Your password was changed" to the owner's devices;
- logs every reset.

To add OTP later, verify a Firebase phone-auth token in the function before changing the password.

**Auth routing.** The splash screen dispatches `restoreSession()`, which uses the cached profile first and then refreshes from Firestore. The router redirects on `auth.status` and the approval status:
- `unknown` → splash
- signed out → login / sign-up / forgot password
- signed in but pending or rejected → waiting-for-approval screen
- approved → dashboard

**Payments (the reference feature).** The student picks a month, amount, optional 12-digit UPI reference and a screenshot. The image is compressed on the phone to about 1600px at quality 70, uploaded to `schools/{schoolId}/payments/{studentId}/…` with a progress bar, and saved as `submitted`. The guru sees "Screenshots to verify" on the dashboard and taps **Mark paid** or **Reject**.

**Event fees.** The data layer is ready. `EventRepository.createEvent` creates the event, a participant group and one `pending` fee per participant in a single batch. `updateFee` handles paid, waived and per-student amounts.

---

## 6. Adding a feature (recipe)

Using **Attendance** as the example:
1. **Model**: already exists (`AttendanceRecord`).
2. **Repository**: already exists (`AttendanceRepository.fetch/save`).
3. **State**: add an `AttendanceState` (or reuse `ListState<T>`) to `AppState`.
4. **Actions**: add request, loaded and failed actions in `app_actions.dart`.
5. **Reducer**: add `TypedReducer`s and wire them into `appReducer`.
6. **Thunk**: create `redux/thunks/attendance_thunks.dart`, following `payment_thunks.dart`.
7. **ViewModel**: create `features/attendance/view_models/attendance_view_model.dart` with `fromStore`.
8. **View**: replace the `ComingSoonView` in `attendance_view.dart` with a `StoreConnector`.
9. **Test**: add reducer tests in `test/`.

---

## 7. Module status

| Module | Status |
|---|---|
| Env / flavors, DI, Dio, connectivity, storage, theme, router | ✅ Done |
| Sign-up (guru/student, DOB, gender, institute), mobile + password login | ✅ Done |
| Forgot password (mobile + new + re-enter, via Cloud Function) | ✅ Done |
| Guru approval of join requests, waiting-for-approval screen | ✅ Done |
| Dashboard (guru and student views) | ✅ Done |
| Monthly fee screenshot upload + guru verify/reject | ✅ Done |
| Bottom tabs: Home, Profile, Events | ✅ Done |
| Profile view + edit (name, DOB, gender, photo), sign out | ✅ Done |
| Events: list, month calendar, schedule (date + start/end time), create, edit, delete, dancers, optional fee | ✅ Done |
| Students the guru adds (no app needed): add, edit, remove, parent mobile; on the roster for attendance, events, birthdays | ✅ Done |
| Announcements: list (offline cached), staff post / edit / delete / pin | ✅ Done |
| Firestore + Storage security rules | ✅ Done |
| Attendance: take Present/Absent per date and per batch, offline-safe, monthly summary; students and parents see their own days | ✅ Done. Own view shows days saved after this release |
| Batches: add / edit / delete, choose students | ✅ Done |
| Event running order: add/edit/delete songs, drag to reorder, performers per song (staff edit, everyone reads) | ✅ Done |
| Event fees: per-event totals, tick Paid / Waived / change amount, student UPI screenshot upload, remind pending (push via Cloud Function) | ✅ Done. Deploy `remindPendingEventFees` |
| Gallery: photos, videos, audio grouped by event, link to a song, staff upload/delete | ✅ Done |
| Theory library: topics, search, notes with pictures, staff add / edit / delete | ✅ Done |
| Telugu / Tamil / Hindi | 🔜 |

### Cloud Functions to add (server side)

These run on the Blaze plan. The app already saves `fcmTokens` on each user.
- `onEventFeesCreated`: when `events/{id}/fees/{studentId}` is created, push "₹X due for <event> by <date>".
- `remindPendingEventFees` (HTTP, called via `ApiService`): **written** in `functions/index.js`, deploy it. Still to add: a daily scheduled job that reminds pending participants near the due date.
- `onPaymentReviewed`: when a payment becomes `verified` or `rejected`, notify the student.
- `onAnnouncementCreated`: push to the whole school.

---

## 8. Notes and known limits

- **Unverified build.** This boilerplate was written where the Flutter SDK and pub.dev could not be downloaded, so `flutter analyze` and `flutter test` have not been run yet. A separate code review against the package sources found no compile errors, but run `flutter pub get && flutter analyze && flutter test` first and fix anything flagged.
- **Password reset has no OTP** (your choice). See "Forgot password" above for the safeguards in place and how to add OTP.
- **Accounts added by hand** in the console should include `"status": "approved"`. Without it they still work, but they won't appear in student lists.
- **Parent payment lists** use a `whereIn` query on `studentId`. If Firestore rejects it under the security rules, give parents one query per child instead.
- **`firebaseReady`.** Until `flutterfire configure` is run, the app starts in a safe mode and the login screen explains what to do.
