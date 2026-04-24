import 'package:flutter/material.dart';

class SelectSportPage extends StatelessWidget {
  final String selectedSport;

  const SelectSportPage({
    super.key,
    required this.selectedSport,
  });

  void _handleTap(BuildContext context, _SportItem sport) {
    if (!sport.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${sport.name} estará disponible más adelante'),
        ),
      );
      return;
    }

    Navigator.pop(context, sport.name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const sports = [
      _SportItem(
        name: 'Fútbol',
        icon: Icons.sports_soccer,
        enabled: true,
      ),
      _SportItem(
        name: 'Tenis',
        icon: Icons.sports_tennis,
        enabled: false,
      ),
      _SportItem(
        name: 'Pádel',
        icon: Icons.sports_tennis,
        enabled: false,
      ),
      _SportItem(
        name: 'Boxeo',
        icon: Icons.sports_mma,
        enabled: false,
      ),
      _SportItem(
        name: 'Básquet',
        icon: Icons.sports_basketball,
        enabled: false,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Elegir deporte'),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sports.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final sport = sports[index];
            final isSelected = selectedSport == sport.name;

            return InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _handleTap(context, sport),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: theme.colorScheme.surface,
                  border: Border.all(
                    color: isSelected && sport.enabled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant.withOpacity(0.35),
                    width: isSelected && sport.enabled ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isSelected && sport.enabled
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        sport.icon,
                        color: sport.enabled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sport.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sport.enabled ? 'Disponible' : 'Próximamente',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: sport.enabled
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected && sport.enabled)
                      Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.primary,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SportItem {
  final String name;
  final IconData icon;
  final bool enabled;

  const _SportItem({
    required this.name,
    required this.icon,
    required this.enabled,
  });
}