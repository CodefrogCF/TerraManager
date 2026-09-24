import 'package:flutter/material.dart';
import 'package:http/browser_client.dart';

import 'shared_client/shared_api_client.dart';
import 'shared_client/shared_care_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final client = BrowserClient()..withCredentials = true;
  runApp(SharedCareApp(api: SharedApiClient(Uri.base, client)));
}
