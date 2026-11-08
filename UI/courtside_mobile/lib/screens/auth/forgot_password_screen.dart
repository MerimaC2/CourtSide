import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../providers/auth_provider.dart';
import '../../utils/util.dart';
import '../../utils/validators.dart';
import 'reset_password_screen.dart';
import '../../providers/api_error.dart';

/// Step one of recovering an account: the address the code is sent to.
///
/// The server answers the same way whether or not the address is registered, so this screen
/// can only ever say that the email was sent — anything more would let anyone check which
/// addresses have accounts.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    final email = _emailController.text.trim();
    try {
      await context.read<AuthProvider>().requestPasswordReset(email);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email)),
      );
    } catch (e) {
      if (mounted) showError(context, describeError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Zaboravljena lozinka')),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(context,
                    'Unesite email adresu vašeg naloga i poslat ćemo vam kod za novu lozinku.'),
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: tr(context, 'Email'),
                  prefixIcon: const Icon(Icons.mail_outline),
                ),
                validator: (v) => validateEmail(context, v),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: _sending
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submit,
                        child: Text(tr(context, 'Pošalji kod')),
                      ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
                ),
                child: Text(tr(context, 'Već imam kod')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
