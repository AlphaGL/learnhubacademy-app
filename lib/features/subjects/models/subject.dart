class Subject {
  final int id;
  final String name;
  final String code;
  final String description;
  final String semester; // 'first' | 'second' | 'both'

  Subject({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.semester,
  });

  factory Subject.fromMap(Map<String, dynamic> m) => Subject(
        id: m['id'] as int,
        name: (m['name'] ?? '') as String,
        code: (m['code'] ?? '') as String,
        description: (m['description'] ?? '') as String,
        semester: (m['semester'] ?? 'first') as String,
      );

  String get semesterLabel => switch (semester) {
        'second' => 'Second Semester',
        'both' => 'Both Semesters',
        _ => 'First Semester',
      };
}
