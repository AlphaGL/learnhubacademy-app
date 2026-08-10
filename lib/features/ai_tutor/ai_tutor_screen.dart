import 'package:flutter/material.dart';

import '../../core/services/ai_tutor_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';

class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key, this.initialPrompt});

  /// Set when opened from a material's "Explain with AI" — sent
  /// automatically once history has loaded, same as the website's
  /// ai-tutor/?prompt= auto-send.
  final String? initialPrompt;

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _ChatBubble {
  _ChatBubble({required this.role, required this.text, this.pending = false});
  final String role;
  String text;
  bool pending;
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final _messages = <_ChatBubble>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loadingHistory = true;
  bool _sending = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await AiTutorApiService.instance.history();
      setState(() {
        _messages.addAll(
            history.map((h) => _ChatBubble(role: h.role, text: h.text)));
        _loadingHistory = false;
      });
      _scrollToBottom();
      if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
        _send(widget.initialPrompt!.trim());
      }
    } on AiTutorException catch (e) {
      setState(() {
        _loadError = e.message;
        _loadingHistory = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? overrideText]) async {
    final text = overrideText ?? _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    _inputController.clear();
    final pendingBubble = _ChatBubble(role: 'model', text: 'Thinking…', pending: true);
    setState(() {
      _messages.add(_ChatBubble(role: 'user', text: text));
      _messages.add(pendingBubble);
      _sending = true;
    });
    _scrollToBottom();

    try {
      final reply = await AiTutorApiService.instance.send(text);
      setState(() {
        pendingBubble
          ..text = reply
          ..pending = false;
      });
    } on AiTutorException catch (e) {
      setState(() {
        pendingBubble
          ..text = e.message
          ..pending = false;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tutor'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(scheme)),
          _buildInputBar(scheme),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load the AI tutor',
        message: _loadError!,
        onRetry: () {
          setState(() {
            _loadError = null;
            _loadingHistory = true;
          });
          _loadHistory();
        },
      );
    }
    if (_messages.isEmpty) {
      return const EmptyState(
        icon: Icons.smart_toy_outlined,
        title: 'Ask me anything',
        message: 'I can explain a topic step by step, give worked examples, '
            'or quiz you to check your understanding.',
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _BubbleWidget(bubble: _messages[i]),
    );
  }

  Widget _buildInputBar(ColorScheme scheme) {
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
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Type your question…',
                  isDense: true,
                ),
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

class _BubbleWidget extends StatelessWidget {
  const _BubbleWidget({required this.bubble});
  final _ChatBubble bubble;

  @override
  Widget build(BuildContext context) {
    final isUser = bubble.role == 'user';
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.brand : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
        ),
        child: Opacity(
          opacity: bubble.pending ? 0.6 : 1,
          child: Text(
            bubble.text,
            style: TextStyle(
              color: isUser ? Colors.white : scheme.onSurface,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }
}
