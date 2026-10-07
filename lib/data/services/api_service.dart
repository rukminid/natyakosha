import '../../core/network/dio_client.dart';

/// Calls to your own HTTP endpoints (Cloud Functions), via the Dio client.
///
/// These endpoints are not part of this boilerplate yet; they show where
/// server-side work lives. See README → "Cloud Functions to add".
class ApiService {
  ApiService(this._client);

  final DioClient _client;

  /// Sets a new password for the account registered with [mobile]
  /// (10 digits). Called while signed out — see functions/index.js.
  Future<void> resetPasswordByMobile({required String mobile, required String newPassword}) =>
      _client.post<dynamic>(
        '/resetPasswordByMobile',
        data: {'mobile': mobile, 'newPassword': newPassword},
      );

  /// Ask the server to push a fee reminder to everyone still pending.
  Future<void> remindPendingEventFees({required String schoolId, required String eventId}) =>
      _client.post<dynamic>(
        '/remindPendingEventFees',
        data: {'schoolId': schoolId, 'eventId': eventId},
      );

  /// Monthly attendance + fee summary for the guru's dashboard.
  Future<Map<String, dynamic>> monthlyReport({
    required String schoolId,
    required String month,
  }) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/monthlyReport',
      query: {'schoolId': schoolId, 'month': month},
    );
    return data;
  }
}
