import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'interceptors.dart';

Dio createDio() {
  var baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
  if (!kIsWeb && Platform.isAndroid && baseUrl.contains('localhost')) {
    // Android emulator must use 10.0.2.2 to reach host machine
    baseUrl = baseUrl.replaceFirst('localhost', '10.0.2.2');
  }

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));
  dio.interceptors.add(AuthInterceptor());
  return dio;
}

final dioInstance = createDio();
