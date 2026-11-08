import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/profile.dart';
import '../../providers/profile_provider.dart';
import '../../utils/authorization.dart';
import '../../utils/image_validation.dart';
import '../../utils/util.dart';
import '../../utils/validators.dart';
import '../../widgets/dialog_header.dart';
import '../../providers/api_error.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  final _phoneController = TextEditingController();

  Profile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _imageVersion = 0;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await context.read<ProfileProvider>().get();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _firstNameController.text = profile.firstName;
        _lastNameController.text = profile.lastName;
        _phoneController.text = profile.phoneNumber ?? '';
      });
    } catch (e) {
      if (mounted) {
        final message = describeError(e);
        setState(() => _error = trMessage(context, message));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<ProfileProvider>();
    try {
      final updated = await provider.update(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );
      Authorization.firstName = updated.firstName;
      Authorization.lastName = updated.lastName;
      if (mounted) showSuccess(context, 'Profil je ažuriran.');
    } catch (e) {
      if (mounted) showError(context, describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The picture as the avatar loads it, which is also the key the image cache keeps it under.
  NetworkImage get _profileImage => NetworkImage(
        context.read<ProfileProvider>().imageUrl,
        headers: {'Authorization': 'Bearer ${Authorization.token}'},
      );

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    if (!mounted) return;
    final provider = context.read<ProfileProvider>();
    final cachedImage = _profileImage;
    try {
      final bytes = await picked.readAsBytes();
      final contentType = imageContentTypeFor(picked.name);
      final error = validateImage(bytes, contentType);
      if (error != null) {
        if (mounted) showError(context, error);
        return;
      }
      await provider.uploadImage(bytes, picked.name, contentType);
      // The new picture is served from the same address as the old one, so the cached copy
      // has to go for it to be fetched — here and whenever the profile is opened again.
      await cachedImage.evict();
      if (!mounted) return;
      final profile = _profile!;
      setState(() {
        _profile = Profile(
          id: profile.id,
          username: profile.username,
          email: profile.email,
          firstName: profile.firstName,
          lastName: profile.lastName,
          phoneNumber: profile.phoneNumber,
          hasProfileImage: true,
        );
        _imageVersion++;
      });
      showSuccess(context, 'Profilna slika je ažurirana.');
    } catch (e) {
      if (mounted) showError(context, describeError(e));
    }
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: dialogHeader(ctx, tr(ctx, 'Promjena lozinke')),
        content: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: tr(ctx, 'Trenutna lozinka')),
                  validator: (v) => (v == null || v.isEmpty) ? trMessage(ctx, 'Unesite lozinku') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: tr(ctx, 'Nova lozinka')),
                  validator: (v) => (v == null || v.length < 6)
                      ? trMessage(ctx, 'Lozinka mora imati najmanje 6 znakova.')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: tr(ctx, 'Potvrda nove lozinke')),
                  validator: (v) => v != newController.text
                      ? trMessage(ctx, 'Lozinke se ne podudaraju')
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr(ctx, 'Odustani')),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
            },
            child: Text(tr(ctx, 'Sačuvaj')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      await context.read<ProfileProvider>().changePassword(
            currentPassword: currentController.text,
            newPassword: newController.text,
          );
      if (mounted) showSuccess(context, 'Lozinka je promijenjena.');
    } catch (e) {
      if (mounted) showError(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Moj profil')),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: Text(tr(context, 'Pokušaj ponovo'))),
                      ],
                    ),
                  ),
                )
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    final profile = _profile!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: kPrimaryColor.withValues(alpha: 0.12),
                    backgroundImage: profile.hasProfileImage ? _profileImage : null,
                    key: ValueKey(_imageVersion),
                    child: profile.hasProfileImage
                        ? null
                        : const Icon(Icons.person, size: 48, color: kPrimaryColor),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: kPrimaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              initialValue: profile.username,
              enabled: false,
              decoration: InputDecoration(labelText: tr(context, 'Korisničko ime')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: profile.email ?? '',
              enabled: false,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(labelText: tr(context, 'Ime')),
              validator: (v) => (v == null || v.trim().isEmpty) ? trMessage(context, 'Unesite ime') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(labelText: tr(context, 'Prezime')),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? trMessage(context, 'Unesite prezime') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: tr(context, 'Broj telefona')),
              validator: (v) => validatePhone(context, v, required: false),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: _saving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(onPressed: _save, child: Text(tr(context, 'Sačuvaj'))),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: _changePassword,
                child: Text(tr(context, 'Promijeni lozinku')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
