import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trial1/services/api_services.dart';

class SyncEventService {
  /// Subscribe to sync status updates via Server-Sent Events
  /// Returns a stream of sync status updates
  ///
  /// The backend controls when the stream closes (sends 'stream_closed').
  /// The frontend should NOT close on completed/failed — the backend's
  /// waiting window handles the lifecycle.
  static Stream<Map<String, dynamic>> subscribeSyncStatus(String uid) async* {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    final idToken = await user.getIdToken();
    final url = Uri.parse('${BackendService.baseUrl}/gmail/sync/stream');

    print('[SSE] Connecting to sync status stream...');

    final request = http.Request('GET', url);
    request.headers['Authorization'] = 'Bearer $idToken';
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';

    final client = http.Client();

    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('SSE connection failed: ${response.statusCode}');
      }

      print('[SSE] Connected to sync status stream');

      await for (var chunk in response.stream.transform(utf8.decoder)) {
        // SSE messages are in format: "data: {...}\n\n"
        final lines = chunk.split('\n');

        for (var line in lines) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6).trim();
            if (jsonStr.isEmpty) continue;

            try {
              final data = jsonDecode(jsonStr) as Map<String, dynamic>;
              print('[SSE] Received: $data');

              // Only close when backend explicitly says stream_closed
              if (data['status'] == 'stream_closed') {
                yield data;
                client.close();
                return;
              }

              yield data;
            } catch (e) {
              print('[SSE] Failed to parse message: $e');
            }
          }
        }
      }
    } catch (e) {
      print('[SSE] Stream error: $e');
      client.close();
      rethrow;
    }
  }

  /// Wait for sync to complete using SSE
  /// Returns a map with 'success' boolean and 'newMessagesCount' integer
  static Future<Map<String, dynamic>> waitForSyncCompletion(
    String uid, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    String? lastTerminalStatus;
    int newMessagesCount = 0;

    try {
      await for (var status in subscribeSyncStatus(uid).timeout(
        timeout,
        onTimeout: (sink) {
          print('[SSE] Timeout waiting for sync completion');
          sink.add({'status': 'timeout'});
          sink.close();
        },
      )) {
        print('[SSE] Sync status: ${status['status']}');

        // Capture new messages count when available
        if (status.containsKey('new_messages_count')) {
          newMessagesCount = status['new_messages_count'] ?? 0;
        }

        if (status['status'] == 'completed') {
          print(
            '[SSE] Sync completed with $newMessagesCount new messages, resolving success',
          );
          lastTerminalStatus = 'completed';
          return {'success': true, 'newMessagesCount': newMessagesCount};
        } else if (status['status'] == 'failed') {
          print('[SSE] Sync failed, resolving failure');
          lastTerminalStatus = 'failed';
          return {'success': false, 'newMessagesCount': 0};
        } else if (status['status'] == 'timeout') {
          print('[SSE] Sync timeout, resolving failure');
          return {'success': false, 'newMessagesCount': 0};
        } else if (status['status'] == 'stream_closed') {
          print('[SSE] Stream closed event received');
          // Only resolve if a terminal status was seen before
          if (lastTerminalStatus == 'completed') {
            print(
              '[SSE] Stream closed after completed, resolving success with $newMessagesCount new messages',
            );
            return {'success': true, 'newMessagesCount': newMessagesCount};
          } else if (lastTerminalStatus == 'failed') {
            print('[SSE] Stream closed after failed, resolving failure');
            return {'success': false, 'newMessagesCount': 0};
          } else {
            print(
              '[SSE] Stream closed without terminal status, resolving failure',
            );
            return {'success': false, 'newMessagesCount': 0};
          }
        }
      }
    } catch (e) {
      print('[SSE] Error waiting for sync: $e');
      return {'success': false, 'newMessagesCount': 0};
    }
    print('[SSE] Stream ended without terminal status, resolving failure');
    return {
      'success': false,
      'newMessagesCount': 0,
    }; // Timeout or stream closed
  }
}
