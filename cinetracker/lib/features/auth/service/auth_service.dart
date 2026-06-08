import 'package:cinetracker/core/network/api_service.dart';
import 'package:dio/dio.dart';

class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}

class LoginTokens {
  final String accessToken;
  final String refreshToken;

  LoginTokens({required this.accessToken, required this.refreshToken});
}

class AuthService {
  final ApiService apiService;

  AuthService(this.apiService);

  Future<LoginTokens> login(String username, String password) async {
    try {
      final response = await apiService.dio.post(
        "/auth/login",
        data: {"username": username, "password": password},
      );

      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        final dataMap = raw['data'] is Map<String, dynamic> ? raw['data'] as Map<String, dynamic> : raw;
        final accessToken =
            dataMap['accessToken']?.toString() ?? dataMap['access_token']?.toString() ?? dataMap['token']?.toString();
        final refreshToken =
            dataMap['refreshToken']?.toString() ?? dataMap['refresh_token']?.toString();

        if (accessToken != null &&
            accessToken.isNotEmpty &&
            refreshToken != null &&
            refreshToken.isNotEmpty) {
          return LoginTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
        }
      }

      throw AuthException(
        "Invalid login response: accessToken/refreshToken missing",
      );
    } on DioException catch (e) {
      throw AuthException(_resolveLoginErrorMessage(e));
    } catch (e) {
      throw AuthException("An unexpected error occurred during login.");
    }
  }

  String _resolveLoginErrorMessage(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    String? serverMessage;
    if (data is Map<String, dynamic>) {
      serverMessage =
          data['message']?.toString() ??
          data['error']?.toString() ??
          data['details']?.toString();
    } else if (data is String && data.trim().isNotEmpty) {
      serverMessage = data;
    }

    if (statusCode == 401) {
      return serverMessage ?? "Invalid username or password.";
    }

    if (statusCode == 403) {
      return serverMessage ?? "Please verify your email before logging in.";
    }

    return serverMessage ?? "Login failed. Please try again.";
  }

  Future<void> register(String username, String email, String password) async {
    final payload = {
      "username": username,
      "email": email,
      "password": password,
    };

    try {
      await apiService.dio.post("/auth/register", data: payload);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;

      // some spring setups map register with trailing slash only.
      if (statusCode == 404 || statusCode == 405) {
        try {
          await apiService.dio.post("/auth/register/", data: payload);
          return;
        } on DioException catch (fallbackError) {
          throw AuthException(_resolveRegisterErrorMessage(fallbackError));
        }
      }

      throw AuthException(_resolveRegisterErrorMessage(e));
    }
  }

  String _resolveRegisterErrorMessage(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    String? serverMessage;
    if (data is Map<String, dynamic>) {
      serverMessage =
          data['message']?.toString() ??
          data['error']?.toString() ??
          data['details']?.toString();
    } else if (data is String && data.trim().isNotEmpty) {
      serverMessage = data;
    }

    if (statusCode == 409) {
      return serverMessage ?? "Username or email already exists.";
    }

    if (statusCode == 400) {
      return serverMessage ?? "Please check your registration details.";
    }

    if (statusCode == 500) {
      return "Server error while creating account. Try again.";
    }

    return serverMessage ?? "Registration failed. Please try again.";
  }

  Future<void> forgotPassword(String email) async {
    try {
      await apiService.dio.post(
        "/auth/forgot-password",
        data: {"email": email},
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      String? serverMessage;
      if (data is Map<String, dynamic>) {
        serverMessage = data['message']?.toString() ?? data['error']?.toString();
      }
      throw AuthException(serverMessage ?? "Failed to request password reset. Please try again.");
    } catch (e) {
      throw AuthException("An unexpected error occurred.");
    }
  }

  Future<LoginTokens> googleLogin(String idToken) async {
    try {
      final response = await apiService.dio.post(
        "/auth/google",
        data: {"idToken": idToken},
      );

      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        final dataMap = raw['data'] is Map<String, dynamic> ? raw['data'] as Map<String, dynamic> : raw;
        final accessToken =
            dataMap['accessToken']?.toString() ?? dataMap['access_token']?.toString() ?? dataMap['token']?.toString();
        final refreshToken =
            dataMap['refreshToken']?.toString() ?? dataMap['refresh_token']?.toString();

        if (accessToken != null &&
            accessToken.isNotEmpty &&
            refreshToken != null &&
            refreshToken.isNotEmpty) {
          return LoginTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
        }
      }

      throw AuthException(
        "Invalid Google login response from server",
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      String? serverMessage;
      if (data is Map<String, dynamic>) {
        serverMessage = data['message']?.toString() ?? data['error']?.toString();
      }
      throw AuthException(serverMessage ?? "Google login failed. Please try again.");
    } catch (e) {
      throw AuthException("An unexpected error occurred during Google sign in.");
    }
  }
}
