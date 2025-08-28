// lib/features/coach/screens/motivation_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/repositories/ai_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/data/models/performance_summary.dart';


// RUH HALİ SEÇENEKLERİ
enum Mood { focused, neutral, tired, stressed, badResult, goodResult, workshop }

// EKRANIN DURUMUNU YÖNETEN STATE
final chatScreenStateProvider = StateProvider<Mood?>((ref) => null);

final chatHistoryProvider = StateProvider<List<ChatMessage>>((ref) => []);

class MotivationChatScreen extends ConsumerStatefulWidget {
  final Object? initialPrompt;
  const MotivationChatScreen({super.key, this.initialPrompt});

  @override
  ConsumerState<MotivationChatScreen> createState() => _MotivationChatScreenState();
}

class _MotivationChatScreenState extends ConsumerState<MotivationChatScreen> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;
  late AnimationController _backgroundAnimationController;

  @override
  void initState() {
    super.initState();
    _backgroundAnimationController = AnimationController(vsync: this, duration: 4.seconds)..repeat(reverse: true);
    Future.microtask(() async {
      ref.read(chatHistoryProvider.notifier).state = [];
      if (widget.initialPrompt != null) {
        if (widget.initialPrompt is String) {
          await _onMoodSelected(widget.initialPrompt as String);
        } else if (widget.initialPrompt is Map<String, dynamic>) {
          final contextData = widget.initialPrompt as Map<String, dynamic>;
          await _onMoodSelected(contextData['type'], extraContext: contextData);
        }
      } else {
        ref.read(chatScreenStateProvider.notifier).state = null;
      }
    });
  }

  @override
  void dispose() {
    _backgroundAnimationController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage({String? quickReply}) async {
    final text = quickReply ?? _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(chatHistoryProvider.notifier).update((state) => [...state, ChatMessage(text, isUser: true)]);
    _controller.clear();
    FocusScope.of(context).unfocus();

    setState(() => _isTyping = true);
    _scrollToBottom(isNewMessage: true);

    final aiService = ref.read(aiServiceProvider);
    final user = ref.read(userProfileProvider).value!;
    final tests = ref.read(testsProvider).value!;
    final performance = ref.read(performanceProvider).value!;
    final aiResponse = await aiService.getPersonalizedMotivation(
      user: user,
      tests: tests,
      performance: performance,
      promptType: 'user_chat',
      emotion: text,
    );

    ref.read(chatHistoryProvider.notifier).update((state) => [...state, ChatMessage(aiResponse, isUser: false)]);
    setState(() => _isTyping = false);
    _scrollToBottom(isNewMessage: true);
  }

  Future<void> _onMoodSelected(String moodType, {Map<String, dynamic>? extraContext}) async {
    final user = ref.read(userProfileProvider).value!;
    final tests = ref.read(testsProvider).value!;
    final performance = ref.read(performanceProvider).value!;

    final Map<String, Mood> moodMapping = {
      'welcome': Mood.neutral, 'new_test_good': Mood.goodResult,
      'new_test_bad': Mood.badResult, 'focused': Mood.focused,
      'neutral': Mood.neutral, 'tired': Mood.tired, 'stressed': Mood.stressed,
      'workshop_review': Mood.workshop,
    };
    final mood = moodMapping[moodType] ?? Mood.neutral;
    ref.read(chatScreenStateProvider.notifier).state = mood;

    setState(() => _isTyping = true);

    final aiService = ref.read(aiServiceProvider);
    final aiResponse = await aiService.getPersonalizedMotivation(
      user: user, tests: tests, performance: performance, promptType: moodType, emotion: null, workshopContext: extraContext,
    );

    ref.read(chatHistoryProvider.notifier).state = [ChatMessage(aiResponse, isUser: false)];
    setState(() => _isTyping = false);
    _scrollToBottom(isNewMessage: true);
  }

  void _scrollToBottom({bool isNewMessage = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: isNewMessage ? 400.ms : 100.ms,
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(chatHistoryProvider);
    final selectedMood = ref.watch(chatScreenStateProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Zihinsel Harbiye'),
        backgroundColor: Colors.black.withOpacity(0.2),
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: _backgroundAnimationController,
        builder: (context, child) {
          final color = _getMoodColor(selectedMood);
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 2.5,
                colors: [
                  color.withOpacity(0.3 + (_backgroundAnimationController.value * 0.1)),
                  AppTheme.primaryColor,
                ],
              ),
            ),
            child: child,
          );
        },
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: 500.ms,
                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                child: selectedMood == null
                    ? _SmartBriefingView(onPromptSelected: _onMoodSelected)
                    : Column(
                  children: [
                    _BattleSummaryCard(),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        itemCount: history.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isTyping && index == history.length) {
                            return const _TypingBubble();
                          }
                          final message = history[index];
                          return _MessageBubble(message: message);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (selectedMood != null) _buildChatInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'BilgeAI\'ye yaz...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: AppTheme.primaryColor.withOpacity(0.7),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => _sendMessage(),
              icon: const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Color _getMoodColor(Mood? mood) {
    switch (mood) {
      case Mood.focused: return AppTheme.secondaryColor;
      case Mood.goodResult: return AppTheme.successColor;
      case Mood.stressed:
      case Mood.badResult: return AppTheme.accentColor;
      case Mood.tired: return Colors.indigo;
      case Mood.workshop: return Colors.purple;
      default: return AppTheme.lightSurfaceColor;
    }
  }
}

class _SmartBriefingView extends ConsumerWidget {
  final Function(String) onPromptSelected;
  const _SmartBriefingView({required this.onPromptSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;
    final tests = ref.watch(testsProvider).value;
    final List<Widget> briefingCards = [];

    if (user != null && tests != null) {
      if (tests.isNotEmpty) {
        briefingCards.add(_BriefingButton(
          icon: Icons.flag_circle_rounded,
          title: "Son Denemeyi Değerlendir",
          subtitle: "En son eklediğin deneme sonucunu masaya yatıralım.",
          onTap: () {
            final lastTest = tests.first;
            final avgNet = user.testCount > 0 ? user.totalNetSum / user.testCount : 0;
            onPromptSelected(lastTest.totalNet > avgNet ? 'new_test_good' : 'new_test_bad');
          },
          delay: 400.ms,
        ));
      }
      if (user.streak > 2) {
        briefingCards.add(_BriefingButton(
          icon: Icons.local_fire_department_rounded,
          title: "${user.streak} Günlük Seri!",
          subtitle: "Bu harika gidişatı ve motivasyonunu konuşalım.",
          onTap: () => onPromptSelected('focused'),
          delay: 500.ms,
        ));
      }
    }

    briefingCards.add(_BriefingButton(
      icon: Icons.chat_bubble_outline_rounded,
      title: "Aklında Ne Var?",
      subtitle: "Sadece sohbet etmek ve içini dökmek için buradayım.",
      onTap: () => onPromptSelected('neutral'),
      delay: 600.ms,
    ));

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircleAvatar(backgroundColor: AppTheme.secondaryColor, radius: 40,
            child: Icon(Icons.auto_awesome, size: 40, color: AppTheme.primaryColor))
            .animate().fadeIn(delay: 200.ms).scale(),
        const SizedBox(height: 24),
        Text("Zihinsel Harbiye'ye Hoş Geldin", style: Theme.of(context).textTheme.headlineSmall)
            .animate().fadeIn(delay: 300.ms),
        const SizedBox(height: 8),
        Text("Sana nasıl yardımcı olabilirim?", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.secondaryTextColor))
            .animate().fadeIn(delay: 300.ms),
        const SizedBox(height: 40),
        ...briefingCards,
      ],
    );
  }
}

class _BriefingButton extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Duration delay;
  const _BriefingButton({required this.title, required this.subtitle, required this.icon, required this.onTap, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 32, color: AppTheme.secondaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: delay).slideY(begin: 0.5, curve: Curves.easeOutCubic);
  }
}

class _BattleSummaryCard extends ConsumerWidget {
  const _BattleSummaryCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;
    final tests = ref.watch(testsProvider).value;
    if (user == null || tests == null || tests.isEmpty) return const SizedBox.shrink();

    final lastTestNet = tests.first.totalNet.toStringAsFixed(1);
    final streak = user.streak.toString();
    final avgNet = (user.totalNetSum / user.testCount).toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 90, 16, 8),
      color: Colors.black.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryItem(label: "Son Net", value: lastTestNet),
            _SummaryItem(label: "Ort. Net", value: avgNet),
            _SummaryItem(label: "Seri", value: streak),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.5);
  }
}

class _SummaryItem extends StatelessWidget {
  final String label, value;
  const _SummaryItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)),
      ],
    );
  }
}


class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Animate(
      effects: [
        FadeEffect(duration: 500.ms, curve: Curves.easeIn),
        SlideEffect(begin: isUser ? const Offset(0.2, 0) : const Offset(-0.2, 0), curve: Curves.easeOutCubic),
      ],
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) const CircleAvatar(backgroundColor: AppTheme.secondaryColor,
                child: Icon(Icons.auto_awesome, size: 20, color: AppTheme.primaryColor), radius: 16),
            if (!isUser) const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser ? AppTheme.secondaryColor : AppTheme.lightSurfaceColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
                    bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
                    bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
                  ),
                ),
                child: Text(message.text, style: TextStyle(color: isUser ? AppTheme.primaryColor : Colors.white,
                    fontSize: 16, height: 1.4, fontWeight: isUser ? FontWeight.w500 : FontWeight.normal)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 0.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const CircleAvatar(backgroundColor: AppTheme.secondaryColor,
                child: Icon(Icons.auto_awesome, size: 20, color: AppTheme.primaryColor), radius: 16),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.lightSurfaceColor,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20), bottomLeft: Radius.circular(4))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  return Animate(
                    delay: (index * 200).ms, onPlay: (c) => c.repeat(reverse: true),
                    effects: const [ScaleEffect(duration: Duration(milliseconds: 600), curve: Curves.easeInOut,
                        begin: Offset(0.7, 0.7), end: Offset(1.1, 1.1))],
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: AppTheme.secondaryTextColor.withOpacity(0.7), shape: BoxShape.circle),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}