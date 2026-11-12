import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

// ------------------------------------------------------------------ server sheet
Future<void> showServerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _ServerSheet(),
  );
}

class _ServerSheet extends StatefulWidget {
  const _ServerSheet();
  @override
  State<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends State<_ServerSheet> {
  late final TextEditingController _c = TextEditingController(text: app.serverUrl);
  String? _status;
  bool _ok = false;
  bool _testing = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final url = Api.normalize(_c.text);
    if (url.isEmpty) return;
    setState(() {
      _testing = true;
      _status = null;
    });
    try {
      final res = await Api(url, null).get('/health', timeout: 6);
      final ai = res is Map && res['ai_configured'] == true;
      if (!mounted) return;
      setState(() {
        _ok = true;
        _status = ai ? 'Connected. The AI assistant is ready.' : 'Connected. (AI key not set on the server yet.)';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _ok = false;
        _status = e.message;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    await app.setServer(_c.text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: context.line, borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Server address', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Type the address of the computer running the AutoAssist server, for example http://192.168.1.5:8000',
          style: TextStyle(color: context.muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        AppField(controller: _c, hint: 'http://192.168.1.5:8000', icon: Icons.dns_rounded, keyboard: TextInputType.url),
        if (_status != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(_ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                size: 18, color: _ok ? AppColors.ok : AppColors.danger),
            const SizedBox(width: 8),
            Expanded(child: Text(_status!, style: TextStyle(color: _ok ? AppColors.ok : AppColors.danger, fontSize: 13))),
          ]),
        ],
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: PillButton(label: 'Test', outlined: true, loading: _testing, onTap: _test)),
          const SizedBox(width: 12),
          Expanded(child: PillButton(label: 'Save', onTap: _save)),
        ]),
      ]),
    );
  }
}

// ------------------------------------------------------------------ welcome
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: AppImage(name: 'welcome_hero', icon: Icons.directions_car_rounded)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withAlpha(110), Colors.black.withAlpha(20), Colors.black.withAlpha(160)],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                icon: const Icon(Icons.settings_rounded, color: Colors.white),
                onPressed: () => showServerSheet(context),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: size.height * 0.14,
          child: Column(children: [
            Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.car_repair_rounded, size: 40, color: Color(0xFF111114)),
            ),
            const SizedBox(height: 16),
            const Text('AutoAssist',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            const Text('Roadside help, anywhere', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, child) =>
                Transform.translate(offset: Offset(0, (1 - v) * 80), child: Opacity(opacity: v, child: child)),
            child: Container(
              padding: EdgeInsets.fromLTRB(28, 32, 28, 28 + bottom),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('WELCOME', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const SizedBox(height: 10),
                Text(
                  'Find a mechanic near you, get help fast\nand talk to our AI vehicle assistant.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.muted, height: 1.45),
                ),
                const SizedBox(height: 26),
                PillButton(
                  label: 'Login',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                ),
                const SizedBox(height: 12),
                PillButton(
                  label: 'Sign Up',
                  outlined: true,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ login
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty || _pw.text.isEmpty) {
      showMsg(context, 'Enter your email and password.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await app.api.post('/auth/login', body: {'email': email, 'password': _pw.text});
      await app.setSession(res['token'] as String, Map<String, dynamic>.from(res['user'] as Map));
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _demo(String email) {
    _email.text = email;
    _pw.text = 'demo1234';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const BackBtn(),
              const Spacer(),
              RoundIconButton(icon: Icons.settings_rounded, onTap: () => showServerSheet(context)),
            ]),
            const SizedBox(height: 32),
            const Text('Welcome back', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Log in to request help and find mechanics.', style: TextStyle(color: context.muted)),
            const SizedBox(height: 28),
            AppField(
              controller: _email,
              hint: 'Email address',
              icon: Icons.mail_outline_rounded,
              keyboard: TextInputType.emailAddress,
              action: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            AppField(
              controller: _pw,
              hint: 'Password',
              icon: Icons.lock_outline_rounded,
              obscure: _hide,
              onSubmitted: (_) => _submit(),
              suffix: IconButton(
                icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: context.muted),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
            const SizedBox(height: 24),
            PillButton(label: 'Login', loading: _busy, onTap: _submit),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context)
                    .pushReplacement(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: Text.rich(TextSpan(
                  text: "Don't have an account? ",
                  style: TextStyle(color: context.muted),
                  children: const [
                    TextSpan(text: 'Sign up', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
                  ],
                )),
              ),
            ),
            const SizedBox(height: 20),
            Text('TRY A DEMO ACCOUNT',
                style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: context.muted)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _demoChip('Driver', 'driver@demo.com'),
              _demoChip('Mechanic', 'mechanic@demo.com'),
              _demoChip('Supplier', 'supplier@demo.com'),
            ]),
            const SizedBox(height: 28),
            Tappable(
              onTap: () => showServerSheet(context).then((_) {
                if (mounted) setState(() {});
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: context.field, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(Icons.dns_rounded, size: 18, color: context.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Server: ${app.serverUrl}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.muted, fontSize: 13)),
                  ),
                  Text('Change', style: TextStyle(color: context.ink, fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _demoChip(String label, String email) => Tappable(
        onTap: () => _demo(email),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(18)),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      );
}

// ------------------------------------------------------------------ register
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _biz = TextEditingController();
  final _pw = TextEditingController();
  String _role = 'driver';
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _biz.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    String? problem;
    if (_name.text.trim().length < 2) {
      problem = 'Enter your full name.';
    } else if (!_email.text.contains('@')) {
      problem = 'Enter a valid email address.';
    } else if (_pw.text.length < 6) {
      problem = 'Password must be at least 6 characters.';
    } else if (_role != 'driver' && _biz.text.trim().isEmpty) {
      problem = 'Enter your business name.';
    }
    if (problem != null) {
      showMsg(context, problem, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await app.api.post('/auth/register', body: {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': _pw.text,
        'role': _role,
        'business_name': _biz.text.trim(),
      });
      await app.setSession(res['token'] as String, Map<String, dynamic>.from(res['user'] as Map));
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const BackBtn(),
              const Spacer(),
              RoundIconButton(icon: Icons.settings_rounded, onTap: () => showServerSheet(context)),
            ]),
            const SizedBox(height: 24),
            const Text('Create account', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Choose how you will use AutoAssist.', style: TextStyle(color: context.muted)),
            const SizedBox(height: 20),
            Row(children: [
              _roleTile('driver', 'Driver', Icons.directions_car_rounded),
              const SizedBox(width: 10),
              _roleTile('mechanic', 'Mechanic', Icons.build_rounded),
              const SizedBox(width: 10),
              _roleTile('supplier', 'Parts shop', Icons.inventory_2_rounded),
            ]),
            const SizedBox(height: 20),
            AppField(controller: _name, hint: 'Full name', icon: Icons.person_outline_rounded, action: TextInputAction.next),
            const SizedBox(height: 12),
            AppField(
              controller: _email,
              hint: 'Email address',
              icon: Icons.mail_outline_rounded,
              keyboard: TextInputType.emailAddress,
              action: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            AppField(
              controller: _phone,
              hint: 'Phone number',
              icon: Icons.phone_outlined,
              keyboard: TextInputType.phone,
              action: TextInputAction.next,
            ),
            if (_role != 'driver') ...[
              const SizedBox(height: 12),
              AppField(
                controller: _biz,
                hint: _role == 'mechanic' ? 'Garage / business name' : 'Shop name',
                icon: Icons.storefront_outlined,
                action: TextInputAction.next,
              ),
            ],
            const SizedBox(height: 12),
            AppField(
              controller: _pw,
              hint: 'Password (min. 6 characters)',
              icon: Icons.lock_outline_rounded,
              obscure: _hide,
              suffix: IconButton(
                icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: context.muted),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
            const SizedBox(height: 24),
            PillButton(label: 'Create account', loading: _busy, onTap: _submit),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: Text.rich(TextSpan(
                  text: 'Already have an account? ',
                  style: TextStyle(color: context.muted),
                  children: const [
                    TextSpan(text: 'Login', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
                  ],
                )),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _roleTile(String value, String label, IconData icon) {
    final sel = _role == value;
    return Expanded(
      child: Tappable(
        onTap: () => setState(() => _role = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: sel ? context.ink : context.card,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(children: [
            Icon(icon, color: sel ? context.onInk : context.muted, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? context.onInk : context.muted)),
          ]),
        ),
      ),
    );
  }
}
