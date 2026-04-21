import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_service.dart';
import 'update_password_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final String selectedCity;
  final ValueChanged<String> onCityChanged;

  const ForgotPasswordPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.selectedCity,
    required this.onCityChanged,
  });

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();

  StreamSubscription<AuthState>? _authSubscription;

  bool isLoading = false;
  bool emailSent = false;
  bool _openedUpdatePassword = false;

  @override
  void initState() {
    super.initState();

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      if (event == AuthChangeEvent.passwordRecovery &&
          !_openedUpdatePassword &&
          mounted) {
        _openedUpdatePassword = true;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UpdatePasswordPage(
              isDarkMode: widget.isDarkMode,
              onThemeChanged: widget.onThemeChanged,
              selectedCity: widget.selectedCity,
              onCityChanged: widget.onCityChanged,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Ingresá tu correo';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(text)) return 'Ingresá un correo válido';
    return null;
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      await _authService.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        emailSent = true;
      });

      _showSnackBar(
        'Te enviamos un email para restablecer tu contraseña',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      String message = e.toString();
      if (message.contains('Exception:')) {
        message = message.replaceFirst('Exception: ', '');
      }
      _showSnackBar(message);
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 12),
                Text(
                  'Olvidé mi contraseña',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresá tu correo y te vamos a enviar un email para crear una nueva contraseña.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                if (emailSent)
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.22),
                      ),
                    ),
                    child: Text(
                      'Email enviado a ${emailController.text.trim()}. Abrí el enlace desde el mail para crear tu nueva contraseña.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.2),
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: isLoading ? null : _submit,
                            child: Text(
                              isLoading
                                  ? 'Enviando...'
                                  : 'Enviar email de recuperación',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}