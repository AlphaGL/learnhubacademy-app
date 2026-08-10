import 'package:flutter/material.dart';

import '../../core/services/studygroups_api_service.dart';
import '../../shared/widgets/app_widgets.dart';
import 'group_detail_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _courseController = TextEditingController();
  bool _isPublic = true;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _courseController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please give your group a name.')));
      return;
    }
    setState(() => _creating = true);
    try {
      final slug = await StudyGroupsApiService.instance.createGroup(
        name: name,
        description: _descriptionController.text.trim(),
        course: _courseController.text.trim(),
        isPublic: _isPublic,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => GroupDetailScreen(slug: slug)));
      }
    } on StudyGroupsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Study Group')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Group name'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _courseController,
            decoration: const InputDecoration(labelText: 'Course (optional)'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Public group'),
            subtitle: const Text('Anyone can find and join. Off = invite-only.'),
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
          ),
          const SizedBox(height: 20),
          GradientButton(label: 'Create group', loading: _creating, onPressed: _creating ? null : _create),
        ],
      ),
    );
  }
}
