import 'package:flutter/material.dart';

/// Brand colors sampled directly from the BENGS Figma file (300dpi color
/// picker on the "Add A Beng" screen, 19 Aug 2026). Keep this file as the
/// single source of truth — never hardcode these hex values elsewhere.
class AppColors {
  AppColors._();

  static const Color primaryBlue = Color(0xFF1D5BFE);
  static const Color iconBlue = Color(0xFF153DB9);
  // CLAUDE.md documents two amber readings (#E0A800/#FAC829); re-sampling
  // the logo mark directly from bengs01.pdf on 2026-09-02 gave #FFC727 —
  // clearly the lighter one, not the darker #E0A800 this used to be.
  static const Color amber = Color(0xFFFAC829);
  static const Color amberDark = Color(0xFFE0A800);
  static const Color mapPinRed = Color(0xFFFF383D);
  static const Color navyText = Color(0xFF0F1330);
  static const Color sheetLavender = Color(0xFFE7ECFF);
  static const Color mapBackground = Color(0xFFEFEEEC);
  static const Color cardWhite = Colors.white;
  static const Color mutedText = Color(0xFF999999);
  static const Color hairline = Color(0xFFEEEEEE);
  static const Color paper = Color(0xFFF4F6FB);
  static const Color fieldHint = Color(0xFF79767D);
}
