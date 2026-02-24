import 'dart:io';
import 'package:http/io_client.dart';

/// Creates a custom HttpClient that bypasses SSL certificate validation.
///
/// ⚠ Warning:
/// This should be used only in development or controlled environments.
/// It accepts all SSL certificates including invalid or self-signed ones.
HttpClient _getHttpClient() {
  final client = HttpClient()
    ..badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
  return client;
}

/// Global IOClient instance using custom HttpClient.
///
/// Useful for making HTTP requests to servers with self-signed SSL certificates.
final ioClient = IOClient(_getHttpClient());
