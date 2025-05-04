import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:newagendaapp/overlay/createplan.dart';
import 'package:newagendaapp/widigits/nav.dart';
import 'package:newagendaapp/service/firebaseServices.dart';
import 'package:newagendaapp/widigits/dayappointment.dart';

class Month extends StatefulWidget {
  final String uid;

  const Month({Key? key, required this.uid}) : super(key: key);

  @override
  _MonthState createState() => _MonthState();
}

class _MonthState extends State<Month> {
  bool _isOverlayVisible = false;
  Map<DateTime, List<Map<String, dynamic>>> _appointmentsByDate = {};

  final FirestoreAccess _firestoreAccess = FirestoreAccess();

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  void _toggleOverlay() {
    setState(() {
      _isOverlayVisible = !_isOverlayVisible;
    });
  }

  Future<void> _fetchAppointments() async {
    final appointments = await _firestoreAccess.getAppointments(widget.uid);
    final groupedAppointments = <DateTime, List<Map<String, dynamic>>>{};

    for (var appointment in appointments) {
      final startTime = (appointment['startTime'] as Timestamp).toDate();
      final dateKey = DateTime(startTime.year, startTime.month, startTime.day);

      if (!groupedAppointments.containsKey(dateKey)) {
        groupedAppointments[dateKey] = [];
      }
      groupedAppointments[dateKey]!.add(appointment);
    }

    setState(() {
      _appointmentsByDate = groupedAppointments;
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
              padding: const EdgeInsets.only(bottom: 48.0),
              child: ListView.builder(
                itemCount: 24,
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
                            // Empty cells at the beginning of the grid
                            return const SizedBox(); // Ensure consistent height for empty cells
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

                          final appointments =
                              _appointmentsByDate[currentDay] ?? [];

                          return GestureDetector(
                            onTap: () {
                              if (appointments.isNotEmpty) {
                                showDialog(
                                  context: context,
                                  barrierColor: Colors.black.withOpacity(0.5),
                                  builder: (context) {
                                    return StatefulBuilder(
                                      builder: (context, setState) {
                                        Future<void>
                                        reloadDayAppointments() async {
                                          await _fetchAppointments(); // Reload the Month page data
                                          setState(
                                            () {},
                                          ); // Update the DayAppointmentsOverlay
                                        }

                                        final updatedAppointments =
                                            _appointmentsByDate[currentDay] ??
                                            [];

                                        return DayAppointmentsOverlay(
                                          uid: widget.uid,
                                          selectedDay: currentDay,
                                          appointments: updatedAppointments,
                                          onClose:
                                              () => Navigator.of(context).pop(),
                                          onReload: () async {
                                            await reloadDayAppointments(); // Reload the DayAppointmentsOverlay
                                          },
                                          reloadCallback:
                                              _fetchAppointments, // Reload the Month page
                                        );
                                      },
                                    );
                                  },
                                );
                              }
                            },
                            child: SizedBox(
                              height:
                                  60, // Constrain the height of each grid cell
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    decoration:
                                        isToday
                                            ? const BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color:
                                                      Colors
                                                          .black, // Underline color
                                                  width:
                                                      2.0, // Underline thickness
                                                ),
                                              ),
                                            )
                                            : null,
                                    child: Text(
                                      '$day',
                                      style: TextStyle(
                                        fontSize:
                                            14, // Adjust font size to fit better
                                        fontWeight:
                                            isToday
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                        color:
                                            isToday
                                                ? Colors.black
                                                : Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 4,
                                  ), // Space between the day and circles
                                  Expanded(
                                    child: Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 3,
                                      runSpacing: 3,
                                      children:
                                          appointments
                                              .take(6) // Limit to 6 circles
                                              .map(
                                                (_) => Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.black,
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                              )
                                              .toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
            heroTag: 'month_fab',
            backgroundColor: const Color(0xFF003049),
            onPressed: _toggleOverlay,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: NavBar(
            currentIndex: 1,
            uid: widget.uid,
            onFabPressed: _toggleOverlay,
          ),
        ),
        if (_isOverlayVisible)
          CreatePlanOverlay(
            onClose: _toggleOverlay,
            uid: widget.uid,
            onSave: () {
              _fetchAppointments(); // Refresh appointments after saving or updating
            },
          ),
      ],
    );
  }
}
