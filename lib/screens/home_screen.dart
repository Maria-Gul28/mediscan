import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ask_ai_fab.dart';
import '../widgets/medicine_info_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  final _api = ApiService();
  final _stt = SttService();
  final _tts = TtsService();

  File? _selectedImage;
  bool _isListening = false;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() => _selectedImage = File(picked.path));
    if (!mounted) return;
    context.read<AppState>().setMedicine(null);
  }

  Future<void> _identifyFromImage() async {
    if (_selectedImage == null) return;
    final appState = context.read<AppState>();
    appState.setLoading(true);
    appState.setError(null);

    try {
      final medicine = await _api.identifyImage(_selectedImage!);
      if (!mounted) return;
      appState.setMedicine(medicine);
      appState.setLoading(false);
      // Speak the same full summary shown in the medicine card.
      await _tts.speak(medicine.speakableSummary(appState.language),
          lang: appState.language);
    } catch (e) {
      if (!mounted) return;
      appState.setError('Something went wrong: $e');
    } finally {
      if (mounted) appState.setLoading(false);
    }
  }

  bool _voicePressActive = false;
  Future<bool>? _voiceStartFuture;

  Future<void> _startVoiceInput() async {
    if (_voicePressActive || context.read<AppState>().isLoading) return;
    final appState = context.read<AppState>();
    _voicePressActive = true;
    appState.setError(null);
    setState(() => _isListening = true);

    // Speech starts on press-down. Keep the Future so a very quick release
    // waits for initialization before stopping the microphone.
    _voiceStartFuture = _stt.startListening(urdu: appState.language == 'ur');
    bool started;
    try {
      started = await _voiceStartFuture!;
    } catch (e) {
      started = false;
      if (mounted) appState.setError('Could not start microphone: $e');
    }

    if (!mounted) return;
    if (!started) {
      _voicePressActive = false;
      _voiceStartFuture = null;
      setState(() => _isListening = false);
      appState.setError(
        'Speech recognition is unavailable. Check microphone permission and your phone speech-recognition settings.',
      );
    }
  }

  Future<void> _stopVoiceInput() async {
    if (!_voicePressActive && !_isListening) return;
    // Release immediately marks the gesture inactive, then waits for speech
    // service initialization if the user released quickly.
    _voicePressActive = false;
    final startFuture = _voiceStartFuture;
    if (startFuture != null) {
      try {
        await startFuture;
      } catch (_) {
        // Start errors are shown by _startVoiceInput.
      }
    }
    if (!mounted) return;
    setState(() => _isListening = false);

    final name = await _stt.stopListening();
    _voiceStartFuture = null;
    if (!mounted) return;

    if (name.isEmpty) {
      final speechError = _stt.lastError;
      appStateError(
          'No speech detected. Press and hold the microphone while saying a medicine name${speechError == null ? '.' : ' (speech recognition: $speechError).'}');
      return;
    }

    final appState = context.read<AppState>();
    appState.setLoading(true);
    appState.setError(null);
    try {
      final medicine = await _api.identifyByName(name);
      if (!mounted) return;
      appState.setMedicine(medicine);
      appState.setLoading(false);
      // Voice and picture identification now give the same spoken summary.
      await _tts.speak(medicine.speakableSummary(appState.language),
          lang: appState.language);
    } catch (e) {
      if (!mounted) return;
      appState.setError('Medicine identification failed: $e');
    } finally {
      if (mounted) appState.setLoading(false);
    }
  }

  void appStateError(String message) {
    if (!mounted) return;
    context.read<AppState>().setError(message);
  }

  @override
  void dispose() {
    _stt.stopListening();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final lang = appState.language;
    final isUrdu = lang == 'ur';
    final medicine = appState.currentMedicine;

    return Scaffold(
      backgroundColor: AppColors.mintBg,
      floatingActionButton: AskAiFab(lang: lang, medicine: medicine),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(lang, isUrdu)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildScanCard(lang, isUrdu),
                  const SizedBox(height: 16),
                  if (appState.isLoading) _LoadingNotice(lang: lang),
                  if (appState.errorMessage != null)
                    _ErrorBanner(message: appState.errorMessage!),
                  if (medicine != null && !medicine.identified)
                    _NotIdentifiedCard(medicine: medicine, lang: lang),
                  if (medicine != null && medicine.identified)
                    MedicineInfoCard(medicine: medicine, lang: lang),
                  const SizedBox(height: 90),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String lang, bool isUrdu) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadii.headerBottom),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.medication_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Strings.of('app_title', lang),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    Text(Strings.of('app_tagline', lang),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _LanguageToggle(current: lang),
        ],
      ),
    );
  }

  Widget _buildScanCard(String lang, bool isUrdu) {
    return Container(
      padding: const EdgeInsets.all(18),
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
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.mintChip,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_scanner,
                      color: AppColors.primaryTeal, size: 18),
                ),
                const SizedBox(width: 10),
                Text(Strings.of('scan_heading', lang),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textDark)),
              ],
            ),
            const SizedBox(height: 4),
            Text(Strings.of('scan_subheading', lang),
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 14),
            AspectRatio(
              aspectRatio: 1.4,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.mintBg,
                  borderRadius: BorderRadius.circular(AppRadii.preview),
                  border: Border.all(color: AppColors.border),
                ),
                child: _selectedImage == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_a_photo_outlined,
                                color: AppColors.textMuted, size: 32),
                            const SizedBox(height: 8),
                            Text(Strings.of('preview_placeholder', lang),
                                style: const TextStyle(
                                    color: AppColors.textMuted)),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.preview),
                        child: Image.file(_selectedImage!,
                            fit: BoxFit.cover, width: double.infinity),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.deepTeal,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(Strings.of('gallery', lang)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.deepTeal,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text(Strings.of('camera', lang)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryButtonGradient,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                boxShadow: _selectedImage == null ? null : AppShadows.button,
              ),
              child: ElevatedButton.icon(
                onPressed: _selectedImage == null ? null : _identifyFromImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
                icon: Icon(Icons.search,
                    color:
                        _selectedImage == null ? Colors.white70 : Colors.white),
                label: Text(Strings.of('identify_medicine', lang),
                    style: TextStyle(
                        color: _selectedImage == null
                            ? Colors.white70
                            : Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(Strings.of('or_say_name', lang),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ),
                Expanded(child: Divider(color: AppColors.border)),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _startVoiceInput(),
              onTapUp: (_) => _stopVoiceInput(),
              onTapCancel: _stopVoiceInput,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isListening ? AppColors.errorBg : AppColors.mintChip,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(
                      color: _isListening
                          ? AppColors.listening.withValues(alpha: 0.35)
                          : AppColors.primaryTeal.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening
                            ? AppColors.listening
                            : AppColors.primaryTeal),
                    const SizedBox(width: 8),
                    Text(
                      _isListening
                          ? Strings.of('listening', lang)
                          : Strings.of('tap_to_speak', lang),
                      style: TextStyle(
                        color: _isListening
                            ? AppColors.listening
                            : AppColors.deepTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingNotice extends StatelessWidget {
  final String lang;
  const _LoadingNotice({required this.lang});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.card - 2),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppColors.primaryTeal)),
          const SizedBox(width: 14),
          Expanded(
              child: Text(Strings.of('identifying', lang),
                  style: const TextStyle(color: AppColors.textDark))),
        ],
      ),
    );
  }
}

class _NotIdentifiedCard extends StatelessWidget {
  final dynamic medicine;
  final String lang;
  const _NotIdentifiedCard({required this.medicine, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.card - 2),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(medicine.purpose(lang),
              style: const TextStyle(fontSize: 15, color: AppColors.textDark)),
        ],
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final String current;
  const _LanguageToggle({required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _tab(context, 'English', 'en'),
          _tab(context, 'اردو', 'ur'),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, String label, String code) {
    final selected = current == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => context.read<AppState>().setLanguage(code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? AppColors.deepTeal : Colors.white,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.errorText)),
    );
  }
}
