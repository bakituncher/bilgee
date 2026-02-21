// lib/features/games/games_hub.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart';

// ==================== OYUN MERKEZİ ====================
class GamesHub extends StatelessWidget {
  const GamesHub({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Oyun Merkezi',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withAlpha(25),
                    colorScheme.secondary.withAlpha(25),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.games_rounded, size: 48, color: colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Eğlenerek Öğren!',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Oyunlarla bilgini pekiştir',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0),

            const SizedBox(height: 24),

            // Oyun Kartları
            _GameCard(
              title: 'Yazım Kuralları',
              subtitle: 'Doğru yazımı bul',
              icon: Icons.spellcheck_rounded,
              color: const Color(0xFF10B981),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpellingGame())),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideX(begin: -0.1, end: 0),

            const SizedBox(height: 12),

            _GameCard(
              title: 'Yazar-Eser Eşleştirme',
              subtitle: 'Yazarları eserleriyle eşleştir',
              icon: Icons.auto_stories_rounded,
              color: const Color(0xFF8B5CF6),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthorWorkGame())),
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms).slideX(begin: -0.1, end: 0),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: colorScheme.surfaceContainerHighest.withAlpha(76),
          border: Border.all(color: color.withAlpha(76), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withAlpha(38),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 32, color: color),
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
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 18, color: colorScheme.onSurfaceVariant.withAlpha(128)),
          ],
        ),
      ),
    );
  }
}

// ==================== YAZIM KURALLARI OYUNU ====================
class SpellingGame extends StatefulWidget {
  const SpellingGame({super.key});

  @override
  State<SpellingGame> createState() => _SpellingGameState();
}

class _SpellingGameState extends State<SpellingGame> {
  int _score = 0;
  int _currentIndex = 0;
  bool _answered = false;
  String? _selected;
  bool _loading = true;
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final String response = await rootBundle.loadString('assets/data/confused_words.json');
      final data = json.decode(response);
      final List<dynamic> categories = data['categories'];

      // Tüm kelimeleri topla
      List<Map<String, dynamic>> allWords = [];
      for (var category in categories) {
        final List<dynamic> words = category['words'];
        for (var word in words) {
          allWords.add({
            'correct': word['correct'],
            'wrong': List<String>.from(word['wrong']),
            'meaning': word['meaning'],
          });
        }
      }

      // Rastgele 15 kelime seç
      allWords.shuffle(Random());
      final selectedWords = allWords.take(15).toList();

      // Doğru/Yanlış soruları hazırla
      _questions = [];
      for (var word in selectedWords) {
        final correct = word['correct'] as String;
        final wrongList = List<String>.from(word['wrong']);

        // Doğru yazımı göster
        _questions.add({
          'word': correct,
          'isCorrect': true,
        });

        // Yanlış yazımlardan birini göster
        if (wrongList.isNotEmpty) {
          wrongList.shuffle(Random());
          _questions.add({
            'word': wrongList.first,
            'isCorrect': false,
          });
        }
      }

      _questions.shuffle(Random());
      _questions = _questions.take(10).toList();

      setState(() {
        _loading = false;
      });
    } catch (e) {
      print('Karıştırılan kelimeler yüklenirken hata: $e');
      _questions = [
        {'word': 'İlgi', 'isCorrect': true},
        {'word': 'İlgı', 'isCorrect': false},
      ];
      setState(() {
        _loading = false;
      });
    }
  }

  void _check(bool userAnswer) {
    if (_answered) return;
    final isCorrect = _questions[_currentIndex]['isCorrect'] as bool;
    final correct = (userAnswer == isCorrect);

    setState(() {
      _answered = true;
      _selected = userAnswer ? 'doğru' : 'yanlış';
      if (correct) _score += 10;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (_currentIndex < _questions.length - 1) {
        setState(() { _currentIndex++; _answered = false; _selected = null; });
      } else {
        _showResult();
      }
    });
  }

  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(_score >= 70 ? Icons.emoji_events_rounded : Icons.try_sms_star_rounded, color: _score >= 70 ? Colors.amber : Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Oyun Bitti!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Skorun: $_score / ${_questions.length * 10}', style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: Theme.of(ctx).colorScheme.primary)),
            const SizedBox(height: 12),
            Text(
              _score >= 70 ? 'Harika! Yazım kurallarında çok iyisin! 🎉' : _score >= 50 ? 'İyi gidiyorsun! Biraz daha pratik yaparsan mükemmel olacak! 💪' : 'Endişelenme, pratik yaparak gelişebilirsin! 📚',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text('Ana Menü')),
          FilledButton(onPressed: () { Navigator.pop(ctx); setState(() { _score = 0; _currentIndex = 0; _answered = false; _selected = null; }); _loadQuestions(); }, child: const Text('Tekrar Oyna')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yazım Kuralları')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text('Sorular yükleniyor...', style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yazım Kuralları')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Sorular yüklenemedi', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Lütfen daha sonra tekrar deneyin', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Geri Dön'),
              ),
            ],
          ),
        ),
      );
    }

    final q = _questions[_currentIndex];
    final word = q['word'] as String;
    final isCorrect = q['isCorrect'] as bool;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yazım Kuralları'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: colorScheme.primary.withAlpha(38), borderRadius: BorderRadius.circular(20)),
                child: Text('Skor: $_score', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: colorScheme.primary)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Progress
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _questions.length,
                        minHeight: 8,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(colorScheme.primary)
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${_currentIndex + 1}/${_questions.length}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: colorScheme.onSurfaceVariant)),
                ],
              ),

              const Spacer(),

              // Soru
              Text(
                'Bu yazım doğru mu?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 32),

              // Kelime
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: colorScheme.primary.withAlpha(25),
                  border: Border.all(color: colorScheme.primary.withAlpha(51), width: 2),
                ),
                child: Text(
                  word,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.primary,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ).animate(key: ValueKey(_currentIndex)).fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),

              const Spacer(),

              // Doğru/Yanlış Butonları
              Row(
                children: [
                  Expanded(
                    child: _AnswerButton(
                      label: 'YANLIŞ',
                      icon: Icons.close_rounded,
                      color: Colors.red,
                      isSelected: _answered && _selected == 'yanlış',
                      isCorrectAnswer: _answered && !isCorrect,
                      isWrongAnswer: _answered && isCorrect && _selected == 'yanlış',
                      onTap: _answered ? null : () => _check(false),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _AnswerButton(
                      label: 'DOĞRU',
                      icon: Icons.check_rounded,
                      color: Colors.green,
                      isSelected: _answered && _selected == 'doğru',
                      isCorrectAnswer: _answered && isCorrect,
                      isWrongAnswer: _answered && !isCorrect && _selected == 'doğru',
                      onTap: _answered ? null : () => _check(true),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== YAZAR-ESER OYUNU ====================
class AuthorWorkGame extends StatefulWidget {
  const AuthorWorkGame({super.key});

  @override
  State<AuthorWorkGame> createState() => _AuthorWorkGameState();
}

class _AuthorWorkGameState extends State<AuthorWorkGame> {
  int _score = 0;
  int _currentIndex = 0;
  bool _answered = false;
  String? _selected;
  List<Map<String, dynamic>> _questions = [];

  final List<Map<String, dynamic>> _authorWorks = [
    {'work': 'Safahat', 'author': 'Mehmet Akif Ersoy'},
    {'work': 'Sinekli Bakkal', 'author': 'Halide Edip Adıvar'},
    {'work': 'Çalıkuşu', 'author': 'Reşat Nuri Güntekin'},
    {'work': 'Tutunamayanlar', 'author': 'Oğuz Atay'},
    {'work': 'Küçük Prens', 'author': 'Antoine de Saint-Exupéry'},
    {'work': 'Suç ve Ceza', 'author': 'Fyodor Dostoyevski'},
    {'work': 'Kuyucaklı Yusuf', 'author': 'Sabahattin Ali'},
    {'work': 'Hamlet', 'author': 'William Shakespeare'},
    {'work': 'Sefiller', 'author': 'Victor Hugo'},
    {'work': 'Beyaz Diş', 'author': 'Jack London'},
    {'work': 'Kürk Mantolu Madonna', 'author': 'Sabahattin Ali'},
    {'work': 'Yaprak Dökümü', 'author': 'Reşat Nuri Güntekin'},
    {'work': 'Fatih-Harbiye', 'author': 'Peyami Safa'},
    {'work': 'Huzur', 'author': 'Ahmet Hamdi Tanpınar'},
    {'work': 'İnce Memed', 'author': 'Yaşar Kemal'},
  ];

  @override
  void initState() {
    super.initState();
    _generateQuestions();
  }

  void _generateQuestions() {
    _authorWorks.shuffle(Random());
    final selected = _authorWorks.take(10).toList();

    _questions = [];
    for (var item in selected) {
      // Doğru eşleştirme
      _questions.add({
        'work': item['work'],
        'author': item['author'],
        'isCorrect': true,
      });

      // Yanlış eşleştirme
      final wrongAuthors = _authorWorks.where((a) => a['author'] != item['author']).toList();
      wrongAuthors.shuffle(Random());
      _questions.add({
        'work': item['work'],
        'author': wrongAuthors.first['author'],
        'isCorrect': false,
      });
    }

    _questions.shuffle(Random());
    _questions = _questions.take(10).toList();
  }

  void _check(bool userAnswer) {
    if (_answered) return;
    final isCorrect = _questions[_currentIndex]['isCorrect'] as bool;
    final correct = (userAnswer == isCorrect);

    setState(() {
      _answered = true;
      _selected = userAnswer ? 'doğru' : 'yanlış';
      if (correct) _score += 10;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (_currentIndex < _questions.length - 1) {
        setState(() { _currentIndex++; _answered = false; _selected = null; });
      } else {
        _showResult();
      }
    });
  }

  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(_score >= 70 ? Icons.emoji_events_rounded : Icons.try_sms_star_rounded, color: _score >= 70 ? Colors.amber : Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Oyun Bitti!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Skorun: $_score / ${_questions.length * 10}', style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: Theme.of(ctx).colorScheme.primary)),
            const SizedBox(height: 12),
            Text(_score >= 70 ? 'Harika! Edebiyat bilgin çok iyi! 📚' : _score >= 50 ? 'İyi gidiyorsun! Biraz daha pratik yaparsan mükemmel olacak! 💪' : 'Endişelenme, okuyarak gelişebilirsin! 📖', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text('Ana Menü')),
          FilledButton(onPressed: () { Navigator.pop(ctx); setState(() { _score = 0; _currentIndex = 0; _answered = false; _selected = null; }); _generateQuestions(); }, child: const Text('Tekrar Oyna')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_questions.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final q = _questions[_currentIndex];
    final work = q['work'] as String;
    final author = q['author'] as String;
    final isCorrect = q['isCorrect'] as bool;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yazar-Eser Eşleştirme'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: colorScheme.primary.withAlpha(38), borderRadius: BorderRadius.circular(20)),
                child: Text('Skor: $_score', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: colorScheme.primary)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Progress
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _questions.length,
                        minHeight: 8,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(colorScheme.primary)
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${_currentIndex + 1}/${_questions.length}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: colorScheme.onSurfaceVariant)),
                ],
              ),

              const Spacer(),

              // Soru
              Text(
                'Bu eşleştirme doğru mu?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 32),

              // Eser-Yazar Kartı
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: const Color(0xFF8B5CF6).withAlpha(25),
                  border: Border.all(color: const Color(0xFF8B5CF6).withAlpha(51), width: 2),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.auto_stories_rounded, size: 48, color: Color(0xFF8B5CF6)),
                    const SizedBox(height: 24),
                    Text(
                      work,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withAlpha(102),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_downward_rounded, size: 24),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      author,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8B5CF6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ).animate(key: ValueKey(_currentIndex)).fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),

              const Spacer(),

              // Doğru/Yanlış Butonları
              Row(
                children: [
                  Expanded(
                    child: _AnswerButton(
                      label: 'YANLIŞ',
                      icon: Icons.close_rounded,
                      color: Colors.red,
                      isSelected: _answered && _selected == 'yanlış',
                      isCorrectAnswer: _answered && !isCorrect,
                      isWrongAnswer: _answered && isCorrect && _selected == 'yanlış',
                      onTap: _answered ? null : () => _check(false),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _AnswerButton(
                      label: 'DOĞRU',
                      icon: Icons.check_rounded,
                      color: Colors.green,
                      isSelected: _answered && _selected == 'doğru',
                      isCorrectAnswer: _answered && isCorrect,
                      isWrongAnswer: _answered && !isCorrect && _selected == 'doğru',
                      onTap: _answered ? null : () => _check(true),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== ORTAK CEVAP BUTONU ====================
class _AnswerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isCorrectAnswer;
  final bool isWrongAnswer;
  final VoidCallback? onTap;

  const _AnswerButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isCorrectAnswer,
    required this.isWrongAnswer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color borderColor;

    if (isCorrectAnswer) {
      backgroundColor = Colors.green.withAlpha(51);
      borderColor = Colors.green;
    } else if (isWrongAnswer) {
      backgroundColor = Colors.red.withAlpha(51);
      borderColor = Colors.red;
    } else if (isSelected) {
      backgroundColor = color.withAlpha(38);
      borderColor = color;
    } else {
      backgroundColor = color.withAlpha(25);
      borderColor = color.withAlpha(76);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 3),
        ),
        child: Column(
          children: [
            Icon(
              isCorrectAnswer ? Icons.check_circle_rounded :
              isWrongAnswer ? Icons.cancel_rounded : icon,
              size: 48,
              color: isCorrectAnswer ? Colors.green :
                     isWrongAnswer ? Colors.red : color,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: isCorrectAnswer ? Colors.green :
                       isWrongAnswer ? Colors.red : color,
              ),
            ),
          ],
        ),
      ),
    ).animate(target: isSelected || isCorrectAnswer || isWrongAnswer ? 1 : 0)
     .scale(duration: 200.ms, begin: const Offset(1, 1), end: const Offset(1.05, 1.05));
  }
}

