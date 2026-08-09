import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import 'models/course_grade.dart';

class CgpaCalculatorScreen extends StatefulWidget {
  const CgpaCalculatorScreen({super.key});

  @override
  State<CgpaCalculatorScreen> createState() => _CgpaCalculatorScreenState();
}

class _CgpaCalculatorScreenState extends State<CgpaCalculatorScreen> {
  static const _prefsKey = 'cgpa_semesters_v1';
  final List<Semester> _semesters = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final list = (jsonDecode(raw) as List)
          .map((e) => Semester.fromJson(e as Map<String, dynamic>))
          .toList();
      _semesters.addAll(list);
    }
    if (_semesters.isEmpty) {
      _semesters.add(Semester(title: 'Semester 1'));
    }
    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_semesters.map((s) => s.toJson()).toList()),
    );
  }

  double get _cgpa {
    final units = _semesters.fold(0, (s, sem) => s + sem.totalUnits);
    final qp = _semesters.fold(0.0, (s, sem) => s + sem.totalQualityPoints);
    return units == 0 ? 0 : qp / units;
  }

  void _addSemester() {
    setState(() => _semesters
        .add(Semester(title: 'Semester ${_semesters.length + 1}')));
    _save();
  }

  void _addCourse(Semester sem) {
    setState(() => sem.courses.add(CourseGrade()));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final cgpa = _cgpa;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CGPA Calculator'),
        actions: [
          IconButton(
            tooltip: 'Reset',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _semesters
                  ..clear()
                  ..add(Semester(title: 'Semester 1'));
              });
              _save();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CgpaHeader(cgpa: cgpa),
          const SizedBox(height: 16),
          for (int i = 0; i < _semesters.length; i++)
            _SemesterCard(
              semester: _semesters[i],
              onChanged: () {
                setState(() {});
                _save();
              },
              onAddCourse: () => _addCourse(_semesters[i]),
              onRemove: _semesters.length > 1
                  ? () {
                      setState(() => _semesters.removeAt(i));
                      _save();
                    }
                  : null,
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addSemester,
            icon: const Icon(Icons.add),
            label: const Text('Add semester'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CgpaHeader extends StatelessWidget {
  const _CgpaHeader({required this.cgpa});
  final double cgpa;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.brand, AppTheme.accent],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('Cumulative GPA',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(cgpa.toStringAsFixed(2),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.bold)),
          Text(degreeClass(cgpa),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SemesterCard extends StatelessWidget {
  const _SemesterCard({
    required this.semester,
    required this.onChanged,
    required this.onAddCourse,
    this.onRemove,
  });

  final Semester semester;
  final VoidCallback onChanged;
  final VoidCallback onAddCourse;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(semester.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.brand.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('GPA ${semester.gpa.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: AppTheme.brand,
                          fontWeight: FontWeight.bold)),
                ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (final course in semester.courses)
              _CourseRow(
                course: course,
                onChanged: onChanged,
                onRemove: semester.courses.length > 1
                    ? () {
                        semester.courses.remove(course);
                        onChanged();
                      }
                    : null,
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddCourse,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add course'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({
    required this.course,
    required this.onChanged,
    this.onRemove,
  });

  final CourseGrade course;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Course code
          Expanded(
            flex: 4,
            child: TextFormField(
              initialValue: course.code,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Course code',
              ),
              onChanged: (v) {
                course.code = v;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          // Credit unit
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<int>(
              value: course.creditUnit,
              isDense: true,
              decoration: const InputDecoration(isDense: true),
              items: [for (int u = 1; u <= 6; u++) u]
                  .map((u) =>
                      DropdownMenuItem(value: u, child: Text('$u CU')))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  course.creditUnit = v;
                  onChanged();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          // Grade
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: course.grade,
              isDense: true,
              decoration: const InputDecoration(isDense: true),
              items: GradePoint.all
                  .map((g) => DropdownMenuItem(
                      value: g.letter, child: Text(g.letter)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  course.grade = v;
                  onChanged();
                }
              },
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
