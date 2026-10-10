/// Small hand-rolled string table. Deliberately avoids the word "AI"
/// anywhere in user-facing text - identification and chat are presented as
/// features of the app itself, not as AI-branded functionality.
class Strings {
  static const Map<String, Map<String, String>> _t = {
    'app_title': {'en': 'MediScan', 'ur': 'میڈی سکین'},
    'app_tagline': {
      'en': 'Scan • Understand • Listen',
      'ur': 'اسکین • سمجھیں • سنیں'
    },
    'scan_heading': {
      'en': 'Scan a medicine pack',
      'ur': 'دوا کی تصویر اسکین کریں'
    },
    'scan_subheading': {
      'en': 'Photograph the medicine so the printed name is clear.',
      'ur': 'دوا کی تصویر لیں تاکہ نام واضح نظر آئے۔',
    },
    'preview_placeholder': {
      'en': 'Preview appears here',
      'ur': 'تصویر یہاں نظر آئے گی'
    },
    'gallery': {'en': 'Gallery', 'ur': 'گیلری'},
    'camera': {'en': 'Camera', 'ur': 'کیمرہ'},
    'identify_medicine': {'en': 'Identify Medicine', 'ur': 'دوا پہچانیں'},
    'or_say_name': {'en': 'or say the name', 'ur': 'یا نام بولیں'},
    'listening': {'en': 'Listening...', 'ur': 'سن رہا ہے...'},
    'tap_to_speak': {
      'en': 'Tap to speak the medicine name',
      'ur': 'دوا کا نام بولنے کے لیے دبائیں'
    },
    'purpose': {'en': 'Purpose', 'ur': 'استعمال'},
    'dosage': {'en': 'Dosage', 'ur': 'مقدارِ خوراک'},
    'precaution': {'en': 'Precaution', 'ur': 'احتیاط'},
    'disclaimer': {
      'en':
          'This information is for general guidance only. Always confirm with a doctor or pharmacist before using any medicine.',
      'ur':
          'یہ معلومات صرف رہنمائی کے لیے ہیں۔ دوا استعمال کرنے سے پہلے ڈاکٹر یا فارماسسٹ سے مشورہ کریں۔',
    },
    'ask_ai': {'en': 'Ask', 'ur': 'پوچھیں'},
    'guess_notice': {
      'en':
          'This is an educated guess and hasn\'t been fully confirmed. Please double-check with a pharmacist.',
      'ur':
          'یہ ایک اندازہ ہے اور مکمل طور پر تصدیق شدہ نہیں ہے۔ براہ کرم فارماسسٹ سے تصدیق کریں۔',
    },
    'identifying': {
      'en': 'Identifying the medicine - this can take a few seconds...',
      'ur': 'دوا کی شناخت ہو رہی ہے...'
    },
    'voice_not_installed': {
      'en': 'voice not installed',
      'ur': 'آواز انسٹال نہیں'
    },
  };

  static String of(String key, String lang) =>
      _t[key]?[lang] ?? _t[key]?['en'] ?? key;
}
