import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/api.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Driver <-> mechanic chat. New messages arrive instantly over a WebSocket;
/// a light background refresh keeps things working if the socket drops.
class ChatScreen extends StatefulWidget {
  final int requestId;
  final String title;
  const ChatScreen({super.key, required this.requestId, required this.title});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> _msgs = [];
  final _c = TextEditingController();
  final _scroll = ScrollController();
  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _poll;
  int _lastId = 0;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch(initial: true);
    _connect();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _sub?.cancel();
    _ch?.sink.close();
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _connect() {
    try {
      final token = Uri.encodeQueryComponent(app.api.token ?? '');
      final url = app.api.wsUrl('/ws/requests/${widget.requestId}?token=$token');
      final ch = WebSocketChannel.connect(Uri.parse(url));
      _ch = ch;
      ch.ready.catchError((_) {});
      _sub = ch.stream.listen(
        (data) {
          try {
            _add(Map<String, dynamic>.from(jsonDecode(data as String) as Map));
          } catch (_) {}
        },
        onError: (_) {},
        cancelOnError: true,
      );
    } catch (_) {
      // Polling keeps the chat working without the socket.
    }
  }

  Future<void> _fetch({bool initial = false}) async {
    try {
      final data = await app.api.get('/requests/${widget.requestId}/messages', query: {'after_id': _lastId});
      if (!mounted) return;
      for (final m in asList(data)) {
        _add(m, scroll: false);
      }
      setState(() {
        _loading = false;
        _error = null;
      });
      if (initial) _toBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (initial) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  void _add(Map<String, dynamic> m, {bool scroll = true}) {
    final id = m['id'] as int;
    if (_msgs.any((x) => x['id'] == id)) return;
    if (!mounted) return;
    setState(() {
      _msgs.add(m);
      if (id > _lastId) _lastId = id;
    });
    if (scroll) _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _c.text.trim();
    if (text.isEmpty || _sending) return;
    _c.clear();
    setState(() => _sending = true);
    try {
      final res = await app.api.post('/requests/${widget.requestId}/messages', body: {'text': text});
      _add(Map<String, dynamic>.from(res as Map));
    } on ApiException catch (e) {
      if (mounted) {
        _c.text = text;
        showMsg(context, e.message, error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Row(children: [
              const BackBtn(),
              const SizedBox(width: 14),
              Avatar(widget.title, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                  Text('Request #${widget.requestId}', style: TextStyle(color: context.muted, fontSize: 12)),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _error != null
                    ? EmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'Chat unavailable', subtitle: _error!)
                    : _msgs.isEmpty
                        ? const EmptyState(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'No messages yet',
                            subtitle: 'Say hello and share any details that will help.',
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                            itemCount: _msgs.length,
                            itemBuilder: (context, i) {
                              final m = _msgs[i];
                              return ChatBubble(
                                text: m['text'] as String,
                                mine: m['sender_id'] == app.userId,
                                time: hhmm(m['created_at'] as String?),
                              );
                            },
                          ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(children: [
              Expanded(
                child: AppField(
                  controller: _c,
                  hint: 'Type a message...',
                  action: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 10),
              RoundIconButton(icon: Icons.send_rounded, bg: AppColors.accent, fg: Colors.white, size: 52, onTap: _send),
            ]),
          ),
        ]),
      ),
    );
  }
}
