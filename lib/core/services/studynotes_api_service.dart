import 'dart:convert';

import 'app_api_client.dart';

class StudyNotesException implements Exception {
  const StudyNotesException(this.message);
  final String message;
  @override
  String toString() => message;
}

class StudyNoteModel {
  const StudyNoteModel({
    required this.id,
    required this.title,
    required this.sourceFilename,
    required this.summary,
    required this.status,
    required this.audioUrl,
    required this.isUnlocked,
    required this.updatedAt,
  });
  final int id;
  final String title;
  final String sourceFilename;
  final String summary;
  final String status; // 'draft' | 'ready'
  final String audioUrl;
  final bool isUnlocked;
  final String updatedAt;

  factory StudyNoteModel.fromJson(Map<String, dynamic> j) => StudyNoteModel(
        id: j['id'] as int,
        title: j['title'] as String,
        sourceFilename: (j['source_filename'] ?? '') as String,
        summary: (j['summary'] ?? '') as String,
        status: j['status'] as String,
        audioUrl: (j['audio_url'] ?? '') as String,
        isUnlocked: j['is_unlocked'] as bool,
        updatedAt: j['updated_at'] as String,
      );
}

/// Mirrors studynotes/views.py — upload a PDF, AI reads and summarizes it.
/// Capped at one summary a day per student (subscriber or not) to bound
/// Gemini token spend on document-sized input; non-subscribers additionally
/// pay ₦500 per note via the same Paystack flow as Document Studio.
class StudyNotesApiService {
  StudyNotesApiService._();
  static final StudyNotesApiService instance = StudyNotesApiService._();

  final AppApiClient _client = AppApiClient.instance;

  Future<T> _run<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AppApiException catch (e) {
      throw StudyNotesException(e.message);
    }
  }

  Future<
      ({
        List<StudyNoteModel> notes,
        bool isSubscriber,
        bool usedToday,
        bool usedAudioToday,
        int maxUploadBytes
      })> home() => _run(() async {
        final resp = await _client.request('GET', '/api/studynotes/');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (
          notes: (data['notes'] as List)
              .map((e) => StudyNoteModel.fromJson(e as Map<String, dynamic>))
              .toList(),
          isSubscriber: data['is_subscriber'] as bool,
          usedToday: data['used_today'] as bool,
          usedAudioToday: data['used_audio_today'] as bool,
          maxUploadBytes: data['max_upload_bytes'] as int,
        );
      });

  Future<StudyNoteModel> create({
    required String title,
    required List<int> fileBytes,
    required String filename,
  }) =>
      _run(() async {
        final resp = await _client.requestMultipart(
          '/api/studynotes/create/',
          fields: {'title': title},
          fileField: 'source_file',
          fileBytes: fileBytes,
          filename: filename,
          contentType: 'application/pdf',
        );
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return StudyNoteModel.fromJson(data['note'] as Map<String, dynamic>);
      });

  Future<StudyNoteModel> detail(int noteId) => _run(() async {
        final resp = await _client.request('GET', '/api/studynotes/$noteId/');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return StudyNoteModel.fromJson(data['note'] as Map<String, dynamic>);
      });

  Future<void> deleteNote(int noteId) => _run(() async {
        final resp = await _client.request('POST', '/api/studynotes/$noteId/delete/');
        _client.checkOk(resp);
      });

  Future<StudyNoteModel> generate(int noteId) => _run(() async {
        final resp = await _client.request('POST', '/api/studynotes/$noteId/generate/');
        _client.checkOk(
          resp,
          subscriptionStatus: 429,
          subscriptionMessage: "You've used your AI summary for today — come back tomorrow.",
        );
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return StudyNoteModel.fromJson(data['note'] as Map<String, dynamic>);
      });

  Future<StudyNoteModel> generateAudio(int noteId) => _run(() async {
        final resp = await _client.request('POST', '/api/studynotes/$noteId/generate-audio/');
        _client.checkOk(
          resp,
          subscriptionStatus: 429,
          subscriptionMessage: "You've used your audio generation for today — come back tomorrow.",
        );
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return StudyNoteModel.fromJson(data['note'] as Map<String, dynamic>);
      });

  Future<String> initiatePayment(int noteId) => _run(() async {
        final resp = await _client.request('POST', '/api/studynotes/$noteId/pay/');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['authorization_url'] as String;
      });
}
