import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'firebase_options.dart';
import 'pages/auth/login.dart';
import 'pages/planning.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  String accessToken =
      "pk.eyJ1IjoiYXJ0aHVybWV5ZnJvaWR0IiwiYSI6ImNtYTNseDMyajE2MzYyaXNmN2pxZmRqZ2EifQ.vV10oj7eLmsUgyAU9zb0sQ";
  MapboxOptions.setAccessToken(accessToken);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 0, 48, 73),
        ),
      ),
      home: const AuthWrapper(), // Use AuthWrapper to decide the initial page
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> _checkUserExists(String userId) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
      return doc.exists; // Returns true if the document exists, false otherwise
    } catch (e) {
      print("Error checking user existence: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is already logged in, check if they exist in the database
      return FutureBuilder<bool>(
        future: _checkUserExists(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData && snapshot.data == true) {
            // User exists in the database, navigate to the Planning page
            return Planning(uid: user.uid);
          } else {
            // User does not exist in the database, sign them out
            FirebaseAuth.instance.signOut();
            return const LoginPage();
          }
        },
      );
    } else {
      // No user is logged in, navigate to the Login page
      return const LoginPage();
    }
  }
}
