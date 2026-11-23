import 'package:flutter/material.dart';

import 'screens/auth/splash_screen.dart';
import 'services/supabase_service.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const BengsApp());
}

class BengsApp extends StatelessWidget {
  const BengsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BENGS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primaryBlue,
        scaffoldBackgroundColor: Colors.white,
        // TODO: bundle the actual brand font (looks like a rounded
        // geometric sans in the Figma file) once confirmed with design.
      ),
      home: const SplashScreen(),
    );
  }
}
