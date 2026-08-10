import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/services/app_api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../shared/widgets/app_widgets.dart';
import '../ambassador/ambassador_home_screen.dart';
import '../awards/awards_home_screen.dart';
import '../exams/exam_history_screen.dart';
import '../materials/offline_materials_screen.dart';
import '../notifications/notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _privacyUrl = 'https://best-learnhub.vercel.app/privacy';
  static const _pricingUrl = '${AppConfig.siteUrl}/pricing/';

  bool? _subscribed;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    try {
      final subscribed = await AppApiClient.instance.refreshSubscriptionStatus();
      if (mounted) setState(() => _subscribed = subscribed);
    } catch (_) {
      if (mounted) setState(() => _subscribed = false);
    }
  }

  Future<void> _openPricing() async {
    await launchUrl(Uri.parse(_pricingUrl), mode: LaunchMode.externalApplication);
    // The student may have just paid on the website — refresh so the app
    // reflects it without needing a full app restart.
    _loadSubscription();
  }

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
          const SectionHeader(title: 'Earn'),
          PremiumCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _tile(context, Icons.people_alt_outlined, 'Ambassador Programme',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const AmbassadorHomeScreen()))),
                _divider(scheme),
                _tile(context, Icons.emoji_events_outlined, 'Excellence Awards',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const AwardsHomeScreen()))),
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
                _tile(context, Icons.assignment_turned_in_outlined, 'My Results',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ExamHistoryScreen()))),
                _divider(scheme),
                _tile(context, Icons.bookmark_outline_rounded, 'Offline Materials',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const OfflineMaterialsScreen()))),
                _divider(scheme),
                _tile(
                  context,
                  Icons.workspace_premium_outlined,
                  _subscribed == true ? 'Subscription — Active' : 'Subscribe',
                  _openPricing,
                ),
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
}
