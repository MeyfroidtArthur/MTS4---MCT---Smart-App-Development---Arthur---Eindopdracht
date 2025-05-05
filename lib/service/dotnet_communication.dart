import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendOnMyWayNotification({
  required String apiUrl, // e.g., http://your-server:5000/notify
  required String fcmToken,
  required String title,
  required String body,
}) async {
  final response = await http.post(
    Uri.parse(apiUrl),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'fcmToken': fcmToken, 'title': title, 'body': body}),
  );

  if (response.statusCode == 200) {
    print('Notification sent!');
  } else {
    print('Failed to send notification: ${response.body}');
  }
}
