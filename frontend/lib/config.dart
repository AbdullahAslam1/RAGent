import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    if (kIsWeb) return "http://localhost:8080";
    if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:8080"; // Android emulator -> your PC
    }
    return "http://localhost:8080";
  }

  // Keep this list identical to ALLOWED_MODELS in agent.py
  static const List<String> models = [
    "gemini-3.8-flash",
    "gemini-3.1-pro",
    "gemini-3.7-flash",
    "gemini-3.5-flash-lite",
  ];

  static const String defaultModel = "gemini-3.8-flash";

  static const int maxUploadBytes = 10 * 1024 * 1024; // matches the backend
}