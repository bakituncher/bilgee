// lib/features/coach/screens/motivation_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/repositories/ai_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:flutter/services.dart';
import 'package:taktik/core/safety/ai_content_safety.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';

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
  String _currentPromptType = 'user_chat'; // YENİ: Aktif sohbet modunu saklamak için

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
      promptType: _currentPromptType, // DÜZELTME: 'user_chat' yerine mevcut modu kullan
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

    // Servisleri ve provider'ları en başta tanımla
    final aiService = ref.read(aiServiceProvider);
    final user = ref.read(userProfileProvider).value!;
    final tests = ref.read(testsProvider).value!;
    final performance = ref.read(performanceProvider).value!;

    // Motivasyon chat görevini kaydet (ilk kullanımda)
    ref.read(questNotifierProvider.notifier).userUsedMotivationChat();

    // Seçilen modun hafızasını temizle
    await aiService.clearChatMemory(user.id, moodType);

    // YENİ: Seçilen kişilik türünü state'e kaydet.
    setState(() {
      _currentPromptType = moodType;
    });

    // moodType'a göre ruh halini belirle
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
      // Eski modlar için geriye dönük uyumluluk
      final Map<String, Mood> moodMapping = {
        'welcome': Mood.neutral, 'new_test_good': Mood.goodResult,
        'new_test_bad': Mood.badResult, 'focused': Mood.focused,
        'neutral': Mood.neutral, 'tired': Mood.tired, 'stressed': Mood.stressed,
        'workshop_review': Mood.workshop,
      };
      mood = moodMapping[moodType] ?? Mood.neutral;
    }

    // UI durumunu güncelle
    ref.read(chatScreenStateProvider.notifier).state = mood;
    setState(() => _isTyping = true);

    // AI'dan ilk cevabı al
    final history = ref.read(chatHistoryProvider);
    final historySummary = _buildConversationHistory(history);

    final aiResponse = await aiService.getPersonalizedMotivation(
      user: user,
      tests: tests,
      performance: performance,
      promptType: moodType,
      emotion: null,
      workshopContext: extraContext,
      conversationHistory: historySummary,
      lastUserMessage: '',
    );

    if (!mounted) return;

    // Sohbet geçmişini AI'nin ilk mesajıyla güncelle
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
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          // YENI: Sohbet içindeyken geri ikonunu Süit’e dönecek şekilde özelleştir
          leading: selectedMood != null
              ? BackButton(onPressed: _exitToSuite)
              : null,
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Stack(
          children: [
            Column(
              children: [
                // AI içerik uyarısı
                if (selectedMood != null)
                  AiContentSafety.buildDisclaimerBanner(context),
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
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
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
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
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
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.black,
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
                    backgroundColor: Colors.transparent,
                    radius: 42,
                    backgroundImage: AssetImage('assets/images/bunnyy.png'),
                  ).animate().fadeIn(delay: 180.ms).scale(),
                  const SizedBox(height: 24),
                  Text('Motivasyon Sohbeti', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))
                      .animate().fadeIn(delay: 260.ms),
                  const SizedBox(height: 10),
                  Text(
                    'Hızlı destek için bir başlık seç. Deneme Değerlendirme ve Strateji Danışma AiHub’a taşındı.',
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.3),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 24),
                  // KALDI: Dostça Destek
                  _BriefingButton(
                    icon: Icons.favorite_rounded,
                    title: 'Dostça Destek',
                    subtitle: 'Stres / moral düşüşü için kısa destek + mikro adım.',
                    onTap: () => onPromptSelected('psych_support'),
                    delay: 380.ms,
                  ),
                  // KALDI: Motivasyon Köşesi
                  _BriefingButton(
                    icon: Icons.bolt_rounded,
                    title: 'Motivasyon Köşesi',
                    subtitle: '5 dk. mikro meydan okuma ve ritim önerisi.',
                    onTap: () => onPromptSelected('motivation_corner'),
                    delay: 460.ms,
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Taktik AI Koçu yalnızca akademik strateji ve motivasyon aracıdır. Tıbbi veya psikolojik teşhis/tedavi amaçlı tasarlanmamıştır. Sağlık sorunları için lütfen lisanslı bir uzmana başvurun.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                  ),
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
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0x18222C2C), const Color(0x10222C2C)]
                : [
              colorScheme.surfaceContainerHighest.withOpacity(0.4),
              colorScheme.surfaceContainerHighest.withOpacity(0.2),
            ],
          ),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : colorScheme.outline.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
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
                gradient: LinearGradient(colors: [theme.colorScheme.secondary, theme.colorScheme.secondary]),
              ),
              child: Icon(icon, size: 30, color: isDark ? theme.primaryColor : Colors.black87),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.25),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant.withOpacity(0.8),
            ),
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
    final colorScheme = Theme.of(context).colorScheme;

    final Color bg = isUser ? colorScheme.secondary : colorScheme.surfaceContainerHighest;
    final Color fg = isUser ? Colors.black : colorScheme.onSurface;

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
                backgroundColor: Colors.transparent,
                radius: 14,
                backgroundImage: AssetImage('assets/images/bunnyy.png'),
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
            const CircleAvatar(
                backgroundColor: Colors.transparent,
                radius: 16,
                backgroundImage: AssetImage('assets/images/bunnyy.png')),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7), shape: BoxShape.circle),
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
