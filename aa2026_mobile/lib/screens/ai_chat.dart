import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'request_form.dart';

class _Msg {
  final String role; // 'user' | 'assistant'
  final String text;
  final bool greeting;
  const _Msg(this.role, this.text, {this.greeting = false});
}

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  static const _suggestions = [
    'My car will not start',
    'Engine is overheating',
    'Strange noise when braking',
    'How do I change a flat tyre?',
  ];

  final List<_Msg> _msgs = [
    const _Msg(
      'assistant',
      'Hi, I am AutoAssist AI. Tell me what your vehicle is doing and I will suggest what to check. '
          'If it looks serious, I will help you decide when to call a mechanic.',
      greeting: true,
    ),
  ];
  final _c = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _vehicles = [];
  int _vIndex = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    try {
      final list = asList(await app.api.get('/vehicles'));
      if (mounted) setState(() => _vehicles = list);
    } on ApiException {
      // The assistant works without a vehicle.
    }
  }

  String? get _vehicleText {
    if (_vehicles.isEmpty) return null;
    final v = _vehicles[_vIndex < _vehicles.length ? _vIndex : 0];
    return '${v['year']} ${v['make']} ${v['model']}';
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

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _c.text).trim();
    if (text.isEmpty || _sending) return;
    _c.clear();
    setState(() {
      _msgs.add(_Msg('user', text));
      _sending = true;
    });
    _toBottom();
    try {
      final res = await app.api.post('/ai/chat', timeout: 70, body: {
        'messages': [
          for (final m in _msgs)
            if (!m.greeting) {'role': m.role, 'content': m.text},
        ],
        'vehicle': _vehicleText,
      });
      final reply = (((res as Map)['reply'] as String?) ?? '').trim();
      if (!mounted) return;
      setState(() => _msgs.add(_Msg('assistant', reply)));
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
      _toBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showSuggestions = _msgs.length == 1 && !_sending;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Row(children: [
              const BackBtn(),
              const SizedBox(width: 14),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('AI assistant', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Text('Preliminary guidance only', style: TextStyle(color: context.muted, fontSize: 12)),
                ]),
              ),
              if (_vehicles.isNotEmpty)
                PopupMenuButton<int>(
                  onSelected: (i) => setState(() => _vIndex = i),
                  itemBuilder: (_) => [
                    for (int i = 0; i < _vehicles.length; i++)
                      PopupMenuItem<int>(value: i, child: Text('${_vehicles[i]['make']} ${_vehicles[i]['model']}')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(18)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.directions_car_rounded, size: 16, color: context.muted),
                      const SizedBox(width: 6),
                      Text(
                        '${_vehicles[_vIndex < _vehicles.length ? _vIndex : 0]['make']}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      Icon(Icons.arrow_drop_down_rounded, color: context.muted),
                    ]),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              itemCount: _msgs.length + (_sending ? 1 : 0) + (showSuggestions ? 1 : 0),
              itemBuilder: (context, i) {
                if (i < _msgs.length) {
                  final m = _msgs[i];
                  return ChatBubble(text: m.text, mine: m.role == 'user', markdown: m.role == 'assistant' && !m.greeting);
                }
                if (_sending) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(18)),
                      child: const TypingDots(),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in _suggestions)
                      Tappable(
                        onTap: () => _send(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: context.muted.withAlpha(90)),
                          ),
                          child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ]),
                );
              },
            ),
          ),
          if (app.role == 'driver')
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Tappable(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RequestFormScreen())),
                child: Row(children: [
                  const Icon(Icons.build_rounded, size: 15, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text('Still stuck? Request a mechanic',
                      style: TextStyle(color: context.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(children: [
              Expanded(
                child: AppField(
                  controller: _c,
                  hint: 'Describe the problem...',
                  action: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 10),
              RoundIconButton(
                icon: Icons.send_rounded,
                bg: AppColors.accent,
                fg: Colors.white,
                size: 52,
                onTap: _sending ? null : _send,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
