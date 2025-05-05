import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:newagendaapp/pages/location.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import 'firebase_options.dart';
import 'pages/planning.dart';
import 'pages/auth/login.dart';
import 'service/firebaseServices.dart';
import 'config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set Mapbox access token
  MapboxOptions.setAccessToken(Config.mapboxAccessToken);

  runApp(const MyApp());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<Widget> _initialPage;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  Timer? _appointmentFetchTimer;
  List<Map<String, dynamic>> _previousAppointments = [];
  Set<String> _notifiedAppointments = {};
  Set<String> _notifiedOneDayAppointments = {};
  double _currentLatitude = 0.0;
  double _currentLongitude = 0.0;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _initialPage = _getInitialPage();
    _initializeNotifications();
    _requestNotificationPermissions();
    _startAppointmentFetchTimer();
    _setupFirebaseMessaging();
  }

  @override
  void dispose() {
    _appointmentFetchTimer?.cancel();
    super.dispose();
  }

  /// Starts a periodic timer to fetch upcoming appointments.
  void _setupFirebaseMessaging() async {
    NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
    }

    String? fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('public_users')
            .doc(user.uid)
            .set({'fcmToken': fcmToken}, SetOptions(merge: true));
        print('FCM Token saved: $fcmToken');
      }
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('public_users')
            .doc(user.uid)
            .set({'fcmToken': newToken}, SetOptions(merge: true));
        print('FCM Token updated: $newToken');
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
        'Received a message in the foreground: ${message.notification?.title}',
      );
      if (message.notification != null) {
        _showNotification(
          id: message.hashCode,
          title: message.notification!.title ?? 'No Title',
          body: message.notification!.body ?? 'No Body',
          channelId: 'test_channel',
          channelName: 'Test Notifications',
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print(
        'Notification clicked and app opened: ${message.notification?.title}',
      );
    });
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Kanaal voor testmeldingen',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } catch (e) {
      print("Error showing notification: $e");
    }
  }

  void _startAppointmentFetchTimer() {
    _appointmentFetchTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _fetchUpcomingAppointments();
      _fetchSharedAppointments(); // Check shared appointments
    });
  }

  /// Updates the current location of the user.
  Future<void> _updateCurrentLocation() async {
    try {
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
      setState(() {
        _currentLatitude = locationData.latitude ?? 0.0;
        _currentLongitude = locationData.longitude ?? 0.0;
      });
    } catch (e) {
      print("Error updating location: $e");
    }
  }

  /// Fetches upcoming appointments and handles notifications.
  Future<void> _fetchUpcomingAppointments() async {
    try {
      await _updateCurrentLocation();
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      FirestoreAccess firestoreAccess = FirestoreAccess();
      List<Map<String, dynamic>> appointments = await firestoreAccess
          .getAppointments(user.uid);

      DateTime now = DateTime.now();
      List<Map<String, dynamic>> upcomingAppointments =
          appointments.where((appointment) {
            DateTime startTime =
                (appointment['startTime'] as Timestamp).toDate();
            return startTime.isAfter(now);
          }).toList();

      _processAppointments(upcomingAppointments);
    } catch (e) {
      print("Error fetching appointments: $e");
    }
  }

  /// Calculates travel time using OpenRouteService API.
  Future<double> _calculateTravelTime(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
    String travelMode,
  ) async {
    final String url =
        'https://api.openrouteservice.org/v2/directions/$travelMode/geojson';

    final body = jsonEncode({
      "coordinates": [
        [startLon, startLat],
        [endLon, endLat],
      ],
    });

    try {
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
        return data['features'][0]['properties']['segments'][0]['duration'] /
            60;
      } else {
        print("Error fetching route: ${response.statusCode}");
        return 0.0; // Fallback travel time
      }
    } catch (e) {
      print("Error calculating travel time: $e");
      return 0.0; // Fallback travel time
    }
  }

  /// Sends a 1-day reminder notification for an appointment.
  Future<void> _sendOneDayReminderNotification(
    Map<String, dynamic> appointment,
    DateTime startTime,
  ) async {
    String title = appointment['title'];
    String locationName = appointment['locationName'];
    String appointmentId =
        appointment['id']; // Ensure each appointment has a unique ID.
    String userId =
        FirebaseAuth.instance.currentUser!.uid; // Get the current user's UID.

    // Check if the notification has already been sent
    DocumentSnapshot doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('appointments')
            .doc(appointmentId)
            .get();

    if (!doc.exists ||
        (doc.data() as Map<String, dynamic>)['notificationSentOneDay'] !=
            true) {
      if (startTime.difference(DateTime.now()).inHours < 24) {
        await _showNotification(
          id: appointment.hashCode,
          title:
              "Herinnering: $title morgen om ${DateFormat('HH:mm').format(startTime)}",
          body:
              'Je afspraak bij $locationName is morgen. Vergeet niet te plannen!',
          channelId: 'reminder_channel',
          channelName: 'Reminder Notifications',
        );

        // Update the database to mark the notification as sent
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('appointments')
            .doc(appointmentId)
            .set({'notificationSentOneDay': true}, SetOptions(merge: true));
      }
    }
  }

  /// Sends a travel notification for an appointment.
  Future<void> _sendTravelNotification(
    Map<String, dynamic> appointment,
    DateTime leaveTime,
    DateTime startTime,
  ) async {
    String title = appointment['title'];
    String locationName = appointment['locationName'];
    String appointmentId =
        appointment['id']; // Ensure each appointment has a unique ID.
    String userId =
        FirebaseAuth.instance.currentUser!.uid; // Get the current user's UID.

    // Check if the notification has already been sent
    DocumentSnapshot doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('appointments')
            .doc(appointmentId)
            .get();

    if (!doc.exists ||
        (doc.data() as Map<String, dynamic>)['notificationSentTravel'] !=
            true) {
      if (leaveTime.difference(DateTime.now()).inMinutes.abs() <= 1) {
        await _showNotification(
          id: appointment.hashCode + 1,
          title: "Afspraak $title om ${DateFormat('HH:mm').format(startTime)}",
          body:
              'Je moet nu vertrekken om $locationName te bereiken voor je afspraak.',
          channelId: 'test_channel',
          channelName: 'Test Notifications',
          payload: jsonEncode({
            'TravelMode': appointment['TravelMode'],
            'latitude': appointment['latitude'],
            'longitude': appointment['longitude'],
            'locationName': locationName,
          }),
        );

        // Update the database to mark the notification as sent
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('appointments')
            .doc(appointmentId)
            .set({'notificationSentTravel': true}, SetOptions(merge: true));
      }
    }
  }

  /// Processes appointments and sends notifications.
  void _processAppointments(List<Map<String, dynamic>> appointments) async {
    for (var appointment in appointments) {
      double travelTime = await _calculateTravelTime(
        _currentLatitude,
        _currentLongitude,
        appointment['latitude'],
        appointment['longitude'],
        appointment['TravelMode'],
      );

      travelTime += 30; // Add buffer time
      DateTime startTime = (appointment['startTime'] as Timestamp).toDate();
      DateTime leaveTime = startTime.subtract(
        Duration(minutes: travelTime.toInt()),
      );
      appointment['leaveTime'] = leaveTime;

      // Send separate notifications
      await _sendOneDayReminderNotification(appointment, startTime);
      await _sendTravelNotification(appointment, leaveTime, startTime);
    }
    _previousAppointments = appointments;
  }

  /// Requests notification permissions with fallback.
  Future<void> _requestNotificationPermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidImplementation =
            _notificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
      } else if (Platform.isIOS) {
        final iosImplementation =
            _notificationsPlugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >();
        await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      print("Error requesting notification permissions: $e");
    }
  }

  /// Initializes the notification system.
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(),
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          final appointment = jsonDecode(details.payload!);
          Navigator.push(
            _navigatorKey.currentContext!,
            MaterialPageRoute(
              builder:
                  (context) => LocationPage(
                    uid: FirebaseAuth.instance.currentUser?.uid ?? '',
                    initialLocationName: appointment['locationName'],
                    initialLatitude: appointment['latitude'],
                    initialLongitude: appointment['longitude'],
                    initialTransportMode: appointment['TravelMode'],
                  ),
            ),
          );
        }
      },
    );
  }

  /// Determines the initial page based on user authentication.
  Future<Widget> _getInitialPage() async {
    User? user = FirebaseAuth.instance.currentUser;
    return user != null ? Planning(uid: user.uid) : LoginPage();
  }

  /// Fetches shared appointments and handles notifications.
  Future<void> _fetchSharedAppointments() async {
    try {
      print("Fetching shared appointments...");
      String userId = FirebaseAuth.instance.currentUser!.uid;

      // Fetch shared appointments
      QuerySnapshot sharedAppointmentsSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('shared')
              .get();

      for (var creatorDoc in sharedAppointmentsSnapshot.docs) {
        QuerySnapshot appointmentsSnapshot =
            await creatorDoc.reference
                .collection('appointments')
                .get(); // Fetch all appointments

        print(
          'Fetched shared appointments: ${appointmentsSnapshot.docs.length}',
        );

        for (var appointmentDoc in appointmentsSnapshot.docs) {
          Map<String, dynamic> appointmentData =
              appointmentDoc.data() as Map<String, dynamic>;

          // Check if 'vertrokken' exists and is true
          if (appointmentData['vertrokken'] == true) {
            // Check if notificationFriend is already sent
            if (appointmentData['notificationFriend'] != true) {
              // Send notification
              await _showNotification(
                id: appointmentDoc.hashCode,
                title: "Je vriend is vertrokken!",
                body:
                    "Je vriend is vertrokken naar ${appointmentData['locationName']}.",
                channelId: 'friend_channel',
                channelName: 'Friend Notifications',
              );

              // Update Firestore to mark notification as sent
              await appointmentDoc.reference.set({
                'notificationFriend': true,
              }, SetOptions(merge: true));
            }
          }
        }
      }
    } catch (e) {
      print("Error fetching shared appointments: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF003049)),
      ),
      home: FutureBuilder<Widget>(
        future: _initialPage,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            Widget homePage = snapshot.data!;
            return homePage;
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
    );
  }
}
