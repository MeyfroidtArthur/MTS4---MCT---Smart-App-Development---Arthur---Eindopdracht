import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OsmAddressSearchWidget extends StatefulWidget {
  final String? initialValue; // Add an initial value
  final Function(double lat, double lon, String? displayName)
  onCoordinatesSelected;

  OsmAddressSearchWidget({
    this.initialValue, // Optional initial value
    required this.onCoordinatesSelected,
  });

  @override
  _OsmAddressSearchWidgetState createState() => _OsmAddressSearchWidgetState();
}

class _OsmAddressSearchWidgetState extends State<OsmAddressSearchWidget> {
  late TextEditingController _controller;
  List<Map<String, dynamic>> _suggestions = [];
  OverlayEntry? _overlayEntry; // Make this nullable

  @override
  void initState() {
    super.initState();
    // Set the controller with the initial value
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    _removeOverlay(); // Ensure the overlay is removed during dispose
    super.dispose();
  }

  // Fetch address suggestions from the Nominatim API
  Future<void> _searchAddress(String query) async {
    final url =
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Agenda App School (arthur.meyfroidt@student.howest.be)', // required by Nominatim
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _suggestions = List<Map<String, dynamic>>.from(data);
      });
    } else {
      print("Failed to load suggestions");
    }
  }

  // Select a suggestion and pass the coordinates back
  void _selectSuggestion(Map<String, dynamic> suggestion) {
    final displayName =
        suggestion['display_name'] ??
        'Unknown Location'; // Fallback if displayName is null
    final lat = double.parse(suggestion['lat']);
    final lon = double.parse(suggestion['lon']);

    widget.onCoordinatesSelected(
      lat,
      lon,
      displayName,
    ); // Pass the name (nullable)

    setState(() {
      _controller.text = displayName;
      _suggestions = [];
    });

    // Remove overlay safely if it's initialized
    _removeOverlay();
  }

  // Show the overlay suggestions above everything else
  void _showSuggestions(BuildContext context) {
    if (_suggestions.isNotEmpty && _overlayEntry == null) {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final offset = renderBox.localToGlobal(
        Offset.zero,
      ); // Position of TextField
      final height = renderBox.size.height; // Height of the TextField

      // Initialize OverlayEntry only when needed
      _overlayEntry = OverlayEntry(
        builder:
            (context) => Positioned(
              top: offset.dy + height, // Directly below the TextField
              left: offset.dx,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  color: Colors.white,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return ListTile(
                        title: Text(suggestion['display_name']),
                        onTap: () => _selectSuggestion(suggestion),
                      );
                    },
                  ),
                ),
              ),
            ),
      );

      // Insert the overlay above everything else
      Overlay.of(context)?.insert(_overlayEntry!);
    }
  }

  // Safely remove the overlay
  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null; // Reset after removal
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: (value) {
        if (value.length > 2) {
          _searchAddress(value);
          _showSuggestions(context); // Show suggestions when the user types
        } else {
          setState(() {
            _suggestions = [];
          });
          _removeOverlay(); // Safely remove the overlay when there's no input
        }
      },
      decoration: InputDecoration(
        hintText: 'Enter address',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
