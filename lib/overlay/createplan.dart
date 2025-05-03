import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:newagendaapp/pages/planning.dart';
import 'package:newagendaapp/widigits/autocomplete.dart';
import 'package:newagendaapp/service/firebaseServices.dart'; // Import FirestoreAccess

class CreatePlanOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final String uid;
  final VoidCallback? onSave; // Optional callback for saving

  const CreatePlanOverlay({
    required this.onClose,
    required this.uid,
    this.onSave, // Optional parameter
  });

  @override
  _CreatePlanOverlayState createState() => _CreatePlanOverlayState();
}

class _CreatePlanOverlayState extends State<CreatePlanOverlay> {
  final FirestoreAccess firestoreAccess =
      FirestoreAccess(); // Initialize FirestoreAccess

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  double? destinationLatitude;
  double? destinationLongitude;
  String destinationName =
      'Destination'; // Add a variable to store the destination name

  DateTime startDateTime = DateTime.now();
  DateTime endDateTime = DateTime.now().add(Duration(hours: 1));
  String selectedTransport = 'car';
  Color selectedColor = Colors.blue;
  OverlayEntry? _overlayEntry;

  Future<void> _pickDateTime({required bool isStart}) async {
    DateTime initialDate = isStart ? startDateTime : endDateTime;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(), // Set firstDate to today
      lastDate: DateTime.now().add(
        Duration(days: 365 * 2),
      ), // Restrict to 2 years from now
    );
    if (pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (pickedTime == null) return;

    final selectedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isStart) {
        startDateTime = selectedDateTime;
        if (endDateTime.isBefore(startDateTime)) {
          endDateTime = startDateTime.add(Duration(hours: 1));
        }
      } else {
        endDateTime = selectedDateTime;
      }
    });
  }

  // Update destination coordinates
  void _updateDestination(double latitude, double longitude, String name) {
    setState(() {
      destinationLatitude = latitude;
      destinationLongitude = longitude;
      destinationName = name; // Update the destination name
    });
    print(
      'Selected coordinates: Latitude $latitude, Longitude $longitude, Name: $name',
    );
  }

  // Transport iconen selecteren
  Widget _transportIcon(String type, IconData icon) {
    final isSelected = selectedTransport == type;
    return IconButton(
      icon: Icon(icon, color: isSelected ? Colors.black : Colors.grey.shade400),
      onPressed: () {
        setState(() {
          selectedTransport = type;
        });
      },
    );
  }

  // Deelnemer kleurcirkel
  Widget _colorCircle(Color color) {
    final isSelected = selectedColor == color;
    final borderColor = isSelected ? darken(color, 0.2) : Colors.transparent;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedColor = color;
        });
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 3),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat("d MMM");
    final timeFormat = DateFormat("HH:mm");

    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 320,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: widget.onClose,
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (titleController.text.isEmpty ||
                                descriptionController.text.isEmpty ||
                                destinationLatitude == null ||
                                destinationLongitude == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please fill in all fields'),
                                ),
                              );
                              return;
                            }

                            try {
                              await firestoreAccess.CreateAppointment(
                                widget.uid,
                                titleController.text,
                                descriptionController.text,
                                startDateTime,
                                endDateTime,
                                destinationName,
                                destinationLatitude!,
                                destinationLongitude!,
                                selectedTransport,
                                '#${selectedColor.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                              );
                              print("Appointment saved successfully");
                              if (widget.onSave != null) {
                                widget
                                    .onSave!(); // Trigger the callback if provided
                              }
                              widget.onClose(); // Close the overlay
                            } catch (e) {
                              print("Failed to save appointment: $e");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to save appointment'),
                                ),
                              );
                            }
                          },
                          icon: Icon(Icons.save),
                          label: Text('Save'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF003049),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // Title input
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: 'Titel',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Description input
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        hintText: 'Beschrijving',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Date and time pickers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => _pickDateTime(isStart: true),
                          child: Column(
                            children: [
                              Text(dateFormat.format(startDateTime)),
                              Text(timeFormat.format(startDateTime)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward),
                        GestureDetector(
                          onTap: () => _pickDateTime(isStart: false),
                          child: Column(
                            children: [
                              Text(dateFormat.format(endDateTime)),
                              Text(timeFormat.format(endDateTime)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // Destination search
                    OsmAddressSearchWidget(
                      onCoordinatesSelected:
                          (lat, lon, name) => _updateDestination(
                            lat,
                            lon,
                            name!,
                          ), // Use the name
                    ),
                    SizedBox(height: 20),

                    // Transport icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _transportIcon('car', Icons.directions_car),
                        _transportIcon('bike', Icons.directions_bike),
                        _transportIcon('walk', Icons.directions_walk),
                        _transportIcon('bus', Icons.directions_bus),
                      ],
                    ),
                    SizedBox(height: 24),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Deelnemers'),
                    ),
                    SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        onPressed: () {},
                        child: Text('Add +'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          shape: StadiumBorder(),
                          padding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Color selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _colorCircle(Color(0xFF1668B8)), // blue
                        _colorCircle(Color(0xFF1F7E1F)), // green
                        _colorCircle(Color(0xFF9C6500)), // orange
                        _colorCircle(Color(0xFF91349B)), // paars
                        _colorCircle(Color(0xFFD90000)), // rood
                        _colorCircle(Color(0xFF626E7B)), // grijs
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color darken(Color color, [double amount = .1]) {
  assert(amount >= 0 && amount <= 1);
  final hsl = HSLColor.fromColor(color);
  final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return hslDark.toColor();
}
