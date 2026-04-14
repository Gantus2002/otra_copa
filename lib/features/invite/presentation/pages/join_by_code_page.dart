import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../tournaments/data/tournament_remote_service.dart';
import '../../data/join_request_service.dart';

class JoinByCodePage extends StatefulWidget {
  const JoinByCodePage({super.key});

  @override
  State<JoinByCodePage> createState() => _JoinByCodePageState();
}

class _JoinByCodePageState extends State<JoinByCodePage> {
  final TextEditingController codeController = TextEditingController();
  final TournamentRemoteService _remoteService = TournamentRemoteService();
  final JoinRequestService _requestService = JoinRequestService();

  Map<String, dynamic>? foundTournament;
  bool isLoading = false;

  Future<String> _getCurrentUserDisplayName() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('No hay usuario logueado');
    }

    final profile = await client
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .maybeSingle();

    final fullName = profile?['full_name'];

    if (fullName == null || fullName.toString().trim().isEmpty) {
      return user.email ?? 'Jugador';
    }

    return fullName.toString();
  }

  Future<void> _joinTournament() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final code = codeController.text.trim().toUpperCase();

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenés que iniciar sesión')),
      );
      return;
    }

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un código')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final tournament = await _remoteService.findByInviteCode(code);

      if (tournament == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código inválido')),
        );
        return;
      }

      final playerName = await _getCurrentUserDisplayName();

      await _requestService.createRequest(
        tournamentId: tournament['id'],
        playerName: playerName,
        userId: user.id,
      );

      setState(() {
        foundTournament = tournament;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud enviada. Esperando aprobación'),
        ),
      );
    } catch (e) {
      final message = e.toString();

      if (message.contains('duplicate key') ||
          message.contains('join_requests_unique_user_tournament')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ya enviaste una solicitud para este torneo'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unirse por código'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Ingresá el código del torneo',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vas a unirte con tu cuenta actual: ${user?.email ?? 'sin sesión'}',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : _joinTournament,
              child: Text(isLoading ? 'Validando...' : 'Unirme'),
            ),
            const SizedBox(height: 24),
            if (foundTournament != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Torneo encontrado',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Nombre: ${foundTournament!['name']}'),
                      Text('Ubicación: ${foundTournament!['location']}'),
                      Text('Tipo: ${foundTournament!['tournament_type']}'),
                      Text('Modalidad: ${foundTournament!['game_mode']}'),
                      Text('Categoría: ${foundTournament!['category']}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}