import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import '../materials/material_detail_screen.dart';
import '../materials/materials_screen.dart';
import '../materials/models/material_model.dart';
import '../subjects/models/subject.dart';

/// Mirrors the website's /search/ page — searches courses and materials by
/// name (exam years aren't included: that table isn't granted direct
/// Supabase read access, unlike Subject/Material which already are).
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<Subject> _subjects = [];
  List<MaterialModel> _materials = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _query = query);
    if (query.isEmpty) {
      setState(() {
        _subjects = [];
        _materials = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final subjectRows = await SupabaseService.client
          .from(AppConfig.tblSubject)
          .select('id, name, code, description, semester')
          .or('name.ilike.%$query%,code.ilike.%$query%')
          .limit(20);
      final materialRows = await SupabaseService.client
          .from(AppConfig.tblMaterial)
          .select('id, subject_id, title, material_type, content, file_url, video_url, views')
          .ilike('title', '%$query%')
          .limit(30);
      if (!mounted) return;
      setState(() {
        _subjects =
            (subjectRows as List).map((e) => Subject.fromMap(e as Map<String, dynamic>)).toList();
        _materials = (materialRows as List)
            .map((e) => MaterialModel.fromMap(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Search courses, materials…',
            border: InputBorder.none,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_query.isEmpty) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: 'Search LearnHub',
        message: 'Find courses and materials by name.',
      );
    }
    if (_loading) return const SkeletonList();
    if (_subjects.isEmpty && _materials.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results',
        message: 'Try a different search term.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_subjects.isNotEmpty) ...[
          SectionHeader(title: 'Courses (${_subjects.length})'),
          const SizedBox(height: 8),
          for (final s in _subjects) ...[
            PremiumCard(
              padding: const EdgeInsets.all(14),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MaterialsScreen(subject: s)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: AppTheme.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  ),
                  const SizedBox(width: 8),
                  Pill(s.code),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
        ],
        if (_materials.isNotEmpty) ...[
          SectionHeader(title: 'Materials (${_materials.length})'),
          const SizedBox(height: 8),
          for (final m in _materials) ...[
            PremiumCard(
              padding: const EdgeInsets.all(14),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => MaterialDetailScreen(material: m))),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded, color: AppTheme.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(m.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}
