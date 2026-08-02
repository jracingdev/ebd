import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/data/user_models.dart';

const _boxName = 'ebd_v1';
const _keyEditions = 'editions';
const _keyRecords = 'records';
const _keyFinances = 'finances';
const _keyAttendance = 'attendance';
const _keyStudents = 'students';
const _keyLessons = 'lessons';
const _keyBetel = 'betel_catalog';
const _keyCustomGroups = 'custom_groups';
const _keyActiveEditions = 'active_editions';

class EbdStorage {
  EbdStorage(this._box);

  final Box _box;

  static Future<EbdStorage> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox(_boxName);
    return EbdStorage(box);
  }

  List<T> _readList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = _box.get(key);
    if (raw == null) return [];
    final list = raw is String ? jsonDecode(raw) : raw;
    if (list is! List) return [];
    return list
        .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> items) async {
    await _box.put(key, jsonEncode(items));
  }

  List<Edition> loadEditions() => _readList(_keyEditions, Edition.fromJson);

  Future<void> saveEditions(List<Edition> items) =>
      _writeList(_keyEditions, items.map((e) => e.toJson()).toList());

  List<DeliveryRecord> loadRecords() =>
      _readList(_keyRecords, DeliveryRecord.fromJson);

  Future<void> saveRecords(List<DeliveryRecord> items) =>
      _writeList(_keyRecords, items.map((e) => e.toJson()).toList());

  List<FinanceEntry> loadFinances() =>
      _readList(_keyFinances, FinanceEntry.fromJson);

  Future<void> saveFinances(List<FinanceEntry> items) =>
      _writeList(_keyFinances, items.map((e) => e.toJson()).toList());

  List<AttendanceSession> loadAttendance() =>
      _readList(_keyAttendance, AttendanceSession.fromJson);

  Future<void> saveAttendance(List<AttendanceSession> items) =>
      _writeList(_keyAttendance, items.map((e) => e.toJson()).toList());

  List<Student> loadStudents() => _readList(_keyStudents, Student.fromJson);

  Future<void> saveStudents(List<Student> items) =>
      _writeList(_keyStudents, items.map((e) => e.toJson()).toList());

  List<Lesson> loadLessons() => _readList(_keyLessons, Lesson.fromJson);

  Future<void> saveLessons(List<Lesson> items) =>
      _writeList(_keyLessons, items.map((e) => e.toJson()).toList());

  List<BetelCatalogItem> loadBetelCatalog() {
    final raw = _box.get(_keyBetel);
    if (raw == null) return [];
    final list = raw is String ? jsonDecode(raw) : raw;
    if (list is! List) return [];
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return BetelCatalogItem(
        grupo: m['grupo'] as String,
        trimestre: m['trimestre'] as String,
        serie: m['serie'] as String,
        tema: m['tema'] as String?,
        sku: m['sku'] as String?,
        capaUrl: m['capa_url'] as String? ?? m['capaUrl'] as String?,
        produtoUrl: m['produto_url'] as String? ?? m['produtoUrl'] as String?,
        preco: (m['preco'] as num?)?.toDouble(),
      );
    }).toList();
  }

  Future<void> saveBetelCatalog(List<BetelCatalogItem> items) =>
      _writeList(_keyBetel, items.map((e) => e.toJson()).toList());

  List<String> loadCustomGroups() {
    final raw = _box.get(_keyCustomGroups);
    if (raw == null) return [];
    final list = raw is String ? jsonDecode(raw) : raw;
    if (list is! List) return [];
    return list
        .map((e) => e.toString().trim())
        .where((g) => g.isNotEmpty && !isDefaultGroup(g))
        .toSet()
        .toList();
  }

  Future<void> saveCustomGroups(List<String> groups) => _box.put(
        _keyCustomGroups,
        jsonEncode(
          groups
              .map((g) => g.trim())
              .where((g) => g.isNotEmpty && !isDefaultGroup(g))
              .toSet()
              .toList(),
        ),
      );

  /// Edição ativa por turma (`grupo` → `editionId`). O sync Betel não altera isso.
  Map<String, String> loadActiveEditions() {
    final raw = _box.get(_keyActiveEditions);
    if (raw == null) return {};
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) return {};
    return {
      for (final e in decoded.entries)
        if (e.key.toString().trim().isNotEmpty &&
            e.value.toString().trim().isNotEmpty)
          e.key.toString(): e.value.toString(),
    };
  }

  Future<void> saveActiveEditions(Map<String, String> map) => _box.put(
        _keyActiveEditions,
        jsonEncode(map),
      );

  AppBackup exportBackup() => AppBackup(
        version: kBackupVersion,
        exportedAt: DateTime.now(),
        editions: loadEditions(),
        records: loadRecords(),
        finances: loadFinances(),
        attendance: loadAttendance(),
        students: loadStudents(),
        lessons: loadLessons(),
        customGroups: loadCustomGroups(),
      );

  Future<void> importBackup(AppBackup backup) async {
    await saveEditions(backup.editions);
    await saveRecords(backup.records);
    await saveFinances(backup.finances);
    await saveAttendance(backup.attendance);
    await saveStudents(backup.students);
    await saveLessons(backup.lessons);
    await saveCustomGroups(backup.customGroups);
  }
}
