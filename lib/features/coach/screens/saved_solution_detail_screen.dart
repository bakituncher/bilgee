import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:taktik/features/coach/models/saved_solution_model.dart';
import 'package:taktik/features/coach/providers/saved_solutions_provider.dart';
import 'package:taktik/features/coach/screens/question_solver_screen.dart'; // Markdown builder'lar için
import 'package:markdown/markdown.dart' as md;
import 'package:taktik/features/coach/services/question_solver_service.dart';

class SavedSolutionDetailScreen extends ConsumerStatefulWidget {
  final SavedSolutionModel solution;

  const SavedSolutionDetailScreen({super.key, required this.solution});

  @override
  ConsumerState<SavedSolutionDetailScreen> createState() =>
      _SavedSolutionDetailScreenState();
}

class _SavedSolutionDetailScreenState
    extends ConsumerState<SavedSolutionDetailScreen> {
  bool _isSolving = false; // Çözüm işlemi sürüyor mu?
  bool _isChatMode = false; // Sohbet modu aktif mi?
  bool _isChatLoading = false; // Sohbet cevap bekliyor mu?

  final List<SolverMessage> _messages = []; // Sohbet geçmişi
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _solveQuestion(SavedSolutionModel currentSolution) async {
    // Premium Kontrolü
    final isPremium = ref.read(premiumStatusProvider);
    if (!isPremium) {
      context.push('/ai-hub/offer', extra: {
        'title': 'Soru Çözücü',
        'subtitle': 'Anında çözüm cebinde.',
        'icon': Icons.camera_enhance_rounded,
        'color': Colors.orangeAccent,
        'marketingTitle': 'Soruda Takılma!',
        'marketingSubtitle': 'Yapamadığın sorunun fotoğrafını çek, Taktik Tavşan adım adım çözümünü anlatsın.',
        'redirectRoute': null, // Mevcut sayfada kalması için null bırakıldı
      });
      return;
    }

    setState(() => _isSolving = true);

    try {
      final service = ref.read(questionSolverServiceProvider);
      final user = ref.read(userProfileProvider).value;

      // Kayıtlı resim yolunu XFile'a çevir
      final imageFile = XFile(currentSolution.localImagePath);

      // Soruyu çözdür
      final result = await service.solveQuestion(
        imageFile,
        examType: user?.selectedExam,
      );

      // Sonucu kaydet (Modeli güncelle)
      await ref
          .read(savedSolutionsProvider.notifier)
          .updateSolution(currentSolution, result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Soru başarıyla çözüldü!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString().replaceAll("Exception:", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSolving = false);
      }
    }
  }

  // SOHBET MODUNU BAŞLAT
  void _activateChatMode(String initialSolution) {
    if (initialSolution.isEmpty || initialSolution == 'Görsel Soru') return;

    setState(() {
      _isChatMode = true;
      // İlk çözümü sohbetin ilk mesajı olarak ekle
      if (_messages.isEmpty) {
        _messages.add(SolverMessage(initialSolution, isUser: false));
      }
    });

    // Hafif bir kaydırma efekti ile kullanıcıya odaklanma hissi ver
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // TAKİP SORUSU GÖNDER
  Future<void> _sendFollowUpMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _isChatLoading) return;

    // 1. Kullanıcı mesajını ekle
    setState(() {
      _messages.add(SolverMessage(text, isUser: true));
      _isChatLoading = true;
    });
    _chatController.clear();
    _scrollToBottom();

    try {
      final service = ref.read(questionSolverServiceProvider);
      final user = ref.read(userProfileProvider).value;

      // Bağlam olarak ilk çözümü kullan (mesajların ilki)
      final contextSolution = _messages.first.text;

      final response = await service.solveFollowUp(
        originalPrompt: "Context",
        previousSolution: contextSolution,
        userQuestion: text,
        examType: user?.selectedExam,
      );

      if (mounted) {
        setState(() {
          _messages.add(SolverMessage(response, isUser: false));
          _isChatLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'))
        );
        setState(() => _isChatLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Listeyi dinle
    final allSolutions = ref.watch(savedSolutionsProvider);

    // SORUNUN ÇÖZÜMÜ: Key yerine ID ile eşleştirme yapıyoruz ve hata durumunda eskisini kullanıyoruz.
    // Bu sayede 'firstWhere' hata fırlatsa bile uygulama çökmez veya beyaz ekranda kalmaz.
    SavedSolutionModel currentSolution;
    try {
      currentSolution = allSolutions.firstWhere(
            (s) => s.id == widget.solution.id,
        orElse: () => widget.solution, // Bulamazsa mevcut olanı kullan (Fallback)
      );
    } catch (_) {
      currentSolution = widget.solution;
    }

    // Çözüldü mü kontrolü (Varsayılan metin: "Görsel Soru")
    final bool isSolved = currentSolution.solutionText != 'Görsel Soru';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        // Çözülmemişse "Soru", çözülmüşse "Çözüm" yazsın
        title: Text(isSolved ? 'Çözüm' : 'Soru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Silinsin mi?'),
                  content: const Text('Bu işlem geri alınamaz.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('İptal')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sil',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );

              if (confirm == true) {
                await ref
                    .read(savedSolutionsProvider.notifier)
                    .deleteSolution(currentSolution);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Soru Resmi (Animasyon ile birlikte) - ScrollView dışında
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black,
                ),
                constraints: const BoxConstraints(maxHeight: 300),
                child: Stack(
                  children: [
                    Image.file(File(currentSolution.localImagePath),
                        fit: BoxFit.contain),
                    if (_isSolving)
                      _ScanningAnalysisOverlay(theme: theme),
                  ],
                ),
              ),
            ),
          ),

          // İÇERİK ALANI
          Expanded(
            child: !isSolved && !_isSolving
                ? _buildUnsolvedState(theme, currentSolution)
                : _isChatMode
                    ? _buildChatView(theme)
                    : _buildInitialResultView(theme, currentSolution),
          ),

          // Chat Input (Sadece sohbet modunda görünür)
          if (_isChatMode && isSolved) _buildInputArea(theme),
        ],
      ),
    );
  }
}

// --- TARAMA EFEKTLİ ANALİZ OVERLAY ---
class _ScanningAnalysisOverlay extends StatefulWidget {
  final ThemeData theme;

  const _ScanningAnalysisOverlay({required this.theme});

  @override
  State<_ScanningAnalysisOverlay> createState() => _ScanningAnalysisOverlayState();
}

class _ScanningAnalysisOverlayState extends State<_ScanningAnalysisOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scanAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withOpacity(0.4),
      ),
      child: AnimatedBuilder(
        animation: _scanAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              // Grid overlay (opsiyonel - gelişmiş görünüm için)
              CustomPaint(
                painter: _GridPainter(
                  color: widget.theme.colorScheme.primary.withOpacity(0.1),
                ),
                size: Size.infinite,
              ),

              // Ana tarama çizgisi
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: _ScanLinePainter(
                    progress: _scanAnimation.value,
                    color: widget.theme.colorScheme.primary,
                  ),
                  child: Container(),
                ),
              ),

              // Merkez bilgi kutusu
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: widget.theme.colorScheme.surface.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.theme.colorScheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Radar ikonu
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Dış halka (pulse efekti)
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.theme.colorScheme.primary.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                          ).animate(onPlay: (c) => c.repeat())
                              .scale(
                                begin: const Offset(1.0, 1.0),
                                end: const Offset(1.3, 1.3),
                                duration: 1.5.seconds,
                              )
                              .fadeOut(begin: 0.6, duration: 1.5.seconds),

                          // İç ikon
                          Icon(
                            Icons.document_scanner_outlined,
                            size: 36,
                            color: widget.theme.colorScheme.primary,
                          ).animate(onPlay: (c) => c.repeat())
                              .shimmer(
                                duration: 1.8.seconds,
                                color: widget.theme.colorScheme.secondary,
                              ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Metin
                      Text(
                        'Soru Analiz Ediliyor',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: widget.theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Progress indicator
                      SizedBox(
                        width: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            backgroundColor: widget.theme.colorScheme.primary.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate()
                    .fadeIn(duration: 300.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.0, 1.0),
                      duration: 300.ms,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Tarama çizgisi çizen CustomPainter
class _ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScanLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Progress -1'den 1'e gidiyor, biz bunu 0-1 aralığına çevirelim
    final normalizedProgress = (progress + 1) / 2;
    final scanY = size.height * normalizedProgress;

    // Glow efekti için gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withOpacity(0.0),
        color.withOpacity(0.3),
        color.withOpacity(0.8),
        color.withOpacity(0.3),
        color.withOpacity(0.0),
      ],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
    );

    final rect = Rect.fromLTWH(
      0,
      scanY - 40,
      size.width,
      80,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, paint);

    // Ana tarama çizgisi (ince parlak çizgi)
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, scanY),
      Offset(size.width, scanY),
      linePaint,
    );

    // Yan nokta efektleri
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 5; i++) {
      final x = (size.width / 4) * i;
      canvas.drawCircle(Offset(x, scanY), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Grid çizen CustomPainter (arka plan detayı)
class _GridPainter extends CustomPainter {
  final Color color;

  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 30.0;

    // Dikey çizgiler
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Yatay çizgiler
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

// --- UI BİLEŞENLERİ ---

extension on _SavedSolutionDetailScreenState {
  Widget _buildUnsolvedState(ThemeData theme, SavedSolutionModel currentSolution) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Bu soru henüz çözülmemiş.",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                "Çözümü görmek için butona tıkla.",
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _solveQuestion(currentSolution),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text("Yapay Zeka ile Çöz"),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
                  delay: 1.seconds, duration: 2.seconds),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialResultView(ThemeData theme, SavedSolutionModel currentSolution) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: MarkdownBody(
              data: currentSolution.solutionText,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                    color: theme.colorScheme.onSurface, height: 1.5, fontSize: 15),
                h1: TextStyle(
                    color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                strong: TextStyle(
                    color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700),
              ),
              builders: {
                'latex': LatexElementBuilder(
                  textStyle:
                      TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
                ),
              },
              extensionSet: md.ExtensionSet(
                [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                [
                  ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                  LatexInlineSyntax()
                ],
              ),
            ),
          ).animate().fadeIn().slideY(begin: 0.1, end: 0),
          const SizedBox(height: 16),
          // "Anlamadığım kısmı sor" butonu
          FilledButton.icon(
            onPressed: () => _activateChatMode(currentSolution.solutionText),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text("Anlamadığım Kısmı Sor"),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              backgroundColor: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildChatView(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_isChatLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) return _buildTypingIndicator(theme);
        return _buildMessageBubble(theme, _messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ThemeData theme, SolverMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isUser ? theme.colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    "Taktik Tavşan",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            MarkdownBody(
              data: message.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: isUser
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontSize: 15,
                ),
                strong: TextStyle(
                  color: isUser
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              builders: {
                'latex': LatexElementBuilder(
                  textStyle: TextStyle(
                    color: isUser
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              },
              extensionSet: md.ExtensionSet(
                [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                [
                  ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                  LatexInlineSyntax()
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn().slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: InputDecoration(
                hintText: 'Anlamadığın yeri sor...',
                filled: true,
                fillColor:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendFollowUpMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isChatLoading ? null : _sendFollowUpMessage,
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "Cevap yazılıyor...",
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

