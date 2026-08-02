/// Preferências da Harpa EBD (Hive).
class HarpaPrefs {
  const HarpaPrefs({
    this.lastHymnNumber = 1,
    this.fontSize = 18,
    this.ttsSpeechRate = 0.42,
    this.ttsVoiceName,
  });

  final int lastHymnNumber;
  final double fontSize;
  final double ttsSpeechRate;
  final String? ttsVoiceName;

  HarpaPrefs copyWith({
    int? lastHymnNumber,
    double? fontSize,
    double? ttsSpeechRate,
    String? ttsVoiceName,
    bool clearTtsVoice = false,
  }) {
    return HarpaPrefs(
      lastHymnNumber: lastHymnNumber ?? this.lastHymnNumber,
      fontSize: fontSize ?? this.fontSize,
      ttsSpeechRate: ttsSpeechRate ?? this.ttsSpeechRate,
      ttsVoiceName:
          clearTtsVoice ? null : (ttsVoiceName ?? this.ttsVoiceName),
    );
  }

  Map<String, dynamic> toJson() => {
        'lastHymnNumber': lastHymnNumber,
        'fontSize': fontSize,
        'ttsSpeechRate': ttsSpeechRate,
        if (ttsVoiceName != null) 'ttsVoiceName': ttsVoiceName,
      };

  factory HarpaPrefs.fromJson(Map<String, dynamic> json) {
    return HarpaPrefs(
      lastHymnNumber: (json['lastHymnNumber'] as num?)?.toInt() ?? 1,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18,
      ttsSpeechRate: (json['ttsSpeechRate'] as num?)?.toDouble() ?? 0.42,
      ttsVoiceName: json['ttsVoiceName'] as String?,
    );
  }
}

class HarpaCatalogEntry {
  const HarpaCatalogEntry({required this.number, required this.title});

  final int number;
  final String title;

  factory HarpaCatalogEntry.fromJson(Map<String, dynamic> json) {
    return HarpaCatalogEntry(
      number: (json['number'] as num).toInt(),
      title: (json['title'] as String?)?.trim() ?? '',
    );
  }
}

class HarpaStanza {
  const HarpaStanza({
    required this.sequence,
    required this.text,
    this.isChorus = false,
  });

  final int sequence;
  final String text;
  final bool isChorus;

  Map<String, dynamic> toJson() => {
        'sequence': sequence,
        'text': text,
        'isChorus': isChorus,
      };

  factory HarpaStanza.fromJson(Map<String, dynamic> json) {
    return HarpaStanza(
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      text: (json['text'] as String?) ??
          (json['lyrics'] as String?) ??
          '',
      isChorus: json['isChorus'] == true || json['chorus'] == true,
    );
  }
}

class HarpaHymn {
  const HarpaHymn({
    required this.number,
    required this.title,
    required this.stanzas,
    this.sourceNote,
  });

  final int number;
  final String title;
  final List<HarpaStanza> stanzas;
  final String? sourceNote;

  bool get hasLyrics => stanzas.any((s) => s.text.trim().isNotEmpty);

  String get plainText {
    final buf = StringBuffer();
    for (final s in stanzas) {
      if (s.isChorus) buf.writeln('Refrão');
      buf.writeln(s.text.trim());
      buf.writeln();
    }
    return buf.toString().trim();
  }

  Map<String, dynamic> toJson() => {
        'number': number,
        'title': title,
        'stanzas': stanzas.map((e) => e.toJson()).toList(),
        if (sourceNote != null) 'sourceNote': sourceNote,
      };

  factory HarpaHymn.fromJson(Map<String, dynamic> json) {
    final stanzasRaw = json['stanzas'] ?? json['verses'];
    final list = stanzasRaw is List ? stanzasRaw : const [];
    return HarpaHymn(
      number: (json['number'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?)?.trim() ?? '',
      stanzas: [
        for (final e in list)
          HarpaStanza.fromJson(Map<String, dynamic>.from(e as Map)),
      ]..sort((a, b) => a.sequence.compareTo(b.sequence)),
      sourceNote: json['sourceNote'] as String?,
    );
  }
}

class HarpaLoadResult {
  const HarpaLoadResult({this.hymn, this.errorMessage, this.missingLyrics = false});

  final HarpaHymn? hymn;
  final String? errorMessage;
  final bool missingLyrics;
}
