import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:newagendaapp/pages/location.dart';
import 'package:newagendaapp/service/firebaseServices.dart';
import 'package:newagendaapp/widigits/appointment_info_overlay.dart';

class DayAppointmentsOverlay extends StatelessWidget {
  final DateTime selectedDay;
  final List<Map<String, dynamic>> appointments;
  final VoidCallback onClose;
  final VoidCallback onReload; // Add this callback
  final Future<void> Function() reloadCallback; // Add a reload callback
  final String uid;

  const DayAppointmentsOverlay({
    Key? key,
    required this.selectedDay,
    required this.appointments,
    required this.onClose,
    required this.onReload, // Initialize the callback
    required this.reloadCallback, // Initialize the reload callback
    required this.uid,
  }) : super(key: key);

  Future<void> _deleteAppointment(String appointmentId) async {
    try {
      FirestoreAccess firestoreAccess = FirestoreAccess();
      await firestoreAccess.deleteAppointment(uid, appointmentId);
      await reloadCallback(); // Reload the Month page
      onReload(); // Reload the DayAppointmentsOverlay
    } catch (e) {
      print('Error deleting appointment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onClose,
          child: Container(
            color: Colors.black.withOpacity(0.5), // Semi-transparent background
          ),
        ),
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Appointments for ${DateFormat('d MMMM yyyy').format(selectedDay)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Appointments List
                Expanded(
                  child:
                      appointments.isEmpty
                          ? const Center(child: Text('No appointments found'))
                          : ListView.builder(
                            itemCount: appointments.length,
                            itemBuilder: (context, index) {
                              final appointment = appointments[index];
                              final backgroundColor = Color(
                                int.parse(
                                  appointment['Color'].replaceFirst(
                                    '#',
                                    '0xFF',
                                  ),
                                ),
                              );

                              return GestureDetector(
                                onTap: () {
                                  // Open the AppointmentInfoOverlay
                                  showDialog(
                                    context: context,
                                    builder:
                                        (context) => AppointmentInfoOverlay(
                                          appointment: appointment,
                                          onClose: () {
                                            Navigator.of(context).pop();
                                          },
                                          onDelete: _deleteAppointment,
                                          onReload: () async {
                                            await reloadCallback(); // Reload Month and overlay
                                            onReload(); // Reload the DayAppointmentsOverlay
                                          },
                                          uid: uid,
                                        ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  padding: const EdgeInsets.all(12.0),
                                  decoration: BoxDecoration(
                                    color: backgroundColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Stack(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Day of the Month
                                          Text(
                                            DateFormat('d').format(
                                              (appointment['startTime']
                                                      as Timestamp)
                                                  .toDate(),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 16,
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
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                // Time
                                                Text(
                                                  '${DateFormat('HH:mm').format((appointment['startTime'] as Timestamp).toDate())} - ${DateFormat('HH:mm').format((appointment['endTime'] as Timestamp).toDate())}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                // Location
                                                if (appointment['locationName'] !=
                                                    null)
                                                  Text(
                                                    appointment['locationName'],
                                                    style: const TextStyle(
                                                      fontSize: 14,
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
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) => LocationPage(
                                                        uid: uid,
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
                                              size: 24, // Adjust size if needed
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
