import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/app_api_client.dart';
import '../../core/services/studygroups_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.slug});
  final String slug;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late Future<GroupDetail> _future;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = StudyGroupsApiService.instance.detail(widget.slug);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = StudyGroupsApiService.instance.detail(widget.slug));
    await _future;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      await StudyGroupsApiService.instance.join(widget.slug);
      await _refresh();
    } on StudyGroupsException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave group?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Leave')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await StudyGroupsApiService.instance.leave(widget.slug);
      if (mounted) Navigator.of(context).pop();
    } on StudyGroupsException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this group?'),
        content: const Text('This removes the group and all its messages for everyone. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await StudyGroupsApiService.instance.deleteGroup(widget.slug);
      if (mounted) Navigator.of(context).pop();
    } on StudyGroupsException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    _messageController.clear();
    setState(() => _sending = true);
    try {
      await StudyGroupsApiService.instance.postMessage(widget.slug, text);
      await _refresh();
      _scrollToBottom();
    } on StudyGroupsException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteMessage(GroupMessage msg) async {
    try {
      await StudyGroupsApiService.instance.deleteMessage(widget.slug, msg.id);
      await _refresh();
    } on StudyGroupsException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _showInviteDialog() async {
    final controller = TextEditingController();
    final identifier = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite someone'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Username or email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Invite')),
        ],
      ),
    );
    if (identifier == null || identifier.isEmpty) return;
    try {
      await StudyGroupsApiService.instance.invite(widget.slug, identifier);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite sent')));
      }
    } on StudyGroupsException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _showMembers(GroupDetail detail) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        children: [
          Text('Members (${detail.members.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          for (final m in detail.members)
            ListTile(
              leading: CircleAvatar(child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?')),
              title: Text(m.name),
              trailing: m.role == 'owner' ? const Pill('Owner') : null,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<GroupDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            return Scaffold(
              appBar: AppBar(),
              body: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load this group',
                message: snap.error.toString(),
                onRetry: _refresh,
              ),
            );
          }
          final detail = snap.data!;
          _scrollToBottom();
          return Scaffold(
            appBar: AppBar(
              title: Text(detail.group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [
                IconButton(
                  icon: const Icon(Icons.people_outline_rounded),
                  onPressed: () => _showMembers(detail),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'invite') _showInviteDialog();
                    if (value == 'leave') _leave();
                    if (value == 'delete') _deleteGroup();
                  },
                  itemBuilder: (context) => [
                    if (detail.isAdmin)
                      const PopupMenuItem(value: 'invite', child: Text('Invite someone')),
                    if (detail.isMember && !detail.isAdmin)
                      const PopupMenuItem(value: 'leave', child: Text('Leave group')),
                    if (detail.isAdmin)
                      const PopupMenuItem(value: 'delete', child: Text('Delete group')),
                  ],
                ),
              ],
            ),
            body: detail.isMember
                ? Column(
                    children: [
                      Expanded(child: _buildMessages(detail)),
                      _buildInputBar(),
                    ],
                  )
                : _buildJoinPrompt(detail),
          );
        },
      ),
    );
  }

  Widget _buildJoinPrompt(GroupDetail detail) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups_rounded, size: 56, color: AppTheme.brand),
            const SizedBox(height: 16),
            Text(detail.group.name,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                textAlign: TextAlign.center),
            if (detail.group.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(detail.group.description, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            GradientButton(label: 'Join group', loading: _busy, onPressed: _busy ? null : _join),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages(GroupDetail detail) {
    if (detail.messages.isEmpty) {
      return const EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No messages yet',
        message: 'Say hello to get the discussion started.',
      );
    }
    final myId = AppApiClient.instance.cachedDjangoUserId;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: detail.messages.length,
      itemBuilder: (context, i) {
        final msg = detail.messages[i];
        final isMine = myId != null && msg.authorId == myId;
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: (isMine || detail.isAdmin)
                ? () => _deleteMessage(msg)
                : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              decoration: BoxDecoration(
                color: isMine
                    ? AppTheme.brand
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMine ? 14 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMine)
                    Text(msg.author,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            color: isMine ? Colors.white70 : AppTheme.brand)),
                  Text(msg.body,
                      style: TextStyle(color: isMine ? Colors.white : null, height: 1.4)),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(msg.createdAt),
                    style: TextStyle(
                        fontSize: 10, color: isMine ? Colors.white70 : Colors.black45),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return DateFormat('MMM d, h:mm a').format(dt.toLocal());
  }

  Widget _buildInputBar() {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant.withOpacity(0.5))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(hintText: 'Message…', isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
