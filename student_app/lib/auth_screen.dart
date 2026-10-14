import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'home_screen.dart';
import 'backend_errors.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _universityController = TextEditingController();

  static const Color lightScaffoldBg = Color(0xFFF3EFE6);
  static const Color lightEmeraldDark = Color(0xFF0E332E);
  static const Color lightEmeraldInput = Color(0xFF08221E);
  static const Color lightGoldBorder = Color(0xFFC5A059);

  static const Color darkScaffoldBg = Color(0xFF0B0F17);
  static const Color darkCardBg = Color(0xFF151E2E);
  static const Color darkInputBg = Color(0xFF101724);
  static const Color darkGoldBorder = Color(0xFFC5A059);

  static const Color goldAccent = Color(0xFFD8B467);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _universityController.dispose();
    super.dispose();
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, textDirection: TextDirection.rtl),
        backgroundColor:
            isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      ),
    );
  }

  static bool isStrongPassword(String v) =>
      v.length >= 8 &&
      RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(v) &&
      RegExp(r'\d').hasMatch(v);

  Future<void> _showForgotPasswordDialog() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
      ),
    );

    if (changed == true) {
      _showMessage('تم تغيير كلمة المرور، سجّل الدخول بها');
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final res = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (res.session != null) {
        _showMessage('مرحباً بك مجدداً!');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } on AuthException catch (e) {
      _showMessage(friendlyError(e), isError: true);
    } catch (e) {
      _showMessage(friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final university = _universityController.text.trim();

    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'university_name': university,
        },
      );

      final user = response.user;
      if (user != null) {
        if (response.session == null) {
          _showMessage(
              'تم إنشاء الحساب. تحقق من بريدك الإلكتروني لتأكيده ثم سجّل الدخول.');
          return;
        }

        _showMessage('تم إنشاء الحساب بنجاح!');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } on AuthException catch (e) {
      _showMessage(friendlyError(e), isError: true);
    } catch (e) {
      _showMessage(friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? darkScaffoldBg : lightScaffoldBg;
    final cardBg = isDark ? darkCardBg : lightEmeraldDark;
    final inputBg = isDark ? darkInputBg : lightEmeraldInput;
    final border = isDark ? darkGoldBorder : lightGoldBorder;
    final titleColor = isDark ? Colors.white : lightEmeraldDark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cardBg,
                      border: Border.all(
                        color: border,
                        width: 1.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: border.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'MEDNERD ACADEMY',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isLogin ? 'تسجيل الدخول إلى حسابك' : 'إنشاء حساب طالب جديد',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF5A6E69),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: border, width: 1.3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: _buildAuthForm(inputBg, border, isDark),
                  ),
                  const SizedBox(height: 16),
                  if (_isLogin)
                    TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: const Text(
                        'نسيت كلمة المرور؟',
                        style: TextStyle(color: goldAccent, fontSize: 12.5),
                      ),
                    ),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin
                          ? 'ليس لديك حساب؟ إنشاء حساب جديد'
                          : 'لديك حساب بالفعل؟ تسجيل الدخول',
                      style: const TextStyle(
                        color: goldAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthForm(Color inputBg, Color border, bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (!_isLogin) ...[
            _buildField(
              controller: _fullNameController,
              label: 'الاسم الثلاثي',
              icon: Icons.person_outline,
              inputBg: inputBg,
              border: border,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'يرجى إدخال الاسم' : null,
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _universityController,
              label: 'اسم الجامعة والكلية',
              icon: Icons.account_balance_outlined,
              inputBg: inputBg,
              border: border,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'يرجى تحديد الجامعة' : null,
            ),
            const SizedBox(height: 14),
            _buildField(
              controller: _phoneController,
              label: 'رقم الهاتف',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputBg: inputBg,
              border: border,
              validator: (v) => v == null || v.trim().length < 9
                  ? 'يرجى إدخال رقم هاتف صحيح'
                  : null,
            ),
            const SizedBox(height: 14),
          ],
          _buildField(
            controller: _emailController,
            label: 'البريد الإلكتروني',
            icon: Icons.alternate_email,
            keyboardType: TextInputType.emailAddress,
            inputBg: inputBg,
            border: border,
            validator: (v) =>
                v == null || !v.contains('@') ? 'بريد إلكتروني غير صالح' : null,
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _passwordController,
            label: 'كلمة المرور',
            icon: Icons.lock_outline,
            obscureText: true,
            inputBg: inputBg,
            border: border,
            validator: (v) {
              if (_isLogin) {
                return (v == null || v.isEmpty) ? 'أدخل كلمة المرور' : null;
              }
              return isStrongPassword(v ?? '')
                  ? null
                  : 'كلمة المرور 8 خانات على الأقل وتحتوي حروفاً وأرقاماً';
            },
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (_isLogin ? _handleLogin : _handleSignUp),
              style: ElevatedButton.styleFrom(
                backgroundColor: border,
                foregroundColor:
                    isDark ? const Color(0xFF0B0F17) : lightEmeraldDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color:
                            isDark ? const Color(0xFF0B0F17) : lightEmeraldDark,
                      ),
                    )
                  : Text(
                      _isLogin ? 'تسجيل الدخول' : 'إنشاء الحساب والمتابعة',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color inputBg,
    required Color border,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: goldAccent, size: 20),
        filled: true,
        fillColor: inputBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border.withOpacity(0.4), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border.withOpacity(0.3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;

  const _ForgotPasswordDialog({required this.initialEmail});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailCtrl;
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_codeSent) {
        final email = _emailCtrl.text.trim();
        if (!email.contains('@')) throw 'بريد إلكتروني غير صالح';
        await supabase.auth.resetPasswordForEmail(email);
        if (mounted) {
          setState(() {
            _codeSent = true;
            _busy = false;
          });
        }
      } else {
        final pw = _passCtrl.text;
        if (!_AuthScreenState.isStrongPassword(pw)) {
          throw 'كلمة المرور 8 خانات على الأقل وتحتوي حروفاً وأرقاماً';
        }
        await supabase.auth.verifyOTP(
          type: OtpType.recovery,
          email: _emailCtrl.text.trim(),
          token: _codeCtrl.text.trim(),
        );
        await supabase.auth.updateUser(UserAttributes(password: pw));
        await supabase.auth.signOut();
        if (mounted) Navigator.pop(context, true);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyError(e);
        });
      }
    } on String catch (m) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = m;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'تعذر إكمال العملية، تحقق من الاتصال';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('استعادة كلمة المرور'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailCtrl,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(labelText: 'البريد الإلكتروني'),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'الرمز المرسل إلى بريدك'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'كلمة المرور الجديدة'),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!,
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: Text(_codeSent ? 'تغيير كلمة المرور' : 'إرسال الرمز'),
        ),
      ],
    );
  }
}
