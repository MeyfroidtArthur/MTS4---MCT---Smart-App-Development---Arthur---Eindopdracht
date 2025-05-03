import 'package:newagendaapp/pages/planning.dart';
import 'package:newagendaapp/pages/location.dart';
import 'package:newagendaapp/pages/account.dart';
import 'package:flutter/material.dart';
import 'package:newagendaapp/overlay/createplan.dart';
import 'package:intl/intl.dart';
import 'package:newagendaapp/widigits/nav.dart';

class Month extends StatefulWidget {
  final String uid; // Add a parameter to accept user info

  const Month({Key? key, required this.uid}) : super(key: key);

  @override
  _MonthState createState() => _MonthState();
}

class _MonthState extends State<Month> {
  bool _isOverlayVisible = false;

  void _toggleOverlay() {
    setState(() {
      _isOverlayVisible = !_isOverlayVisible;
    });
  }

  String getDutchMonth(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maart',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Augustus',
      'September',
      'Oktober',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Stack(
      children: [
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48.0),
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 48.0,
              ), // Added bottom padding
              child: ListView.builder(
                itemCount: 24, // 24 months to display
                itemBuilder: (context, index) {
                  final monthDate = DateTime(now.year, now.month + index, 1);
                  final monthName = getDutchMonth(monthDate.month);
                  final year = monthDate.year;
                  final totalDays = DateUtils.getDaysInMonth(
                    year,
                    monthDate.month,
                  );
                  final today = DateTime.now();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          '$monthName $year',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: totalDays + monthDate.weekday - 1,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1,
                            ),
                        itemBuilder: (context, dayIndex) {
                          if (dayIndex < monthDate.weekday - 1) {
                            return const SizedBox(); // Empty cells at the beginning
                          }

                          final day = dayIndex - (monthDate.weekday - 2);
                          final currentDay = DateTime(
                            year,
                            monthDate.month,
                            day,
                          );
                          final isToday =
                              currentDay.day == today.day &&
                              currentDay.month == today.month &&
                              currentDay.year == today.year;

                          return Column(
                            children: [
                              Text(
                                '$day',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      isToday
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  color:
                                      isToday ? Colors.black : Colors.grey[800],
                                ),
                              ),
                              if (isToday)
                                Container(
                                  width: 16,
                                  height: 2,
                                  color: Colors.black,
                                  margin: const EdgeInsets.only(top: 2),
                                )
                              else
                                const SizedBox(height: 2),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'month_fab', // Single heroTag for all pages
            backgroundColor: const Color(0xFF003049),
            onPressed: _toggleOverlay, // Trigger the FAB action
            child: const Icon(Icons.add, color: Colors.white),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: NavBar(
            currentIndex: 1, // Named argument for the current index
            uid: widget.uid, // Named argument for the user ID
            onFabPressed: _toggleOverlay, // Named argument for the FAB action
          ),
        ),
        if (_isOverlayVisible)
          CreatePlanOverlay(onClose: _toggleOverlay, uid: widget.uid),
      ],
    );
  }
}

// Extensie om eerste letter hoofdletter te maken
extension StringCasingExtension on String {
  String capitalize() =>
      isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : '';
}
