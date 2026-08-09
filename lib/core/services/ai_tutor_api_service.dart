import 'dart:convert';

import 'app_api_client.dart';

class AiTutorException implements Exception {
  const AiTutorException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AiChatTurn {
  const AiChatTurn({required this.role, required this.text});
  final String role; // 'user' | 'model'
  final String text;

  factory AiChatTurn.fromJson(Map<String, dynamic> json) => AiChatTurn(
        role: json['role'] as String,
        text: json['text'] as String,
      );
}

/// Talks to the website's AI tutor chat API (learning/gemini_service.py,
/// exposed via learning/views.py api_ai_tutor_*) — Gemini itself is only
/// ever called server-side, so no API key ships inside this app.
class AiTutorApiService {
  AiTutorApiService._();
  static final AiTutorApiService instance = AiTutorApiService._();

  final AppApiClient _client = AppApiClient.instance;

  Future<List<AiChatTurn>> history() async {
    try {
      final resp = await _client.request('GET', '/api/ai-tutor/history/');
      _client.checkOk(resp);
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return (data['messages'] as List)
          .map((e) => AiChatTurn.fromJson(e as Map<String, dynamic>))
          .toList();
    } on AppApiException catch (e) {
      throw AiTutorException(e.message);
    }
  }

  Future<String> send(String message) async {
    try {
      final resp = await _client.request('POST', '/api/ai-tutor/send/',
          body: {'message': message});
      _client.checkOk(resp);
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['reply'] as String;
    } on AppApiException catch (e) {
      throw AiTutorException(e.message);
    }
  }
}
