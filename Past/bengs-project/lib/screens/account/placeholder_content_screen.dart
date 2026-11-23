import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Privacy Policy and Help Center both need real legal/support copy that
/// doesn't exist anywhere in this project yet — this keeps the Account
/// screen's navigation structurally complete (per bengs01.pdf) without
/// fabricating content. Swap the body text out once real copy exists.
class PlaceholderContentScreen extends StatelessWidget {
  const PlaceholderContentScreen({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Colors.white, foregroundColor: AppColors.navyText, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, style: const TextStyle(color: AppColors.mutedText, fontSize: 13, height: 1.5)),
        ),
      ),
    );
  }
}
