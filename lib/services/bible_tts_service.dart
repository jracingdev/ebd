import 'package:flutter_tts/flutter_tts.dart';

class BibleTtsService {
  BibleTtsService() : _tts = FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;
  bool speaking = false;

  Future<void> init() async {
    if (_ready) return;
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() => speaking = false);
    _tts.setCancelHandler(() => speaking = false);
    _tts.setErrorHandler((_) => speaking = false);
    _ready = true;
  }

  Future<void> speak(String text) async {
    await init();
    speaking = true;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    speaking = false;
    await _tts.stop();
  }

  Future<void> dispose() async {
    await stop();
  }
}
