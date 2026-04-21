import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../../../navigation/presentation/pages/main_navigation_page.dart';

class UpdatePasswordPage extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final String selectedCity;
  final ValueChanged<String> onCityChanged;

  const UpdatePasswordPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.selectedCity,
    required this.onCityChanged,
  });

  @override
  State<UpdatePasswordPage> createState() => _UpdatePasswordPageState();
}

class _UpdatePasswordPageState extends State<UpdatePasswordPage> {
  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Ingresá una contraseña';
    if (text.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Repetí la contraseña';
    if (text != passwordController.text.trim()) {
      return 'Las contraseñas no coinciden';
    }
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
      await _authService.updatePassword(
        newPassword: passwordController.text.trim(),
      );

      if (!mounted) return;

      _showSnackBar(
        'Contraseña actualizada correctamente',
        backgroundColor: Colors.green,
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MainNavigationPage(
            isDarkMode: widget.isDarkMode,
            onThemeChanged: widget.onThemeChanged,
            selectedCity: widget.selectedCity,
            onCityChanged: widget.onCityChanged,
          ),
        ),
        (route) => false,
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
        title: const Text('Nueva contraseña'),
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
                  'Creá una nueva contraseña',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Elegí una contraseña segura para volver a entrar a tu cuenta.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
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
                          controller: passwordController,
                          obscureText: obscurePassword,
                          validator: _validatePassword,
                          decoration: InputDecoration(
                            labelText: 'Nueva contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: confirmPasswordController,
                          obscureText: obscureConfirmPassword,
                          validator: _validateConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Repetir contraseña',
                            prefixIcon: const Icon(Icons.lock_reset_outlined),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  obscureConfirmPassword =
                                      !obscureConfirmPassword;
                                });
                              },
                              icon: Icon(
                                obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: isLoading ? null : _submit,
                            child: Text(
                              isLoading
                                  ? 'Guardando...'
                                  : 'Actualizar contraseña',
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