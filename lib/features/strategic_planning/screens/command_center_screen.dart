// lib/features/strategic_planning/screens/command_center_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';

class StrategyPhase {
  final String title;
  final String content;

  StrategyPhase({required this.title, required this.content});
}

class CommandCenterScreen extends ConsumerStatefulWidget {
  final UserModel user;
  const CommandCenterScreen({super.key, required this.user});

  @override
  ConsumerState<CommandCenterScreen> createState() => _CommandCenterScreenState();
}

class _CommandCenterScreenState extends ConsumerState<CommandCenterScreen> {
  List<StrategyPhase> _phases = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final planDoc = ref.watch(planProvider).value;
    _parseStrategy(planDoc?.longTermStrategy);
  }


  void _parseStrategy(String? strategyText) {
    if (strategyText == null || strategyText.isEmpty) return;

    final lines = strategyText.split('\n');
    final List<StrategyPhase> parsedPhases = [];
    StringBuffer contentBuffer = StringBuffer();
    String? currentTitle;

    final headerRegex = RegExp(r'^(#+)\s(.*)');

    for (var line in lines) {
      final match = headerRegex.firstMatch(line.trim());

      if (match != null) {
        if (currentTitle != null) {
          parsedPhases.add(StrategyPhase(title: currentTitle, content: contentBuffer.toString().trim()));
        }
        currentTitle = match.group(2)?.trim();
        contentBuffer.clear();
      } else if (currentTitle != null) {
        contentBuffer.writeln(line);
      }
    }

    if (currentTitle != null) {
      parsedPhases.add(StrategyPhase(title: currentTitle, content: contentBuffer.toString().trim()));
    }

    // setState'i sadece widget ağacı oluşturulduktan sonra çağır
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _phases = parsedPhases;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final planDocAsync = ref.watch(planProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Komuta Merkezi"),
      ),
      body: planDocAsync.when(
        data: (planDoc) {
          final longTermStrategy = planDoc?.longTermStrategy;
          if (_phases.isEmpty) {
            return _buildFallbackView(longTermStrategy ?? "Strateji metni bulunamadı.");
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: _phases.length,
            itemBuilder: (context, index) {
              final phase = _phases[index];
              if (phase.content.isEmpty) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      phase.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: (100 * index).ms).slideY(begin: 0.2);
              }
              return _StrategyPhaseCard(
                phase: phase,
                initiallyExpanded: index == _phases.indexWhere((p) => p.content.isNotEmpty),
              ).animate().fadeIn(delay: (100 * index).ms).slideY(begin: 0.2);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => _buildFallbackView("Strateji yüklenirken bir hata oluştu: $e"),
      ),
    );
  }

  Widget _buildFallbackView(String rawStrategy) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 48),
          const SizedBox(height: 16),
          Text(
            "Strateji Formatı Okunamadı",
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Stratejinin ham metnini aşağıda görebilirsin:",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor),
            textAlign: TextAlign.center,
          ),
          const Divider(height: 32),
          MarkdownBody(data: rawStrategy),
        ],
      ),
    );
  }
}

class _StrategyPhaseCard extends StatefulWidget {
  final StrategyPhase phase;
  final bool initiallyExpanded;

  const _StrategyPhaseCard({
    required this.phase,
    this.initiallyExpanded = false,
  });

  @override
  State<_StrategyPhaseCard> createState() => _StrategyPhaseCardState();
}

class _StrategyPhaseCardState extends State<_StrategyPhaseCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }
  IconData _getIconForPhase(String title) {
    if (title.contains("AŞAMA: 1") || title.contains("AŞAMA") && title.contains("1") || title.contains("HAKİMİYET")) {
      return Icons.foundation_rounded;
    } else if (title.contains("AŞAMA: 2") || title.contains("AŞAMA") && title.contains("2") || title.contains("HÜCUM") || title.contains("CANAVARI")) {
      return Icons.military_tech_rounded;
    } else if (title.contains("AŞAMA: 3") || title.contains("AŞAMA") && title.contains("3") || title.contains("ZAFER") || title.contains("PROVASI")) {
      return Icons.emoji_events_rounded;
    } else if (title.contains("MOTTO")) {
      return Icons.flag_rounded;
    }
    return Icons.insights_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: Icon(_getIconForPhase(widget.phase.title), color: AppTheme.secondaryColor, size: 32),
              title: Text(
                widget.phase.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              trailing: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                color: AppTheme.secondaryTextColor,
              ),
            ),
            ClipRect(
              child: AnimatedSize(
                duration: 300.ms,
                curve: Curves.easeInOut,
                child: SizedBox(
                  width: double.infinity,
                  height: _isExpanded ? null : 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: MarkdownBody(
                      data: widget.phase.content,
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        p: const TextStyle(color: AppTheme.secondaryTextColor, fontSize: 16, height: 1.5),
                        listBullet: const TextStyle(color: AppTheme.textColor, fontSize: 16, height: 1.5),
                        strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}