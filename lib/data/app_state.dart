import 'package:flutter/foundation.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/data/storage.dart';
import 'package:uuid/uuid.dart';

class AppState extends ChangeNotifier {
  AppState(this._storage);

  final EbdStorage _storage;
  final _uuid = const Uuid();

  List<Edition> editions = [];
  List<DeliveryRecord> records = [];
  List<FinanceEntry> finances = [];
  List<AttendanceSession> attendance = [];
  List<Student> students = [];

  String selectedGroup = kGroups.first;
  String modeView = 'revistas'; // revistas | ofertas | presenca | alunos | painel

  Future<void> load() async {
    editions = _storage.loadEditions();
    records = _storage.loadRecords();
    finances = _storage.loadFinances();
    attendance = _storage.loadAttendance();
    students = _storage.loadStudents();
    notifyListeners();
  }

  void selectGroup(String group) {
    selectedGroup = group;
    notifyListeners();
  }

  void setModeView(String mode) {
    modeView = mode;
    notifyListeners();
  }

  List<Student> studentsFor(String grupo) =>
      students.where((s) => s.grupo == grupo).toList()
        ..sort((a, b) => a.nome.compareTo(b.nome));

  Edition? currentEdition(String grupo) {
    final eds = editions.where((e) => e.grupo == grupo).toList()
      ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
    return eds.isEmpty ? null : eds.first;
  }

  Future<void> addStudent(String nome, String grupo) async {
    students = [
      ...students,
      Student(
        id: _uuid.v4().replaceAll('-', '').substring(0, 12),
        nome: nome.trim(),
        grupo: grupo,
        criadoEm: DateTime.now(),
      ),
    ];
    await _storage.saveStudents(students);
    notifyListeners();
  }

  Future<void> removeStudent(String id) async {
    students = students.where((s) => s.id != id).toList();
    await _storage.saveStudents(students);
    notifyListeners();
  }

  Future<void> addEdition({
    required String grupo,
    required String trimestre,
    String? capa,
  }) async {
    editions = [
      ...editions,
      Edition(
        id: _uuid.v4().replaceAll('-', '').substring(0, 12),
        grupo: grupo,
        trimestre: trimestre.trim(),
        capa: capa,
        criadoEm: DateTime.now(),
      ),
    ];
    await _storage.saveEditions(editions);
    notifyListeners();
  }

  Future<void> addDelivery({
    required String nome,
    required String grupo,
    required String edicaoId,
    required double valor,
    String status = 'pendente',
  }) async {
    records = [
      ...records,
      DeliveryRecord(
        id: _uuid.v4().replaceAll('-', '').substring(0, 12),
        nome: nome.trim(),
        grupo: grupo,
        edicaoId: edicaoId,
        valor: valor,
        status: status,
        data: DateTime.now(),
      ),
    ];
    await _storage.saveRecords(records);
    notifyListeners();
  }

  Future<void> toggleDeliveryStatus(String id) async {
    records = records
        .map(
          (r) => r.id == id
              ? r.copyWith(status: r.isPago ? 'pendente' : 'pago')
              : r,
        )
        .toList();
    await _storage.saveRecords(records);
    notifyListeners();
  }

  Future<void> addFinance({
    required String grupo,
    required String data,
    required String tipo,
    required double valor,
    String descricao = '',
  }) async {
    finances = [
      ...finances,
      FinanceEntry(
        id: _uuid.v4().replaceAll('-', '').substring(0, 12),
        grupo: grupo,
        data: data,
        tipo: tipo,
        valor: valor,
        descricao: descricao,
        criadoEm: DateTime.now(),
      ),
    ];
    await _storage.saveFinances(finances);
    notifyListeners();
  }

  Future<void> ensureAttendanceSession(String grupo, String data) async {
    final existing = attendance.where((a) => a.grupo == grupo && a.data == data);
    if (existing.isNotEmpty) return;
    final alunos = studentsFor(grupo);
    final sessionId = _uuid.v4().replaceAll('-', '').substring(0, 12);
    final pessoas = alunos
        .map(
          (s) => AttendancePerson(
            id: sessionId,
            nome: s.nome,
            presente: false,
            alunoId: s.id,
          ),
        )
        .toList();
    attendance = [
      ...attendance,
      AttendanceSession(
        id: sessionId,
        grupo: grupo,
        data: data,
        pessoas: pessoas,
        criadoEm: DateTime.now(),
      ),
    ];
    await _storage.saveAttendance(attendance);
    notifyListeners();
  }

  Future<void> setAttendancePresent({
    required String sessionId,
    required String alunoId,
    required bool presente,
  }) async {
    attendance = attendance.map((s) {
      if (s.id != sessionId) return s;
      final pessoas = s.pessoas
          .map(
            (p) => p.alunoId == alunoId ? p.copyWith(presente: presente) : p,
          )
          .toList();
      return AttendanceSession(
        id: s.id,
        grupo: s.grupo,
        data: s.data,
        pessoas: pessoas,
        criadoEm: s.criadoEm,
      );
    }).toList();
    await _storage.saveAttendance(attendance);
    notifyListeners();
  }

  AppBackup exportBackup() => _storage.exportBackup();

  Future<void> importBackup(AppBackup backup) async {
    await _storage.importBackup(backup);
    await load();
  }
}
