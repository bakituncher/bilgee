// lib/features/admin/screens/user_statistics_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/admin_providers.dart';
import 'package:taktik/shared/widgets/custom_back_button.dart';

class UserStatisticsScreen extends ConsumerWidget {
  const UserStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı İstatistikleri'),
        leading: const CustomBackButton(),
      ),
      body: statsAsync.when(
        data: (stats) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userStatisticsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text(
                  'Sınav Tipi Dağılımı',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildExamTypeCard(
                  context,
                  'YKS',
                  // DÜZELTME: Gelen veriyi güvenli bir şekilde Map<String, dynamic> yapıyoruz
                  Map<String, dynamic>.from(stats['yks'] ?? {}),
                  Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildExamTypeCard(
                  context,
                  'LGS',
                  Map<String, dynamic>.from(stats['lgs'] ?? {}),
                  Colors.green,
                ),
                const SizedBox(height: 12),
                _buildExamTypeCard(
                  context,
                  'KPSS',
                  Map<String, dynamic>.from(stats['kpss'] ?? {}),
                  Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildExamTypeCard(
                  context,
                  'AGS',
                  Map<String, dynamic>.from(stats['ags'] ?? {}),
                  Colors.purple,
                ),
                const SizedBox(height: 24),
                _buildTotalCard(context, stats),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Hata: $error',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(userStatisticsProvider),
                child: const Text('Yeniden Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamTypeCard(
      BuildContext context,
      String examName,
      Map<String, dynamic> data,
      Color color,
      ) {
    final total = data['total'] ?? 0;
    final premium = data['premium'] ?? 0;
    final premiumPercentage = total > 0 ? (premium / total * 100) : 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        examName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toplam Kullanıcı: $total',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem(
                  context,
                  'Premium',
                  '$premium',
                  Icons.star,
                  Colors.amber,
                ),
                _buildStatItem(
                  context,
                  'Normal',
                  '${total - premium}',
                  Icons.person,
                  Colors.grey,
                ),
                _buildStatItem(
                  context,
                  'Premium %',
                  '${premiumPercentage.toStringAsFixed(1)}%',
                  Icons.percent,
                  color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      BuildContext context,
      String label,
      String value,
      IconData icon,
      Color color,
      ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalCard(BuildContext context, Map<String, dynamic> stats) {
    // Burada güvenli erişim için ?. operatörü ve ?? 0 kullanımı zaten var,
    // ancak stats['yks'] gibi erişimler dinamik olduğu için sorun çıkarmaz.
    // _buildExamTypeCard fonksiyonunda ise Map<String, dynamic> beklediği için sorun çıkıyordu.

    // Verileri güvenli çekmek için helper
    int getStat(String key, String field) {
      final map = stats[key];
      if (map is Map) {
        return (map[field] as num?)?.toInt() ?? 0;
      }
      return 0;
    }

    final totalUsers = getStat('yks', 'total') +
        getStat('lgs', 'total') +
        getStat('kpss', 'total') +
        getStat('ags', 'total');

    final totalPremium = getStat('yks', 'premium') +
        getStat('lgs', 'premium') +
        getStat('kpss', 'premium') +
        getStat('ags', 'premium');

    final overallPremiumPercentage = totalUsers > 0
        ? (totalPremium / totalUsers * 100)
        : 0.0;

    return Card(
      elevation: 4,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'GENEL TOPLAM',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$totalUsers',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Toplam Kullanıcı',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.3),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$totalPremium',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Premium Kullanıcı',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.3),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${overallPremiumPercentage.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Premium Oranı',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}