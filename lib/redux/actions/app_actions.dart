import '../../data/models/announcement.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/attendance_summary.dart';
import '../../data/models/batch.dart';
import '../../data/models/app_user.dart';
import '../../data/models/chat.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/dance_event.dart';
import '../../data/models/event_fee.dart';
import '../../data/models/event_item.dart';
import '../../data/models/institute.dart';
import '../../data/models/media_item.dart';
import '../../data/models/member.dart';
import '../../data/models/payment.dart';
import '../../data/models/theory_note.dart';

/// Plain action classes (like Redux action objects with a `type`).
/// The class itself is the type; fields are the payload.

// ---------------- Connectivity ----------------
class SetConnectivityAction {
  const SetConnectivityAction({required this.isOnline});
  final bool isOnline;
}

// ---------------- Auth ----------------
class AuthRequestAction {
  const AuthRequestAction();
}

class AuthSuccessAction {
  const AuthSuccessAction(this.user);
  final AppUser user;
}

class AuthFailureAction {
  const AuthFailureAction(this.message);
  final String message;
}

class SignedOutAction {
  const SignedOutAction();
}

class ClearAuthErrorAction {
  const ClearAuthErrorAction();
}

// ---------------- Payments ----------------
class PaymentsRequestAction {
  const PaymentsRequestAction();
}

class PaymentsLoadedAction {
  const PaymentsLoadedAction(this.items);
  final List<Payment> items;
}

class PaymentsFailureAction {
  const PaymentsFailureAction(this.message);
  final String message;
}

class PaymentSubmitStartAction {
  const PaymentSubmitStartAction();
}

class PaymentUploadProgressAction {
  const PaymentUploadProgressAction(this.progress);
  final double progress;
}

class PaymentSubmittedAction {
  const PaymentSubmittedAction(this.payment);
  final Payment payment;
}

class PaymentSubmitFailedAction {
  const PaymentSubmitFailedAction(this.message);
  final String message;
}

class PaymentReviewStartAction {
  const PaymentReviewStartAction(this.paymentId);
  final String paymentId;
}

class PaymentReviewedAction {
  const PaymentReviewedAction(this.paymentId, this.status, this.reviewerId);
  final String paymentId;
  final PaymentStatus status;
  final String reviewerId;
}

class PaymentReviewFailedAction {
  const PaymentReviewFailedAction(this.paymentId, this.message);
  final String paymentId;
  final String message;
}

// ---------------- Announcements ----------------
class AnnouncementsRequestAction {
  const AnnouncementsRequestAction();
}

class AnnouncementsLoadedAction {
  const AnnouncementsLoadedAction(this.items);
  final List<Announcement> items;
}

class AnnouncementsFailureAction {
  const AnnouncementsFailureAction(this.message);
  final String message;
}

// ---------------- Events ----------------
class EventsRequestAction {
  const EventsRequestAction();
}

class EventsLoadedAction {
  const EventsLoadedAction(this.items);
  final List<DanceEvent> items;
}

class EventsFailureAction {
  const EventsFailureAction(this.message);
  final String message;
}

// ---------------- Event running order ----------------
class EventItemsRequestAction {
  const EventItemsRequestAction(this.eventId);
  final String eventId;
}

class EventItemsLoadedAction {
  const EventItemsLoadedAction(this.eventId, this.items);
  final String eventId;
  final List<EventItem> items;
}

class EventItemsFailureAction {
  const EventItemsFailureAction(this.eventId, this.message);
  final String eventId;
  final String message;
}

// ---------------- Event fees ----------------
class EventFeesRequestAction {
  const EventFeesRequestAction(this.eventId);
  final String eventId;
}

class EventFeesLoadedAction {
  const EventFeesLoadedAction(this.eventId, this.items);
  final String eventId;
  final List<EventFee> items;
}

class EventFeesFailureAction {
  const EventFeesFailureAction(this.eventId, this.message);
  final String eventId;
  final String message;
}

// ---------------- Gallery ----------------
class MediaRequestAction {
  const MediaRequestAction();
}

class MediaLoadedAction {
  const MediaLoadedAction(this.items);
  final List<MediaItem> items;
}

class MediaFailureAction {
  const MediaFailureAction(this.message);
  final String message;
}

// ---------------- Theory ----------------
class TheoryRequestAction {
  const TheoryRequestAction();
}

class TheoryLoadedAction {
  const TheoryLoadedAction(this.items);
  final List<TheoryNote> items;
}

class TheoryFailureAction {
  const TheoryFailureAction(this.message);
  final String message;
}

// ---------------- Institutes (sign-up dropdown) ----------------
class InstitutesRequestAction {
  const InstitutesRequestAction();
}

class InstitutesLoadedAction {
  const InstitutesLoadedAction(this.items);
  final List<Institute> items;
}

class InstitutesFailureAction {
  const InstitutesFailureAction(this.message);
  final String message;
}

// ---------------- Join requests (staff) ----------------
class PendingMembersRequestAction {
  const PendingMembersRequestAction();
}

class PendingMembersLoadedAction {
  const PendingMembersLoadedAction(this.items);
  final List<AppUser> items;
}

class PendingMembersFailureAction {
  const PendingMembersFailureAction(this.message);
  final String message;
}

/// Removes the member from the pending list once approved or rejected.
class MemberReviewedAction {
  const MemberReviewedAction(this.uid);
  final String uid;
}

// ---------------- Students (event participant picker) ----------------
class StudentsRequestAction {
  const StudentsRequestAction();
}

class StudentsLoadedAction {
  const StudentsLoadedAction(this.items);
  final List<AppUser> items;
}

class StudentsFailureAction {
  const StudentsFailureAction(this.message);
  final String message;
}

// ---------------- Directory (chat pickers, birthday board) ----------------
class DirectoryRequestAction {
  const DirectoryRequestAction();
}

class DirectoryLoadedAction {
  const DirectoryLoadedAction(this.items);
  final List<Member> items;
}

class DirectoryFailureAction {
  const DirectoryFailureAction(this.message);
  final String message;
}

// ---------------- Chat ----------------
class ChatsRequestAction {
  const ChatsRequestAction();
}

class ChatsLoadedAction {
  const ChatsLoadedAction(this.items);
  final List<Chat> items;
}

class ChatsFailureAction {
  const ChatsFailureAction(this.message);
  final String message;
}

class MessagesLoadedAction {
  const MessagesLoadedAction(this.chatId, this.items);
  final String chatId;
  final List<ChatMessage> items;
}

class ChatSendFailedAction {
  const ChatSendFailedAction(this.message);
  final String message;
}

class ClearChatSendErrorAction {
  const ClearChatSendErrorAction();
}

// ---------------- Attendance ----------------
class AttendanceRequestAction {
  const AttendanceRequestAction(this.date, {this.batchId = AttendanceRecord.allStudents});
  final DateTime date;
  final String batchId;
}

class AttendanceLoadedAction {
  const AttendanceLoadedAction(this.date, this.record, {this.batchId = AttendanceRecord.allStudents});
  final DateTime date;
  final String batchId;

  /// Null when attendance was not taken that day.
  final AttendanceRecord? record;
}

class AttendanceFailureAction {
  const AttendanceFailureAction(this.date, this.message, {this.batchId = AttendanceRecord.allStudents});
  final DateTime date;
  final String batchId;
  final String message;
}

/// Dispatched as soon as the guru taps Save, before the server confirms.
class AttendanceSavedAction {
  const AttendanceSavedAction(this.record);
  final AttendanceRecord record;
}

class AttendanceSaveFailedAction {
  const AttendanceSaveFailedAction(this.message);
  final String message;
}

class ClearAttendanceSaveErrorAction {
  const ClearAttendanceSaveErrorAction();
}

class AttendanceMonthRequestAction {
  const AttendanceMonthRequestAction(this.year, this.month);
  final int year;
  final int month;
}

class AttendanceMonthLoadedAction {
  const AttendanceMonthLoadedAction(this.year, this.month, this.items);
  final int year;
  final int month;
  final List<AttendanceRecord> items;
}

class AttendanceMonthFailureAction {
  const AttendanceMonthFailureAction(this.message);
  final String message;
}

/// A student's (or a parent's children's) own months, by student id.
class MyAttendanceRequestAction {
  const MyAttendanceRequestAction(this.year, this.month);
  final int year;
  final int month;
}

class MyAttendanceLoadedAction {
  const MyAttendanceLoadedAction(this.year, this.month, this.days);
  final int year;
  final int month;
  final Map<String, List<StudentDay>> days;
}

class MyAttendanceFailureAction {
  const MyAttendanceFailureAction(this.year, this.month, this.message);
  final int year;
  final int month;
  final String message;
}

// ---------------- Batches ----------------
class BatchesRequestAction {
  const BatchesRequestAction();
}

class BatchesLoadedAction {
  const BatchesLoadedAction(this.items);
  final List<Batch> items;
}

class BatchesFailureAction {
  const BatchesFailureAction(this.message);
  final String message;
}
