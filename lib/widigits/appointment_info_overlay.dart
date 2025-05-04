import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:newagendaapp/overlay/createplan.dart';
import 'package:newagendaapp/pages/planning.dart';

class AppointmentInfoOverlay extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onClose;
  final Future<void> Function(String appointmentId) onDelete;
  final VoidCallback onReload; // Add this callback
  final String uid;

  const AppointmentInfoOverlay({
    Key? key,
    required this.appointment,
    required this.onClose,
    required this.onDelete,
    required this.onReload, // Initialize the callback
    required this.uid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat("d MMM");
    final timeFormat = DateFormat("HH:mm");

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 340,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with space for the close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              appointment['title'] ?? 'Afspraakdetails',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              softWrap: true,
                            ),
                          ),
                          const SizedBox(width: 48), // Space for close button
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Date and Time in a Row
                      if (appointment['startTime'] != null &&
                          appointment['endTime'] != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  dateFormat.format(
                                    appointment['startTime'].toDate(),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${timeFormat.format(appointment['startTime'].toDate())} - ${timeFormat.format(appointment['endTime'].toDate())}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      if (appointment['startTime'] != null &&
                          appointment['endTime'] != null)
                        const SizedBox(height: 8),

                      // Location Information
                      if (appointment['locationName'] != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.place,
                              color: Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                appointment['locationName']!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      if (appointment['locationName'] != null)
                        const SizedBox(height: 8),

                      if (appointment['locationAddress'] != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                appointment['locationAddress']!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      if (appointment['locationAddress'] != null)
                        const SizedBox(height: 8),

                      if (appointment['description'] != null)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.notes,
                              color: Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                appointment['description']!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                      if (appointment['description'] != null)
                        const SizedBox(height: 24),

                      // Footer with Delete and Edit Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF700A0C),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.delete, color: Colors.white),
                            label: const Text(
                              'Verwijder',
                              style: TextStyle(color: Colors.white),
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Bevestiging'),
                                    content: const Text(
                                      'Weet je zeker dat je deze afspraak wilt verwijderen?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(
                                            context,
                                          ).pop(false); // Cancel
                                        },
                                        child: const Text('Annuleren'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(
                                            context,
                                          ).pop(true); // Confirm
                                        },
                                        child: const Text('Verwijderen'),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (confirm == true) {
                                await onDelete(appointment['id']);
                                onClose();
                              }
                            },
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return CreatePlanOverlay(
                                    onClose: () {
                                      Navigator.of(context).pop();
                                    },
                                    uid: uid ?? '', // Zorg dat uid niet null is
                                    onSave: () {
                                      Navigator.of(context).pop();
                                      onReload(); // Trigger the reload callback
                                    },
                                    initialData: {
                                      'id':
                                          appointment['id'] ??
                                          '', // Gebruik een lege string als fallback
                                      'title':
                                          appointment['title'] ?? 'Geen titel',
                                      'description':
                                          appointment['description'] ??
                                          'Geen beschrijving',
                                      'startDateTime':
                                          appointment['startTime']?.toDate() ??
                                          DateTime.now(),
                                      'endDateTime':
                                          appointment['endTime']?.toDate() ??
                                          DateTime.now().add(
                                            Duration(hours: 1),
                                          ),
                                      'destinationName':
                                          appointment['locationName'] ??
                                          'Geen locatie',
                                      'destinationLatitude':
                                          appointment['latitude'] ?? 0.0,
                                      'destinationLongitude':
                                          appointment['longitude'] ?? 0.0,
                                      'selectedTransport':
                                          appointment['TravelMode'] ?? 'car',
                                      'selectedColor':
                                          appointment['Color'] ??
                                          '#FF0000', // Standaardkleur rood
                                    },
                                  );
                                },
                              );
                            },
                            icon: const Icon(Icons.edit, color: Colors.white),
                            label: const Text(
                              'Aanpassen',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF003049),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
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
                  onTap: onClose,
                  child: Icon(Icons.close, color: Colors.grey[800], size: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
