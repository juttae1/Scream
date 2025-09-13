import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/user_profile.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/ui/home/home_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  final _auth = AuthService();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final user = UserProfile(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      pin: _pinCtrl.text.trim(),
    );
    await _auth.signUp(user);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('간편 회원가입',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 24),
                _LabeledField(
                  label: '이름',
                  child: TextFormField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontSize: 20),
                    decoration: const InputDecoration(hintText: '이름을 입력하세요'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력하세요' : null,
                  ),
                ),
                const SizedBox(height: 16),
                _LabeledField(
                  label: '연락처',
                  child: TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontSize: 20),
                    decoration: const InputDecoration(hintText: '010-1234-5678'),
                    validator: (v) => (v == null || v.trim().length < 10) ? '연락처를 확인하세요' : null,
                  ),
                ),
                const SizedBox(height: 16),
                _LabeledField(
                  label: '간편 PIN(4자리)',
                  child: TextFormField(
                    controller: _pinCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    style: const TextStyle(fontSize: 20, letterSpacing: 6),
                    decoration: const InputDecoration(counterText: '', hintText: '****'),
                    validator: (v) => (v == null || v.length != 4) ? '4자리 PIN을 입력하세요' : null,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2FA24A),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                          )
                        : const Text('회원가입 완료'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
