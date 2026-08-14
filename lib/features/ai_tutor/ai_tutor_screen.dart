import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

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
  _ChatBubble({
    required this.role,
    required this.text,
    this.pending = false,
    this.attachmentType,
    this.attachmentUrl,
    this.localImageBytes,
  });
  final String role;
  String text;
  bool pending;
  final String? attachmentType; // 'image' | 'audio'
  final String? attachmentUrl;
  final Uint8List? localImageBytes;
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final _messages = <_ChatBubble>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  bool _loadingHistory = true;
  bool _sending = false;
  bool _isRecording = false;
  String? _loadError;

  XFile? _pendingImage;
  Uint8List? _pendingImageBytes;
  String? _pendingAudioPath;

  static const _maxImageBytes = 8 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await AiTutorApiService.instance.history();
      setState(() {
        _messages.addAll(history.map((h) => _ChatBubble(
              role: h.role,
              text: h.text,
              attachmentType: h.attachmentType,
              attachmentUrl: h.attachmentUrl,
            )));
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

  // ── Attachments ──────────────────────────────────────────────────────
  Future<void> _showAttachSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('That image is too large (max 8MB).')));
        }
        return;
      }
      setState(() {
        _pendingImage = file;
        _pendingImageBytes = bytes;
        _pendingAudioPath = null;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not access that image.')));
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _pendingAudioPath = path;
        _pendingImage = null;
        _pendingImageBytes = null;
      });
      return;
    }
    if (!await _audioRecorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Microphone permission is required to record a voice note.')));
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/ai_tutor_voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    // WAV is the one audio format confirmed to work with Gemini's inline
    // multimodal input — see learning/views.py AI_CHAT_ALLOWED_AUDIO_TYPES.
    await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: path);
    setState(() => _isRecording = true);
  }

  void _clearPendingAttachment() {
    setState(() {
      _pendingImage = null;
      _pendingImageBytes = null;
      _pendingAudioPath = null;
    });
  }

  // ── Sending ──────────────────────────────────────────────────────────
  Future<void> _send([String? overrideText]) async {
    final text = overrideText ?? _inputController.text.trim();
    final hasAttachment = _pendingImageBytes != null || _pendingAudioPath != null;
    if (text.isEmpty && !hasAttachment) return;
    if (_sending) return;
    _inputController.clear();

    List<int>? attachmentBytes;
    ChatAttachmentType? attachmentType;
    String? filename;
    Uint8List? localImageBytes;
    String? bubbleAttachmentType;

    if (_pendingImageBytes != null) {
      attachmentBytes = _pendingImageBytes;
      attachmentType = ChatAttachmentType.image;
      filename = _pendingImage?.name ?? 'photo.jpg';
      localImageBytes = _pendingImageBytes;
      bubbleAttachmentType = 'image';
    } else if (_pendingAudioPath != null) {
      attachmentBytes = await File(_pendingAudioPath!).readAsBytes();
      attachmentType = ChatAttachmentType.audio;
      filename = 'voice-note.wav';
      bubbleAttachmentType = 'audio';
    }
    _clearPendingAttachment();

    final pendingBubble = _ChatBubble(role: 'model', text: 'Thinking…', pending: true);
    setState(() {
      _messages.add(_ChatBubble(
        role: 'user',
        text: text,
        attachmentType: bubbleAttachmentType,
        localImageBytes: localImageBytes,
      ));
      _messages.add(pendingBubble);
      _sending = true;
    });
    _scrollToBottom();

    try {
      final reply = await AiTutorApiService.instance.send(
        text,
        attachmentBytes: attachmentBytes,
        attachmentType: attachmentType,
        attachmentFilename: filename,
      );
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
        message: 'Type a question, attach a photo of a problem, or record a voice note.',
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
    final hasPendingAttachment = _pendingImageBytes != null || _pendingAudioPath != null;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPendingAttachment)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: scheme.surfaceContainerHighest.withOpacity(0.5),
              child: Row(
                children: [
                  if (_pendingImageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_pendingImageBytes!, width: 40, height: 40, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Photo attached', style: TextStyle(fontSize: 13))),
                  ] else ...[
                    Icon(Icons.mic_rounded, color: scheme.primary),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Voice note ready', style: TextStyle(fontSize: 13))),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: _clearPendingAttachment,
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(6, 8, 12, 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outlineVariant.withOpacity(0.5))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  tooltip: 'Attach a photo',
                  onPressed: _sending || _isRecording ? null : _showAttachSheet,
                ),
                IconButton(
                  icon: Icon(_isRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
                      color: _isRecording ? AppTheme.danger : null),
                  tooltip: _isRecording ? 'Stop recording' : 'Record a voice note',
                  onPressed: _sending ? null : _toggleRecording,
                ),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !_isRecording,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: _isRecording ? 'Recording…' : 'Type your question…',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending || _isRecording ? null : () => _send(),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
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
    final isImage = bubble.attachmentType == 'image';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(isImage ? 8 : 12),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (bubble.attachmentType == 'image') _buildImage(),
              if (bubble.attachmentType == 'audio') _buildAudio(isUser, scheme),
              if (bubble.text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: bubble.attachmentType != null ? 8 : 0,
                    left: isImage ? 4 : 0,
                    right: isImage ? 4 : 0,
                  ),
                  child: Text(
                    bubble.text,
                    style: TextStyle(color: isUser ? Colors.white : scheme.onSurface, height: 1.45),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    Widget image;
    if (bubble.localImageBytes != null) {
      image = Image.memory(bubble.localImageBytes!, fit: BoxFit.cover);
    } else if (bubble.attachmentUrl != null) {
      image = CachedNetworkImage(imageUrl: bubble.attachmentUrl!, fit: BoxFit.cover);
    } else {
      return const SizedBox();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 200), child: image),
    );
  }

  Widget _buildAudio(bool isUser, ColorScheme scheme) {
    return InkWell(
      onTap: bubble.attachmentUrl != null
          ? () => launchUrl(Uri.parse(bubble.attachmentUrl!), mode: LaunchMode.externalApplication)
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_fill_rounded,
              color: isUser ? Colors.white : scheme.primary, size: 28),
          const SizedBox(width: 8),
          Text('Voice note',
              style:
                  TextStyle(color: isUser ? Colors.white : scheme.onSurface, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
