/// Route paths, in one place (like a react-navigation route-name enum).
class Routes {
  Routes._();

  static const splash = '/splash';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const pendingApproval = '/pending-approval';
  static const approvals = '/approvals';
  static const dashboard = '/';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';

  static const students = '/students';
  static const studentNew = '/students/new';
  static String studentEdit(String id) => '/students/$id/edit';

  static const chat = '/chat';
  static const newChat = '/chat/new';
  static const newGroup = '/chat/new-group';
  static String chatRoom(String id) => '/chat/$id';

  static const attendance = '/attendance';
  static const myAttendance = '/my-attendance';
  static const batches = '/batches';
  static const payments = '/payments';
  static const uploadPayment = '/payments/upload';
  static const events = '/events';
  static const eventNew = '/events/new';
  static String eventDetail(String id) => '/events/$id';
  static String eventEdit(String id) => '/events/$id/edit';
  static String eventOrder(String id) => '/events/$id/order';
  static const eventFees = '/event-fees';
  static String eventFeeDetail(String id) => '/event-fees/$id';
  static const gallery = '/gallery';
  static const announcements = '/announcements';
  static const announcementNew = '/announcements/new';
  static String announcementEdit(String id) => '/announcements/$id/edit';
  static const theory = '/theory';
  static const theoryNew = '/theory/new';
  static String theoryDetail(String id) => '/theory/$id';
  static String theoryEdit(String id) => '/theory/$id/edit';
}
