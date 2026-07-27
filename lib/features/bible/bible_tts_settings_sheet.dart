import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/services/bible_repository.dart';
import 'package:livro_registro/services/bible_tts_service.dart';
import 'package:livro_registro/theme/app_theme.dart';

/// Bottom sheet: velocidade + voz TTS (persistido em [BiblePrefs]).
Future<void> showBibleTtsSettingsSheet(
  BuildContext context, {
  required BibleTtsService tts,
}) async {
  final repo = context.read<BibleRepository>();
  await tts.configure(
    speechRate: repo.prefs.ttsSpeechRate,
    preferredVoiceName: repo.prefs.ttsVoiceName,
  );
  final voices = await tts.refreshVoices();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.cream,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModal) {
          final prefs = context.watch<BibleRepository>().prefs;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              28 + MediaQuery.paddingOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Leitura em voz alta',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text(
                  'A qualidade depende das vozes instaladas no aparelho '
                  '(Google Text-to-Speech / Siri). Vozes “neural” soam mais naturais.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 16),
                Text(
                  'Velocidade (${prefs.ttsSpeechRate.toStringAsFixed(2)})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: prefs.ttsSpeechRate.clamp(0.2, 0.75),
                  min: 0.2,
                  max: 0.75,
                  divisions: 11,
                  label: prefs.ttsSpeechRate.toStringAsFixed(2),
                  activeColor: AppColors.green,
                  onChanged: (v) async {
                    await repo.setTtsSpeechRate(v);
                    await tts.configure(speechRate: v);
                    setModal(() {});
                  },
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await repo.setTtsSpeechRate(0.35);
                        await tts.configure(speechRate: 0.35);
                        setModal(() {});
                      },
                      child: const Text('Devagar'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await repo.setTtsSpeechRate(0.42);
                        await tts.configure(speechRate: 0.42);
                        setModal(() {});
                      },
                      child: const Text('Natural'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await repo.setTtsSpeechRate(0.55);
                        await tts.configure(speechRate: 0.55);
                        setModal(() {});
                      },
                      child: const Text('Rápido'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Voz',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: prefs.ttsVoiceName != null &&
                              voices.any((v) => v.name == prefs.ttsVoiceName)
                          ? prefs.ttsVoiceName
                          : null,
                      isExpanded: true,
                      hint: const Text('Automática (melhor pt-BR)'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Automática (melhor pt-BR)'),
                        ),
                        for (final v in voices)
                          DropdownMenuItem<String?>(
                            value: v.name,
                            child: Text(
                              v.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (name) async {
                        await repo.setTtsVoiceName(name);
                        await tts.configure(preferredVoiceName: name ?? '');
                        setModal(() {});
                      },
                    ),
                  ),
                ),
                if (voices.isEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Nenhuma voz pt-BR listada. No Android, instale ou baixe '
                    'vozes em Configurações → Sistema → Idioma → '
                    'Saída de texto para voz (Google). No iPhone, em '
                    'Acessibilidade → Conteúdo falado → Vozes.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}
