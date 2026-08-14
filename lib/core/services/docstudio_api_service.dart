import 'dart:convert';

import 'app_api_client.dart';

class DocStudioException implements Exception {
  const DocStudioException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DocumentTypeModel {
  const DocumentTypeModel({
    required this.slug,
    required this.name,
    required this.description,
    required this.icon,
    required this.outputFormat,
    required this.sectionNoun,
    required this.defaultSections,
  });
  final String slug;
  final String name;
  final String description;
  final String icon;
  final String outputFormat; // 'docx' | 'pptx'
  final String sectionNoun;
  final List<String> defaultSections;

  factory DocumentTypeModel.fromJson(Map<String, dynamic> j) => DocumentTypeModel(
        slug: j['slug'] as String,
        name: j['name'] as String,
        description: (j['description'] ?? '') as String,
        icon: (j['icon'] ?? '') as String,
        outputFormat: j['output_format'] as String,
        sectionNoun: (j['section_noun'] ?? 'Section') as String,
        defaultSections: (j['default_sections'] as List).cast<String>(),
      );
}

class DocumentSectionModel {
  const DocumentSectionModel({
    required this.id,
    required this.title,
    required this.content,
    required this.order,
  });
  final int id;
  final String title;
  final String content;
  final int order;

  factory DocumentSectionModel.fromJson(Map<String, dynamic> j) => DocumentSectionModel(
        id: j['id'] as int,
        title: j['title'] as String,
        content: (j['content'] ?? '') as String,
        order: j['order'] as int,
      );
}

class DocumentModel {
  const DocumentModel({
    required this.id,
    required this.title,
    required this.topic,
    required this.instructions,
    required this.documentType,
    required this.isUnlocked,
    required this.updatedAt,
    this.sections,
  });
  final int id;
  final String title;
  final String topic;
  final String instructions;
  final DocumentTypeModel documentType;
  final bool isUnlocked;
  final String updatedAt;
  final List<DocumentSectionModel>? sections;

  factory DocumentModel.fromJson(Map<String, dynamic> j) => DocumentModel(
        id: j['id'] as int,
        title: j['title'] as String,
        topic: (j['topic'] ?? '') as String,
        instructions: (j['instructions'] ?? '') as String,
        documentType: DocumentTypeModel.fromJson(j['document_type'] as Map<String, dynamic>),
        isUnlocked: j['is_unlocked'] as bool,
        updatedAt: j['updated_at'] as String,
        sections: j['sections'] == null
            ? null
            : (j['sections'] as List)
                .map((e) => DocumentSectionModel.fromJson(e as Map<String, dynamic>))
                .toList(),
      );
}

/// Mirrors docstudio/views.py — AI-drafted projects/reports/slides, edited
/// section by section, then downloaded as a real .docx/.pptx.
class DocStudioApiService {
  DocStudioApiService._();
  static final DocStudioApiService instance = DocStudioApiService._();

  final AppApiClient _client = AppApiClient.instance;

  Future<T> _run<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AppApiException catch (e) {
      throw DocStudioException(e.message);
    }
  }

  Future<({List<DocumentTypeModel> types, bool isSubscriber})> types() => _run(() async {
        final resp = await _client.request('GET', '/api/docstudio/types/');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (
          types: (data['types'] as List)
              .map((e) => DocumentTypeModel.fromJson(e as Map<String, dynamic>))
              .toList(),
          isSubscriber: data['is_subscriber'] as bool,
        );
      });

  Future<List<DocumentModel>> documents() => _run(() async {
        final resp = await _client.request('GET', '/api/docstudio/documents/');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['documents'] as List)
            .map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<DocumentModel> create({
    required String typeSlug,
    required String title,
    required String topic,
    required String instructions,
    required List<String> sectionTitles,
  }) =>
      _run(() async {
        final resp = await _client.request('POST', '/api/docstudio/documents/create/', body: {
          'type_slug': typeSlug,
          'title': title,
          'topic': topic,
          'instructions': instructions,
          'section_titles': sectionTitles,
        });
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return DocumentModel.fromJson(data['document'] as Map<String, dynamic>);
      });

  Future<DocumentModel> detail(int documentId) => _run(() async {
        final resp = await _client.request('GET', '/api/docstudio/documents/$documentId/');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return DocumentModel.fromJson(data['document'] as Map<String, dynamic>);
      });

  Future<void> deleteDocument(int documentId) => _run(() async {
        final resp = await _client.request('POST', '/api/docstudio/documents/$documentId/delete/');
        _client.checkOk(resp);
      });

  Future<DocumentSectionModel> generateSection(int documentId, int sectionId) => _run(() async {
        final resp = await _client.request(
            'POST', '/api/docstudio/documents/$documentId/sections/$sectionId/generate/');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return DocumentSectionModel.fromJson(data['section'] as Map<String, dynamic>);
      });

  Future<void> saveSection(int documentId, int sectionId, {String? title, String? content}) =>
      _run(() async {
        final body = <String, dynamic>{};
        if (title != null) body['title'] = title;
        if (content != null) body['content'] = content;
        final resp = await _client.request(
            'POST', '/api/docstudio/documents/$documentId/sections/$sectionId/save/',
            body: body);
        _client.checkOk(resp);
      });

  Future<DocumentSectionModel> addSection(int documentId, String title) => _run(() async {
        final resp = await _client.request(
            'POST', '/api/docstudio/documents/$documentId/sections/add/', body: {'title': title});
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return DocumentSectionModel.fromJson(data['section'] as Map<String, dynamic>);
      });

  Future<void> deleteSection(int documentId, int sectionId) => _run(() async {
        final resp = await _client.request(
            'POST', '/api/docstudio/documents/$documentId/sections/$sectionId/delete/');
        _client.checkOk(resp);
      });

  Future<void> reorderSections(int documentId, List<int> orderedSectionIds) => _run(() async {
        final resp = await _client.request(
            'POST', '/api/docstudio/documents/$documentId/sections/reorder/',
            body: {'order': orderedSectionIds});
        _client.checkOk(resp);
      });

  Future<String> initiatePayment(int documentId) => _run(() async {
        final resp = await _client.request('POST', '/api/docstudio/documents/$documentId/pay/');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['authorization_url'] as String;
      });
}
