import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_locale.dart';
import '../../utils/util.dart';
import '../courts/courts_list_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().signIn(
            _usernameController.text.trim(),
            _passwordController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CourtsListScreen()),
      );
    } catch (e) {
      if (mounted) showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F2),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: kPrimaryColor,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(Icons.sports_tennis_rounded,
                          color: Colors.white, size: 46),
                    ),
                    const SizedBox(height: 18),
                    const Text('CourtSide',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor)),
                    const SizedBox(height: 4),
                    Text(tr(context, 'Rezerviši svoj teren'),
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    const SizedBox(height: 32),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(tr(context, 'Prijava'),
                                  style: const TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: tr(context, 'Korisničko ime'),
                                  prefixIcon: const Icon(Icons.person_outline),
                                ),
                                textInputAction: TextInputAction.next,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? tr(context, 'Unesite korisničko ime')
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscure,
                                decoration: InputDecoration(
                                  labelText: tr(context, 'Lozinka'),
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _login(),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? tr(context, 'Unesite lozinku')
                                    : null,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 50,
                                child: _loading
                                    ? const Center(child: CircularProgressIndicator())
                                    : ElevatedButton(
                                        onPressed: _login,
                                        child: Text(tr(context, 'Prijava')),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      child: Text(tr(context, 'Nemate nalog? Registruj se')),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _LoginLanguageToggle(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Language toggle for the login screen's light background (the shared
/// [LanguageToggle] widget uses white text, meant for the app's colored
/// AppBars).
class _LoginLanguageToggle extends StatelessWidget {
  const _LoginLanguageToggle();

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final targetLabel = locale.language == AppLanguage.bs ? 'EN' : 'BS';
    return TextButton.icon(
      onPressed: locale.toggle,
      icon: Icon(Icons.language, color: Colors.grey.shade700, size: 18),
      label: Text(targetLabel,
          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
    );
  }
}
