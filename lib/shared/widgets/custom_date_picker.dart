import 'package:flutter/material.dart';

/// Türkçe, şık ve kaydırılabilir tarih seçici
class CustomDatePicker {
  static Future<DateTime?> show({
    required BuildContext context,
    DateTime? initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    // Varsayılan tarih: 10 Ekim 2010
    final selectedDate = initialDate ?? DateTime(2010, 10, 10);

    return await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DatePickerBottomSheet(
        initialDate: selectedDate,
        firstDate: firstDate,
        lastDate: lastDate,
      ),
    );
  }
}

class _DatePickerBottomSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _DatePickerBottomSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_DatePickerBottomSheet> createState() => _DatePickerBottomSheetState();
}

class _DatePickerBottomSheetState extends State<_DatePickerBottomSheet> {
  late int selectedYear;
  late int selectedMonth;
  late int selectedDay;

  late FixedExtentScrollController yearController;
  late FixedExtentScrollController monthController;
  late FixedExtentScrollController dayController;

  static const List<String> monthNames = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialDate.year;
    selectedMonth = widget.initialDate.month;
    selectedDay = widget.initialDate.day;

    // Controller'ları başlat - ortada olsun
    final yearList = _getYears();
    final yearIndex = yearList.indexOf(selectedYear);
    yearController = FixedExtentScrollController(initialItem: yearIndex >= 0 ? yearIndex : 0);

    monthController = FixedExtentScrollController(initialItem: selectedMonth - 1);
    dayController = FixedExtentScrollController(initialItem: selectedDay - 1);
  }

  @override
  void dispose() {
    yearController.dispose();
    monthController.dispose();
    dayController.dispose();
    super.dispose();
  }

  List<int> _getYears() {
    return List.generate(
      widget.lastDate.year - widget.firstDate.year + 1,
      (index) => widget.firstDate.year + index,
    );
  }

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  void _updateDay() {
    final maxDays = _getDaysInMonth(selectedYear, selectedMonth);
    if (selectedDay > maxDays) {
      setState(() {
        selectedDay = maxDays;
      });
      // Günü güncelle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (dayController.hasClients) {
          dayController.jumpToItem(selectedDay - 1);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final years = _getYears();
    final maxDays = _getDaysInMonth(selectedYear, selectedMonth);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Başlık
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'İptal',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    'Doğum Tarihini Seç',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        DateTime(selectedYear, selectedMonth, selectedDay),
                      );
                    },
                    child: Text(
                      'Tamam',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Tarih seçici wheel'ler
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  // Gün
                  Expanded(
                    flex: 2,
                    child: Stack(
                      children: [
                        ListWheelScrollView.useDelegate(
                          controller: dayController,
                          itemExtent: 50,
                          perspective: 0.005,
                          diameterRatio: 1.2,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            setState(() {
                              selectedDay = index + 1;
                            });
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: maxDays,
                            builder: (context, index) {
                              final day = index + 1;
                              final isSelected = day == selectedDay;
                              return Center(
                                child: Text(
                                  day.toString(),
                                  style: TextStyle(
                                    fontSize: isSelected ? 24 : 18,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Seçim çizgileri
                        IgnorePointer(
                          child: Center(
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
                                  bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Ay
                  Expanded(
                    flex: 3,
                    child: Stack(
                      children: [
                        ListWheelScrollView.useDelegate(
                          controller: monthController,
                          itemExtent: 50,
                          perspective: 0.005,
                          diameterRatio: 1.2,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            setState(() {
                              selectedMonth = index + 1;
                              _updateDay();
                            });
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: 12,
                            builder: (context, index) {
                              final isSelected = index + 1 == selectedMonth;
                              return Center(
                                child: Text(
                                  monthNames[index],
                                  style: TextStyle(
                                    fontSize: isSelected ? 24 : 18,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        IgnorePointer(
                          child: Center(
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
                                  bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Yıl
                  Expanded(
                    flex: 2,
                    child: Stack(
                      children: [
                        ListWheelScrollView.useDelegate(
                          controller: yearController,
                          itemExtent: 50,
                          perspective: 0.005,
                          diameterRatio: 1.2,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            setState(() {
                              selectedYear = years[index];
                              _updateDay();
                            });
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: years.length,
                            builder: (context, index) {
                              final year = years[index];
                              final isSelected = year == selectedYear;
                              return Center(
                                child: Text(
                                  year.toString(),
                                  style: TextStyle(
                                    fontSize: isSelected ? 24 : 18,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        IgnorePointer(
                          child: Center(
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
                                  bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

