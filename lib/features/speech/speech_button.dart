import 'package:flutter/material.dart';

import '../../shared/models/money_entry.dart';
import '../../shared/theme/app_theme.dart';

class SpeechButton extends StatelessWidget {
  const SpeechButton({
    super.key,
    required this.mode,
    required this.isListening,
    required this.isSaving,
    required this.onMicTap,
    required this.onMicLongPress,
    this.transcript,
    this.status,
    this.errorMessage,
  });

  final VoiceMode mode;
  final bool isListening;
  final bool isSaving;
  final VoidCallback onMicTap;
  final VoidCallback onMicLongPress;
  final String? transcript;
  final String? status;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      color: colors.hero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          children: [
            GestureDetector(
              onTap: isSaving ? null : onMicTap,
              onLongPress: isSaving ? null : onMicLongPress,
              child: SizedBox.square(
                dimension: 142,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isListening ? colors.expense : primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 66,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF06201D)
                        : Colors.white,
                  ),
                ),
              ),
            ),
            if (status != null && status!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                status!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.muted,
                      height: 1.25,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (transcript != null && transcript!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  transcript!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.expense,
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
