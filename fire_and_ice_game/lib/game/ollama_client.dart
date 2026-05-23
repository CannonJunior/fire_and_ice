import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show debugPrint;

/// Thin wrapper around the local Ollama REST API for in-game RADIO COMMS chat.
class OllamaClient {
  OllamaClient._();

  static const _url   = 'http://localhost:11434/api/chat';
  static const _model = 'qwen3.5:0.8b';
  static const _system =
      'You are the Squadron Duty Officer at the Fire & Ice aerial firefighting '
      'airbase. You coordinate fire suppression missions, monitor active fire '
      'fronts, track retardant and water loads, and support pilots in the air. '
      'Respond in a terse, professional aviation radio style. Keep replies under '
      '3 sentences. Use brevity codes where natural (WILCO, ROGER, NEGATIVE, '
      'AFFIRM, STANDBY). Never break character.';

  /// Send [userMessage] with prior [history] (role, content) pairs.
  /// Returns the assistant reply, or an error string on failure.
  static Future<String> chat(
      String userMessage, List<(String, String)> history) async {
    final messages = [
      {'role': 'system', 'content': _system},
      ...history.map((h) => {'role': h.$1, 'content': h.$2}),
      {'role': 'user', 'content': userMessage},
    ];
    try {
      final resp = await html.HttpRequest.request(
        _url,
        method: 'POST',
        requestHeaders: {'Content-Type': 'application/json'},
        sendData: jsonEncode({'model': _model, 'messages': messages, 'stream': false, 'think': false}),
      );
      final data = jsonDecode(resp.responseText ?? '{}') as Map<String, dynamic>;
      return (data['message']?['content'] as String?)?.trim() ?? '[no response]';
    } catch (e) {
      debugPrint('[OllamaClient] $e');
      return '[COMMS OFFLINE]';
    }
  }
}
