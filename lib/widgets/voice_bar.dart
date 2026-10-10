import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../l10n/strings.dart';
import '../theme/app_colors.dart';

/// The teal "play button + waveform + voice not installed" bar from the
/// mockup. Tapping play calls [TtsService.speak] on [textToSpeak]; if the
/// requested language's voice isn't on the device, we still speak (falling
/// back to English) but show the "voice not installed" label so the user
/// understands why it doesn't sound like Urdu.
class VoiceBar extends StatefulWidget {
  final String textToSpeak;
  final String category; // shown as the pill label, e.g. "Fever & Pain"
  final String
      genericNameHint; // shown as the quoted subtitle, e.g. "paracetamol"
  final String lang;

  const VoiceBar({
    super.key,
    required this.textToSpeak,
    required this.category,
    required this.genericNameHint,
    required this.lang,
  });

  @override
  State<VoiceBar> createState() => _VoiceBarState();
}

class _VoiceBarState extends State<VoiceBar> {
  final _tts = TtsService();
  bool _isPlaying = false;
  bool? _voiceInstalled;

  @override
  void initState() {
    super.initState();
    _tts.onCompletion(() => setState(() => _isPlaying = false));
    if (widget.lang == 'ur') {
      _tts.isUrduAvailable().then((v) => setState(() => _voiceInstalled = v));
    }
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _tts.stop();
      setState(() => _isPlaying = false);
      return;
    }
    setState(() => _isPlaying = true);
    await _tts.speak(widget.textToSpeak, lang: widget.lang);
  }

  @override
  Widget build(BuildContext context) {
    final showNotInstalled = widget.lang == 'ur' && _voiceInstalled == false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppColors.primaryButtonGradient,
                borderRadius: BorderRadius.circular(AppRadii.chip),
              ),
              child: Text(widget.category,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            Text('"${widget.genericNameHint}"',
                style: const TextStyle(
                    color: AppColors.textMuted, fontStyle: FontStyle.italic)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.mintChip,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: _togglePlay,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryButtonGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Waveform(active: _isPlaying),
              ),
              const SizedBox(width: 8),
              if (showNotInstalled)
                Row(
                  children: [
                    const Icon(Icons.mic, size: 16, color: AppColors.listening),
                    const SizedBox(width: 4),
                    Text(Strings.of('voice_not_installed', widget.lang),
                        style: const TextStyle(
                            color: AppColors.listening, fontSize: 12)),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}

/// A purely decorative static waveform, matching the mockup. Bars pulse
/// while [active] is true.
class _Waveform extends StatelessWidget {
  final bool active;
  const _Waveform({required this.active});

  @override
  Widget build(BuildContext context) {
    final heights = [6, 14, 10, 18, 8, 16, 12, 20, 9, 15, 7, 17, 11, 19, 8, 13];
    return SizedBox(
      height: 22,
      child: Row(
        children: heights
            .map((h) => Container(
                  width: 3,
                  height: active ? h.toDouble() : (h * 0.6),
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryTeal
                        : AppColors.primaryTeal.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
