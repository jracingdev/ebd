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
    preferredVoiceName: repo.prefs.ttsVoiceName ?? TtsVoiceProfiles.female,
  );
  await tts.refreshVoices();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.cream,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModal) {
          final prefs = context.watch<BibleRepository>().prefs;
          final profiles = tts.selectableProfiles;
          final selectedId = _resolveSelectedProfileId(
            prefs.ttsVoiceName,
            profiles,
          );

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
                  'Escolha um perfil pelo nome. A qualidade depende das vozes '
                  'instaladas no aparelho (Google Text-to-Speech / Siri). '
                  'Perfis “neural” soam mais naturais.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
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
                  'Perfil de voz',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedId,
                      isExpanded: true,
                      itemHeight: 56,
                      hint: const Text('Feminina (recomendada)'),
                      items: [
                        for (final p in profiles)
                          DropdownMenuItem<String>(
                            value: p.name,
                            child: _VoiceProfileTile(profile: p),
                          ),
                      ],
                      onChanged: (id) async {
                        if (id == null) return;
                        await repo.setTtsVoiceName(id);
                        await tts.configure(preferredVoiceName: id);
                        setModal(() {});
                      },
                    ),
                  ),
                ),
                if (tts.availableVoices.isEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Nenhuma voz pt-BR listada. No Android, instale ou baixe '
                    'vozes em Configurações → Sistema → Idioma → '
                    'Saída de texto para voz (Google). No iPhone, em '
                    'Acessibilidade → Conteúdo falado → Vozes.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  const Text(
                    '“Feminina” e “Masculina” escolhem automaticamente a melhor '
                    'voz pt-BR de cada grupo. Você também pode escolher um '
                    'perfil pelo nome.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.35,
                    ),
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

String _resolveSelectedProfileId(
  String? stored,
  List<TtsVoiceOption> profiles,
) {
  final id = (stored == null || stored.isEmpty)
      ? TtsVoiceProfiles.female
      : stored;
  if (profiles.any((p) => p.name == id)) return id;
  // Preferência antiga (só nome técnico) ou voz removida → feminina.
  return profiles.any((p) => p.name == TtsVoiceProfiles.female)
      ? TtsVoiceProfiles.female
      : (profiles.isNotEmpty ? profiles.first.name : TtsVoiceProfiles.female);
}

class _VoiceProfileTile extends StatelessWidget {
  const _VoiceProfileTile({required this.profile});

  final TtsVoiceOption profile;

  @override
  Widget build(BuildContext context) {
    final sub = profile.isGroupProfile
        ? (profile.qualityHint ?? profile.genderLabel)
        : profile.technicalSubtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          profile.profileName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        if (sub != null && sub.isNotEmpty)
          Text(
            sub,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.muted,
              height: 1.2,
            ),
          ),
      ],
    );
  }
}
