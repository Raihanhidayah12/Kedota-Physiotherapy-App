import 'package:flutter/material.dart';

class CustomDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool Function(DateTime date)? selectableDay;

  const CustomDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.selectableDay,
  });

  @override
  State<CustomDatePickerDialog> createState() => _CustomDatePickerDialogState();
}

class _CustomDatePickerDialogState extends State<CustomDatePickerDialog> {
  late DateTime _displayedMonth;
  DateTime? _selectedDate;

  final List<String> _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
    );
    _selectedDate = widget.initialDate;
  }

  void _onMonthSelected(int monthIndex) {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, monthIndex + 1);
    });
  }

  void _onYearSelected(int year) {
    setState(() {
      _displayedMonth = DateTime(year, _displayedMonth.month);
    });
  }

  void _onDateSelected(DateTime date) {
    if (widget.selectableDay?.call(date) == false) return;
    setState(() {
      _selectedDate = date;
    });
    // Return selected date after short delay for visual feedback
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        Navigator.of(context).pop(date);
      }
    });
  }

  int get _daysInMonth {
    return DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
  }

  int get _firstDayOffset {
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    // In Dart, DateTime.weekday: 1=Mon, 7=Sun.
    // We want Sun=0, Mon=1, ..., Sat=6.
    return firstDay.weekday % 7;
  }

  @override
  Widget build(BuildContext context) {
    final years = List.generate(
      widget.lastDate.year - widget.firstDate.year + 1,
      (index) => widget.firstDate.year + index,
    );

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                children: [
                  // MONTH DROPDOWN
                  PopupMenuButton<int>(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: _onMonthSelected,
                    itemBuilder: (context) {
                      return List.generate(_months.length, (index) {
                        final isSelected = _displayedMonth.month == index + 1;
                        return PopupMenuItem<int>(
                          value: index,
                          child: Text(
                            _months[index],
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? const Color(0xFF00A79D)
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        );
                      });
                    },
                    child: Text(
                      _months[_displayedMonth.month - 1],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // YEAR DROPDOWN
                  PopupMenuButton<int>(
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: _onYearSelected,
                    // Open to current year approximately
                    initialValue: _displayedMonth.year,
                    constraints: const BoxConstraints(maxHeight: 300),
                    itemBuilder: (context) {
                      return years.map((year) {
                        final isSelected = _displayedMonth.year == year;
                        return PopupMenuItem<int>(
                          value: year,
                          child: Text(
                            year.toString(),
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? const Color(0xFF00A79D)
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        );
                      }).toList();
                    },
                    child: Text(
                      _displayedMonth.year.toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const Spacer(),

                  // PENCIL ICON
                  GestureDetector(
                    onTap: () {
                      // Close dialog without returning a date (so parent can focus input)
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFEAF7F4), // Light teal background
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.edit,
                          size: 16,
                          color: Color(0xFF00A79D),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // DAYS OF WEEK HEADER
              Row(
                children: ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'].map(
                  (day) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
              const SizedBox(height: 12),

              // DAYS GRID
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: _firstDayOffset + _daysInMonth,
                itemBuilder: (context, index) {
                  if (index < _firstDayOffset) {
                    return const SizedBox.shrink();
                  }

                  final dayNumber = index - _firstDayOffset + 1;
                  final currentDate = DateTime(
                    _displayedMonth.year,
                    _displayedMonth.month,
                    dayNumber,
                  );

                  final isSelected =
                      _selectedDate != null &&
                      _selectedDate!.year == currentDate.year &&
                      _selectedDate!.month == currentDate.month &&
                      _selectedDate!.day == currentDate.day;

                  // Simple check if date is outside bounds
                  final isSelectable =
                      currentDate.isAfter(
                        widget.firstDate.subtract(const Duration(days: 1)),
                      ) &&
                      currentDate.isBefore(
                        widget.lastDate.add(const Duration(days: 1)),
                      ) &&
                      (widget.selectableDay?.call(currentDate) ?? true);

                  return GestureDetector(
                    onTap: isSelectable
                        ? () => _onDateSelected(currentDate)
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFD8E4EB)
                            : Colors.transparent, // Light blue from Figma
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          dayNumber.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: !isSelectable
                                ? const Color(
                                    0xFFCBD5E1,
                                  ) // Greyed out if unselectable
                                : const Color(
                                    0xFF1E293B,
                                  ), // Dark text otherwise
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
