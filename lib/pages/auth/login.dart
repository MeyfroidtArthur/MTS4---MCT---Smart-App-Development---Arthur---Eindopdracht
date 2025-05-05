import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:newagendaapp/pages/auth/Register.dart';
import 'package:newagendaapp/pages/auth/vergeten.dart';
import 'package:newagendaapp/service/firebaseServices.dart';
import 'package:newagendaapp/pages/planning.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Add this import

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirestoreAccess _firebaseService = FirestoreAccess();

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vul alle velden in')));
      return;
    }

    final userId = await _firebaseService.signInUser(email, password);
    if (userId != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Succesvol ingelogd!')));

      // Generate and save the FCM token
      try {
        String? fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          // Fetch the user's name from the nested path
          DocumentSnapshot userInfoDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('userinfo')
                  .doc('details') // Assuming 'details' is the document name
                  .get();

          String name =
              userInfoDoc.exists
                  ? userInfoDoc['name'] ?? 'Unknown User'
                  : 'Unknown User';

          // Check if the public_users document already exists
          DocumentSnapshot publicUserDoc =
              await FirebaseFirestore.instance
                  .collection('public_users')
                  .doc(userId)
                  .get();

          if (!publicUserDoc.exists) {
            // Create the public_users document if it doesn't exist
            await FirebaseFirestore.instance
                .collection('public_users')
                .doc(userId)
                .set({'name': name, 'fcmToken': fcmToken, 'userId': userId});
            print("Public user data created: $name, $fcmToken, $userId");
          } else {
            // Update the FCM token if the document already exists
            await FirebaseFirestore.instance
                .collection('public_users')
                .doc(userId)
                .update({'fcmToken': fcmToken});
            print("Public user data updated with new FCM token: $fcmToken");
          }
        }
      } catch (e) {
        print("Error saving public user data: $e");
      }

      // Navigate to Planning page with the userId
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Planning(uid: userId)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inloggen mislukt. Controleer je gegevens.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const mainColor = Color(0xFF003049);

    return Scaffold(
      backgroundColor: mainColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Log in op je account',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'E-mail',
                  hintStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Colors.white,
                  ),
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Wachtwoord',
                  hintStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Colors.white,
                  ),
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleLogin, // Call the login handler
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: mainColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Inloggen", style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Heb je nog geen account?",
                    style: TextStyle(color: Colors.white70),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterPage(),
                        ),
                      );
                    },
                    child: const Text(
                      "Registreren",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WachtwoordVergetenPage(),
                    ),
                  );
                },
                child: const Text(
                  "Wachtwoord vergeten?",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
