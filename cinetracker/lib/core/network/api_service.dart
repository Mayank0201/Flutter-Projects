import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: dotenv.get("BASE_URL"),
      headers: {"Content-Type": "application/json"},
    ),
  );

  void setToken(String token) {
    dio.options.headers["Authorization"] = "Bearer $token";
  }
}
