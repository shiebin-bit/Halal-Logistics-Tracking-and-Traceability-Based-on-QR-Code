import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/assistant_message.dart';
import 'auth_session_service.dart';

class RoleAssistantReply {
  const RoleAssistantReply({
    required this.message,
    required this.suggestions,
    required this.disclaimer,
  });

  final String message;
  final List<String> suggestions;
  final String disclaimer;
}

class RoleAssistantService {
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const int _maxHistoryItems = 8;

  static Future<RoleAssistantReply> sendMessage({
    required String role,
    required String screen,
    required String prompt,
    required Map<String, dynamic> context,
    required List<AssistantMessage> history,
  }) async {
    final token = await AuthSessionService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('You must be signed in to use the assistant.');
    }

    final trimmedHistory = history.length <= _maxHistoryItems
        ? history
        : history.sublist(history.length - _maxHistoryItems);

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/assistant/chat'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'role': role,
              'screen': screen,
              'prompt': prompt,
              'context': context,
              'history': trimmedHistory
                  .map((message) => message.toRequestJson())
                  .toList(),
            }),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
        'The AI assistant request timed out. Please check that the backend API is running and try again.',
      );
    } on http.ClientException {
      throw Exception(
        'Unable to reach the AI assistant service. Please confirm the backend API address is reachable from this device.',
      );
    }

    Map<String, dynamic> body;
    try {
      body = response.body.isEmpty
          ? const <String, dynamic>{}
          : (jsonDecode(response.body) as Map).cast<String, dynamic>();
    } catch (_) {
      body = const <String, dynamic>{};
    }

    if (response.statusCode != 200) {
      final rawMessage = (body['message'] ?? '').toString();
      final message = rawMessage.contains('route api/assistant/chat could not be found')
          ? 'The running backend API does not have the AI assistant route yet. Restart or rebuild the backend service, then try again.'
          : (rawMessage.isNotEmpty
              ? rawMessage
              : 'Unable to reach the assistant.');
      throw Exception(message);
    }

    final suggestions = (body['suggestions'] as List?)
            ?.map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false) ??
        const <String>[];

    return RoleAssistantReply(
      message: (body['message'] ?? '').toString(),
      suggestions: suggestions,
      disclaimer: (body['disclaimer'] ??
              'AI guidance supports operations only. Confirm final decisions in the official workflow.')
          .toString(),
    );
  }

  static String welcomeFor(String role, String screen) {
    switch (screen) {
      case 'processor.create_batch':
        return 'I can help you explain batch fields, check whether this draft looks complete, or summarize what is ready before saving.';
      case 'processor.batch_detail':
        return 'I can summarize this batch, explain its current status, or suggest the next processor action.';
      case 'logistics.route_detail':
        return 'I can summarize this route, interpret alert points, or help draft a concise incident note.';
      case 'logistics.checkpoint_scanner':
        return 'I can help you confirm what is missing before checkpoint submission and suggest concise checkpoint wording.';
      case 'retailer.receive_inspect':
        return 'I can explain the receiving checks, compare accept vs reject, and help draft a short rejection note.';
      default:
        return 'I can summarize this screen, explain the current workflow, and suggest the next safe step.';
    }
  }

  static List<String> starterPromptsFor(String role, String screen) {
    switch (screen) {
      case 'processor.create_batch':
        return const [
          'Check whether this draft batch is complete.',
          'Explain the certificate fields I still need.',
          'Summarize this draft batch in a short note.',
        ];
      case 'processor.inventory':
        return const [
          'Summarize the current processor inventory view.',
          'Summarize my batch activity this month.',
          'Explain the current status labels in this list.',
        ];
      case 'processor.batch_detail':
        return const [
          'Summarize this batch for a supervisor update.',
          'Explain what the current batch status means.',
          'What should the processor do next on this batch?',
        ];
      case 'logistics.routes':
        return const [
          'Summarize my assigned shipments.',
          'Summarize my logistics activity this month.',
          'Which route looks highest priority?',
        ];
      case 'logistics.checkpoint_scanner':
        return const [
          'Explain what I should confirm before submitting a checkpoint.',
          'Draft a concise checkpoint note from this screen.',
          'What information looks missing here?',
        ];
      case 'logistics.route_detail':
        return const [
          'Summarize this route detail for dispatch.',
          'Explain any alert signals in this route.',
          'Draft an incident note based on this shipment state.',
        ];
      case 'retailer.incoming':
        return const [
          'Summarize the incoming shipments on this screen.',
          'Summarize my retailer activity this month.',
          'Which shipment should I inspect first?',
        ];
      case 'retailer.receive_inspect':
        return const [
          'Explain the difference between accept and reject here.',
          'Check which receiving inputs still look incomplete.',
          'Draft a concise rejection reason from this context.',
        ];
      case 'retailer.inventory':
        return const [
          'Summarize my delivered inventory.',
          'Summarize what changed this month for the retailer.',
          'Explain what this inventory view means operationally.',
        ];
      default:
        return const [
          'Summarize this screen for me.',
          'What should I do next here?',
          'Explain the important fields on this page.',
        ];
    }
  }
}
