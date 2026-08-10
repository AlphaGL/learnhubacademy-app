import 'package:flutter/material.dart';

import '../../core/services/studygroups_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

class StudyGroupsListScreen extends StatefulWidget {
  const StudyGroupsListScreen({super.key});

  @override
  State<StudyGroupsListScreen> createState() => _StudyGroupsListScreenState();
}

class _StudyGroupsListScreenState extends State<StudyGroupsListScreen> {
  late Future<GroupsDirectory> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = StudyGroupsApiService.instance.list();
  }

  Future<void> _refresh() async {
    setState(() => _future = StudyGroupsApiService.instance.list(query: _query));
    await _future;
  }

  void _openGroup(String slug) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GroupDetailScreen(slug: slug)))
        .then((_) => _refresh());
  }

  Future<void> _respondInvite(GroupInvite invite, bool accept) async {
    try {
      final slug = await StudyGroupsApiService.instance.respondInvite(invite.id, accept);
      await _refresh();
      if (accept && slug != null && mounted) _openGroup(slug);
    } on StudyGroupsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Groups')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create'),
        onPressed: () async {
          final created = await Navigator.of(context)
              .push<bool>(MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
          if (created == true) _refresh();
        },
      ),
      body: FutureBuilder<GroupsDirectory>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load Study Groups',
              message: snap.error.toString(),
              onRetry: () => setState(() => _future = StudyGroupsApiService.instance.list()),
            );
          }
          final dir = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search public groups…',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: (_) => _refresh(),
                ),
                if (dir.pendingInvites.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Invites'),
                  for (final invite in dir.pendingInvites)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PremiumCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(invite.groupName,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('Invited by ${invite.invitedBy}',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 12.5)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _respondInvite(invite, false),
                                    child: const Text('Decline'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => _respondInvite(invite, true),
                                    child: const Text('Accept'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                if (dir.myGroups.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'My Groups'),
                  for (final g in dir.myGroups) ...[
                    _GroupTile(group: g, onTap: () => _openGroup(g.slug)),
                    const SizedBox(height: 10),
                  ],
                ],
                const SizedBox(height: 20),
                const SectionHeader(title: 'Discover'),
                if (dir.publicGroups.isEmpty)
                  const EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'No public groups found',
                    message: 'Try a different search, or create your own group.',
                  )
                else
                  for (final g in dir.publicGroups) ...[
                    _GroupTile(group: g, onTap: () => _openGroup(g.slug)),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 60),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, required this.onTap});
  final StudyGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.groups_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    ),
                    if (group.isVerified)
                      const Icon(Icons.verified_rounded, color: AppTheme.brand, size: 16),
                    if (!group.isPublic) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.lock_outline_rounded, size: 14, color: scheme.onSurfaceVariant),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (group.course.isNotEmpty) ...[
                      Pill(group.course),
                      const SizedBox(width: 8),
                    ],
                    Text('${group.memberCount} members',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
