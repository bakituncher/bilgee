// lib/features/coach/screens/motivation_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/repositories/ai_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:flutter/services.dart';


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
  bool _showScrollToBottom = false;
  late AnimationController _backgroundAnimationController;

  // YENI: Sohbetten Süit ekranına dönüş helper
  void _exitToSuite() {
    if (!mounted) return;
    ref.read(chatScreenStateProvider.notifier).state = null; // Süit ekranına dön
    ref.read(chatHistoryProvider.notifier).state = []; // geçmişi temizle
    setState(() => _isTyping = false);
  }

  // YENI: Son N mesajdan kısa bir özet üret
  String _buildConversationHistory(List<ChatMessage> history, {int maxTurns = 10, int maxChars = 800}) {
    if (history.isEmpty) return '';
    final recent = history.length > maxTurns ? history.sublist(history.length - maxTurns) : history;
    final lines = recent.map((m) => (m.isUser ? 'Kullanıcı: ' : 'AI: ') + m.text.replaceAll('\n', ' ').trim()).toList();
    var out = lines.join(' | ');
    if (out.length > maxChars) out = out.substring(out.length - maxChars);
    return out;
  }

  @override
  void initState() {
    super.initState();
    _backgroundAnimationController = AnimationController(vsync: this, duration: 4.seconds)..repeat(reverse: true);
    _scrollController.addListener(_onScroll);
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

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final off = _scrollController.offset;
    final shouldShow = off < (max - 200);
    if (_showScrollToBottom != shouldShow) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  @override
  void dispose() {
    _backgroundAnimationController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage({String? quickReply}) async {
    if (_isTyping) return; // yeniden tetiklemeyi engelle
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

    // YENI: Sohbet geçmişini ve son kullanıcı mesajını geçir
    final history = ref.read(chatHistoryProvider);
    final historySummary = _buildConversationHistory(history);

    final aiResponse = await aiService.getPersonalizedMotivation(
      user: user,
      tests: tests,
      performance: performance,
      promptType: 'user_chat',
      emotion: null,
      conversationHistory: historySummary,
      lastUserMessage: text,
    );

    if (!mounted) return;
    ref.read(chatHistoryProvider.notifier).update((state) => [...state, ChatMessage(aiResponse, isUser: false)]);
    setState(() => _isTyping = false);
    _scrollToBottom(isNewMessage: true);
  }

  Future<void> _onMoodSelected(String moodType, {Map<String, dynamic>? extraContext}) async {
    if (_isTyping) return; // yeniden tetiklemeyi engelle
    final user = ref.read(userProfileProvider).value!;
    final tests = ref.read(testsProvider).value!;
    final performance = ref.read(performanceProvider).value!;

    // YENİ: Sohbete başlamadan önce o modun hafızasını temizle.
    // Bu, AI'nin eski konuşmaları hatırlayıp "Aleyküm selam" gibi garip başlangıçlar yapmasını önler.
    final aiService = ref.read(aiServiceProvider);
    await aiService.clearChatMemory(user.id, moodType);

    Mood mood = Mood.neutral;
    if (moodType == 'trial_review') {
      if (tests.isNotEmpty && user.testCount > 0) {
        final last = tests.first;
        final avg = user.totalNetSum / user.testCount;
        mood = last.totalNet >= avg ? Mood.goodResult : Mood.badResult;
      } else {
        mood = Mood.neutral;
      }
    } else if (moodType == 'strategy_consult') {
      mood = Mood.focused;
    } else if (moodType == 'psych_support') {
      mood = Mood.stressed;
    } else if (moodType == 'motivation_corner') {
      mood = Mood.workshop;
    } else {
      // Eski modlar için geriye dönük destek
      final Map<String, Mood> moodMapping = {
        'welcome': Mood.neutral, 'new_test_good': Mood.goodResult,
        'new_test_bad': Mood.badResult, 'focused': Mood.focused,
        'neutral': Mood.neutral, 'tired': Mood.tired, 'stressed': Mood.stressed,
        'workshop_review': Mood.workshop,
      };
      mood = moodMapping[moodType] ?? Mood.neutral;
    }
    ref.read(chatScreenStateProvider.notifier).state = mood;

    setState(() => _isTyping = true);

    // YENI: Başlangıçta mümkünse kısa geçmiş de gönder
    final history = ref.read(chatHistoryProvider);
    final historySummary = _buildConversationHistory(history);

    final aiResponse = await aiService.getPersonalizedMotivation(
      user: user, tests: tests, performance: performance, promptType: moodType, emotion: null, workshopContext: extraContext,
      conversationHistory: historySummary, lastUserMessage: '',
    );

    if (!mounted) return;
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

    // DÜZ: arka plan animasyonu yerine sade arka plan
    // AppTheme odaklı renk paleti

    return PopScope(
      canPop: selectedMood == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (ref.read(chatScreenStateProvider) != null) {
          _exitToSuite();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('Sohbet'),
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
          // YENI: Sohbet içindeyken geri ikonunu Süit’e dönecek şekilde özelleştir
          leading: selectedMood != null
              ? BackButton(onPressed: _exitToSuite)
              : null,
        ),
        backgroundColor: AppTheme.primaryColor,
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: 200.ms,
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: selectedMood == null
                        ? _SmartBriefingView(onPromptSelected: _onMoodSelected)
                        : RepaintBoundary(
                            child: ListView.builder(
                              controller: _scrollController,
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              cacheExtent: 300,
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: true,
                              addSemanticIndexes: false,
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                              itemCount: history.length + (_isTyping ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (_isTyping && index == history.length) {
                                  return const _TypingBubble();
                                }
                                final message = history[index];
                                final bool isLastRealMessage = index == history.length - 1;
                                return _MessageBubble(message: message, animate: isLastRealMessage);
                              },
                            ),
                          ),
                  ),
                ),
                if (selectedMood != null) _buildChatInput(),
              ],
            ),
            if (_showScrollToBottom)
              Positioned(
                right: 16,
                bottom: (selectedMood != null) ? 88 : 24,
                child: FloatingActionButton.small(
                  heroTag: 'toBottom',
                  backgroundColor: AppTheme.lightSurfaceColor,
                  foregroundColor: Colors.white,
                  onPressed: () => _scrollToBottom(isNewMessage: false),
                  child: const Icon(Icons.arrow_downward_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.lightSurfaceColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Yaz...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isTyping ? null : () => _sendMessage(),
              icon: _isTyping
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.all(12),
                shape: const CircleBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _SmartBriefingView extends ConsumerWidget {
  final Function(String) onPromptSelected;
  const _SmartBriefingView({required this.onPromptSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 60),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  const CircleAvatar(
                    backgroundColor: AppTheme.secondaryColor,
                    radius: 42,
                    child: Icon(Icons.auto_awesome, size: 42, color: AppTheme.primaryColor),
                  ).animate().fadeIn(delay: 180.ms).scale(),
                  const SizedBox(height: 24),
                  Text('Motivasyon Süiti', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))
                      .animate().fadeIn(delay: 260.ms),
                  const SizedBox(height: 10),
                  Text(
                    'Durumuna uygun derin ve kişisel yönlendirme al.',
                    style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.secondaryTextColor, height: 1.3),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 36),
                  _BriefingButton(
                    icon: Icons.flag_circle_rounded,
                    title: 'Deneme Değerlendirme',
                    subtitle: 'Son deneme analizi + 48 saatlik mini toparlanma planı.',
                    onTap: () => onPromptSelected('trial_review'),
                    delay: 380.ms,
                  ),
                  _BriefingButton(
                    icon: Icons.track_changes_rounded,
                    title: 'Strateji Danışma',
                    subtitle: 'Haftalık ritim, odak sırası ve takip metrikleri.',
                    onTap: () => onPromptSelected('strategy_consult'),
                    delay: 460.ms,
                  ),
                  _BriefingButton(
                    icon: Icons.favorite_rounded,
                    title: 'Psikolojik Destek',
                    subtitle: 'Stres / moral düşüşü için kısa destek + mikro adım.',
                    onTap: () => onPromptSelected('psych_support'),
                    delay: 520.ms,
                  ),
                  _BriefingButton(
                    icon: Icons.bolt_rounded,
                    title: 'Motivasyon Köşesi',
                    subtitle: '5 dk. mikro meydan okuma ve ritim önerisi.',
                    onTap: () => onPromptSelected('motivation_corner'),
                    delay: 580.ms,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BriefingButton extends StatelessWidget {
  final String title, subtitle; final IconData icon; final VoidCallback onTap; final Duration delay;
  const _BriefingButton({required this.title, required this.subtitle, required this.icon, required this.onTap, required this.delay});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x18222C2C), Color(0x10222C2C)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [AppTheme.secondaryColor, AppTheme.successColor]),
              ),
              child: Icon(icon, size: 30, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor, height: 1.25),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_ios_rounded, size: 18, color: AppTheme.secondaryTextColor.withValues(alpha: 0.8)),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay).slideY(begin: 0.35, curve: Curves.easeOutCubic);
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool animate;
  const _MessageBubble({required this.message, this.animate = false});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    final Color bg = isUser ? AppTheme.secondaryColor : AppTheme.lightSurfaceColor;
    final Color fg = isUser ? AppTheme.primaryColor : Colors.white;

    final content = GestureDetector(
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: message.text));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mesaj kopyalandı')));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser)
              const CircleAvatar(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: AppTheme.primaryColor,
                radius: 14,
                child: Icon(Icons.auto_awesome, size: 16),
              ),
            if (!isUser) const SizedBox(width: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
                      bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(10),
                      bottomRight: isUser ? const Radius.circular(10) : const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(color: fg, fontSize: 16, height: 1.48),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!animate) return content;
    return Animate(
      effects: const [FadeEffect(duration: Duration(milliseconds: 150), curve: Curves.easeIn)],
      child: content,
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
                      decoration: BoxDecoration(color: AppTheme.secondaryTextColor.withValues(alpha: 0.7), shape: BoxShape.circle),
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
