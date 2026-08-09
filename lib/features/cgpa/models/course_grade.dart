/// 5-point grading scale used by most Nigerian universities.
/// A=5, B=4, C=3, D=2, E=1, F=0.
class GradePoint {
  final String letter;
  final double point;
  const GradePoint(this.letter, this.point);

  static const all = <GradePoint>[
    GradePoint('A', 5),
    GradePoint('B', 4),
    GradePoint('C', 3),
    GradePoint('D', 2),
    GradePoint('E', 1),
    GradePoint('F', 0),
  ];

  static GradePoint byLetter(String l) =>
      all.firstWhere((g) => g.letter == l, orElse: () => all.first);
}

class CourseGrade {
  String code;
  int creditUnit;
  String grade; // letter

  CourseGrade({this.code = '', this.creditUnit = 3, this.grade = 'A'});

  double get point => GradePoint.byLetter(grade).point;
  double get qualityPoints => point * creditUnit;

  Map<String, dynamic> toJson() =>
      {'code': code, 'cu': creditUnit, 'grade': grade};

  factory CourseGrade.fromJson(Map<String, dynamic> j) => CourseGrade(
        code: (j['code'] ?? '') as String,
        creditUnit: (j['cu'] ?? 3) as int,
        grade: (j['grade'] ?? 'A') as String,
      );
}

class Semester {
  String title;
  List<CourseGrade> courses;

  Semester({required this.title, List<CourseGrade>? courses})
      : courses = courses ?? [CourseGrade()];

  int get totalUnits => courses.fold(0, (s, c) => s + c.creditUnit);
  double get totalQualityPoints =>
      courses.fold(0.0, (s, c) => s + c.qualityPoints);
  double get gpa => totalUnits == 0 ? 0 : totalQualityPoints / totalUnits;

  Map<String, dynamic> toJson() => {
        'title': title,
        'courses': courses.map((c) => c.toJson()).toList(),
      };

  factory Semester.fromJson(Map<String, dynamic> j) => Semester(
        title: (j['title'] ?? 'Semester') as String,
        courses: ((j['courses'] ?? []) as List)
            .map((e) => CourseGrade.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Classification of the resulting CGPA (5-point scale).
String degreeClass(double cgpa) {
  if (cgpa >= 4.5) return 'First Class';
  if (cgpa >= 3.5) return 'Second Class Upper';
  if (cgpa >= 2.4) return 'Second Class Lower';
  if (cgpa >= 1.5) return 'Third Class';
  if (cgpa > 0) return 'Pass';
  return '—';
}
