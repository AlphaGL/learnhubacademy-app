import 'dart:convert';

import 'app_api_client.dart';

class AiTutorException implements Exception {
  const AiTutorException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum ChatAttachmentType { image, audio }

class AiChatTurn {
  const AiChatTurn({
    required this.role,
    required this.text,
    this.attachmentUrl,
    this.attachmentType,
  });
  final String role; // 'user' | 'model'
  final String text;
  final String? attachmentUrl;
  final String? attachmentType; // 'image' | 'audio'

  factory AiChatTurn.fromJson(Map<String, dynamic> json) {
    final url = json['attachment_url'] as String?;
    final type = json['attachment_type'] as String?;
    return AiChatTurn(
      role: json['role'] as String,
      text: json['text'] as String,
      attachmentUrl: (url != null && url.isNotEmpty) ? url : null,
      attachmentType: (type != null && type.isNotEmpty) ? type : null,
    );
  }
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

  /// [attachmentBytes] must already be in a Django-accepted format:
  /// image/png|jpeg|webp, or audio/wav — see [attachmentContentType].
  Future<String> send(
    String message, {
    List<int>? attachmentBytes,
    ChatAttachmentType? attachmentType,
    String? attachmentFilename,
  }) async {
    try {
      final resp = await _client.requestMultipart(
        '/api/ai-tutor/send/',
        fields: {'message': message},
        fileField: attachmentBytes != null ? 'attachment' : null,
        fileBytes: attachmentBytes,
        filename: attachmentFilename,
        contentType: attachmentType == null ? null : _contentTypeFor(attachmentType, attachmentFilename),
      );
      _client.checkOk(resp);
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['reply'] as String;
    } on AppApiException catch (e) {
      throw AiTutorException(e.message);
    }
  }

  String _contentTypeFor(ChatAttachmentType type, String? filename) {
    if (type == ChatAttachmentType.audio) return 'audio/wav';
    final ext = (filename ?? '').toLowerCase();
    if (ext.endsWith('.png')) return 'image/png';
    if (ext.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
