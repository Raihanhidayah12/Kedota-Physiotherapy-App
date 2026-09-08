import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_language.dart';
import '../../services/notification_service.dart';
import '../home/main_screen.dart';

class AccountCreatedScreen extends StatefulWidget {
  const AccountCreatedScreen({super.key});

  @override
  State<AccountCreatedScreen> createState() => _AccountCreatedScreenState();
}

class _AccountCreatedScreenState extends State<AccountCreatedScreen>
    with SingleTickerProviderStateMixin {
  int _countdown = 3;
  Timer? _timer;
  late final AnimationController _iconController;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconFade;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _iconScale = CurvedAnimation(
      parent: _iconController,
      curve: Curves.elasticOut,
    );
    _iconFade = CurvedAnimation(
      parent: _iconController,
      curve: const Interval(0, 0.45, curve: Curves.easeOut),
    );
    _iconController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendWelcomeNotification();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        _goToHome();
      }
    });
  }

  Future<void> _sendWelcomeNotification() async {
    final title = t(context, 'welcomeNotificationTitle');
    final body = t(context, 'welcomeNotificationBody');
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('welcome_notification_sent') ?? false) return;
    await NotificationService().showNotification(
      id: 200,
      title: title,
      body: body,
      payload: 'welcome_new_patient_promo',
    );
    await prefs.setBool('welcome_notification_sent', true);
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = t(
      context,
      'accountCreatedCountdown',
    ).replaceFirst('%s', '$_countdown');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _iconFade,
                  child: ScaleTransition(
                    scale: _iconScale,
                    child: _buildSuccessIcon(),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  t(context, 'accountCreatedTitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00A79D),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF5F686A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon() => Container(
    width: 120,
    height: 120,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0xFFE5F4F0),
    ),
    padding: const EdgeInsets.all(10),
    child: Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFBDE8D9),
      ),
      padding: const EdgeInsets.all(9),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF43B67E),
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 58),
      ),
    ),
  );
}
