import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/env.dart';
import '../errors/app_exception.dart';
import '../utils/app_logger.dart';
import 'connectivity_service.dart';

/// Axios-style HTTP client: one configured instance with interceptors.
/// Used for Cloud Functions endpoints (reminders, reports) and any
/// future REST API. Firestore/Storage calls go through the Firebase SDKs.
class DioClient {
  DioClient(this._connectivity) {
    dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: Duration(milliseconds: Env.apiTimeoutMs),
        receiveTimeout: Duration(milliseconds: Env.apiTimeoutMs),
        headers: {'Accept': 'application/json'},
      ),
    );
    dio.interceptors.addAll([
      _OfflineInterceptor(_connectivity),
      _AuthInterceptor(),
      if (Env.enableLogs) _LogInterceptor(),
    ]);
  }

  final ConnectivityService _connectivity;
  late final Dio dio;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _wrap(() => dio.get<T>(path, queryParameters: query));

  Future<T> post<T>(String path, {Object? data}) =>
      _wrap(() => dio.post<T>(path, data: data));

  Future<T> put<T>(String path, {Object? data}) =>
      _wrap(() => dio.put<T>(path, data: data));

  Future<T> delete<T>(String path) => _wrap(() => dio.delete<T>(path));

  Future<T> _wrap<T>(Future<Response<T>> Function() call) async {
    try {
      final res = await call();
      return res.data as T;
    } catch (e) {
      throw AppException.from(e);
    }
  }
}

/// Fails fast with a friendly error instead of waiting for a timeout.
class _OfflineInterceptor extends Interceptor {
  _OfflineInterceptor(this._connectivity);
  final ConnectivityService _connectivity;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!await _connectivity.isOnline()) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: AppException.offline,
        ),
      );
      return;
    }
    handler.next(options);
  }
}

/// Attaches the Firebase ID token so Cloud Functions can verify the caller.
class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}

class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.d('→ ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    AppLogger.d('← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.w('✗ ${err.requestOptions.uri}: ${err.message}');
    handler.next(err);
  }
}
