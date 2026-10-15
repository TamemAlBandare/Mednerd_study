import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main.dart';
import 'backend_errors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        final subs = await Supabase.instance.client
            .from('student_subscriptions')
            .select('hardware_fingerprint, status, subjects(name)')
            .eq('user_id', user.id);

        if (mounted) {
          setState(() {
            _profileData = profile;
            _subscriptions = List<Map<String, dynamic>>.from(subs);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark
        ? const Color(0xFF0B0F17)
        : const Color(0xFFF3EFE6);
    final cardBg = isDark ? const Color(0xFF151E2E) : const Color(0xFF0E332E);
    final innerBg = isDark ? const Color(0xFF101724) : const Color(0xFF08221E);
    const border = Color(0xFFC5A059);
    const goldAccent = Color(0xFFD8B467);

    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata ?? {};
    final name =
        _profileData?['full_name'] ??
        meta['full_name'] ??
        user?.email?.split('@').first ??
        'طالب الأكاديمية';
    final email = user?.email ?? '-';
    final university =
        (_profileData?['university_name'] ?? meta['university_name'] ?? '')
            .toString()
            .trim();
    final phone = (_profileData?['phone'] ?? meta['phone'] ?? '')
        .toString()
        .trim();

    final bool isDeviceLinked =
        _subscriptions.isNotEmpty &&
        _subscriptions.any(
          (s) =>
              s['hardware_fingerprint'] != null &&
              s['hardware_fingerprint'].toString().trim().isNotEmpty,
        );

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        shape: Border(
          bottom: BorderSide(color: border.withOpacity(0.35), width: 1),
        ),
        title: const Text(
          'الملف الشخصي',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: goldAccent,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'الوضع النهاري' : 'الوضع الليلي',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: goldAccent,
              size: 20,
            ),
            onPressed: toggleTheme,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: goldAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: border.withOpacity(0.7),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: innerBg,
                            border: Border.all(color: border, width: 1.8),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person_rounded,
                                color: goldAccent,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          name.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 12.5,
                          ),
                        ),
                        if (university.isNotEmpty || phone.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Divider(color: border.withOpacity(0.25), height: 1),
                          const SizedBox(height: 14),
                          if (university.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.account_balance_outlined,
                                  color: goldAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    university,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (university.isNotEmpty && phone.isNotEmpty)
                            const SizedBox(height: 8),
                          if (phone.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  color: goldAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  phone,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: border.withOpacity(0.6),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'حالة أمان الجهاز',
                          style: TextStyle(
                            color: goldAccent,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: innerBg,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDeviceLinked
                                      ? const Color(0xFF10B981)
                                      : border.withOpacity(0.5),
                                ),
                              ),
                              child: Icon(
                                isDeviceLinked
                                    ? Icons.verified_user_rounded
                                    : Icons.phonelink_lock_rounded,
                                color: isDeviceLinked
                                    ? const Color(0xFF10B981)
                                    : goldAccent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isDeviceLinked
                                    ? 'الجهاز موثق ومقترن بالحساب بنجاح'
                                    : 'جاهز للاقتران عند تفعيل أول مقرر',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
