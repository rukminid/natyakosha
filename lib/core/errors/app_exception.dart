import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// One error type the UI understands. Services convert raw
/// Firebase / Dio errors into this so view models only show [message].
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  static const offline = AppException(
    'You are offline. Please check your internet connection.',
    code: 'offline',
  );

  factory AppException.from(Object error) {
    if (error is AppException) return error;
    if (error is FirebaseAuthException) return _fromAuth(error);
    if (error is FirebaseException) {
      return AppException(error.message ?? 'Something went wrong.', code: error.code);
    }
    if (error is DioException) return _fromDio(error);
    return AppException('Something went wrong. Please try again.', code: '$error');
  }

  static AppException _fromAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return AppException('Incorrect email or password.', code: e.code);
      case 'too-many-requests':
        return AppException('Too many attempts. Try again in a few minutes.', code: e.code);
      case 'network-request-failed':
        return offline;
      default:
        return AppException(e.message ?? 'Sign-in failed.', code: e.code);
    }
  }

  static AppException _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const AppException('The server took too long to respond.', code: 'timeout');
      case DioExceptionType.connectionError:
        return offline;
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        final msg = data is Map<String, dynamic> && data['message'] is String
            ? data['message'] as String
            : 'Request failed (${e.response?.statusCode}).';
        return AppException(msg, code: '${e.response?.statusCode}');
      default:
        if (e.error is AppException) return e.error! as AppException;
        return AppException(e.message ?? 'Network error.', code: e.type.name);
    }
  }

  @override
  String toString() => 'AppException($code): $message';
}
