import 'package:dio/dio.dart';
import 'package:cinetracker/core/network/api_service.dart';

class AuthService {
  final ApiService apiService;

  AuthService(this.apiService);

  Future<String> login(String username, String password) async {
    final response = await apiService.dio.post(
      "/auth/login",
      data: {"username": username, "password": password},
    );
    return response.data;
  }

  Future<void> register(String username, String email, String password) async {
    await apiService.dio.post(
      "/auth/register/",
      data: {"username": username, "email": email, "password": password},
    );
  }
}
