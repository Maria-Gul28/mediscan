class Medicine {
  final bool identified;
  final String brandName;
  final String genericName;
  final String category;
  final String purposeEn;
  final String purposeUr;
  final String dosageEn;
  final String dosageUr;
  final String precautionEn;
  final String precautionUr;

  Medicine({
    required this.identified,
    required this.brandName,
    required this.genericName,
    required this.category,
    required this.purposeEn,
    required this.purposeUr,
    required this.dosageEn,
    required this.dosageUr,
    required this.precautionEn,
    required this.precautionUr,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      identified: json['identified'] as bool? ?? true,
      brandName: json['brand_name'] as String? ?? 'Unknown',
      genericName: json['generic_name'] as String? ?? '',
      category: json['category'] as String? ?? 'Other',
      purposeEn: json['purpose']?['en'] as String? ?? '',
      purposeUr: json['purpose']?['ur'] as String? ?? '',
      dosageEn: json['dosage']?['en'] as String? ?? '',
      dosageUr: json['dosage']?['ur'] as String? ?? '',
      precautionEn: json['precaution']?['en'] as String? ?? '',
      precautionUr: json['precaution']?['ur'] as String? ?? '',
    );
  }

  /// Sent back to the /api/chat endpoint so the AI has context on what's
  /// currently on screen - there's no database to look this up from anymore.
  Map<String, dynamic> toJson() => {
        'brand_name': brandName,
        'generic_name': genericName,
        'category': category,
        'purpose': {'en': purposeEn, 'ur': purposeUr},
        'dosage': {'en': dosageEn, 'ur': dosageUr},
        'precaution': {'en': precautionEn, 'ur': precautionUr},
      };

  String purpose(String lang) => lang == 'ur' ? purposeUr : purposeEn;
  String dosage(String lang) => lang == 'ur' ? dosageUr : dosageEn;
  String precaution(String lang) => lang == 'ur' ? precautionUr : precautionEn;

  bool get isGuess => brandName.startsWith('Possibly:');

  String speakableSummary(String lang) {
    if (lang == 'ur') {
      return '$brandName۔ $purposeUr۔ خوراک: $dosageUr۔ احتیاط: $precautionUr';
    }
    return '$brandName. $purposeEn. Dosage: $dosageEn. Precaution: $precautionEn';
  }
}
