import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../providers/auth_provider.dart';
import '../../utils/util.dart';
import '../../utils/validators.dart';
import '../../providers/api_error.dart';

/// Step two of recovering an account: the emailed code and the new password.
///
/// [email] is carried over from the previous screen so it does not have to be typed twice;
/// the screen is also reachable on its own for someone who closed the app after asking for
/// the code, which is why the field stays editable.
class ResetPasswordScreen extends StatefulWidget {
  final String? email;

  const ResetPasswordScreen({super.key, this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().resetPassword(
            email: _emailController.text.trim(),
            code: _codeController.text.trim(),
            newPassword: _passwordController.text,
          );
      if (!mounted) return;
      // Back to the sign-in screen, which is what the user came here to be able to do.
      Navigator.of(context).popUntil((route) => route.isFirst);
      showSuccess(context, 'Lozinka je promijenjena. Prijavite se novom lozinkom.');
    } catch (e) {
      if (mounted) showError(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Nova lozinka')),
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
                tr(context, 'Kod smo poslali na vašu email adresu. Vrijedi 15 minuta.'),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: tr(context, 'Kod iz emaila'),
                  prefixIcon: const Icon(Icons.pin_outlined),
                  counterText: '',
                ),
                validator: (v) {
                  final code = v?.trim() ?? '';
                  if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                    return trMessage(context, 'Kod se sastoji od 6 cifara');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: tr(context, 'Nova lozinka'),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                validator: (v) => (v == null || v.length < 6)
                    ? trMessage(context, 'Lozinka mora imati najmanje 6 znakova.')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: tr(context, 'Potvrda nove lozinke'),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                validator: (v) => v != _passwordController.text
                    ? trMessage(context, 'Lozinke se ne podudaraju')
                    : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: _saving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submit,
                        child: Text(tr(context, 'Postavi lozinku')),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
