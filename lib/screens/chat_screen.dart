import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/medicine.dart';
import '../l10n/strings.dart';
import '../theme/app_colors.dart';

class ChatScreen extends StatefulWidget {
  final String lang;
  final Medicine? medicine;
  const ChatScreen({super.key, required this.lang, this.medicine});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatMessage {
  final String role; // "user" | "assistant"
  final String text;
  _ChatMessage(this.role, this.text);
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMessage('user', text));
      _sending = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final reply = await _api.chat(
        message: text,
        history:
            _messages.map((m) => {'role': m.role, 'text': m.text}).toList(),
        lang: widget.lang,
        medicine: widget.medicine,
      );
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage('assistant', reply)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages
          .add(_ChatMessage('assistant', 'Sorry, something went wrong: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mintBg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        ),
        title: Text(Strings.of('ask_ai', widget.lang),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(lang: widget.lang)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      final isUser = msg.role == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 11),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            gradient:
                                isUser ? AppColors.primaryButtonGradient : null,
                            color: isUser ? null : AppColors.cardWhite,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isUser ? 18 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 18),
                            ),
                            boxShadow: isUser ? null : AppShadows.card,
                          ),
                          child: Text(msg.text,
                              style: TextStyle(
                                  color: isUser
                                      ? Colors.white
                                      : AppColors.textDark,
                                  height: 1.4)),
                        ),
                      );
                    },
                  ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: LinearProgressIndicator(
                color: AppColors.primaryTeal,
                backgroundColor: AppColors.mintChip,
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: widget.lang == 'ur'
                              ? 'اپنا سوال لکھیں...'
                              : 'Ask a question...',
                          hintStyle:
                              const TextStyle(color: AppColors.textMuted),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryButtonGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.button,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String lang;
  const _EmptyState({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.mintChip,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppColors.primaryTeal, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              lang == 'ur'
                  ? 'دوا کے بارے میں کچھ بھی پوچھیں'
                  : 'Ask anything about this medicine',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
