import 'package:flutter/material.dart';
import '../../data/auth_service.dart';
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

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;

  Future<void> _submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final fullName = fullNameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!isLogin && fullName.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá todos los campos')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      if (isLogin) {
        await _authService.signIn(
          email: email,
          password: password,
        );
      } else {
        await _authService.signUp(
          email: email,
          password: password,
          fullName: fullName,
        );
      }

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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Iniciar sesión' : 'Crear cuenta'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Otra Copa',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLogin
                  ? 'Entrá con tu cuenta'
                  : 'Creá tu cuenta para empezar',
            ),
            const SizedBox(height: 24),
            if (!isLogin) ...[
              TextField(
                controller: fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Correo',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : _submit,
              child: Text(
                isLoading
                    ? 'Procesando...'
                    : isLogin
                        ? 'Ingresar'
                        : 'Registrarme',
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  isLogin = !isLogin;
                });
              },
              child: Text(
                isLogin
                    ? 'No tengo cuenta'
                    : 'Ya tengo cuenta',
              ),
            ),
          ],
        ),
      ),
    );
  }
}