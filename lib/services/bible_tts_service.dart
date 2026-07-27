import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Opção de voz do motor TTS do sistema (Android/iOS/Web).
class TtsVoiceOption {
  const TtsVoiceOption({
    required this.name,
    required this.locale,
    this.qualityHint,
  });

  final String name;
  final String locale;
  final String? qualityHint;

  String get label {
    final short = name.length > 42 ? '${name.substring(0, 40)}…' : name;
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
  String? _preferredVoiceName;

  Completer<void>? _utteranceDone;
  bool _cancelled = false;
  List<TtsVoiceOption> _voicesCache = const [];

  List<TtsVoiceOption> get availableVoices => _voicesCache;

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

    TtsVoiceOption? chosen;
    if (_preferredVoiceName != null) {
      for (final v in voices) {
        if (v.name == _preferredVoiceName) {
          chosen = v;
          break;
        }
      }
    }
    chosen ??= _pickBestVoice(voices);

    if (chosen != null) {
      try {
        await _tts.setVoice(chosen.toEngineMap());
      } catch (_) {
        await _tts.setLanguage('pt-BR');
      }
    } else {
      await _tts.setLanguage('pt-BR');
    }
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
        options.add(
          TtsVoiceOption(
            name: name,
            locale: locale.isEmpty ? 'pt-BR' : locale,
            qualityHint: _qualityHint(name, locale),
          ),
        );
      }
      options.sort((a, b) => _scoreVoice(b).compareTo(_scoreVoice(a)));
      return options;
    } catch (e) {
      debugPrint('TTS getVoices: $e');
      return const [];
    }
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
        n.contains('studio')) {
      return 'neural';
    }
    if (n.contains('google') || n.contains('siri') || n.contains('samsung')) {
      return 'sistema';
    }
    if (locale.toLowerCase().contains('br')) return 'pt-BR';
    return null;
  }

  static int _scoreVoice(TtsVoiceOption v) {
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
        n.contains('studio')) {
      score += 40;
    }
    if (n.contains('female') ||
        n.contains('femin') ||
        n.contains('lucia') ||
        n.contains('luciana') ||
        n.contains('maria') ||
        n.contains('francisca') ||
        n.contains('vitória') ||
        n.contains('vitoria') ||
        n.contains('heloisa') ||
        n.contains('camila')) {
      score += 25;
    }
    if (n.contains('male') || n.contains('mascul')) score -= 5;
    if (n.contains('google')) score += 10;
    if (n.contains('compact') || n.contains('network')) score -= 15;
    return score;
  }

  static TtsVoiceOption? _pickBestVoice(List<TtsVoiceOption> voices) {
    if (voices.isEmpty) return null;
    final sorted = [...voices]..sort(
        (a, b) => _scoreVoice(b).compareTo(_scoreVoice(a)),
      );
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
