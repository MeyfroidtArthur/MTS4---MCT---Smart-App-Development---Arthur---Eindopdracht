import 'package:newagendaapp/pages/location.dart';
import 'package:newagendaapp/service/firebaseServices.dart'; // Import FirestoreAccess
import 'package:flutter/material.dart';
import 'package:newagendaapp/overlay/createplan.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:newagendaapp/widigits/nav.dart'; // Import NavBar
import 'package:newagendaapp/widigits/appointment_info_overlay.dart';
import 'package:newagendaapp/service/dotnet_communication.dart'; // Import sendOnMyWayNotification
import 'package:cloud_firestore/cloud_firestore.dart'; // Import FirebaseFirestore

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
  Map<String, dynamic>?
  _editingAppointment; // Store the appointment being edited

  @override
  void initState() {
    super.initState();
    _fetchAppointments(); // Fetch appointments when the page loads
  }

  void _toggleOverlay({Map<String, dynamic>? appointment}) {
    setState(() {
      print("Toggling overlay visibility: $_isOverlayVisible");
      _isOverlayVisible = !_isOverlayVisible;
      _editingAppointment = appointment; // Set the appointment being edited
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
                top: 24.0,
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
                                      fontSize:
                                          24, // Match the Month page text size
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
                                final backgroundColor =
                                    appointment['Color'] != null
                                        ? Color(
                                          int.parse(
                                            appointment['Color']!.replaceFirst(
                                              '#',
                                              '0xFF',
                                            ),
                                          ), // Convert hex string to Color
                                        )
                                        : Colors
                                            .grey; // Default color if 'Color' is null

                                return GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      barrierColor: Colors.black.withOpacity(
                                        0.5,
                                      ),
                                      builder: (BuildContext context) {
                                        return AppointmentInfoOverlay(
                                          appointment: appointment,
                                          onClose:
                                              () => Navigator.of(context).pop(),
                                          onDelete: _deleteAppointment,
                                          onReload:
                                              _fetchAppointments, // Pass the reload callback
                                          uid: widget.uid,
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
                                      vertical: 8.0,
                                    ), // Match dayappointment padding
                                    padding: const EdgeInsets.all(
                                      12.0,
                                    ), // Match dayappointment padding
                                    child: Stack(
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Day of the Month
                                            Text(
                                              DateFormat('d').format(
                                                appointment['startTime']
                                                    .toDate(),
                                              ),
                                              style: const TextStyle(
                                                fontSize:
                                                    16, // Match dayappointment font size
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            // Appointment Details
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Title
                                                  Text(
                                                    appointment['title'] ??
                                                        'No Title',
                                                    style: const TextStyle(
                                                      fontSize:
                                                          16, // Match dayappointment font size
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  // Time
                                                  Text(
                                                    '${DateFormat.Hm().format(appointment['startTime'].toDate())} - ${DateFormat.Hm().format(appointment['endTime'].toDate())}',
                                                    style: const TextStyle(
                                                      fontSize:
                                                          14, // Match dayappointment font size
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  // Location
                                                  if (appointment['locationName'] !=
                                                      null)
                                                    Text(
                                                      appointment['locationName']!,
                                                      style: const TextStyle(
                                                        fontSize:
                                                            14, // Match dayappointment font size
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Location Icon
                                        if (appointment['locationName'] != null)
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: GestureDetector(
                                              onTap: () async {
                                                final List<dynamic>?
                                                participants =
                                                    appointment['participants'];
                                                if (participants != null &&
                                                    participants.isNotEmpty) {
                                                  final String participantUid =
                                                      participants[0]['id']; // Get the participant's UID
                                                  final String creatorUid =
                                                      appointment['creatorUid']; // Get the creator's UID
                                                  final String appointmentId =
                                                      appointment['uid']; // Get the appointment ID
                                                  print(participantUid);
                                                  try {
                                                    // Add the vertrokken field to the shared appointment
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection('users')
                                                        .doc(
                                                          participantUid,
                                                        ) // The participant's UID
                                                        .collection('shared')
                                                        .doc(
                                                          creatorUid,
                                                        ) // The creator's UID
                                                        .collection(
                                                          'appointments',
                                                        )
                                                        .doc(
                                                          appointmentId,
                                                        ) // The appointment ID
                                                        .set(
                                                          {'vertrokken': true},
                                                          SetOptions(
                                                            merge: true,
                                                          ),
                                                        );

                                                    print(
                                                      'Shared appointment updated with vertrokken: true',
                                                    );
                                                  } catch (e) {
                                                    print(
                                                      'Failed to add vertrokken to shared appointment: $e',
                                                    );
                                                  }
                                                } else {
                                                  print(
                                                    'No participants found or participants list is empty.',
                                                  );
                                                }

                                                // Navigate to the LocationPage
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (
                                                          context,
                                                        ) => LocationPage(
                                                          uid: widget.uid,
                                                          initialLocationName:
                                                              appointment['locationName'],
                                                          initialLatitude:
                                                              appointment['latitude'],
                                                          initialLongitude:
                                                              appointment['longitude'],
                                                          initialTransportMode:
                                                              appointment['TravelMode'],
                                                        ),
                                                  ),
                                                );
                                              },
                                              child: const Icon(
                                                Icons.location_on,
                                                color: Colors.white,
                                                size:
                                                    24, // Match dayappointment icon size
                                              ),
                                            ),
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
            onPressed: () => _toggleOverlay(),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: NavBar(
            currentIndex: 0, // Set the current index for Planning
            uid: widget.uid, // Pass the user ID
            onFabPressed: () => _toggleOverlay(), // Pass the FAB action
          ),
        ),
        if (_isOverlayVisible)
          CreatePlanOverlay(
            onClose:
                _toggleOverlay, // Close the overlay when the user taps outside or presses close
            uid: widget.uid,
            onSave: () {
              _fetchAppointments(); // Refresh appointments after saving or updating
            },
            initialData:
                _editingAppointment, // Pass the data of the appointment being edited
          ),
      ],
    );
  }
}
