import 'package:flutter/material.dart';

import '../../core/services/ambassador_api_service.dart';
import '../../shared/widgets/app_widgets.dart';

class AmbassadorSettingsScreen extends StatefulWidget {
  const AmbassadorSettingsScreen({super.key});

  @override
  State<AmbassadorSettingsScreen> createState() => _AmbassadorSettingsScreenState();
}

class _AmbassadorSettingsScreenState extends State<AmbassadorSettingsScreen> {
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  String _payoutPreference = 'cash';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await AmbassadorApiService.instance.getSettings();
      _bankNameController.text = (data['bank_name'] ?? '') as String;
      _accountNumberController.text = (data['account_number'] ?? '') as String;
      _accountNameController.text = (data['account_name'] ?? '') as String;
      _payoutPreference = (data['payout_preference'] ?? 'cash') as String;
    } on AmbassadorException catch (_) {
      // First-time settings — leave fields blank.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AmbassadorApiService.instance.saveSettings(
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        accountName: _accountNameController.text.trim(),
        payoutPreference: _payoutPreference,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } on AmbassadorException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bank details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PremiumCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _bankNameController,
                        decoration: const InputDecoration(labelText: 'Bank name'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _accountNumberController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Account number'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _accountNameController,
                        decoration: const InputDecoration(labelText: 'Account name'),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _payoutPreference,
                        decoration: const InputDecoration(labelText: 'Payout preference'),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('Cash (Bank Transfer)')),
                          DropdownMenuItem(
                              value: 'extension', child: Text('Subscription Extension')),
                        ],
                        onChanged: (v) => setState(() => _payoutPreference = v ?? 'cash'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GradientButton(label: 'Save', loading: _saving, onPressed: _saving ? null : _save),
              ],
            ),
    );
  }
}
