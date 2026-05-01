import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trial1/services/api_services.dart';

class SyncStreamUnavailableException implements Exception {
  final String message;

  const SyncStreamUnavailableException(this.message);

  @override
  String toString() => message;
}

class SyncEventService {
  /// Static map to track active stream subscriptions per UID
  /// Prevents duplicate connections when app hot reloads or reconnects
  static final Map<String, StreamController<Map<String, dynamic>>> _activeSubscriptions = {};
  static final Map<String, http.Client> _activeClients = {};

  /// Subscribe to sync status updates via Server-Sent Events
  /// Returns a stream of sync status updates
  /// 
  /// NOTE: Uses singleton pattern to prevent duplicate subscriptions.
  /// If a subscription already exists for this UID, reuses it instead of creating a new connection.
  /// Automatically detects and replaces dead connections.
  static Stream<Map<String, dynamic>> subscribeSyncStatus(String uid) {
    // Check if we already have an active subscription for this UID
    if (_activeSubscriptions.containsKey(uid)) {
      final existingController = _activeSubscriptions[uid]!;
      // If controller is still alive and streaming, reuse it
      if (!existingController.isClosed) {
        print('[SSE] Reusing existing active subscription for $uid');
        return existingController.stream;
      } else {
        // Controller is dead, remove it and create a new one
        print('[SSE] Existing subscription is closed, removing and creating new one for $uid');
        _activeSubscriptions.remove(uid);
        _activeClients.remove(uid);
        
        final existingClient = _activeClients[uid];
        if (existingClient != null) {
          existingClient.close();
        }
      }
    }

    // Create new controller for this subscription
    final controller = StreamController<Map<String, dynamic>>();
    _activeSubscriptions[uid] = controller;

    // Start connection in background (don't await, return stream immediately)
    _startConnectionAsync(uid, controller);
    
    // Return the stream immediately so listeners can subscribe
    return controller.stream;
  }

  static Future<void> _startConnectionAsync(
    String uid,
    StreamController<Map<String, dynamic>> controller,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        controller.close();
        _activeSubscriptions.remove(uid);
        _activeClients.remove(uid);
        throw Exception('No authenticated user');
      }

      final idToken = await user.getIdToken();
      final url = Uri.parse('${BackendService.baseUrl}/gmail/sync/stream');

      print('[SSE] Opening new subscription for $uid');

      final request = http.Request('GET', url);
      request.headers['Authorization'] = 'Bearer $idToken';
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final client = http.Client();
      _activeClients[uid] = client;

      try {
        final response = await client.send(request);

        if (response.statusCode != 200) {
          if (response.statusCode == 503) {
            throw const SyncStreamUnavailableException(
              'Realtime sync service is unavailable right now. Please try again shortly.',
            );
          }
          if (response.statusCode == 401 || response.statusCode == 403) {
            throw const SyncStreamUnavailableException(
              'Your session has expired. Please sign in again.',
            );
          }
          throw SyncStreamUnavailableException(
            'SSE connection failed: ${response.statusCode}',
          );
        }

        print('[SSE] Connected to sync status stream for $uid');

        // Buffer chunks and extract complete SSE events separated by a blank line.
        String buffer = '';
        await for (var chunk in response.stream.transform(utf8.decoder)) {
          buffer += chunk;

          int sepIndex;
          while ((sepIndex = buffer.indexOf('\n\n')) != -1) {
            final eventBlock = buffer.substring(0, sepIndex);
            buffer = buffer.substring(sepIndex + 2);

            // Collect all data: lines (SSE allows multi-line data fields)
            final dataLines = <String>[];
            for (final rawLine in eventBlock.split('\n')) {
              final line = rawLine.trimRight();
              if (line.startsWith('data:')) {
                final payload = line.length > 5 ? line.substring(5) : '';
                dataLines.add(payload.trimLeft());
              }
            }

            if (dataLines.isEmpty) continue;

            final jsonStr = dataLines.join('\n').trim();
            if (jsonStr.isEmpty) continue;

            try {
              final data = jsonDecode(jsonStr) as Map<String, dynamic>;
              print('[SSE] Received: $data');

              if (!controller.isClosed) {
                print('[SSE] Adding to controller (id: ${controller.hashCode}), controller listeners: ${controller.hasListener}');
                controller.add(data);
                print('[SSE] Added to controller successfully');
              } else {
                print('[SSE] Controller is closed, not adding data');
              }

              if (data['status'] == 'stream_closed') {
                break;
              }
            } catch (e, st) {
              print('[SSE] Failed to parse message JSON: $e');
              print('[SSE] Payload causing parse error: $jsonStr');
              print(st);
            }
          }
        }
      } catch (e) {
        print('[SSE] Stream error: $e');
        if (!controller.isClosed) {
          controller.addError(e);
        }
      } finally {
        // Clean up resources
        client.close();
        _activeClients.remove(uid);
        
        if (!controller.isClosed) {
          await controller.close();
        }
        _activeSubscriptions.remove(uid);
        
        print('[SSE] Subscription closed for $uid');
      }
    } catch (e) {
      print('[SSE] Connection setup error: $e');
      if (!controller.isClosed) {
        controller.addError(e);
        await controller.close();
      }
      _activeSubscriptions.remove(uid);
    }
  }

  /// Wait for sync to complete using SSE
  /// Returns a map with 'success' boolean and 'newMessagesCount' integer
  static Future<Map<String, dynamic>> waitForSyncCompletion(
    String uid, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    String? lastTerminalStatus;
    bool pipelineComplete = false;
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

        if (status['pipeline_complete'] == true) {
          pipelineComplete = true;
          print(
            '[SSE] Full pipeline complete with $newMessagesCount new messages, resolving success',
          );
          return {'success': true, 'newMessagesCount': newMessagesCount};
        }

        if (status['status'] == 'completed' || status['status'] == 'no_action') {
          print('[SSE] Sync phase completed, waiting for AI queue to drain...');
          lastTerminalStatus = 'completed';
        } else if (status['status'] == 'failed') {
          print('[SSE] Sync failed, resolving failure');
          lastTerminalStatus = 'failed';
          return {'success': false, 'newMessagesCount': 0};
        } else if (status['status'] == 'timeout') {
          print('[SSE] Sync timeout, resolving failure');
          return {'success': false, 'newMessagesCount': 0};
        } else if (status['status'] == 'stream_closed') {
          print('[SSE] Stream closed event received');
          // Only resolve success if pipeline completion was observed.
          if (pipelineComplete) {
            print(
              '[SSE] Stream closed after pipeline completion, resolving success with $newMessagesCount new messages',
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

  /// Clean up all active subscriptions
  /// Call this on logout or app shutdown to prevent resource leaks
  static Future<void> cleanupAllSubscriptions() async {
    print('[SSE] Cleaning up all active subscriptions...');
    
    // Close all controllers
    for (final controller in _activeSubscriptions.values) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
    _activeSubscriptions.clear();
    
    // Close all HTTP clients
    for (final client in _activeClients.values) {
      client.close();
    }
    _activeClients.clear();
    
    print('[SSE] All subscriptions cleaned up');
  }

  /// Close subscription for a specific UID
  /// Useful if user logs out or switches accounts
  static Future<void> closeSubscription(String uid) async {
    print('[SSE] Closing subscription for $uid');
    
    final controller = _activeSubscriptions.remove(uid);
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
    
    final client = _activeClients.remove(uid);
    if (client != null) {
      client.close();
    }
  }
}

