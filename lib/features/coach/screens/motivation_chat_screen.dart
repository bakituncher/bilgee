// lib/features/coach/screens/motivation_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/repositories/ai_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:flutter/services.dart';
import 'package:taktik/core/safety/ai_content_safety.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';
import 'dart:async';

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
  String _currentPromptType = 'user_chat'; // Aktif sohbet modunu saklamak için
  bool _cameWithInitialPrompt = false; // Kullanıcı direkt sohbete mi girdi?
  bool _showSuggestions = true; // Öneri butonlarını göster
  List<String> _currentSuggestions = []; // Rastgele seçilen öneriler

  // Her sohbet türü için zengin öneri havuzu (her biri 20+)
  static const Map<String, List<String>> _allSuggestionMessages = {
    'trial_review': [
      'Son denememdeki hatalarımı analiz eder misin?',
      'Net ortalamamı nasıl artırabilirim?',
      'Hangi dersime öncelik vermeliyim?',
      'Zayıf konularımı tespit edebilir misin?',
      'Deneme sonuçlarımda bir trend var mı?',
      'En çok hangi soru tiplerinde hata yapıyorum?',
      'Güçlü olduğum dersleri korumak için ne yapmalıyım?',
      'Son denememle öncekini karşılaştırır mısın?',
      'Hangi konulara daha çok zaman ayırmalıyım?',
      'Yanlışlarımı nasıl analiz etmeliyim?',
      'Deneme çözme stratejimi değiştirmeli miyim?',
      'Zaman yönetimim nasıl, geliştirmeli miyim?',
      'Boş bıraktığım sorular hakkında ne dersin?',
      'Net artışım için kısa vadeli hedef önerir misin?',
      'Hangi derste en hızlı net artışı sağlarım?',
      'Denemede stres yönetimi için önerilerin var mı?',
      'Paragraf sorularında çok vakit kaybediyorum',
      'Matematik netim neden düşük, analiz eder misin?',
      'Sayısal derslerde nasıl ilerleme kaydederim?',
      'Sözel netlerimdeki düşüşün sebebi ne olabilir?',
      'Deneme çözerken dikkatim dağılıyor, ne yapmalıyım?',
    ],
    'strategy_consult': [
      'Günlük çalışma programı oluşturmama yardım et',
      'Pomodoro tekniği bana uygun mu?',
      'Verimli ders çalışma teknikleri neler?',
      'Haftalık program nasıl yapmalıyım?',
      'Konu tekrarlarını ne sıklıkla yapmalıyım?',
      'Günde kaç saat çalışmak ideal?',
      'Sabah mı akşam mı çalışmak daha verimli?',
      'Zayıf derslerime ne kadar zaman ayırmalıyım?',
      'Soru çözme ve konu çalışma dengesini nasıl kurarım?',
      'Video ders mi kitap mı daha etkili?',
      'Deneme çözme sıklığım ne olmalı?',
      'Konu eksiklerimi nasıl hızlı kapatırım?',
      'Çalışma ortamımı nasıl düzenlemeliyim?',
      'Mola vermek verimliliği nasıl etkiler?',
      'Akıllı telefon dikkat dağıtıyor, ne yapmalıyım?',
      'Aktif öğrenme teknikleri nelerdir?',
      'Not tutma stratejileri önerir misin?',
      'Formül ve kavramları nasıl ezberlerim?',
      'Hafta sonları nasıl çalışmalıyım?',
      'Birden fazla kaynaktan çalışmak faydalı mı?',
      'Konu çalışmak mı yoksa soru çözmek mi daha önemli?',
      'Sürekli yanlış yapıyorum, nasıl düzeltebilirim?',
    ],
    'psych_support': [
      'Sınav stresi yaşıyorum, ne yapmalıyım?',
      'Motivasyonum düştü, kendimi kötü hissediyorum',
      'Çalışmaya başlayamıyorum, sürekli erteliyorum',
      'Ailemi hayal kırıklığına uğratmaktan korkuyorum',
      'Herkes geziyor ben çalışıyorum, adil değil',
      'Başarısız olursam ne olacak diye çok korkuyorum',
      'Konsantre olamıyorum, aklım sürekli dağılıyor',
      'Kendimi arkadaşlarımla kıyaslıyorum',
      'Çalıştığım halde netlerim artmıyor, umutsuzum',
      'Aile baskısı altında eziliyorum',
      'Uyku düzenim bozuldu, ne yapmalıyım?',
      'Sınav kaygısını nasıl yenerim?',
      'Özgüvenim çok düşük, kendime inanamıyorum',
      'Sosyal medyayı bırakamıyorum, bağımlı gibiyim',
      'Arkadaşlarımla görüşemiyorum, yalnız hissediyorum',
      'Çok yorgunum ama dinlenmeye vaktim yok',
      'Sosyal medyada çok vakit geçiriyorum',
      'Gelecek kaygısı beni çok etkiliyor',
      'Mükemmeliyetçilik beni engelliyor',
      'Her şeyi erteliyorum, başlayamıyorum',
      'Yalnız hissediyorum, ne yapabilirim?'
          'Kimseyle konuşasım gelmiyor',
    ],
    'motivation_corner': [
      'Bugün hiç çalışmak istemiyorum',
      'Enerjimi nasıl yüksek tutabilirim?',
      'Başaramayacakmışım gibi hissediyorum',
      'Beni motive edecek bir şey söyle',
      'Çalışma isteği nasıl gelir?',
      'Hedefime ulaşacağıma inanmak istiyorum',
      'Disiplinli olmak çok zor geliyor',
      'Küçük başarıları kutlamayı unutuyorum',
      'Uzun vadeli motivasyonu nasıl korurum?',
      'Tembellik yapıyorum, kendimden nefret ediyorum',
      'Rakiplerim benden önde, yetişemem',
      'Bana güç verecek bir söz söyle',
      'Başarılı insanlar nasıl motive kalıyor?',
      'Düşük günlerde kendimi nasıl toplarım?',
      'Pes etmek istemiyorum ama çok zor',
      'Küçük adımlarla ilerlemenin değerini anlat',
      'Sabah erken kalkamıyorum, motivasyonum yok',
      'Kendime ödül vermeli miyim?',
      'Başarı hikayeleri duymak istiyorum',
      'Motivasyonumu artıracak alışkanlıklar nelerdir?',
      'Enerjimi yükseltecek aktiviteler önerir misin?',
      'Calışma isteği nasıl artırılır?',
    ],
  };

  // Rastgele 4 öneri seçen fonksiyon
  List<String> _getRandomSuggestions(String promptType) {
    final allSuggestions = _allSuggestionMessages[promptType] ?? [];
    if (allSuggestions.isEmpty) return [];

    final shuffled = List<String>.from(allSuggestions)..shuffle();
    return shuffled.take(4).toList();
  }

  // Sohbetten Süit ekranına dönüş helper
  void _exitToSuite() {
    if (!mounted) return;
    ref.read(chatScreenStateProvider.notifier).state = null; // Süit ekranına dön
    ref.read(chatHistoryProvider.notifier).state = []; // geçmişi temizle
    setState(() => _isTyping = false);
  }

  // Son N mesajdan kısa bir özet üret
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
        print('[MotivationChat] initState - initialPrompt: ${widget.initialPrompt}');
        setState(() {
          _cameWithInitialPrompt = true; // Kullanıcı direkt sohbete girdi
        });
        print('[MotivationChat] initState - _cameWithInitialPrompt set to true');
        if (widget.initialPrompt is String) {
          await _onMoodSelected(widget.initialPrompt as String);
        } else if (widget.initialPrompt is Map<String, dynamic>) {
          final contextData = widget.initialPrompt as Map<String, dynamic>;
          await _onMoodSelected(contextData['type'], extraContext: contextData);
        }
      } else {
        print('[MotivationChat] initState - No initialPrompt, showing menu');
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

    // Öneri butonlarını gizle
    setState(() => _showSuggestions = false);

    ref.read(chatHistoryProvider.notifier).update((state) => [...state, ChatMessage(text, isUser: true)]);
    _controller.clear();
    FocusScope.of(context).unfocus();

    setState(() => _isTyping = true);
    _scrollToBottom(isNewMessage: true);

    final aiService = ref.read(aiServiceProvider);
    final user = ref.read(userProfileProvider).value;
    final tests = ref.read(testsProvider).value;
    final performance = ref.read(performanceProvider).value;

    // Veriler henüz yüklenmediyse güvenli çıkış yap
    if (user == null || tests == null || performance == null) {
      debugPrint('[MotivationChat] _sendMessage: Veriler henüz yüklenmedi, işlem iptal.');
      setState(() => _isTyping = false);
      return;
    }

    // Sohbet geçmişini ve son kullanıcı mesajını geçir
    final history = ref.read(chatHistoryProvider);

    // SON MESAJI HARİÇ TUT
    final historyForPrompt = history.length > 1 ? history.sublist(0, history.length - 1) : <ChatMessage>[];

    // Özeti son mesaj hariç oluşturuyoruz
    final historySummary = _buildConversationHistory(historyForPrompt);

    final aiResponse = await aiService.getPersonalizedMotivation(
      user: user,
      tests: tests,
      performance: performance,
      promptType: _currentPromptType,
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
    if (_isTyping) return;

    final aiService = ref.read(aiServiceProvider);
    final user = ref.read(userProfileProvider).value;
    final tests = ref.read(testsProvider).value;
    final performance = ref.read(performanceProvider).value;

    // Veriler henüz yüklenmediyse güvenli çıkış yap
    if (user == null || tests == null || performance == null) {
      debugPrint('[MotivationChat] _onMoodSelected: Veriler henüz yüklenmedi, işlem iptal.');
      return;
    }

    ref.read(questNotifierProvider.notifier).userUsedMotivationChat();
    await aiService.clearChatMemory(user.id, moodType);

    setState(() {
      _currentPromptType = moodType;
      _showSuggestions = true; // Öneri butonlarını göster
      _currentSuggestions = _getRandomSuggestions(moodType); // Rastgele 4 öneri seç
    });

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
      final Map<String, Mood> moodMapping = {
        'welcome': Mood.neutral, 'new_test_good': Mood.goodResult,
        'new_test_bad': Mood.badResult, 'focused': Mood.focused,
        'neutral': Mood.neutral, 'tired': Mood.tired, 'stressed': Mood.stressed,
        'workshop_review': Mood.workshop,
      };
      mood = moodMapping[moodType] ?? Mood.neutral;
    }

    ref.read(chatScreenStateProvider.notifier).state = mood;
    // Sohbet geçmişini temizle ve kullanıcının mesaj yazmasını bekle
    ref.read(chatHistoryProvider.notifier).state = [];
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

    // DÜZELTME: Klavye yüksekliğini ve safe area'yı alıyoruz
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final paddingBottom = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: selectedMood == null || (_cameWithInitialPrompt && selectedMood != null),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (selectedMood != null && !_cameWithInitialPrompt) {
          ref.read(chatScreenStateProvider.notifier).state = null;
          ref.read(chatHistoryProvider.notifier).state = [];
          setState(() => _isTyping = false);
        }
      },
      child: Scaffold(
        // DÜZELTME: resizeToAvoidBottomInset'i kapatıp manuel yönetiyoruz.
        // Bu, klavye açıldığında UI'ın bozulmasını ve inputun gizlenmesini %100 engeller.
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text(
            'Sohbet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Stack(
          children: [
            Column(
              children: [
                if (selectedMood != null)
                  AiContentSafety.buildDisclaimerBanner(context),

                // DÜZELTME: İçeriğin genişlemesi için Expanded kullanıyoruz
                Expanded(
                  child: AnimatedSwitcher(
                    duration: 200.ms,
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: selectedMood == null
                        ? _SmartBriefingView(onPromptSelected: _onMoodSelected)
                        : RepaintBoundary(
                      child: history.isEmpty && _showSuggestions
                          ? _SuggestionView(
                        promptType: _currentPromptType,
                        suggestions: _currentSuggestions,
                        onSuggestionTap: (text) => _sendMessage(quickReply: text),
                      )
                          : ListView.builder(
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
                          return _MessageBubble(
                            message: message,
                            animate: isLastRealMessage,
                            scrollController: isLastRealMessage && !message.isUser ? _scrollController : null,
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // DÜZELTME: Input alanını Column'un en altına koyuyoruz.
                // Ve klavye yüksekliği kadar (viewInsets.bottom) padding veriyoruz.
                if (selectedMood != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: _buildChatInput(paddingBottom: paddingBottom, isKeyboardOpen: bottomInset > 0),
                  ),
              ],
            ),

            if (_showScrollToBottom)
              Positioned(
                right: 16,
                // DÜZELTME: Butonun konumunu klavye yüksekliğine göre ayarlıyoruz
                bottom: ((selectedMood != null) ? 88 : 24) + bottomInset,
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

  // DÜZELTME: SafeArea widget'ını kaldırdık ve padding'i parametre olarak aldık
  Widget _buildChatInput({required double paddingBottom, required bool isKeyboardOpen}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      // DÜZELTME: Eğer klavye açıksa, bottom padding 16px.
      // Eğer kapalıysa, 16px + Home Indicator (safe area) yüksekliği.
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + (isKeyboardOpen ? 0 : paddingBottom)),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 4,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Mesajını yaz...',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.secondary,
                  colorScheme.secondary.withOpacity(0.8),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.secondary.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _isTyping ? null : () => _sendMessage(),
              icon: _isTyping
                  ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.black.withOpacity(0.7),
                  ),
                ),
              )
                  : const Icon(Icons.send_rounded, size: 24),
              color: Colors.black87,
              padding: const EdgeInsets.all(14),
              constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
            ),
          ),
        ],
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
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Stack(
        children: [
          // Hero Section (Scrollable)
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 450),
            child: Column(
              children: [
                // Premium Hero Section
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                        colorScheme.primaryContainer.withOpacity(0.25),
                        colorScheme.tertiaryContainer.withOpacity(0.15),
                      ]
                          : [
                        colorScheme.primaryContainer.withOpacity(0.5),
                        colorScheme.tertiaryContainer.withOpacity(0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.secondary.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: const CircleAvatar(
                          backgroundColor: Colors.transparent,
                          radius: 26,
                          backgroundImage: AssetImage('assets/images/bunnyy.webp'),
                        ),
                      ).animate().fadeIn(delay: 100.ms).scale(curve: Curves.elasticOut),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Mentörün Taktik Tavşan',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
                      const SizedBox(height: 6),
                      Text(
                        'Motivasyon, strateji, analiz ve destek... Taktik Tavşan sınav yolculuğunda her alanda yanında! 🚀',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 300.ms),
                    ],
                  ),
                ).animate().fadeIn(delay: 50.ms).scale(),
              ],
            ),
          ),

          // Fixed Bottom Panel with Feature Cards
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface.withOpacity(0.0),
                    colorScheme.surface.withOpacity(0.8),
                    colorScheme.surface,
                    colorScheme.surface,
                  ],
                  stops: const [0.0, 0.1, 0.3, 1.0],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Feature Cards
                        _BriefingButton(
                          icon: Icons.favorite_rounded,
                          title: 'Dostça Destek',
                          subtitle: 'Sınav kaygısı veya yorgunluk... Yargılamak yok, çözüm var. Anlat, rahatla ve odaklan.',
                          onTap: () => onPromptSelected('psych_support'),
                          delay: 400.ms,
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF7B1FA2), const Color(0xFF9C27B0)]
                                : [const Color(0xFFE91E63), const Color(0xFFF06292)],
                          ),
                          accentColor: isDark ? const Color(0xFFBA68C8) : const Color(0xFFC2185B),
                        ),

                        const SizedBox(height: 10),

                        _BriefingButton(
                          icon: Icons.bolt_rounded,
                          title: 'Motivasyon Köşesi',
                          subtitle: 'Düşük pille çalışma! Seni anında masaya kilitleyecek güç konuşması için tıkla. ⚡',
                          onTap: () => onPromptSelected('motivation_corner'),
                          delay: 500.ms,
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFFE65100), const Color(0xFFF57C00)]
                                : [const Color(0xFFFF9800), const Color(0xFFFFB74D)],
                          ),
                          accentColor: isDark ? const Color(0xFFFFAB40) : const Color(0xFFF57C00),
                        ),

                        const SizedBox(height: 10),

                        _BriefingButton(
                          icon: Icons.analytics_rounded,
                          title: 'Deneme Analizi',
                          subtitle: 'Hatalarını keşfet. Eksiklerini MR gibi tarayalım, netlerini artıralım. 💡',
                          onTap: () => onPromptSelected('trial_review'),
                          delay: 550.ms,
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF6B4226), const Color(0xFF8B5A2B)]
                                : [const Color(0xFFFFD54F), const Color(0xFFFFB300)],
                          ),
                          accentColor: isDark ? const Color(0xFFFFD54F) : const Color(0xFFFF8F00),
                        ),

                        const SizedBox(height: 10),

                        _BriefingButton(
                          icon: Icons.rocket_launch_rounded,
                          title: 'Strateji Danışma',
                          subtitle: 'Stratejik program ve kişiye özel yol haritası. Planla ve kazan! 🔥',
                          onTap: () => onPromptSelected('strategy_consult'),
                          delay: 600.ms,
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF1A4D6D), const Color(0xFF2563A8)]
                                : [const Color(0xFF42A5F5), const Color(0xFF1E88E5)],
                          ),
                          accentColor: isDark ? const Color(0xFF64B5F6) : const Color(0xFF0D47A1),
                        ),

                        const SizedBox(height: 12),

                        // Disclaimer
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outline.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Rehberlik amaçlıdır, tıbbi tedavi yerine geçmez.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 650.ms),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BriefingButton extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Duration delay;
  final Gradient gradient;
  final Color accentColor;

  const _BriefingButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.delay,
    required this.gradient,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(isDark ? 0.15 : 0.25),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isDark ? Colors.white : Colors.white.withOpacity(0.95),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.white,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? Colors.white.withOpacity(0.85)
                            : Colors.white.withOpacity(0.9),
                        height: 1.25,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: delay).slideX(begin: 0.2, curve: Curves.easeOutCubic);
  }
}

class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool animate;
  final ScrollController? scrollController;
  const _MessageBubble({required this.message, this.animate = false, this.scrollController});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  String _displayedText = '';
  Timer? _typewriterTimer;
  bool _isTyping = false;

  // Typewriter hızı (ms per karakter) - Hayalet gibi hızlı akış
  static const int _baseCharDelay = 1; // Temel hız (çok hızlı)
  static const int _wordDelay = 0; // Kelime sonrası (anında)
  static const int _punctuationDelay = 8; // Noktalama sonrası (minimal)
  static const int _newlineDelay = 12; // Yeni satır sonrası

  @override
  void initState() {
    super.initState();
    // AI mesajları için typewriter efekti, kullanıcı mesajları direkt gösterilir
    if (!widget.message.isUser && widget.animate) {
      _startTypewriterEffect();
    } else {
      _displayedText = widget.message.text;
    }
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    super.dispose();
  }

  void _startTypewriterEffect() {
    final fullText = widget.message.text;
    if (fullText.isEmpty) {
      _displayedText = fullText;
      return;
    }

    setState(() {
      _isTyping = true;
      _displayedText = '';
    });

    int charIndex = 0;

    void typeNextChar() {
      if (!mounted || charIndex >= fullText.length) {
        if (mounted) {
          setState(() => _isTyping = false);
          // Yazım bitince son scroll
          _scrollToBottomSmooth();
        }
        return;
      }

      final char = fullText[charIndex];
      setState(() {
        _displayedText = fullText.substring(0, charIndex + 1);
      });

      charIndex++;

      // Her 20 karakterde bir scroll yap (otomatik takip)
      if (charIndex % 20 == 0 && widget.scrollController != null) {
        _scrollToBottomSmooth();
      }

      // Doğal yazma hissi için değişken gecikme
      int delay = _baseCharDelay;
      if (char == ' ') {
        delay = _wordDelay;
      } else if ('.!?'.contains(char)) {
        delay = _punctuationDelay;
      } else if (',;:'.contains(char)) {
        delay = _punctuationDelay ~/ 2;
      } else if (char == '\n') {
        delay = _newlineDelay;
      }

      _typewriterTimer = Timer(Duration(milliseconds: delay), typeNextChar);
    }

    // İlk karakteri biraz geciktirerek başlat (daha doğal)
    _typewriterTimer = Timer(const Duration(milliseconds: 50), typeNextChar);
  }

  void _scrollToBottomSmooth() {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bg = isUser
        ? colorScheme.secondary
        : colorScheme.surfaceContainerHighest;
    final Color fg = isUser ? Colors.black87 : colorScheme.onSurface;

    final content = GestureDetector(
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: widget.message.text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✓ Mesaj kopyalandı'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const CircleAvatar(
                  backgroundColor: Colors.transparent,
                  radius: 16,
                  backgroundImage: AssetImage('assets/images/bunnyy.webp'),
                ),
              ),
            if (!isUser) const SizedBox(width: 10),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(6),
                      bottomRight: isUser ? const Radius.circular(6) : const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          _displayedText,
                          style: TextStyle(
                            color: fg,
                            fontSize: 15.5,
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      // Yanıp sönen cursor efekti (yazım sırasında)
                      if (_isTyping && !isUser)
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: _BlinkingCursor(color: fg),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!widget.animate) return content;
    return Animate(
      effects: const [
        FadeEffect(duration: Duration(milliseconds: 200), curve: Curves.easeIn),
        SlideEffect(
          begin: Offset(0, 0.1),
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      ],
      child: content,
    );
  }
}

// Yanıp sönen cursor widget'ı - ChatGPT tarzı
class _BlinkingCursor extends StatefulWidget {
  final Color color;
  const _BlinkingCursor({required this.color});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 530),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 2,
        height: 18,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.8),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const CircleAvatar(
                backgroundColor: Colors.transparent,
                radius: 16,
                backgroundImage: AssetImage('assets/images/bunnyy.webp'),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  return Animate(
                    delay: (index * 200).ms,
                    onPlay: (c) => c.repeat(reverse: true),
                    effects: const [
                      ScaleEffect(
                        duration: Duration(milliseconds: 600),
                        curve: Curves.easeInOut,
                        begin: Offset(0.7, 0.7),
                        end: Offset(1.1, 1.1),
                      ),
                    ],
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
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

// Öneri mesajları widget'ı
class _SuggestionView extends StatelessWidget {
  final String promptType;
  final List<String> suggestions;
  final Function(String) onSuggestionTap;

  const _SuggestionView({
    required this.promptType,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  String get _title {
    switch (promptType) {
      case 'trial_review':
        return 'Deneme Analizi';
      case 'strategy_consult':
        return 'Strateji Danışma';
      case 'psych_support':
        return 'Dostça Destek';
      case 'motivation_corner':
        return 'Motivasyon Köşesi';
      default:
        return 'Sohbet';
    }
  }

  String get _subtitle {
    switch (promptType) {
      case 'trial_review':
        return 'Deneme sonuçlarını birlikte değerlendirelim';
      case 'strategy_consult':
        return 'Çalışma stratejin hakkında konuşalım';
      case 'psych_support':
        return 'Seni dinliyorum, ne hissediyorsun?';
      case 'motivation_corner':
        return 'Enerjini yükseltmeye hazır mısın?';
      default:
        return 'Nasıl yardımcı olabilirim?';
    }
  }

  IconData get _icon {
    switch (promptType) {
      case 'trial_review':
        return Icons.analytics_rounded;
      case 'strategy_consult':
        return Icons.rocket_launch_rounded;
      case 'psych_support':
        return Icons.favorite_rounded;
      case 'motivation_corner':
        return Icons.bolt_rounded;
      default:
        return Icons.chat_rounded;
    }
  }

  Color _getAccentColor(ColorScheme colorScheme, bool isDark) {
    switch (promptType) {
      case 'trial_review':
        return isDark ? const Color(0xFFFFD54F) : const Color(0xFFFF8F00);
      case 'strategy_consult':
        return isDark ? const Color(0xFF64B5F6) : const Color(0xFF1976D2);
      case 'psych_support':
        return isDark ? const Color(0xFFBA68C8) : const Color(0xFFC2185B);
      case 'motivation_corner':
        return isDark ? const Color(0xFFFFAB40) : const Color(0xFFF57C00);
      default:
        return colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = _getAccentColor(colorScheme, isDark);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Tavşan Avatar ve Başlık
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: accentColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accentColor.withOpacity(0.5), width: 2),
                    ),
                    child: const CircleAvatar(
                      backgroundColor: Colors.transparent,
                      radius: 32,
                      backgroundImage: AssetImage('assets/images/bunnyy.webp'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_icon, color: accentColor, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        _title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.95, 0.95)),

            const SizedBox(height: 24),

            // Öneri başlığı
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: 16, color: accentColor),
                      const SizedBox(width: 6),
                      Text(
                        'Önerilen Sorular',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 150.ms),

            const SizedBox(height: 16),

            // Öneri butonları
            ...suggestions.asMap().entries.map((entry) {
              final index = entry.key;
              final suggestion = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SuggestionChip(
                  text: suggestion,
                  accentColor: accentColor,
                  onTap: () => onSuggestionTap(suggestion),
                ),
              ).animate().fadeIn(delay: (200 + index * 80).ms).slideX(begin: 0.1);
            }),

            const SizedBox(height: 20),

            // Alt bilgi
            Text(
              'Veya aşağıya kendi mesajını yazabilirsin',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final Color accentColor;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.text,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withOpacity(0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(isDark ? 0.1 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

