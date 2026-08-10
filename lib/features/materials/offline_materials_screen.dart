import 'package:flutter/material.dart';

import '../../core/services/offline_cache_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'material_detail_screen.dart';
import 'models/material_model.dart';

/// Browsable even with no network — everything here comes from the local
/// cache (see OfflineCacheService), so this is the entry point for
/// materials a student saved before going offline.
class OfflineMaterialsScreen extends StatefulWidget {
  const OfflineMaterialsScreen({super.key});

  @override
  State<OfflineMaterialsScreen> createState() => _OfflineMaterialsScreenState();
}

class _OfflineMaterialsScreenState extends State<OfflineMaterialsScreen> {
  late Future<List<MaterialModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = OfflineCacheService.instance.allCached();
  }

  Future<void> _remove(MaterialModel material) async {
    await OfflineCacheService.instance.remove(material.id);
    setState(() => _future = OfflineCacheService.instance.allCached());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Materials')),
      body: FutureBuilder<List<MaterialModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'No offline materials yet',
              message: 'Tap the bookmark icon on any material to save it for offline reading.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final m = items[i];
              return PremiumCard(
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => MaterialDetailScreen(material: m, isOffline: true)),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.bookmark_rounded, color: AppTheme.warning),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(m.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: scheme.onSurfaceVariant),
                      onPressed: () => _remove(m),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
