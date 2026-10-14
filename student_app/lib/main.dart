import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

bool _isEffectivelyDark() {
  final mode = themeNotifier.value;
  if (mode == ThemeMode.system) {
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }
  return mode == ThemeMode.dark;
}

Future<void> toggleTheme() async {
  themeNotifier.value = _isEffectivelyDark() ? ThemeMode.light : ThemeMode.dark;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', themeNotifier.value.name);
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode');
    if (saved == 'light') themeNotifier.value = ThemeMode.light;
    if (saved == 'dark') themeNotifier.value = ThemeMode.dark;
  } catch (_) {}

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gubaorkjjqiclrnahjdt.supabase.co',
  );
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd1YmFvcmtqanFpY2xybmFoamR0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwMTcyMTAsImV4cCI6MjEwNTU5MzIxMH0.mUwrnY4YlQN0pMwZjFC0cObDeh6htvobhlkLg8UmMTU',
  );

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MedNerdApp());
}

final supabase = Supabase.instance.client;

class MedNerdApp extends StatelessWidget {
  const MedNerdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'MedNerd Academy',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF3EFE6),
            primaryColor: const Color(0xFF0E332E),
            cardColor: const Color(0xFF0E332E),
            textTheme: GoogleFonts.cairoTextTheme(ThemeData.light().textTheme),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0E332E),
              secondary: Color(0xFFD8B467),
              surface: Color(0xFFF3EFE6),
              onSurface: Color(0xFF0E332E),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0B0F17),
            primaryColor: const Color(0xFF151E2E),
            cardColor: const Color(0xFF151E2E),
            textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF151E2E),
              secondary: Color(0xFFD8B467),
              surface: Color(0xFF151E2E),
              onSurface: Colors.white,
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.7, end: 1.05)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 60),
      TweenSequenceItem(
          tween: Tween(begin: 1.05, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 40),
    ]).animate(_controller);

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1.0, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
    ));

    _controller.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    final session = supabase.auth.currentSession;
    final Widget targetScreen =
        session != null ? const HomeScreen() : const AuthScreen();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => targetScreen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color splashBg = Color(0xFF0B0F17);
    const Color logoBoxBg = Color(0xFF151E2E);
    const Color goldBorder = Color(0xFFC5A059);
    const Color goldAccent = Color(0xFFD8B467);

    return Scaffold(
      backgroundColor: splashBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    goldBorder.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 110,
                    height: 110,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: logoBoxBg,
                      border: Border.all(
                        color: goldBorder,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: goldBorder.withOpacity(0.25),
                          blurRadius: 35,
                          spreadRadius: 2,
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
                ),
                const SizedBox(height: 32),
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: GoogleFonts.cairo(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Colors.white,
                            ),
                            children: const [
                              TextSpan(text: 'MED'),
                              TextSpan(
                                text: 'NERD',
                                style: TextStyle(color: goldAccent),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'بوابتك الأكاديمية للمحاضرات التفاعلية',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 56),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SizedBox(
                    width: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: logoBoxBg,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(goldAccent),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
