class MaterialModel {
  final int id;
  final int subjectId;
  final String title;
  final String? materialType; // pdf | text | image
  final String content;
  final String? fileUrl;
  final String? videoUrl;
  final int views;

  MaterialModel({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.materialType,
    required this.content,
    required this.fileUrl,
    required this.videoUrl,
    required this.views,
  });

  factory MaterialModel.fromMap(Map<String, dynamic> m) => MaterialModel(
        id: m['id'] as int,
        subjectId: m['subject_id'] as int,
        title: (m['title'] ?? '') as String,
        materialType: m['material_type'] as String?,
        content: (m['content'] ?? '') as String,
        fileUrl: m['file_url'] as String?,
        videoUrl: m['video_url'] as String?,
        views: (m['views'] ?? 0) as int,
      );

  bool get hasPdf => (fileUrl ?? '').isNotEmpty;
  bool get hasVideo => (videoUrl ?? '').isNotEmpty;
}
