import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../shared/widgets/app_widgets.dart';
import '../notifications/notifications_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _privacyUrl = 'https://best-learnhub.vercel.app/privacy';

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final name = (user?.userMetadata?['full_name'] as String?) ?? 'Student';
    final email = user?.email ?? '';
    final theme = context.watch<ThemeController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          PremiumCard(
            gradient: AppTheme.brandGradient,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.9))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Preferences'),
          PremiumCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                      theme.isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: scheme.primary),
                  title: const Text('Dark mode'),
                  value: theme.isDark,
                  onChanged: (v) => theme.toggle(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Account'),
          PremiumCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _tile(context, Icons.notifications_none_rounded, 'Notifications',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()))),
                _divider(scheme),
                _tile(context, Icons.workspace_premium_outlined, 'Subscription',
                    () => _comingSoon(context)),
                _divider(scheme),
                _tile(context, Icons.privacy_tip_outlined, 'Privacy policy',
                    () => launchUrl(Uri.parse(_privacyUrl),
                        mode: LaunchMode.externalApplication)),
                _divider(scheme),
                _tile(context, Icons.info_outline_rounded, 'About', () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'LearnHub',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© ${DateTime.now().year} LearnHub',
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PremiumCard(
            onTap: () => context.read<AuthService>().signOut(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.logout_rounded, color: AppTheme.danger),
                const SizedBox(width: 14),
                const Text('Sign out',
                    style: TextStyle(
                        color: AppTheme.danger, fontWeight: FontWeight.w700)),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme scheme) => Divider(
      height: 1, indent: 56, color: scheme.outlineVariant.withOpacity(0.4));

  Widget _tile(BuildContext context, IconData icon, String title,
      VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('In-app subscription is coming soon.')),
    );
  }
}
