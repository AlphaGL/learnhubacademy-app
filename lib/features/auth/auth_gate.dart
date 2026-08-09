import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/notification_service.dart';
import '../home/home_shell.dart';
import 'login_screen.dart';

/// Decides between the authenticated app and the login screen, reacting to
/// Supabase auth state changes.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (auth.isSignedIn) {
      // Make sure this device's push token is linked to the user.
      NotificationService.instance.syncTokenForCurrentUser();
      return const HomeShell();
    }
    return const LoginScreen();
  }
}
