import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../storage/token_storage.dart';
import '../navigation/app_navigator.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  late final Dio dio;
  late final Dio _refreshDio;
  final TokenStorage _tokenStorage = TokenStorage();
  bool _isForcingLogout = false;
  Future<bool>? _refreshInFlight;

  ApiService._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: dotenv.get("BASE_URL"),
        headers: {"Content-Type": "application/json"},
      ),
    );

    _refreshDio = Dio(
      BaseOptions(
        baseUrl: dotenv.get("BASE_URL"),
        headers: {"Content-Type": "application/json"},
      ),
    );

    dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException error, ErrorInterceptorHandler handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshAccessToken();
          if (refreshed) {
            try {
              // Retry original request
              final cloneReq = await dio.request(
                error.requestOptions.path,
                options: Options(
                  method: error.requestOptions.method,
                  headers: error.requestOptions.headers,
                ),
                data: error.requestOptions.data,
                queryParameters: error.requestOptions.queryParameters,
              );
              return handler.resolve(cloneReq);
            } catch (e) {
              return handler.next(error);
            }
          } else {
            await _forceLogout();
            return handler.next(error);
          }
        }
        return handler.next(error);
      },
    ));
  }

  void setToken(String token) {
    dio.options.headers["Authorization"] = "Bearer $token";
  }

  void clearToken() {
    dio.options.headers.remove("Authorization");
  }

  Future<bool> _refreshAccessToken() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _performRefresh();
    _refreshInFlight = future;

    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _refreshDio.post(
        "/auth/refresh",
        data: {"refreshToken": refreshToken},
      );

      final accessToken = _extractAccessToken(response.data);
      if (accessToken == null || accessToken.isEmpty) {
        return false;
      }

      final nextRefreshToken = _extractRefreshToken(response.data);

      await _tokenStorage.saveAccessToken(accessToken);
      if (nextRefreshToken != null && nextRefreshToken.isNotEmpty) {
        await _tokenStorage.saveRefreshToken(nextRefreshToken);
      }

      setToken(accessToken);
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  String? _extractAccessToken(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final data = raw['data'] ?? raw;
      if (data is Map<String, dynamic>) {
        return data["accessToken"]?.toString() ??
               data["token"]?.toString() ??
               data["access_token"]?.toString();
      }
    }
    return null;
  }

  String? _extractRefreshToken(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final data = raw['data'] ?? raw;
      if (data is Map<String, dynamic>) {
        return data["refreshToken"]?.toString() ??
               data["refresh_token"]?.toString();
      }
    }
    return null;
  }

  Future<void> _forceLogout() async {
    if (_isForcingLogout) return;

    _isForcingLogout = true;
    try {
      clearToken();
      await _tokenStorage.clearTokens();
      _navigateToLogin();
    } finally {
      _isForcingLogout = false;
    }
  }

  void _navigateToLogin() {
    final navigator = appNavigatorKey.currentState;
    if (navigator != null) {
      navigator.pushNamedAndRemoveUntil('/login', (route) => false);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    });
  }
}
