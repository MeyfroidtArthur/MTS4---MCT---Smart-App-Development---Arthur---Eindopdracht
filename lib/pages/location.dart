import 'package:flutter/material.dart';
import 'package:newagendaapp/config.dart';
import 'package:newagendaapp/overlay/createplan.dart';
import 'package:newagendaapp/pages/planning.dart';
import 'package:newagendaapp/widigits/RemainingInfoWidget.dart';
import 'package:newagendaapp/widigits/nav.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as latlong;
import './../widigits/autocomplete.dart';
import 'dart:async';

class LocationPage extends StatefulWidget {
  final String uid;
  final String? initialLocationName; // Add initial location name
  final double? initialLatitude; // Add initial latitude
  final double? initialLongitude; // Add initial longitude
  final String? initialTransportMode;

  const LocationPage({
    Key? key,
    required this.uid,
    this.initialLocationName,
    this.initialLatitude,
    this.initialLongitude,
    this.initialTransportMode,
  }) : super(key: key);

  @override
  _LocationState createState() => _LocationState();
}

class _LocationState extends State<LocationPage> {
  bool _isOverlayVisible = false;
  String _selectedTransport = 'car';
  TextEditingController _destinationController = TextEditingController();
  double? _currentLat;
  double? _currentLon;
  MapboxMap? mapboxMap;
  double _destinationLat = 0.0;
  double _destinationLon = 0.0;
  List<latlong.LatLng> _routeCoordinates = [];
  double _remainingDistance = 0.0;
  double _remainingTime = 0.0;
  double _lastLat = 0.0;
  double _lastLon = 0.0;
  Timer? _cameraUpdateTimer;
  StreamSubscription<LocationData>? _locationSubscription;

  void _toggleOverlay() {
    setState(() {
      _isOverlayVisible = !_isOverlayVisible;
    });
  }

  @override
  void initState() {
    super.initState();
    // Set initial location if provided
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _destinationLat = widget.initialLatitude!;
      _destinationLon = widget.initialLongitude!;
    }

    // Set initial transport mode if provided
    if (widget.initialTransportMode != null) {
      _selectedTransport = widget.initialTransportMode!;
    }

    print(
      "Coordinates: ${widget.initialLatitude}, ${widget.initialLongitude}, transport: $_selectedTransport",
    );

    _destinationController.text = widget.initialLocationName ?? '';
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _cameraUpdateTimer?.cancel();
    _locationSubscription?.cancel();
    try {
      mapboxMap?.dispose();
    } catch (_) {}
    mapboxMap = null;
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _addStartMarker() async {
    try {
      if (mapboxMap != null) {
        final style = await mapboxMap!.style;

        if (await style.styleSourceExists('start-point')) {
          await style.removeStyleSource('start-point');
        }

        await style.addSource(
          GeoJsonSource(
            id: 'start-point',
            data: jsonEncode({
              "type": "FeatureCollection",
              "features": [
                {
                  "type": "Feature",
                  "geometry": {
                    "type": "Point",
                    "coordinates": [_currentLon, _currentLat],
                  },
                  "properties": {"title": "Start"},
                },
              ],
            }),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding start marker: $e');
    }
  }

  Future<void> _updateRoute() async {
    List<latlong.LatLng> route = await _getRoute();
    if (mounted) {
      setState(() {
        _routeCoordinates = route;
      });
    }

    if (mapboxMap != null && _routeCoordinates.isNotEmpty) {
      final sourceId = "route";
      final layerId = "route-layer";

      try {
        await mapboxMap!.style.removeStyleLayer(layerId);
        await mapboxMap!.style.removeStyleSource(sourceId);
      } catch (_) {}

      await mapboxMap!.style.addSource(
        GeoJsonSource(
          id: sourceId,
          data: jsonEncode({
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates":
                  _routeCoordinates
                      .map((c) => [c.longitude, c.latitude])
                      .toList(),
            },
          }),
        ),
      );

      await mapboxMap!.style.addLayer(
        LineLayer(
          id: layerId,
          sourceId: sourceId,
          lineColor: Color(0xFF808080).value,
          lineWidth: 5.0,
        ),
      );

      _addEndMarker();
    }
  }

  Future<void> _addEndMarker() async {
    try {
      if (mapboxMap != null) {
        final style = await mapboxMap!.style;

        if (await style.styleSourceExists('end-point')) {
          await style.removeStyleSource('end-point');
        }

        await style.addSource(
          GeoJsonSource(
            id: 'end-point',
            data: jsonEncode({
              "type": "FeatureCollection",
              "features": [
                {
                  "type": "Feature",
                  "geometry": {
                    "type": "Point",
                    "coordinates": [_destinationLon, _destinationLat],
                  },
                  "properties": {"title": "End"},
                },
              ],
            }),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding end marker: $e');
    }
  }

  Future<List<latlong.LatLng>> _getRoute() async {
    if (_currentLat == null || _currentLon == null) return [];
    if (_destinationLat == 0.0 || _destinationLon == 0.0) return [];

    final String url =
        'https://api.openrouteservice.org/v2/directions/$_selectedTransport/geojson';

    final body = jsonEncode({
      "coordinates": [
        [_currentLon, _currentLat],
        [_destinationLon, _destinationLat],
      ],
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': Config.openRouteServiceApiKey,
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final segment = data['features'][0]['properties']['segments'][0];
      final duration = segment['duration'] / 60;
      final distance = segment['distance'] / 1000;

      if (mounted) {
        setState(() {
          _remainingTime = duration;
          _remainingDistance = distance;
        });
      }

      final List<dynamic> coordinates =
          data['features'][0]['geometry']['coordinates'];
      return coordinates
          .map((coord) => latlong.LatLng(coord[1], coord[0]))
          .toList();
    } else {
      print("❌ Fout bij ophalen route: ${response.statusCode}");
      print(response.body);
      return [];
    }
  }

  Future<void> _getCurrentLocation() async {
    Location location = Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    LocationData locationData = await location.getLocation();
    if (mounted) {
      setState(() {
        _currentLat = locationData.latitude;
        _currentLon = locationData.longitude;
      });
    }

    if (mapboxMap != null && _currentLat != null && _currentLon != null) {
      _updateCamera(_currentLat!, _currentLon!);
      _addStartMarker();
    }

    _locationSubscription?.cancel(); // Cancel previous subscription
    _locationSubscription = location.onLocationChanged.listen((locationData) {
      if ((locationData.latitude! - _lastLat).abs() > 0.0001 ||
          (locationData.longitude! - _lastLon).abs() > 0.0001) {
        _lastLat = locationData.latitude!;
        _lastLon = locationData.longitude!;
        if (mounted) {
          _addStartMarker();
          _updateRoute();
        }
      }
    });
  }

  void _updateCamera(double lat, double lon) {
    _cameraUpdateTimer?.cancel();
    _cameraUpdateTimer = Timer(Duration(milliseconds: 500), () {
      if (mapboxMap != null) {
        mapboxMap?.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(lon, lat)),
            zoom: 13.0,
          ),
          MapAnimationOptions(duration: 2000, startDelay: 0),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: 48.0,
                  left: 16.0,
                  right: 16.0,
                  bottom: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Color.fromARGB(255, 33, 33, 33),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OsmAddressSearchWidget(
                        initialValue:
                            widget.initialLocationName, // Set the initial value
                        onCoordinatesSelected:
                            (lat, lon, _) => _updateDestination(lat, lon),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTransportIcon(Icons.directions_car, 'driving-car'),
                    _buildTransportIcon(
                      Icons.directions_bike,
                      'cycling-regular',
                    ),
                    _buildTransportIcon(Icons.directions_walk, 'foot-walking'),
                    _buildTransportIcon(Icons.train, 'driving-train'),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    MapWidget(
                      mapOptions: MapOptions(
                        pixelRatio: MediaQuery.of(context).devicePixelRatio,
                      ),
                      onMapCreated: (MapboxMap map) {
                        mapboxMap = map;
                      },
                      cameraOptions: CameraOptions(
                        center: Point(
                          coordinates: Position(
                            _currentLon ?? 4.899431,
                            _currentLat ?? 52.379189,
                          ),
                        ),
                        zoom: 13.0,
                      ),
                    ),
                    Positioned(
                      bottom: 45,
                      left: 16,
                      right: 16,
                      child: RemainingInfoWidget(
                        remainingTime: _remainingTime,
                        remainingDistance: _remainingDistance,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 16,
                      child: FloatingActionButton(
                        heroTag: 'current_location_fab',
                        mini: true,
                        backgroundColor: Color.fromARGB(255, 2, 77, 117),
                        onPressed: _getCurrentLocation,
                        child: Icon(Icons.my_location, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'location_fab',
            backgroundColor: Color(0xFF003049),
            onPressed: _toggleOverlay,
            child: Icon(Icons.add, color: Colors.white),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: NavBar(
            currentIndex: 2,
            uid: widget.uid,
            onFabPressed: _toggleOverlay,
          ),
        ),
        if (_isOverlayVisible)
          CreatePlanOverlay(
            onClose: _toggleOverlay,
            uid: widget.uid,
            onSave: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => Planning(uid: widget.uid),
                ),
              ); //
            },
          ),
      ],
    );
  }

  Widget _buildTransportIcon(IconData icon, String transport) {
    return IconButton(
      icon: Icon(
        icon,
        color:
            _selectedTransport == transport
                ? Color.fromARGB(255, 33, 33, 33)
                : Color.fromARGB(255, 150, 150, 150),
      ),
      onPressed: () {
        setState(() {
          _selectedTransport = transport;
        });
        _updateRoute();
      },
    );
  }

  void _updateDestination(double latitude, double longitude, [String? name]) {
    setState(() {
      _destinationLat = latitude;
      _destinationLon = longitude;
    });
    _updateRoute();
  }
}
