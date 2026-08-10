import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/services/app_api_client.dart';
import '../../core/services/offline_cache_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import '../exams/exam_years_screen.dart';
import '../subjects/models/subject.dart';
import 'material_detail_screen.dart';
import 'models/material_model.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key, required this.subject});
  final Subject subject;

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  late Future<List<MaterialModel>> _future;
  Set<int> _cachedIds = {};
  bool _offlineFallback = false;

  /// null while checking; Django's Subscription model is the source of
  /// truth (see AppApiClient.refreshSubscriptionStatus) — mirrors the
  /// website's @subscription_required on materials_list/material_detail,
  /// which the app never enforced before.
  bool? _subscribed;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _checkSubscription();
  }

  Future<void> _checkSubscription() async {
    try {
      final cached = AppApiClient.instance.cachedIsSubscribed;
      final subscribed = cached ?? await AppApiClient.instance.refreshSubscriptionStatus();
      if (mounted) setState(() => _subscribed = subscribed);
    } catch (_) {
      if (mounted) setState(() => _subscribed = false);
    }
  }

  Future<List<MaterialModel>> _load() async {
    try {
      final rows = await SupabaseService.client
          .from(AppConfig.tblMaterial)
          .select(
              'id, subject_id, title, material_type, content, file_url, video_url, views')
          .eq('subject_id', widget.subject.id)
          .order('created_at', ascending: false);
      final list = (rows as List)
          .map((e) => MaterialModel.fromMap(e as Map<String, dynamic>))
          .toList();
      final cached = await OfflineCacheService.instance.cachedForSubject(widget.subject.id);
      if (mounted) {
        setState(() {
          _cachedIds = cached.map((m) => m.id).toSet();
          _offlineFallback = false;
        });
      }
      return list;
    } catch (_) {
      // Network unreachable — fall back to whatever was saved for offline
      // reading (see OfflineCacheService), if anything was.
      final cached = await OfflineCacheService.instance.cachedForSubject(widget.subject.id);
      if (cached.isEmpty) rethrow;
      if (mounted) {
        setState(() {
          _cachedIds = cached.map((m) => m.id).toSet();
          _offlineFallback = true;
        });
      }
      return cached;
    }
  }

  ({IconData icon, Color color, String label}) _kindOf(MaterialModel m) {
    if (m.hasVideo) {
      return (icon: Icons.play_circle_rounded, color: AppTheme.danger, label: 'Video');
    }
    if (m.hasPdf || m.materialType == 'pdf') {
      return (icon: Icons.picture_as_pdf_rounded, color: AppTheme.brand, label: 'PDF');
    }
    if (m.materialType == 'image') {
      return (icon: Icons.image_rounded, color: AppTheme.accent, label: 'Slides');
    }
    return (icon: Icons.article_rounded, color: AppTheme.success, label: 'Notes');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.quiz_rounded),
            tooltip: 'Past Questions',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => ExamYearsScreen(subject: widget.subject)),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 10),
              child: Pill(widget.subject.code),
            ),
          ),
        ),
      ),
      body: _subscribed == null
          ? const SkeletonList()
          : (_subscribed == false ? _SubscriptionPaywall(subject: widget.subject) : _buildList()),
    );
  }

  Widget _buildList() {
    return FutureBuilder<List<MaterialModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load materials',
              message: snap.error.toString(),
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.inbox_rounded,
              title: 'Nothing here yet',
              message: 'Materials for this course will appear here soon.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length + (_offlineFallback ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                if (_offlineFallback && i == 0) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppTheme.rSm),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.offline_pin_rounded, color: AppTheme.warning, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('Showing your offline-saved materials — no connection.',
                              style: TextStyle(color: AppTheme.warning, fontSize: 12.5)),
                        ),
                      ],
                    ),
                  );
                }
                final m = items[i - (_offlineFallback ? 1 : 0)];
                final k = _kindOf(m);
                final isCached = _cachedIds.contains(m.id);
                return PremiumCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => MaterialDetailScreen(
                            material: m, isOffline: _offlineFallback)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: k.color.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(k.icon, color: k.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Pill(k.label, color: k.color),
                                const SizedBox(width: 8),
                                Icon(Icons.visibility_outlined,
                                    size: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text('${m.views}',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 12)),
                                if (isCached) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.bookmark_rounded,
                                      size: 14, color: AppTheme.warning),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
  }
}

class _SubscriptionPaywall extends StatelessWidget {
  const _SubscriptionPaywall({required this.subject});
  final Subject subject;

  Future<void> _openPricing() async {
    await launchUrl(Uri.parse('${AppConfig.siteUrl}/pricing/'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 20),
          Text('Subscribe to unlock ${subject.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            'Materials, notes and past questions for this course require an active '
            'subscription or free trial.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Subscribe now',
            icon: Icons.open_in_new_rounded,
            onPressed: _openPricing,
          ),
        ],
      ),
    );
  }
}
