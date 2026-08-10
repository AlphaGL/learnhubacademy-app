import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../shared/widgets/app_widgets.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_friendly(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('Invalid login')) return 'Wrong phone number or password.';
    return s.replaceFirst('Exception: ', '');
  }

  Future<void> _phoneLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    await _run(() async {
      await auth.signInWithPhone(
          phone: _phone.text.trim(), password: _password.text);
      await AnalyticsService.instance.logLogin('phone');
    });
  }

  // Google Sign-In disabled — persistent OAuth config issues, revisit later.
  // Future<void> _googleLogin() async {
  //   final auth = context.read<AuthService>();
  //   await _run(() async {
  //     await auth.signInWithGoogle();
  //     await AnalyticsService.instance.logLogin('google');
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    const Center(child: AppLogo(size: 76))
                        .animate()
                        .scale(duration: 500.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 22),
                    Text('Welcome back 👋',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Sign in to continue learning',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().length < 7)
                          ? 'Enter a valid phone number'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'At least 6 characters'
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ForgotPasswordScreen()),
                                ),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GradientButton(
                      label: 'Sign in',
                      loading: _loading,
                      onPressed: _loading ? null : _phoneLogin,
                    ),
                    // Google Sign-In disabled — persistent OAuth config
                    // issues, revisit later. See _googleLogin in this file
                    // and AuthService.signInWithGoogle.
                    //
                    // Row(children: [
                    //   Expanded(
                    //       child: Divider(
                    //           color: scheme.outlineVariant.withOpacity(0.6))),
                    //   Padding(
                    //     padding: const EdgeInsets.symmetric(horizontal: 12),
                    //     child: Text('or continue with',
                    //         style: TextStyle(color: scheme.onSurfaceVariant)),
                    //   ),
                    //   Expanded(
                    //       child: Divider(
                    //           color: scheme.outlineVariant.withOpacity(0.6))),
                    // ]),
                    // const SizedBox(height: 20),
                    // OutlinedButton.icon(
                    //   onPressed: _loading ? null : _googleLogin,
                    //   icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                    //   label: const Text('Google'),
                    // ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("No account?",
                            style:
                                TextStyle(color: scheme.onSurfaceVariant)),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => const SignupScreen()),
                                  ),
                          child: const Text('Create one'),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
            ),
          ),
        ),
      ),
    );
  }
}
