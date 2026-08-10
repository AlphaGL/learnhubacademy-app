import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import '../materials/materials_screen.dart';
import 'models/subject.dart';

/// Mirrors the website's first/second semester split (semester_subjects
/// view) — a subject with semester='both' shows up under either tab.
class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<List<Subject>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _future = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Subject>> _load() async {
    final rows = await SupabaseService.client
        .from(AppConfig.tblSubject)
        .select('id, name, code, description, semester')
        .order('name');
    return (rows as List)
        .map((e) => Subject.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static const _palette = [
    AppTheme.brand,
    AppTheme.accent,
    AppTheme.success,
    AppTheme.warning,
    AppTheme.brand2,
    AppTheme.danger,
  ];

  List<Subject> _filter(List<Subject> all, String semester) {
    final bySemester =
        all.where((s) => s.semester == semester || s.semester == 'both').toList();
    if (_query.isEmpty) return bySemester;
    return bySemester
        .where((s) =>
            s.name.toLowerCase().contains(_query) || s.code.toLowerCase().contains(_query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'First Semester'),
            Tab(text: 'Second Semester'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or code…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Subject>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SkeletonList();
                }
                if (snap.hasError) {
                  return EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load courses',
                    message: snap.error.toString(),
                    onRetry: () => setState(() => _future = _load()),
                  );
                }
                final all = snap.data ?? [];
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _SubjectList(items: _filter(all, 'first'), palette: _palette),
                    _SubjectList(items: _filter(all, 'second'), palette: _palette),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectList extends StatelessWidget {
  const _SubjectList({required this.items, required this.palette});
  final List<Subject> items;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No courses found',
        message: 'Try a different search term or check the other semester.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final s = items[i];
        final color = palette[i % palette.length];
        return PremiumCard(
          padding: const EdgeInsets.all(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MaterialsScreen(subject: s)),
          ),
          child: Row(
            children: [
              Container(
                height: 50,
                width: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  s.code.isNotEmpty ? s.code.substring(0, 1).toUpperCase() : '?',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Pill(s.code, color: color),
                        const SizedBox(width: 6),
                        if (s.semester == 'both')
                          Flexible(
                            child: Text('Both semesters',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 12)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        );
      },
    );
  }
}
