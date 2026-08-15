import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/services/studynotes_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import 'study_note_detail_screen.dart';

const int _maxUploadBytes = 15 * 1024 * 1024;

class StudyNoteCreateScreen extends StatefulWidget {
  const StudyNoteCreateScreen({super.key});

  @override
  State<StudyNoteCreateScreen> createState() => _StudyNoteCreateScreenState();
}

class _StudyNoteCreateScreenState extends State<StudyNoteCreateScreen> {
  final _titleController = TextEditingController();
  PlatformFile? _picked;
  bool _creating = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not read that file.')));
      }
      return;
    }
    if (file.size > _maxUploadBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('That PDF is larger than 15MB.')));
      }
      return;
    }
    setState(() => _picked = file);
  }

  Future<void> _create() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please give your note a title.')));
      return;
    }
    if (_picked == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please choose a PDF to upload.')));
      return;
    }

    setState(() => _creating = true);
    try {
      final note = await StudyNotesApiService.instance.create(
        title: title,
        fileBytes: _picked!.bytes!,
        filename: _picked!.name,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => StudyNoteDetailScreen(noteId: note.id)),
        );
      }
    } on StudyNotesException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Upload a PDF')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. Week 5 Lecture Notes — Cell Biology',
            ),
          ),
          const SizedBox(height: 20),
          Text('PDF file (max 15MB)',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(AppTheme.rLg),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant, width: 1.5),
                borderRadius: BorderRadius.circular(AppTheme.rLg),
              ),
              child: Column(
                children: [
                  Icon(
                    _picked != null ? Icons.picture_as_pdf_rounded : Icons.upload_file_rounded,
                    size: 36,
                    color: AppTheme.brand,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _picked?.name ?? 'Tap to choose a PDF',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: _picked != null ? FontWeight.w700 : FontWeight.w500,
                      color: _picked != null ? null : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(label: 'Upload & continue', loading: _creating, onPressed: _creating ? null : _create),
        ],
      ),
    );
  }
}
