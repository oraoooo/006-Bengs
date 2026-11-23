import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import 'auth_gate.dart';
import 'onboarding_screen.dart';

/// Figma `bengs_Design` Splash Screen (`79:6437`): full-bleed brand blue,
/// 66px logo mark slightly above center, ExtraBold 46pt "BENGS" from the
/// vertical midpoint. Cold-start only — then [AuthGate] (welcome / session).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const Duration displayDuration = Duration(milliseconds: 1800);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  var _didLeave = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashScreen.displayDuration, _leave);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_didLeave || !mounted) return;
    _didLeave = true;
    _timer?.cancel();
    final seenOnboarding = await OnboardingScreen.hasSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            seenOnboarding ? const AuthGate() : const OnboardingScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.primaryBlue,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _leave,
        child: Scaffold(
          backgroundColor: AppColors.primaryBlue,
          body: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                // Figma: logo 66×66, center at 50% − 50px.
                top: size.height / 2 - 50 - 33,
                child: Center(
                  child: Image.asset(
                    'assets/images/bengs_logo_mark.png',
                    width: 66,
                    height: 66,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              Positioned(
                left: size.width * 0.0945,
                right: size.width * 0.092,
                top: size.height / 2,
                child: const Text(
                  'BENGS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
