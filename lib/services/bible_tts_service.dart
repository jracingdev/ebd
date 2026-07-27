import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Gênero percebido da voz TTS (motor ou heurística).
enum TtsVoiceGender { female, male, unknown }

/// IDs estáveis de perfil (persistidos em [BiblePrefs.ttsVoiceName]).
abstract final class TtsVoiceProfiles {
  static const female = 'profile:female';
  static const male = 'profile:male';

  static bool isGroupProfile(String? id) =>
      id == female || id == male;
}

/// Opção/perfil de voz do motor TTS do sistema (Android/iOS/Web).
class TtsVoiceOption {
  const TtsVoiceOption({
    required this.name,
    required this.locale,
    required this.gender,
    required this.profileName,
    this.qualityHint,
    this.isGroupProfile = false,
  });

  /// Nome técnico do motor (`getVoices`) ou id de perfil de grupo.
  final String name;
  final String locale;
  final TtsVoiceGender gender;
  /// Nome amigável ex.: "Ana (feminina)".
  final String profileName;
  final String? qualityHint;
  final bool isGroupProfile;

  String get genderLabel => switch (gender) {
        TtsVoiceGender.female => 'feminina',
        TtsVoiceGender.male => 'masculina',
        TtsVoiceGender.unknown => 'voz',
      };

  /// Rótulo principal na UI.
  String get label => profileName;

  /// Subtítulo técnico (só vozes reais do motor).
  String? get technicalSubtitle {
    if (isGroupProfile) return null;
    final short = name.length > 48 ? '${name.substring(0, 46)}…' : name;
    if (qualityHint == null || qualityHint!.isEmpty) return short;
    return '$short · $qualityHint';
  }

  Map<String, String> toEngineMap() => {
        'name': name,
        'locale': locale,
      };
}

/// Leitura em voz alta da Bíblia via motor TTS do SO (`flutter_tts`).
///
/// A naturalidade depende das vozes instaladas no aparelho (Google TTS /
/// Siri / Edge). Este serviço escolhe a melhor pt-BR disponível, calibra
/// rate/pitch e fala versículo a versículo com pausas.
class BibleTtsService {
  BibleTtsService() : _tts = FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;
  bool speaking = false;
  double _speechRate = 0.42;
  /// Perfil persistido: `profile:female` / `profile:male` / nome do motor.
  String? _preferredVoiceName;

  Completer<void>? _utteranceDone;
  bool _cancelled = false;
  List<TtsVoiceOption> _voicesCache = const [];

  List<TtsVoiceOption> get availableVoices => _voicesCache;

  /// Perfis para a UI: grupos Feminina/Masculina + vozes do aparelho.
  List<TtsVoiceOption> get selectableProfiles {
    final voices = _voicesCache;
    if (voices.isEmpty) return const [];

    return [
      const TtsVoiceOption(
        name: TtsVoiceProfiles.female,
        locale: 'pt-BR',
        gender: TtsVoiceGender.female,
        profileName: 'Feminina (recomendada)',
        qualityHint: 'melhor pt-BR do grupo',
        isGroupProfile: true,
      ),
      const TtsVoiceOption(
        name: TtsVoiceProfiles.male,
        locale: 'pt-BR',
        gender: TtsVoiceGender.male,
        profileName: 'Masculina',
        qualityHint: 'melhor pt-BR do grupo',
        isGroupProfile: true,
      ),
      ...voices,
    ];
  }

  double get speechRate => _speechRate;

  Future<void> init({
    double? speechRate,
    String? preferredVoiceName,
  }) async {
    if (speechRate != null) _speechRate = speechRate.clamp(0.2, 0.75);
    if (preferredVoiceName != null) {
      _preferredVoiceName =
          preferredVoiceName.isEmpty ? null : preferredVoiceName;
    }
    if (_ready) {
      await _applyVoiceAndProsody();
      return;
    }

    try {
      await _tts.setSharedInstance(true);
    } catch (_) {}

    await _tts.setLanguage('pt-BR');
    await _tts.setVolume(1.0);
    await _tts.setPitch(0.98);
    await _tts.awaitSpeakCompletion(true);

    try {
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    } catch (_) {}

    _tts.setCompletionHandler(() {
      speaking = false;
      if (_utteranceDone != null && !_utteranceDone!.isCompleted) {
        _utteranceDone!.complete();
      }
    });
    _tts.setCancelHandler(() {
      speaking = false;
      if (_utteranceDone != null && !_utteranceDone!.isCompleted) {
        _utteranceDone!.complete();
      }
    });
    _tts.setErrorHandler((_) {
      speaking = false;
      if (_utteranceDone != null && !_utteranceDone!.isCompleted) {
        _utteranceDone!.complete();
      }
    });

    _voicesCache = await _loadVoices();
    await _applyVoiceAndProsody();
    _ready = true;
  }

  Future<void> configure({
    double? speechRate,
    String? preferredVoiceName,
  }) async {
    await init(
      speechRate: speechRate,
      preferredVoiceName: preferredVoiceName,
    );
  }

  Future<List<TtsVoiceOption>> refreshVoices() async {
    await init();
    _voicesCache = await _loadVoices();
    return _voicesCache;
  }

  Future<void> _applyVoiceAndProsody() async {
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(0.98);
    await _tts.setVolume(1.0);

    final voices = _voicesCache.isEmpty ? await _loadVoices() : _voicesCache;
    if (voices.isEmpty) {
      await _tts.setLanguage('pt-BR');
      return;
    }

    final chosen = resolveVoice(voices, _preferredVoiceName);

    if (chosen != null && !chosen.isGroupProfile) {
      try {
        await _tts.setVoice(chosen.toEngineMap());
      } catch (_) {
        await _tts.setLanguage('pt-BR');
      }
    } else {
      await _tts.setLanguage('pt-BR');
    }
  }

  /// Resolve preferência persistida → voz concreta do motor.
  static TtsVoiceOption? resolveVoice(
    List<TtsVoiceOption> voices,
    String? preferred,
  ) {
    if (voices.isEmpty) return null;

    if (preferred == TtsVoiceProfiles.male) {
      return _pickBestVoice(voices, preferGender: TtsVoiceGender.male);
    }
    if (preferred == TtsVoiceProfiles.female ||
        preferred == null ||
        preferred.isEmpty) {
      return _pickBestVoice(voices, preferGender: TtsVoiceGender.female);
    }

    for (final v in voices) {
      if (v.name == preferred) return v;
    }
    // Preferência antiga/inexistente: cai no default feminino.
    return _pickBestVoice(voices, preferGender: TtsVoiceGender.female);
  }

  Future<List<TtsVoiceOption>> _loadVoices() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return const [];
      final options = <TtsVoiceOption>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final name = '${map['name'] ?? ''}';
        final locale = '${map['locale'] ?? map['loc'] ?? ''}';
        if (name.isEmpty) continue;
        if (!_isPortugueseLocale(locale) && !_looksPortugueseName(name)) {
          continue;
        }
        final genderField =
            '${map['gender'] ?? map['Gender'] ?? map['voiceGender'] ?? ''}';
        final gender = _detectGender(name, genderField);
        final quality = _qualityHint(name, locale);
        options.add(
          TtsVoiceOption(
            name: name,
            locale: locale.isEmpty ? 'pt-BR' : locale,
            gender: gender,
            profileName: '', // preenchido abaixo
            qualityHint: quality,
          ),
        );
      }
      options.sort((a, b) => _scoreVoice(b).compareTo(_scoreVoice(a)));
      return _assignFriendlyNames(options);
    } catch (e) {
      debugPrint('TTS getVoices: $e');
      return const [];
    }
  }

  /// Nomes amigáveis estáveis (ordenados por id técnico).
  static List<TtsVoiceOption> _assignFriendlyNames(
    List<TtsVoiceOption> voices,
  ) {
    const femaleNames = [
      'Ana',
      'Clara',
      'Sofia',
      'Beatriz',
      'Lúcia',
      'Marina',
      'Helena',
      'Camila',
      'Isabela',
      'Vitória',
    ];
    const maleNames = [
      'Pedro',
      'Bruno',
      'Rafael',
      'Diego',
      'Lucas',
      'André',
      'Thiago',
      'Felipe',
      'Gabriel',
      'Ricardo',
    ];
    const neutralNames = [
      'Voz A',
      'Voz B',
      'Voz C',
      'Voz D',
      'Voz E',
      'Voz F',
    ];

    // Mapa fixo para ids conhecidos do Google / iOS.
    const known = <String, String>{
      'pt-br-x-afs': 'Ana',
      'pt-br-x-afb': 'Clara',
      'pt-br-x-afc': 'Sofia',
      'pt-br-x-afd': 'Beatriz',
      'pt-br-x-afe': 'Marina',
      'pt-br-x-ptd': 'Pedro',
      'pt-br-x-pte': 'Bruno',
      'luciana': 'Lúcia',
      'luciana compact': 'Lúcia',
      'francisca': 'Francisca',
      'io': 'Clara',
    };

    final byKey = [...voices]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    var fi = 0;
    var mi = 0;
    var ni = 0;
    final used = <String>{};

    String nextFrom(List<String> pool, int index) {
      if (index < pool.length) return pool[index];
      return '${pool[index % pool.length]} ${index ~/ pool.length + 1}';
    }

    String pickGiven(TtsVoiceOption v) {
      final key = v.name.toLowerCase().trim();
      for (final e in known.entries) {
        if (key == e.key || key.contains(e.key)) {
          if (!used.contains(e.value)) return e.value;
        }
      }
      // Nomes próprios já no id técnico.
      for (final n in [...femaleNames, ...maleNames, 'Francisca', 'Heloísa']) {
        if (key.contains(n.toLowerCase().replaceAll('ú', 'u').replaceAll('í', 'i'))) {
          if (!used.contains(n)) return n;
        }
      }
      return switch (v.gender) {
        TtsVoiceGender.female => nextFrom(femaleNames, fi++),
        TtsVoiceGender.male => nextFrom(maleNames, mi++),
        TtsVoiceGender.unknown => nextFrom(neutralNames, ni++),
      };
    }

    String buildLabel(String given, TtsVoiceOption v) {
      final neural = v.qualityHint == 'neural';
      return switch (v.gender) {
        TtsVoiceGender.female =>
          neural ? '$given (neural)' : '$given (feminina)',
        TtsVoiceGender.male =>
          neural ? '$given (masculina · neural)' : '$given (masculina)',
        TtsVoiceGender.unknown =>
          neural ? '$given (neural)' : '$given (pt-BR)',
      };
    }

    final named = <TtsVoiceOption>[];
    for (final v in byKey) {
      final given = pickGiven(v);
      used.add(given);
      named.add(
        TtsVoiceOption(
          name: v.name,
          locale: v.locale,
          gender: v.gender,
          profileName: buildLabel(given, v),
          qualityHint: v.qualityHint,
        ),
      );
    }

    named.sort((a, b) {
      final g = a.gender.index.compareTo(b.gender.index);
      if (g != 0) return g;
      return _scoreVoice(b).compareTo(_scoreVoice(a));
    });
    return named;
  }

  static bool _isPortugueseLocale(String locale) {
    final n = locale.toLowerCase().replaceAll('_', '-');
    return n.startsWith('pt') || n.contains('pt-br') || n.contains('pt-pt');
  }

  static bool _looksPortugueseName(String name) {
    final n = name.toLowerCase();
    return n.contains('brazil') ||
        n.contains('brasil') ||
        n.contains('portuguese') ||
        n.contains('portugu');
  }

  static String? _qualityHint(String name, String locale) {
    final n = name.toLowerCase();
    if (n.contains('neural') ||
        n.contains('natural') ||
        n.contains('enhanced') ||
        n.contains('premium') ||
        n.contains('wavenet') ||
        n.contains('studio') ||
        // Códigos Google locais “x-” costumam ser de maior qualidade.
        RegExp(r'pt-br-x-').hasMatch(n)) {
      return 'neural';
    }
    if (n.contains('google') || n.contains('siri') || n.contains('samsung')) {
      return 'sistema';
    }
    if (locale.toLowerCase().contains('br')) return 'pt-BR';
    return null;
  }

  static TtsVoiceGender _detectGender(String name, String genderField) {
    final g = genderField.toLowerCase().trim();
    if (g.contains('female') ||
        g == 'f' ||
        g.contains('femin') ||
        g == '1') {
      return TtsVoiceGender.female;
    }
    if (g.contains('male') ||
        g == 'm' ||
        g.contains('mascul') ||
        g == '2') {
      // Evita casar "female" já tratado acima.
      if (!g.contains('female')) return TtsVoiceGender.male;
    }

    final n = name.toLowerCase();

    const femaleHints = [
      'female',
      'femin',
      'woman',
      'lucia',
      'luciana',
      'maria',
      'francisca',
      'vitória',
      'vitoria',
      'heloisa',
      'heloísa',
      'camila',
      'ana',
      'clara',
      'sofia',
      'isabela',
      'helena',
      'marina',
      'neural2-a',
      'neural2-c',
      'wavenet-a',
      'wavenet-c',
      'standard-a',
      'standard-c',
      'pt-br-x-af',
    ];
    const maleHints = [
      'male',
      'mascul',
      'man',
      'antonio',
      'antônio',
      'ricardo',
      'daniel',
      'felipe',
      'joao',
      'joão',
      'pedro',
      'bruno',
      'rafael',
      'diego',
      'lucas',
      'andre',
      'andré',
      'thiago',
      'gabriel',
      'neural2-b',
      'wavenet-b',
      'standard-b',
      'pt-br-x-pt',
      'pt-br-x-pd',
    ];

    for (final h in femaleHints) {
      if (n.contains(h)) return TtsVoiceGender.female;
    }
    for (final h in maleHints) {
      if (n.contains(h)) return TtsVoiceGender.male;
    }

    // iOS às vezes expõe "com.apple.voice.compact.pt-BR.Luciana"
    if (n.contains('luciana') || n.contains('francisca')) {
      return TtsVoiceGender.female;
    }

    return TtsVoiceGender.unknown;
  }

  static int _scoreVoice(
    TtsVoiceOption v, {
    TtsVoiceGender? preferGender,
  }) {
    final n = v.name.toLowerCase();
    final loc = v.locale.toLowerCase().replaceAll('_', '-');
    var score = 0;
    if (loc.contains('pt-br') || loc == 'pt_br') score += 50;
    if (loc.startsWith('pt')) score += 20;
    if (n.contains('neural') ||
        n.contains('natural') ||
        n.contains('enhanced') ||
        n.contains('premium') ||
        n.contains('wavenet') ||
        n.contains('studio') ||
        RegExp(r'pt-br-x-').hasMatch(n)) {
      score += 40;
    }
    if (n.contains('google')) score += 10;
    if (n.contains('compact') || n.contains('network')) score -= 15;

    if (preferGender == TtsVoiceGender.female) {
      if (v.gender == TtsVoiceGender.female) {
        score += 35;
      } else if (v.gender == TtsVoiceGender.male) {
        score -= 40;
      } else {
        score += 5; // unknown: aceitável no default feminino
      }
    } else if (preferGender == TtsVoiceGender.male) {
      if (v.gender == TtsVoiceGender.male) {
        score += 35;
      } else if (v.gender == TtsVoiceGender.female) {
        score -= 40;
      } else {
        score += 5;
      }
    } else {
      // Ranking geral: favorece feminina neural (default histórico).
      if (v.gender == TtsVoiceGender.female) score += 25;
      if (v.gender == TtsVoiceGender.male) score -= 5;
    }
    return score;
  }

  static TtsVoiceOption? _pickBestVoice(
    List<TtsVoiceOption> voices, {
    TtsVoiceGender? preferGender,
  }) {
    if (voices.isEmpty) return null;

    if (preferGender != null) {
      final matched =
          voices.where((v) => v.gender == preferGender).toList();
      final pool = matched.isNotEmpty
          ? matched
          : voices
              .where((v) => v.gender == TtsVoiceGender.unknown)
              .toList();
      final use = pool.isNotEmpty ? pool : voices;
      final sorted = [...use]
        ..sort(
          (a, b) => _scoreVoice(b, preferGender: preferGender)
              .compareTo(_scoreVoice(a, preferGender: preferGender)),
        );
      return sorted.first;
    }

    final sorted = [...voices]
      ..sort((a, b) => _scoreVoice(b).compareTo(_scoreVoice(a)));
    return sorted.first;
  }

  Future<void> _awaitUtterance() async {
    _utteranceDone = Completer<void>();
    await _utteranceDone!.future;
  }

  Future<void> _speakChunk(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _cancelled) return;
    speaking = true;
    await _tts.speak(trimmed);
    await _awaitUtterance();
  }

  /// Divide texto em frases para respiração mais natural.
  static List<String> splitIntoSpeechChunks(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return const [];
    final parts = cleaned.split(RegExp(r'(?<=[.!?;:])\s+'));
    final chunks = <String>[];
    final buf = StringBuffer();
    for (final part in parts) {
      if (part.isEmpty) continue;
      if (buf.isEmpty) {
        buf.write(part);
      } else if (buf.length + part.length < 180) {
        buf.write(' ');
        buf.write(part);
      } else {
        chunks.add(buf.toString());
        buf.clear();
        buf.write(part);
      }
    }
    if (buf.isNotEmpty) chunks.add(buf.toString());
    return chunks;
  }

  Future<void> speak(String text) async {
    await init();
    _cancelled = false;
    await _tts.stop();
    speaking = true;
    final chunks = splitIntoSpeechChunks(text);
    if (chunks.isEmpty) {
      speaking = false;
      return;
    }
    for (var i = 0; i < chunks.length; i++) {
      if (_cancelled) break;
      await _speakChunk(chunks[i]);
      if (_cancelled) break;
      if (i < chunks.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 220));
      }
    }
    speaking = false;
  }

  /// Lê um capítulo: introdução + cada versículo com pausa.
  Future<void> speakChapter({
    required String bookName,
    required int chapter,
    required List<({int number, String text})> verses,
  }) async {
    await init();
    _cancelled = false;
    await _tts.stop();
    speaking = true;

    await _speakChunk('$bookName, capítulo $chapter.');
    if (_cancelled) {
      speaking = false;
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));

    for (final v in verses) {
      if (_cancelled) break;
      final intro = 'Versículo ${v.number}.';
      await _speakChunk(intro);
      if (_cancelled) break;
      await Future<void>.delayed(const Duration(milliseconds: 180));
      final chunks = splitIntoSpeechChunks(v.text);
      for (var i = 0; i < chunks.length; i++) {
        if (_cancelled) break;
        await _speakChunk(chunks[i]);
        if (i < chunks.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 160));
        }
      }
      if (_cancelled) break;
      await Future<void>.delayed(const Duration(milliseconds: 420));
    }
    speaking = false;
  }

  Future<void> stop() async {
    _cancelled = true;
    speaking = false;
    if (_utteranceDone != null && !_utteranceDone!.isCompleted) {
      _utteranceDone!.complete();
    }
    await _tts.stop();
  }

  Future<void> dispose() async {
    await stop();
  }
}
