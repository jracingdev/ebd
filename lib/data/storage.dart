import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:livro_registro/data/models.dart';

const _boxName = 'ebd_v1';
const _keyEditions = 'editions';
const _keyRecords = 'records';
const _keyFinances = 'finances';
const _keyAttendance = 'attendance';
const _keyStudents = 'students';

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

  List<Edition> loadEditions() =>
      _readList(_keyEditions, Edition.fromJson);

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

  List<Student> loadStudents() =>
      _readList(_keyStudents, Student.fromJson);

  Future<void> saveStudents(List<Student> items) =>
      _writeList(_keyStudents, items.map((e) => e.toJson()).toList());

  AppBackup exportBackup() => AppBackup(
        version: kBackupVersion,
        exportedAt: DateTime.now(),
        editions: loadEditions(),
        records: loadRecords(),
        finances: loadFinances(),
        attendance: loadAttendance(),
        students: loadStudents(),
      );

  Future<void> importBackup(AppBackup backup) async {
    await saveEditions(backup.editions);
    await saveRecords(backup.records);
    await saveFinances(backup.finances);
    await saveAttendance(backup.attendance);
    await saveStudents(backup.students);
  }
}
