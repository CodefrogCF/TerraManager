import 'package:flutter/material.dart';
import 'package:http/browser_client.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'shared_client/shared_api_client.dart';
import 'shared_client/shared_care_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The default Web fallback fetches a decoder from a public CDN. Shared Care
  // runs entirely on the operator's LAN, so use the browser's native reader.
  MobileScannerPlatform.instance.setWebBarcodeReader(
    WebBarcodeReader.barcodeDetector,
  );
  final client = BrowserClient()..withCredentials = true;
  runApp(SharedCareApp(api: SharedApiClient(Uri.base, client)));
}
