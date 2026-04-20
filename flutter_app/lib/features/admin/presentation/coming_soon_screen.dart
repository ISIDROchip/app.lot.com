import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';

class ComingSoonScreen extends StatelessWidget {
  final String title;
  const ComingSoonScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LuxoraColors.background,
      appBar: AppBar(title: Text(title.toUpperCase())),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction_rounded, size: 80, color: LuxoraColors.primary),
            const SizedBox(height: 24),
            Text(
              'PRÓXIMAMENTE',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: LuxoraColors.textPrimary,
                    letterSpacing: 4,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Esta funcionalidad está en desarrollo.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: LuxoraColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
              child: const Text('VOLVER'),
            ),
          ],
        ),
      ),
    );
  }
}
