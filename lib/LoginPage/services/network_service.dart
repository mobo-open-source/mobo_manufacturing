import 'dart:convert';
import 'dart:io';

/// Service responsible for handling network-level operations related to
/// server discovery and connectivity.
///
/// Provides utilities for:
/// • Server endpoint normalization
/// • Secure HTTP communication
/// • Database discovery via Odoo JSON-RPC endpoints
///
/// Uses low-level HttpClient for fine-grained timeout and certificate control.
class NetworkService {

  /// Fetches available database names from the server.
  ///
  /// Performs URL normalization before making a JSON-RPC request to
  /// the `/web/database/list` endpoint.
  ///
  /// URL Normalization:
  /// • Adds https scheme if missing
  /// • Removes trailing slash if present
  ///
  /// Network Configuration:
  /// • Connection timeout → 12 seconds
  /// • Idle timeout → 10 seconds
  /// • Max connections per host → 5
  /// • Accepts self-signed certificates (for development or private servers)
  ///
  /// Parameters:
  /// • url → Base server URL or domain
  ///
  /// Returns:
  /// • List<String> → Available database names
  ///
  /// Throws:
  /// • Exception → When network request fails or response parsing fails
  Future<List<String>> fetchDatabaseList(String url) async {
    try {
      String normalizedUrl = url.trim();
      if (!normalizedUrl.startsWith('http://') &&
          !normalizedUrl.startsWith('https://')) {
        normalizedUrl = 'https://$normalizedUrl';
      }
      if (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }

      final HttpClient httpClient = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12)
        ..idleTimeout = const Duration(seconds: 10)
        ..maxConnectionsPerHost = 5
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;

      final request = await httpClient.postUrl(
        Uri.parse('$normalizedUrl/web/database/list'),
      );

      request.headers.set('Content-Type', 'application/json');
      request.write(
        jsonEncode({'jsonrpc': '2.0', 'method': 'call', 'params': {}, 'id': 1}),
      );

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      httpClient.close();

      final jsonResponse = jsonDecode(responseBody);
      if (jsonResponse['result'] is List) {
        return (jsonResponse['result'] as List)
            .map((db) => db.toString())
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Error fetching database list: $e');
    }
  }
}
