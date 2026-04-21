import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
      },
    );

    final user = response.user;

    if (user == null) {
      throw Exception('No se pudo crear la cuenta');
    }

    await _client.from('profiles').upsert({
      'id': user.id,
      'full_name': fullName,
      'role': 'player',
      'city': 'Asunción',
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;

    if (user == null) {
      throw Exception('Credenciales incorrectas');
    }

    if (user.emailConfirmedAt == null) {
      await _client.auth.signOut();
      throw Exception('Debes confirmar tu email antes de ingresar');
    }
  }

  Future<void> resendSignupConfirmation({
    required String email,
  }) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  Future<void> sendPasswordResetEmail({
  required String email,
}) async {
  await _client.auth.resetPasswordForEmail(
    email,
    redirectTo: 'otra-copa://login-callback',
  );
}

  Future<void> updatePassword({
    required String newPassword,
  }) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}