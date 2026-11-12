import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';
import '../data/auth_repository.dart';

/// Layar pembuka (selalu terang)
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Scaffold(
      body: Stack(children: [
        Positioned(right: -110, top: -110, child: Container(width: 320, height: 320, decoration: BoxDecoration(color: t.accentTint, shape: BoxShape.circle))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 64, 28, 36),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const LogoTile(size: 92, radius: 28, padding: 10, forceLight: true),
              const Spacer(),
              Text(context.l.introTitle, style: const TextStyle(fontSize: 36, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -1)),
              const Spacer(),
              Row(children: [
                Row(children: [
                  Container(width: 26, height: 8, decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(width: 6),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(8))),
                ]),
                const Spacer(),
                Material(
                  color: t.accent,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => context.go('/login'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 8, 8),
                      child: Row(children: [
                        Text(context.l.next, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(width: 12),
                        Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0x38FFFFFF), shape: BoxShape.circle), child: const Icon(Icons.arrow_forward_rounded, color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _show = false;
  late bool _remember = ref.read(sharedPrefsProvider).getBool('remember') ?? true;
  bool _busy = false;

  Future<void> _login() async {
    setState(() => _busy = true);
    try {
      await ref.read(sharedPrefsProvider).setBool('remember', _remember);
      await ref.read(authRepositoryProvider).signIn(_email.text, _pw.text);
      if (mounted) context.go('/dashboard');
    } on AuthException {
      if (mounted) toast(context, context.l.wrongLogin);
    } catch (_) {
      if (mounted) toast(context, context.l.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = context.tk;
    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: LogoTile(size: 176, radius: 48, padding: 18, forceLight: true)),
                const SizedBox(height: 16),
                Text(l.welcome, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(l.loginSubtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                FieldLabel(l.emailOrUsername),
                TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false, textInputAction: TextInputAction.next),
                FieldLabel(l.password),
                TextField(
                  controller: _pw,
                  obscureText: !_show,
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      tooltip: _show ? l.hidePassword : l.showPassword,
                      icon: Icon(_show ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: t.ink2),
                      onPressed: () => setState(() => _show = !_show),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(children: [
                    AccentCheckbox(value: _remember, label: l.rememberMe, onChanged: (v) => setState(() => _remember = v)),
                    const Spacer(),
                    TextButton(onPressed: () => context.push('/forgot'), child: Text(l.forgotPassword)),
                  ]),
                ),
                FilledButton(onPressed: _busy ? null : _login, child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(l.signIn)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(l.noAccount, style: Theme.of(context).textTheme.bodySmall),
                  TextButton(onPressed: () => context.push('/register'), child: Text(l.signUpHere)),
                ]),
              ]),
            ),
          ),
          Positioned(left: 20, top: 16, child: IconBtn(icon: Icons.arrow_back_ios_new_rounded, label: l.back, onTap: () => context.go('/intro'))),
        ]),
      ),
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _c = List.generate(4, (_) => TextEditingController());
  bool _busy = false;

  Future<void> _submit() async {
    final l = context.l;
    final name = _c[0].text.trim(), email = _c[1].text.trim();
    if (name.isEmpty || !RegExp(r'^\S+@\S+$').hasMatch(email)) return toast(context, l.invalidStoreForm);
    if (_c[3].text.length < AppConfig.minPasswordLength) return toast(context, l.passwordMin);
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signUp(storeName: name, email: email, phone: _c[2].text, password: _c[3].text);
      if (!mounted) return;
      toast(context, l.accountCreated);
      context.go('/login');
    } on AuthException catch (e) {
      if (mounted) toast(context, RegExp('registered|exists', caseSensitive: false).hasMatch(e.message) ? l.emailTaken : e.message);
    } catch (_) {
      if (mounted) toast(context, l.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final labels = [l.storeName, l.storeEmail, l.phone, l.password];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: l.createAccount, onBack: () => context.pop()),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
              for (var i = 0; i < 4; i++) ...[
                FieldLabel(labels[i]),
                TextField(
                  controller: _c[i],
                  obscureText: i == 3,
                  keyboardType: i == 1 ? TextInputType.emailAddress : (i == 2 ? TextInputType.phone : TextInputType.text),
                  decoration: InputDecoration(hintText: labels[i]),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(onPressed: _busy ? null : _submit, child: Text(l.createAccountBtn)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class ForgotScreen extends ConsumerStatefulWidget {
  const ForgotScreen({super.key});
  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  final _email = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: l.forgotTitle, onBack: () => context.pop()),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
              Text(l.forgotBody, style: Theme.of(context).textTheme.bodySmall),
              FieldLabel(l.email),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'nama@email.com')),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  try {
                    await ref.read(authRepositoryProvider).resetPassword(_email.text);
                  } catch (_) {/* pesan tetap umum agar tidak membocorkan email terdaftar */}
                  if (!context.mounted) return;
                  toast(context, l.linkSent);
                  context.pop();
                },
                child: Text(l.sendLink),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
