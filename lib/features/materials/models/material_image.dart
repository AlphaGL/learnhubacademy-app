class MaterialImage {
  final int id;
  final int materialId;
  final String imageUrl;
  final String caption;
  final int order;

  MaterialImage({
    required this.id,
    required this.materialId,
    required this.imageUrl,
    required this.caption,
    required this.order,
  });

  factory MaterialImage.fromMap(Map<String, dynamic> m) => MaterialImage(
        id: m['id'] as int,
        materialId: m['material_id'] as int,
        imageUrl: (m['image_url'] ?? '') as String,
        caption: (m['caption'] ?? '') as String,
        order: (m['order'] ?? 0) as int,
      );
}
