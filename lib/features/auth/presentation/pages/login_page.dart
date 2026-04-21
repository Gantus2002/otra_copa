import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import 'forgot_password_page.dart';
import '../../../navigation/presentation/pages/main_navigation_page.dart';

class LoginPage extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final String selectedCity;
  final ValueChanged<String> onCityChanged;

  const LoginPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.selectedCity,
    required this.onCityChanged,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  bool isResendingEmail = false;
  bool obscurePassword = true;

  String? verificationEmail;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    fullNameController.dispose();
    super.dispose();
  }

  String? _validateFullName(String? value) {
    if (isLogin) return null;
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Ingresá tu nombre completo';
    if (text.length < 3) return 'Nombre demasiado corto';
    return null;
  }

  String? _validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Ingresá tu correo';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(text)) return 'Correo inválido';
    return null;
  }

  String? _validatePassword(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Ingresá tu contraseña';
    if (!isLogin && text.length < 6) {
      return 'Mínimo 6 caracteres';
    }
    return null;
  }

  void _showSnackBar(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final fullName = fullNameController.text.trim();

    setState(() => isLoading = true);

    try {
      if (isLogin) {
        await _authService.signIn(
          email: email,
          password: password,
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainNavigationPage(
              isDarkMode: widget.isDarkMode,
              onThemeChanged: widget.onThemeChanged,
              selectedCity: widget.selectedCity,
              onCityChanged: widget.onCityChanged,
            ),
          ),
        );
      } else {
        await _authService.signUp(
          email: email,
          password: password,
          fullName: fullName,
        );

        if (!mounted) return;

        setState(() {
          verificationEmail = email;
          isLogin = true;
          passwordController.clear();
        });

        _showSnackBar(
          'Te enviamos un email para activar tu cuenta 📩',
          color: Colors.green,
        );
      }
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');

      if (msg.contains('confirmar tu email')) {
        msg = 'Confirmá tu email antes de ingresar';
      }

      _showSnackBar(msg);
    } finally {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _resendEmail() async {
    final email = verificationEmail ?? emailController.text.trim();

    if (email.isEmpty) {
      _showSnackBar('Ingresá tu email primero');
      return;
    }

    setState(() => isResendingEmail = true);

    try {
      await _authService.resendSignupConfirmation(email: email);

      _showSnackBar(
        'Email reenviado 📩',
        color: Colors.green,
      );
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (!mounted) return;
      setState(() => isResendingEmail = false);
    }
  }

  void _toggleMode() {
    setState(() {
      isLogin = !isLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 20),

                Icon(Icons.sports_soccer,
                    size: 60, color: theme.colorScheme.primary),

                const SizedBox(height: 16),

                Text(
                  'Otra Copa',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  isLogin
                      ? 'Ingresá a tu cuenta'
                      : 'Creá tu cuenta',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                if (verificationEmail != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Revisá tu email 📩',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(verificationEmail!),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _resendEmail,
                          child: Text(
                            isResendingEmail
                                ? 'Reenviando...'
                                : 'Reenviar email',
                          ),
                        )
                      ],
                    ),
                  ),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (!isLogin) ...[
                        TextFormField(
                          controller: fullNameController,
                          validator: _validateFullName,
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      TextFormField(
                        controller: emailController,
                        validator: _validateEmail,
                        decoration: const InputDecoration(
                          labelText: 'Correo',
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        validator: _validatePassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),

                      if (isLogin) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ForgotPasswordPage(
  isDarkMode: widget.isDarkMode,
  onThemeChanged: widget.onThemeChanged,
  selectedCity: widget.selectedCity,
  onCityChanged: widget.onCityChanged,
),
                                ),
                              );
                            },
                            child: const Text('Olvidé mi contraseña'),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          child: Text(
                            isLoading
                                ? 'Procesando...'
                                : isLogin
                                    ? 'Ingresar'
                                    : 'Crear cuenta',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: _toggleMode,
                  child: Text(
                    isLogin
                        ? 'No tengo cuenta'
                        : 'Ya tengo cuenta',
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