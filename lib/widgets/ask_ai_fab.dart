import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../models/medicine.dart';
import '../screens/chat_screen.dart';
import '../theme/app_colors.dart';

class AskAiFab extends StatelessWidget {
  final String lang;
  final Medicine? medicine;

  const AskAiFab({super.key, required this.lang, this.medicine});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryButtonGradient,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: AppShadows.button,
      ),
      child: FloatingActionButton.extended(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        icon:
            const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
        label: Text(Strings.of('ask_ai', lang),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ChatScreen(lang: lang, medicine: medicine)),
          );
        },
      ),
    );
  }
}
