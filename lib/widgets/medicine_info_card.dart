import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../l10n/strings.dart';
import '../theme/app_colors.dart';
import 'voice_bar.dart';

class MedicineInfoCard extends StatelessWidget {
  final Medicine medicine;
  final String lang;

  const MedicineInfoCard({
    super.key,
    required this.medicine,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final isUrdu = lang == 'ur';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.card,
      ),
      child: Directionality(
        textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            VoiceBar(
              textToSpeak: medicine.speakableSummary(lang),
              category: medicine.category,
              genericNameHint: medicine.genericName,
              lang: lang,
            ),
            const SizedBox(height: 18),
            Text(
              medicine.brandName,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.deepTeal,
                fontFamily: isUrdu ? 'NotoNastaliqUrdu' : null,
              ),
            ),
            Text(
              medicine.genericName,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 18),
            _Section(
              label: Strings.of('purpose', lang),
              icon: Icons.healing,
              text: medicine.purpose(lang),
              isUrdu: isUrdu,
            ),
            _Section(
              label: Strings.of('dosage', lang),
              icon: Icons.schedule,
              text: medicine.dosage(lang),
              isUrdu: isUrdu,
            ),
            _Section(
              label: Strings.of('precaution', lang),
              icon: Icons.warning_amber,
              text: medicine.precaution(lang),
              isUrdu: isUrdu,
            ),
            const SizedBox(height: 4),
            if (medicine.isGuess) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.guessBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.guessBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: AppColors.guessText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        Strings.of('guess_notice', lang),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.guessText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warnBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.warnText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      Strings.of('disclaimer', lang),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.warnText,
                      ),
                    ),
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

class _Section extends StatelessWidget {
  final String label;
  final IconData icon;
  final String text;
  final bool isUrdu;

  const _Section({
    required this.label,
    required this.icon,
    required this.text,
    required this.isUrdu,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppColors.mintChip,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppColors.primaryTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepTeal,
                    fontFamily: isUrdu ? 'NotoNastaliqUrdu' : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textDark,
                    fontFamily: isUrdu ? 'NotoNastaliqUrdu' : null,
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
