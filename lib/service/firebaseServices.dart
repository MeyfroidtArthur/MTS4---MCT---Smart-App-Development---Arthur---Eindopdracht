import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreAccess {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<User?> createUser(String email, String password, String name) async {
    try {
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await addUserData(userCredential.user!.uid, {
        'name': name,
        'email': email,
        'createdAt': Timestamp.now(),
      });

      return userCredential.user;
    } catch (e) {
      print("Error creating user: $e");
      return null;
    }
  }

  Future<String?> signInUser(String email, String password) async {
    try {
      UserCredential userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user!.uid;
    } catch (e) {
      print("Error signing in user: $e");
      return null;
    }
  }

  Future<void> signOutUser() async {
    try {
      await auth.signOut();
    } catch (e) {
      print("Error signing out user: $e");
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print("Error sending password reset email: $e");
    }
  }

  Future<void> addUserData(String userId, Map<String, dynamic> data) async {
    try {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('userinfo')
          .doc('details') // Optional: Use a fixed document ID like 'details'
          .set(data);
    } catch (e) {
      print("Error adding user data: $e");
    }
  }

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc =
          await firestore
              .collection('users')
              .doc(userId)
              .collection('userinfo')
              .doc('details') // Use the same document ID as in addUserData
              .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      } else {
        print("User info not found");
        return null;
      }
    } catch (e) {
      print("Error getting user info: $e");
      return null;
    }
  }

  Future<void> CreateAppointment(
    String creatorUid,
    String title,
    String description,
    DateTime startDateTime,
    DateTime endDateTime,
    String destinationName,
    double destinationLatitude,
    double destinationLongitude,
    String transportMode,
    String color,
    List<Map<String, dynamic>> participants,
  ) async {
    final appointmentRef =
        FirebaseFirestore.instance
            .collection('users')
            .doc(creatorUid)
            .collection('appointments')
            .doc();

    final appointmentData = {
      'uid': appointmentRef.id,
      'title': title,
      'description': description,
      'startTime': startDateTime,
      'endTime': endDateTime,
      'locationName': destinationName,
      'latitude': destinationLatitude,
      'longitude': destinationLongitude,
      'TravelMode': transportMode,
      'Color': color,
      'creatorUid': creatorUid,
      'participants': participants,
    };

    // Save the appointment in the creator's collection
    await appointmentRef.set(appointmentData);

    // Add the appointment to each participant's shared collection
    for (final participant in participants) {
      final participantUid = participant['id'];
      print('Participant UID: $participantUid');
      final sharedRef = FirebaseFirestore.instance
          .collection('users')
          .doc(participantUid) // The participant's UID
          .collection('shared')
          .doc(creatorUid) // The creator's UID
          .collection('appointments') // Nested collection for appointments
          .doc(appointmentRef.id); // The appointment ID

      await sharedRef.set({
        ...appointmentData,
        'sharedBy': creatorUid, // Indicate who shared the appointment
      });
    }
  }

  Future<List<Map<String, dynamic>>> getAppointments(String userId) async {
    try {
      QuerySnapshot querySnapshot =
          await firestore
              .collection('users')
              .doc(userId)
              .collection('appointments')
              .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Add the document ID as 'id'
        return data;
      }).toList();
    } catch (e) {
      print("Error fetching appointments: $e");
      return [];
    }
  }

  Future<void> deleteAppointment(String userId, String appointmentId) async {
    try {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('appointments')
          .doc(appointmentId)
          .delete();
      print("Appointment deleted successfully");
    } catch (e) {
      print("Error deleting appointment: $e");
    }
  }

  Future<void> UpdateAppointment(
    String creatorUid,
    String appointmentId,
    String title,
    String description,
    DateTime startDateTime,
    DateTime endDateTime,
    String destinationName,
    double destinationLatitude,
    double destinationLongitude,
    String transportMode,
    String color,
    List<Map<String, dynamic>> participants,
  ) async {
    final appointmentRef = FirebaseFirestore.instance
        .collection('users')
        .doc(creatorUid)
        .collection('appointments')
        .doc(appointmentId);

    final appointmentData = {
      'uid': appointmentRef.id,
      'title': title,
      'description': description,
      'startTime': startDateTime,
      'endTime': endDateTime,
      'locationName': destinationName,
      'latitude': destinationLatitude,
      'longitude': destinationLongitude,
      'TravelMode': transportMode,
      'Color': color,
      'creatorUid': creatorUid,
      'participants': participants,
    };

    // Update the appointment
    await appointmentRef.set(appointmentData, SetOptions(merge: true));

    // Update the appointment in each participant's shared collection
    for (final participant in participants) {
      final participantUid = participant['uid'];
      final sharedRef = FirebaseFirestore.instance
          .collection('users')
          .doc(participantUid)
          .collection('shared')
          .doc(appointmentId);

      await sharedRef.set({
        ...appointmentData,
        'sharedBy': creatorUid, // Indicate who shared the appointment
      });
    }
  }
}
