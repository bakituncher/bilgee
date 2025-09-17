// lib/features/onboarding/widgets/personalization_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PersonalizationWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onDataCollected;

  const PersonalizationWidget({
    super.key,
    required this.onDataCollected,
  });

  @override
  State<PersonalizationWidget> createState() => _PersonalizationWidgetState();
}

class _PersonalizationWidgetState extends State<PersonalizationWidget>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Kişiselleştirme verileri
  String? _selectedGoal;
  final TextEditingController _customGoalController = TextEditingController();
  final Map<String, bool> _challenges = {
    'Konu eksiği': false,
    'Zaman yönetimi': false,
    'Motivasyon eksikliği': false,
    'Soru çözme hızı': false,
    'Stres ve kaygı': false,
    'Planlama zorluğu': false,
    'Dikkat dağınıklığı': false,
    'Tekrar eksikliği': false,
  };
  double _weeklyStudyHours = 15.0;
  String _studyStyle = '';

  final List<String> _goalPresets = [
    'Tıp Fakültesi',
    'Mühendislik Fakültesi',
    'Hukuk Fakültesi',
    'Öğretmenlik',
    'İşletme/İktisat',
    'Fen Bilimleri',
    'Sosyal Bilimler',
    'Yabancı Dil',
    'Devlet Kurumu',
    'Diğer',
  ];

  final List<StudyStyleOption> _studyStyles = [
    StudyStyleOption(
      id: 'visual',
      title: 'Görsel Öğrenme',
      description: 'Diyagram, grafik ve görseller kullanarak',
      icon: Icons.visibility,
      color: Colors.blue,
    ),
    StudyStyleOption(
      id: 'auditory',
      title: 'İşitsel Öğrenme',
      description: 'Dinleyerek ve tartışarak',
      icon: Icons.headphones,
      color: Colors.green,
    ),
    StudyStyleOption(
      id: 'kinesthetic',
      title: 'Uygulamalı Öğrenme',
      description: 'Pratik yaparak ve deneyimleyerek',
      icon: Icons.build,
      color: Colors.orange,
    ),
    StudyStyleOption(
      id: 'reading',
      title: 'Okuma/Yazma',
      description: 'Not alarak ve okuyarak',
      icon: Icons.book,
      color: Colors.purple,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _customGoalController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _collectAndContinue();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _collectAndContinue() {
    final data = {
      'goal': _selectedGoal == 'Diğer' ? _customGoalController.text.trim() : _selectedGoal,
      'challenges': _challenges.entries.where((e) => e.value).map((e) => e.key).toList(),
      'weeklyStudyHours': _weeklyStudyHours,
      'studyStyle': _studyStyle,
      'timestamp': DateTime.now().toIso8601String(),
    };
    widget.onDataCollected(data);
  }

  bool _canContinue() {
    switch (_currentStep) {
      case 0:
        return _selectedGoal != null &&
               (_selectedGoal != 'Diğer' || _customGoalController.text.trim().isNotEmpty);
      case 1:
        return _challenges.values.any((selected) => selected);
      case 2:
        return true; // Haftalık saat her zaman geçerli
      case 3:
        return _studyStyle.isNotEmpty;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Başlık ve ilerleme
        Container(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'Seni Tanıyalım 👤',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              )
              .animate()
              .fadeIn(duration: 800.ms)
              .slideY(begin: -0.2, end: 0),

              SizedBox(height: 16),

              Text(
                'Sana en uygun deneyimi sunmak için biraz bilgi alalım',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              )
              .animate(delay: 300.ms)
              .fadeIn(duration: 800.ms),

              SizedBox(height: 20),

              // İlerleme göstergesi
              Row(
                children: List.generate(_totalSteps, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= _currentStep
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              )
              .animate(delay: 500.ms)
              .fadeIn(duration: 800.ms),

              SizedBox(height: 8),

              Text(
                'Adım ${_currentStep + 1} / $_totalSteps',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),

        // İçerik alanı
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: NeverScrollableScrollPhysics(),
            children: [
              _buildGoalStep(),
              _buildChallengesStep(),
              _buildStudyHoursStep(),
              _buildStudyStyleStep(),
            ],
          ),
        ),

        // Alt butonlar
        Container(
          padding: EdgeInsets.all(24),
          child: Row(
            children: [
              if (_currentStep > 0)
                OutlinedButton(
                  onPressed: _previousStep,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 18),
                      SizedBox(width: 8),
                      Text('Geri'),
                    ],
                  ),
                ),

              if (_currentStep > 0) SizedBox(width: 16),

              Expanded(
                child: ElevatedButton(
                  onPressed: _canContinue() ? _nextStep : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    _currentStep < _totalSteps - 1 ? 'Devam Et' : 'Tamamla',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalStep() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hedefin nedir? 🎯',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          )
          .animate()
          .fadeIn(duration: 600.ms)
          .slideX(begin: -0.3, end: 0),

          SizedBox(height: 8),

          Text(
            'Bu bilgi, sana özel içerik ve öneriler sunmamızı sağlar',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          )
          .animate(delay: 200.ms)
          .fadeIn(duration: 600.ms),

          SizedBox(height: 24),

          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _goalPresets.length,
            itemBuilder: (context, index) {
              final goal = _goalPresets[index];
              final isSelected = _selectedGoal == goal;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedGoal = goal;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withOpacity(0.1)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      goal,
                      style: TextStyle(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
              .animate(delay: Duration(milliseconds: index * 100))
              .fadeIn(duration: 600.ms)
              .scale(begin: Offset(0.8, 0.8), end: Offset(1.0, 1.0));
            },
          ),

          if (_selectedGoal == 'Diğer') ...[
            SizedBox(height: 16),
            TextFormField(
              controller: _customGoalController,
              decoration: InputDecoration(
                labelText: 'Hedefini yazabilirsin',
                hintText: 'Örn: Veteriner Hekim olmak',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 600.ms)
            .slideY(begin: 0.3, end: 0),
          ],
        ],
      ),
    );
  }

  Widget _buildChallengesStep() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seni en çok ne zorluyor? 😅',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          )
          .animate()
          .fadeIn(duration: 600.ms)
          .slideX(begin: -0.3, end: 0),

          SizedBox(height: 8),

          Text(
            'Birden fazla seçenek işaretleyebilirsin. Bu bilgiler, sana daha iyi yardım etmemizi sağlar.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          )
          .animate(delay: 200.ms)
          .fadeIn(duration: 600.ms),

          SizedBox(height: 24),

          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _challenges.length,
            itemBuilder: (context, index) {
              final challenge = _challenges.keys.elementAt(index);
              final isSelected = _challenges[challenge] ?? false;

              return InkWell(
                onTap: () {
                  setState(() {
                    _challenges[challenge] = !isSelected;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withOpacity(0.1)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          challenge,
                          style: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .animate(delay: Duration(milliseconds: index * 100))
              .fadeIn(duration: 600.ms)
              .scale(begin: Offset(0.8, 0.8), end: Offset(1.0, 1.0));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudyHoursStep() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Haftalık çalışma hedefin ⏱️',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          )
          .animate()
          .fadeIn(duration: 600.ms)
          .slideX(begin: -0.3, end: 0),

          SizedBox(height: 8),

          Text(
            'Haftada kaç saat çalışmayı planlıyorsun?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          )
          .animate(delay: 200.ms)
          .fadeIn(duration: 600.ms),

          SizedBox(height: 32),

          Center(
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_weeklyStudyHours.toInt()}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          'saat/hafta',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                Text(
                  _getStudyIntensityText(_weeklyStudyHours),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _getStudyIntensityColor(_weeklyStudyHours),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
          .animate(delay: 400.ms)
          .fadeIn(duration: 800.ms)
          .scale(begin: Offset(0.8, 0.8), end: Offset(1.0, 1.0)),

          SizedBox(height: 32),

          Slider(
            value: _weeklyStudyHours,
            min: 5,
            max: 50,
            divisions: 45,
            onChanged: (value) {
              setState(() {
                _weeklyStudyHours = value;
              });
            },
          )
          .animate(delay: 600.ms)
          .fadeIn(duration: 600.ms),

          SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [10, 15, 25, 35].map((hours) {
              return OutlinedButton(
                onPressed: () {
                  setState(() {
                    _weeklyStudyHours = hours.toDouble();
                  });
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: _weeklyStudyHours.toInt() == hours
                      ? theme.colorScheme.primary.withOpacity(0.1)
                      : null,
                ),
                child: Text('$hours'),
              );
            }).toList(),
          )
          .animate(delay: 800.ms)
          .fadeIn(duration: 600.ms),
        ],
      ),
    );
  }

  Widget _buildStudyStyleStep() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Öğrenme stilin nedir? 🧠',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          )
          .animate()
          .fadeIn(duration: 600.ms)
          .slideX(begin: -0.3, end: 0),

          SizedBox(height: 8),

          Text(
            'Hangi yöntemle daha iyi öğreniyorsun?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          )
          .animate(delay: 200.ms)
          .fadeIn(duration: 600.ms),

          SizedBox(height: 24),

          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _studyStyles.length,
            itemBuilder: (context, index) {
              final style = _studyStyles[index];
              final isSelected = _studyStyle == style.id;

              return Container(
                margin: EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _studyStyle = style.id;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? style.color.withOpacity(0.1)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? style.color
                            : theme.colorScheme.outline.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: style.color.withOpacity(0.2),
                          ),
                          child: Icon(
                            style.icon,
                            color: style.color,
                            size: 30,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                style.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? style.color
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                style.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: style.color,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                ),
              )
              .animate(delay: Duration(milliseconds: index * 150))
              .fadeIn(duration: 600.ms)
              .slideX(begin: 0.3, end: 0);
            },
          ),
        ],
      ),
    );
  }

  String _getStudyIntensityText(double hours) {
    if (hours < 10) return '🐌 Hafif Tempo';
    if (hours < 20) return '⚖️ Dengeli Tempo';
    if (hours < 30) return '🔥 Yoğun Tempo';
    return '💪 Süper Yoğun';
  }

  Color _getStudyIntensityColor(double hours) {
    if (hours < 10) return Colors.blue;
    if (hours < 20) return Colors.green;
    if (hours < 30) return Colors.orange;
    return Colors.red;
  }
}

class StudyStyleOption {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  StudyStyleOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
