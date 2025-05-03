import 'package:newagendaapp/service/firebaseServices.dart'; // Import FirestoreAccess
import 'package:flutter/material.dart';
import 'package:newagendaapp/overlay/createplan.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:newagendaapp/widigits/nav.dart'; // Import NavBar

class Planning extends StatefulWidget {
  final String uid;

  const Planning({Key? key, required this.uid}) : super(key: key);

  @override
  _PlanningState createState() => _PlanningState();
}

class _PlanningState extends State<Planning> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  bool _isOverlayVisible = false;
  List<Map<String, dynamic>> _appointments = []; // Store appointments

  @override
  void initState() {
    super.initState();
    _fetchAppointments(); // Fetch appointments when the page loads
  }

  void _toggleOverlay() {
    setState(() {
      _isOverlayVisible = !_isOverlayVisible;
    });
  }

  Future<void> _fetchAppointments() async {
    FirestoreAccess firestoreAccess = FirestoreAccess();
    List<Map<String, dynamic>> appointments = await firestoreAccess
        .getAppointments(widget.uid);

    // Filter out appointments where the end time is before the current time
    final DateTime now = DateTime.now();
    appointments =
        appointments.where((appointment) {
          final DateTime endTime = appointment['endTime'].toDate();
          return endTime.isAfter(
            now,
          ); // Keep only future or ongoing appointments
        }).toList();

    // Sort appointments by start time (closest first)
    appointments.sort((a, b) {
      final DateTime startTimeA = a['startTime'].toDate();
      final DateTime startTimeB = b['startTime'].toDate();
      return startTimeA.compareTo(startTimeB); // Ascending order
    });

    setState(() {
      _appointments = appointments;
    });
  }

  Future<void> _deleteAppointment(String appointmentId) async {
    try {
      FirestoreAccess firestoreAccess = FirestoreAccess();
      await firestoreAccess.deleteAppointment(widget.uid, appointmentId);
      _fetchAppointments(); // Refresh the appointments list
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Afspraak succesvol verwijderd')),
      );
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Fout bij het verwijderen van de afspraak'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group appointments by month
    final Map<String, List<Map<String, dynamic>>> groupedAppointments = {};
    for (var appointment in _appointments) {
      final DateTime startTime = appointment['startTime'].toDate();
      final String monthKey = DateFormat(
        'MMMM yyyy',
      ).format(startTime); // Format as "Month Year"
      if (!groupedAppointments.containsKey(monthKey)) {
        groupedAppointments[monthKey] = [];
      }
      groupedAppointments[monthKey]!.add(appointment);
    }

    return Stack(
      children: [
        Scaffold(
          key: _scaffoldMessengerKey, // Attach the GlobalKey here
          body: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
            ), // Add 16 padding left and right
            child: Padding(
              padding: const EdgeInsets.only(
                top: 16.0,
              ), // Add 16 padding at the top
              child:
                  _appointments.isEmpty
                      ? const Center(child: Text('No appointments found'))
                      : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: groupedAppointments.keys.length,
                        itemBuilder: (context, monthIndex) {
                          final String monthKey = groupedAppointments.keys
                              .elementAt(monthIndex);
                          final List<Map<String, dynamic>> monthAppointments =
                              groupedAppointments[monthKey]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Month Header
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16.0,
                                ),
                                child: Center(
                                  // Center the month text
                                  child: Text(
                                    monthKey,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Colors
                                              .black, // Change text color to black
                                    ),
                                  ),
                                ),
                              ),
                              // Appointments for the Month
                              ...monthAppointments.map((appointment) {
                                final backgroundColor = Color(
                                  int.parse(
                                    appointment['Color'].replaceFirst(
                                      '#',
                                      '0xFF',
                                    ),
                                  ), // Convert hex string to Color
                                );

                                return GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      barrierColor: Colors.black.withOpacity(
                                        0.5,
                                      ),
                                      builder: (BuildContext context) {
                                        final dateFormat = DateFormat("d MMM");
                                        final timeFormat = DateFormat("HH:mm");
                                        return Center(
                                          child: Material(
                                            color: Colors.transparent,
                                            child: Container(
                                              width: 340,
                                              constraints: BoxConstraints(
                                                maxHeight:
                                                    MediaQuery.of(
                                                      context,
                                                    ).size.height *
                                                    0.85,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 32,
                                                    offset: Offset(0, 12),
                                                  ),
                                                ],
                                              ),
                                              child: Stack(
                                                children: [
                                                  // Main content with consistent padding
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          24.0,
                                                        ),
                                                    child: SingleChildScrollView(
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          // Title with space for the close button
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  appointment['title'] ??
                                                                      'Afspraakdetails',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        20,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color:
                                                                        Colors
                                                                            .black87,
                                                                  ),
                                                                  softWrap:
                                                                      true,
                                                                ),
                                                              ),
                                                              // Empty SizedBox to reserve space for the close button
                                                              SizedBox(
                                                                width: 48,
                                                              ),
                                                            ],
                                                          ),
                                                          SizedBox(height: 20),

                                                          // Date and Time in a Row
                                                          if (appointment['startTime'] !=
                                                                  null &&
                                                              appointment['endTime'] !=
                                                                  null)
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .calendar_today,
                                                                      color:
                                                                          Colors
                                                                              .grey[600],
                                                                      size: 20,
                                                                    ),
                                                                    SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    Text(
                                                                      dateFormat.format(
                                                                        appointment['startTime']
                                                                            .toDate(),
                                                                      ),
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            16,
                                                                        color:
                                                                            Colors.black87,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .access_time,
                                                                      color:
                                                                          Colors
                                                                              .grey[600],
                                                                      size: 20,
                                                                    ),
                                                                    SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    Text(
                                                                      '${timeFormat.format(appointment['startTime'].toDate())} - ${timeFormat.format(appointment['endTime'].toDate())}',
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            16,
                                                                        color:
                                                                            Colors.black87,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          if (appointment['startTime'] !=
                                                                  null &&
                                                              appointment['endTime'] !=
                                                                  null)
                                                            SizedBox(height: 8),

                                                          // Other Information Blocks
                                                          if (appointment['locationName'] !=
                                                              null)
                                                            Row(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Icon(
                                                                  Icons.place,
                                                                  color:
                                                                      Colors
                                                                          .grey[600],
                                                                  size: 20,
                                                                ),
                                                                SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    appointment['locationName']!,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          16,
                                                                      color:
                                                                          Colors
                                                                              .black87,
                                                                    ),
                                                                    softWrap:
                                                                        true,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          if (appointment['locationName'] !=
                                                              null)
                                                            SizedBox(height: 8),

                                                          if (appointment['locationAddress'] !=
                                                              null)
                                                            Row(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .location_on,
                                                                  color:
                                                                      Colors
                                                                          .grey[600],
                                                                  size: 20,
                                                                ),
                                                                SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    appointment['locationAddress']!,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          16,
                                                                      color:
                                                                          Colors
                                                                              .black87,
                                                                    ),
                                                                    softWrap:
                                                                        true,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          if (appointment['locationAddress'] !=
                                                              null)
                                                            SizedBox(height: 8),

                                                          if (appointment['travelMode'] !=
                                                              null)
                                                            Row(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .directions,
                                                                  color:
                                                                      Colors
                                                                          .grey[600],
                                                                  size: 20,
                                                                ),
                                                                SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    appointment['travelMode']!,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          16,
                                                                      color:
                                                                          Colors
                                                                              .black87,
                                                                    ),
                                                                    softWrap:
                                                                        true,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          if (appointment['travelMode'] !=
                                                              null)
                                                            SizedBox(height: 8),

                                                          if (appointment['description'] !=
                                                              null)
                                                            Row(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Icon(
                                                                  Icons.notes,
                                                                  color:
                                                                      Colors
                                                                          .grey[600],
                                                                  size: 20,
                                                                ),
                                                                SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    appointment['description']!,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          16,
                                                                      color:
                                                                          Colors
                                                                              .black87,
                                                                    ),
                                                                    softWrap:
                                                                        true,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          if (appointment['description'] !=
                                                              null)
                                                            SizedBox(
                                                              height: 24,
                                                            ),

                                                          // Footer with Delete and Edit Buttons
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              TextButton.icon(
                                                                style: TextButton.styleFrom(
                                                                  backgroundColor:
                                                                      const Color(
                                                                        0xFF700A0C,
                                                                      ), // Delete button color
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            12,
                                                                        vertical:
                                                                            8,
                                                                      ),
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                  ),
                                                                ),
                                                                icon: const Icon(
                                                                  Icons.delete,
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                ),
                                                                label: const Text(
                                                                  'Verwijder',
                                                                  style: TextStyle(
                                                                    color:
                                                                        Colors
                                                                            .white,
                                                                  ),
                                                                ),
                                                                onPressed: () async {
                                                                  // Show confirmation dialog
                                                                  final bool?
                                                                  confirmDelete = await showDialog<
                                                                    bool
                                                                  >(
                                                                    context:
                                                                        context,
                                                                    builder: (
                                                                      BuildContext
                                                                      context,
                                                                    ) {
                                                                      return AlertDialog(
                                                                        title: const Text(
                                                                          'Bevestiging',
                                                                        ),
                                                                        content:
                                                                            const Text(
                                                                              'Ben je zeker dat je het wilt verwijderen?',
                                                                            ),
                                                                        actions: [
                                                                          TextButton(
                                                                            onPressed: () {
                                                                              Navigator.of(
                                                                                context,
                                                                              ).pop(
                                                                                false,
                                                                              ); // Cancel deletion
                                                                            },
                                                                            child: const Text(
                                                                              'Nee',
                                                                            ),
                                                                          ),
                                                                          TextButton(
                                                                            onPressed: () {
                                                                              Navigator.of(
                                                                                context,
                                                                              ).pop(
                                                                                true,
                                                                              ); // Confirm deletion
                                                                            },
                                                                            child: const Text(
                                                                              'Ja',
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      );
                                                                    },
                                                                  );

                                                                  if (confirmDelete ==
                                                                      true) {
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(); // Close the dialog
                                                                    _deleteAppointment(
                                                                      appointment['id'],
                                                                    ); // Proceed with deletion
                                                                  }
                                                                },
                                                              ),
                                                              ElevatedButton.icon(
                                                                onPressed: () {
                                                                  // Handle save
                                                                  print(
                                                                    'Save appointment',
                                                                  );
                                                                },
                                                                icon: Icon(
                                                                  Icons.edit,
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                ),
                                                                label: Text(
                                                                  'Aanpassen',
                                                                  style: TextStyle(
                                                                    color:
                                                                        Colors
                                                                            .white,
                                                                  ),
                                                                ),
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor: Color(
                                                                    0xFF003049,
                                                                  ), // Save button color
                                                                  padding:
                                                                      EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            12,
                                                                        vertical:
                                                                            8,
                                                                      ),
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  // Close button positioned exactly 16px from the right edge
                                                  Positioned(
                                                    top: 24.0,
                                                    right: 24.0,
                                                    child: GestureDetector(
                                                      onTap:
                                                          () =>
                                                              Navigator.of(
                                                                context,
                                                              ).pop(),
                                                      child: Icon(
                                                        Icons.close,
                                                        color: Colors.grey[800],
                                                        size: 24,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: backgroundColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 12.0,
                                    ), // Increased margin
                                    padding: const EdgeInsets.all(
                                      16.0,
                                    ), // Increased padding
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start, // Align items at the top
                                      children: [
                                        // Date (day of the month)
                                        Text(
                                          DateFormat('d').format(
                                            appointment['startTime'].toDate(),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 28, // Increased font size
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 20,
                                        ), // Increased spacing
                                        // Text Information
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                appointment['title'] ?? '',
                                                style: const TextStyle(
                                                  fontSize:
                                                      18, // Increased font size
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(
                                                height: 12,
                                              ), // Increased spacing
                                              Text(
                                                '${DateFormat.Hm().format(appointment['startTime'].toDate())} - ${DateFormat.Hm().format(appointment['endTime'].toDate())}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(
                                                height: 12,
                                              ), // Increased spacing
                                              if (appointment['locationName'] !=
                                                  null)
                                                Text(
                                                  appointment['locationName']!,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              if (appointment['locationAddress'] !=
                                                  null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 16.0,
                                                      ), // Add spacing
                                                  child: Text(
                                                    appointment['locationAddress']!,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        // Location Button
                                        IconButton(
                                          alignment:
                                              Alignment
                                                  .topCenter, // Align icon at the top
                                          icon: const Icon(
                                            Icons.location_on,
                                            color: Colors.white,
                                          ),
                                          onPressed: () {
                                            // Open Google Maps or handle location
                                            print('Navigeren naar locatie');
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        },
                      ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'planning_fab', // Single heroTag for all pages
            backgroundColor: const Color(0xFF003049),
            onPressed: _toggleOverlay,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: NavBar(
            currentIndex: 0, // Set the current index for Planning
            uid: widget.uid, // Pass the user ID
            onFabPressed: _toggleOverlay, // Pass the FAB action
          ),
        ),
        if (_isOverlayVisible)
          CreatePlanOverlay(
            onClose: _toggleOverlay,
            uid: widget.uid,
            onSave:
                _fetchAppointments, // Pass the method to refresh appointments
          ),
      ],
    );
  }
}
