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
              padding: const EdgeInsets.all(8.0),
              children: [
                _buildExamTypeCard(
                  context,
                  'YKS',
                  Map<String, dynamic>.from(stats['yks'] ?? {}),
                  Colors.blue,
                ),
                const SizedBox(height: 6),
                _buildExamTypeCard(
                  context,
                  'LGS',
                  Map<String, dynamic>.from(stats['lgs'] ?? {}),
                  Colors.green,
                ),
                const SizedBox(height: 6),
                _buildExamTypeCard(
                  context,
                  'KPSS',
                  Map<String, dynamic>.from(stats['kpss'] ?? {}),
                  Colors.orange,
                ),
                const SizedBox(height: 6),
                _buildExamTypeCard(
                  context,
                  'AGS',
                  Map<String, dynamic>.from(stats['ags'] ?? {}),
                  Colors.purple,
                ),
                const SizedBox(height: 12),
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
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 8),
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
                      Text(
                        'Toplam: $total',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 6),
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
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 1),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
            fontSize: 11,
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
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'GENEL TOPLAM',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 6),
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Toplam Kullanıcı',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(height: 1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Premium Kullanıcı',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Premium Oranı',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontSize: 10,
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