// lib/shared/widgets/edge_to_edge_example.dart
import 'package:flutter/material.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/shared/widgets/edge_to_edge_wrapper.dart';

/// Android 15+ SDK 35 edge-to-edge kullanım örneği
class EdgeToEdgeExampleScreen extends StatelessWidget {
  const EdgeToEdgeExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EdgeToEdgeScaffold(
      appBar: AppBar(
        title: const Text('Edge-to-Edge Örnek'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: EdgeToEdgeWrapper(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Android 15+ Edge-to-Edge Desteği',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Önemli Notlar:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '• SDK 35 hedefleyen uygulamalar için edge-to-edge zorunludur\n'
                        '• Status bar ve navigation bar şeffaf olmalıdır\n'
                        '• EdgeToEdgeWrapper veya EdgeToEdgeScaffold kullanın\n'
                        '• MediaQuery padding değerlerini doğru kullanın',
                        style: TextStyle(color: AppTheme.textColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // System UI'yi yeniden yapılandır
                  AppTheme.configureSystemUI();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('System UI yeniden yapılandırıldı'),
                    ),
                  );
                },
                child: const Text('System UI\'yi Yenile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
