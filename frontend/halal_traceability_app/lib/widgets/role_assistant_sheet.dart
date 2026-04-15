import 'package:flutter/material.dart';

import '../models/assistant_message.dart';
import '../services/role_assistant_service.dart';

class RoleAssistantSheet extends StatefulWidget {
  const RoleAssistantSheet({
    super.key,
    required this.role,
    required this.screen,
    required this.title,
    required this.accentColor,
    required this.contextBuilder,
    this.showCloseButton = true,
  });

  final String role;
  final String screen;
  final String title;
  final Color accentColor;
  final Map<String, dynamic> Function() contextBuilder;
  final bool showCloseButton;

  @override
  State<RoleAssistantSheet> createState() => _RoleAssistantSheetState();
}

class _RoleAssistantSheetState extends State<RoleAssistantSheet> {
  final List<AssistantMessage> _messages = [];
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late List<String> _suggestions;
  late String _disclaimer;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _suggestions = RoleAssistantService.starterPromptsFor(
      widget.role,
      widget.screen,
    );
    _disclaimer =
        'AI guidance supports operations only. Confirm final decisions in the official workflow.';
    _messages.add(
      AssistantMessage.assistant(
        RoleAssistantService.welcomeFor(widget.role, widget.screen),
      ),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt([String? seededPrompt]) async {
    final prompt = (seededPrompt ?? _promptController.text).trim();
    if (prompt.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _messages.add(AssistantMessage.user(prompt));
      _promptController.clear();
    });
    _scrollToBottom();

    try {
      final reply = await RoleAssistantService.sendMessage(
        role: widget.role,
        screen: widget.screen,
        prompt: prompt,
        context: widget.contextBuilder(),
        history: _messages,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(AssistantMessage.assistant(reply.message));
        _suggestions = reply.suggestions;
        _disclaimer = reply.disclaimer;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          AssistantMessage.assistant(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final surface = Colors.white;
    final muted = Colors.grey[600]!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 26,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.accentColor,
                              widget.accentColor.withValues(alpha: 0.72),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF172033),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _screenLabel(widget.screen),
                              style: TextStyle(
                                color: muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.showCloseButton)
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 18,
                        color: widget.accentColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _disclaimer,
                          style: TextStyle(
                            color: muted,
                            height: 1.35,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isSending && index == _messages.length) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: SizedBox(
                              width: 54,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  3,
                                  (dotIndex) => CircleAvatar(
                                    radius: 4,
                                    backgroundColor: widget.accentColor
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      final message = _messages[index];
                      final isAssistant = message.role == 'assistant';

                      return Align(
                        alignment: isAssistant
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isAssistant ? surface : widget.accentColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            message.content,
                            style: TextStyle(
                              height: 1.45,
                              color: isAssistant
                                  ? const Color(0xFF172033)
                                  : Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  SizedBox(
                    height: 46,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return ActionChip(
                          label: Text(
                            suggestion,
                            style: TextStyle(
                              color: widget.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor:
                              widget.accentColor.withValues(alpha: 0.08),
                          side: BorderSide(
                            color: widget.accentColor.withValues(alpha: 0.14),
                          ),
                          onPressed: () => _sendPrompt(suggestion),
                        );
                      },
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemCount: _suggestions.length,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promptController,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendPrompt(),
                          decoration: InputDecoration(
                            hintText: 'Ask for help on this screen...',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FloatingActionButton.small(
                        heroTag: null,
                        backgroundColor: widget.accentColor,
                        onPressed: _isSending ? null : _sendPrompt,
                        child:
                            const Icon(Icons.send_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _screenLabel(String screen) {
    switch (screen) {
      case 'processor.create_batch':
        return 'Current focus: batch creation';
      case 'processor.inventory':
        return 'Current focus: inventory review';
      case 'processor.batch_detail':
        return 'Current focus: batch detail';
      case 'logistics.routes':
        return 'Current focus: assigned routes';
      case 'logistics.checkpoint_scanner':
        return 'Current focus: checkpoint capture';
      case 'logistics.route_detail':
        return 'Current focus: route detail';
      case 'retailer.incoming':
        return 'Current focus: incoming shipments';
      case 'retailer.receive_inspect':
        return 'Current focus: receiving and inspection';
      case 'retailer.inventory':
        return 'Current focus: delivered inventory';
      default:
        return 'Current focus: operational support';
    }
  }
}
