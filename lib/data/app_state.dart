import 'package:flutter/foundation.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/data/storage.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:livro_registro/services/betel_sync_service.dart';
import 'package:uuid/uuid.dart';

class AppState extends ChangeNotifier {
  AppState(this._storage);

  final EbdStorage _storage;
  final _uuid = const Uuid();
  final _betelSync = BetelSyncService();

  List<Edition> editions = [];
  List<DeliveryRecord> records = [];
  List<FinanceEntry> finances = [];
  List<AttendanceSession> attendance = [];
  List<Student> students = [];
  List<Lesson> lessons = [];
  List<BetelCatalogItem> betelItems = [];

  String selectedGroup = kGroups.first;
  String modeView = 'revistas';

  Future<void> load() async {
    editions = _storage.loadEditions();
    records = _storage.loadRecords();
    finances = _storage.loadFinances();
    attendance = _storage.loadAttendance();
    students = _storage.loadStudents();
    lessons = _storage.loadLessons();
    betelItems = _storage.loadBetelCatalog();
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

  Lesson? lessonForGroupOn(String grupo, DateTime day) {
    final dateOnly = DateTime(day.year, day.month, day.day);
    final list = lessons.where((l) {
      if (l.grupo != null && l.grupo != grupo) return false;
      final ed = editions.where((e) => e.id == l.editionId);
      if (ed.isEmpty) return l.grupo == grupo;
      return ed.first.grupo == grupo;
    }).toList();
    for (final l in list) {
      final d = DateTime(l.dataDomingo.year, l.dataDomingo.month, l.dataDomingo.day);
      if (d == dateOnly) return l;
    }
    // Fallback: nearest upcoming or last past in trimester
    list.sort((a, b) => a.dataDomingo.compareTo(b.dataDomingo));
    Lesson? best;
    for (final l in list) {
      if (!l.dataDomingo.isAfter(dateOnly)) best = l;
    }
    return best ?? (list.isEmpty ? null : list.first);
  }

  Lesson? lessonTodayFor(String? grupo) {
    if (grupo == null) return null;
    return lessonForGroupOn(grupo, DateTime.now());
  }

  Map<String, Lesson?> lessonsTodayByGroup() {
    final now = DateTime.now();
    return {for (final g in kGroups) g: lessonForGroupOn(g, now)};
  }

  Future<void> addStudent({
    required String nome,
    required String grupo,
    String? matricula,
    String? telefone,
    DateTime? aniversario,
    String? fotoUrl,
  }) async {
    students = [
      ...students,
      Student(
        id: _uuid.v4().replaceAll('-', '').substring(0, 12),
        nome: nome.trim(),
        grupo: grupo,
        criadoEm: DateTime.now(),
        matricula: matricula?.trim().isEmpty == true ? null : matricula?.trim(),
        telefone: telefone?.trim().isEmpty == true ? null : telefone?.trim(),
        aniversario: aniversario,
        fotoUrl: fotoUrl,
      ),
    ];
    await _storage.saveStudents(students);
    notifyListeners();
  }

  Future<void> updateStudent(Student student) async {
    students = students.map((s) => s.id == student.id ? student : s).toList();
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
    String? tema,
    String? serie,
    String? sku,
  }) async {
    editions = [
      ...editions,
      Edition(
        id: _uuid.v4().replaceAll('-', '').substring(0, 12),
        grupo: grupo,
        trimestre: trimestre.trim(),
        capa: capa,
        tema: tema,
        serie: serie,
        sku: sku,
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

  Future<FinanceEntry> addFinance({
    required String grupo,
    required String data,
    required String tipo,
    required double valor,
    String descricao = '',
  }) async {
    final entry = FinanceEntry(
      id: _uuid.v4().replaceAll('-', '').substring(0, 12),
      grupo: grupo,
      data: data,
      tipo: tipo,
      valor: valor,
      descricao: descricao,
      criadoEm: DateTime.now(),
    );
    finances = [...finances, entry];
    await _storage.saveFinances(finances);
    notifyListeners();
    return entry;
  }

  Future<void> saveLessonsForEdition({
    required String editionId,
    required String grupo,
    required List<({int numero, String titulo, DateTime data})> items,
  }) async {
    lessons = [
      ...lessons.where((l) => l.editionId != editionId),
      for (final i in items)
        Lesson(
          id: _uuid.v4(),
          editionId: editionId,
          numero: i.numero,
          titulo: i.titulo,
          dataDomingo: i.data,
          grupo: grupo,
        ),
    ];
    await _storage.saveLessons(lessons);
    notifyListeners();
  }

  Future<int> syncBetelCatalog() async {
    final items = await _betelSync.syncCurrentTrimester();
    betelItems = items;
    await _storage.saveBetelCatalog(items);
    // Upsert editions sugeridas por grupo (sem sobrescrever se já existe no mesmo tri)
    for (final item in items) {
      final exists = editions.any(
        (e) => e.grupo == item.grupo && e.trimestre == item.trimestre,
      );
      if (!exists) {
        await addEdition(
          grupo: item.grupo,
          trimestre: item.trimestre,
          capa: item.capaUrl,
          tema: item.tema,
          serie: item.serie,
          sku: item.sku,
        );
      }
      // Adulto também em Varões
      if (item.grupo == 'CIBE') {
        final existsV = editions.any(
          (e) => e.grupo == 'Varões' && e.trimestre == item.trimestre,
        );
        if (!existsV) {
          await addEdition(
            grupo: 'Varões',
            trimestre: item.trimestre,
            capa: item.capaUrl,
            tema: item.tema,
            serie: item.serie,
            sku: item.sku,
          );
        }
      }
    }
    notifyListeners();
    return items.length;
  }

  Future<void> ensureAttendanceSession(String grupo, String data) async {
    final existing =
        attendance.where((a) => a.grupo == grupo && a.data == data).toList();
    if (existing.isNotEmpty) {
      await _repairAttendancePersonIds(existing.first.id);
      await _mergeStudentsIntoSession(existing.first.id, grupo);
      return;
    }
    final alunos = studentsFor(grupo);
    final sessionId = _uuid.v4().replaceAll('-', '').substring(0, 12);
    final pessoas = alunos
        .map(
          (s) => AttendancePerson(
            id: s.id,
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

  /// Inclui alunos novos da turma na sessão aberta, preservando presente/ausente.
  Future<void> _mergeStudentsIntoSession(String sessionId, String grupo) async {
    final alunos = studentsFor(grupo);
    var changed = false;
    attendance = attendance.map((s) {
      if (s.id != sessionId) return s;
      final byId = <String, AttendancePerson>{
        for (final p in s.pessoas) (p.alunoId ?? p.id): p,
      };
      final byName = <String, AttendancePerson>{
        for (final p in s.pessoas) p.nome: p,
      };
      final merged = alunos.map((aluno) {
        final prev = byId[aluno.id] ?? byName[aluno.nome];
        return AttendancePerson(
          id: aluno.id,
          nome: aluno.nome,
          presente: prev?.presente ?? false,
          alunoId: aluno.id,
        );
      }).toList();
      if (merged.length != s.pessoas.length) {
        changed = true;
      } else {
        for (var i = 0; i < merged.length; i++) {
          final a = merged[i];
          final b = s.pessoas[i];
          if (a.id != b.id ||
              a.nome != b.nome ||
              a.presente != b.presente ||
              a.alunoId != b.alunoId) {
            changed = true;
            break;
          }
        }
      }
      return AttendanceSession(
        id: s.id,
        grupo: s.grupo,
        data: s.data,
        pessoas: merged,
        criadoEm: s.criadoEm,
      );
    }).toList();
    if (changed) {
      await _storage.saveAttendance(attendance);
      notifyListeners();
    }
  }

  Future<void> _repairAttendancePersonIds(String sessionId) async {
    var changed = false;
    attendance = attendance.map((s) {
      if (s.id != sessionId) return s;
      final ids = s.pessoas.map((p) => p.id).toSet();
      if (ids.length == s.pessoas.length &&
          s.pessoas.every((p) => p.alunoId != null && p.alunoId == p.id)) {
        return s;
      }
      changed = true;
      final pessoas = s.pessoas.map((p) {
        final alunoId = p.alunoId ??
            () {
              final match = students.where(
                (st) => st.nome == p.nome && st.grupo == s.grupo,
              );
              return match.isEmpty ? null : match.first.id;
            }();
        final uniqueId =
            alunoId ?? _uuid.v4().replaceAll('-', '').substring(0, 12);
        return AttendancePerson(
          id: uniqueId,
          nome: p.nome,
          presente: p.presente,
          alunoId: alunoId ?? uniqueId,
        );
      }).toList();
      return AttendanceSession(
        id: s.id,
        grupo: s.grupo,
        data: s.data,
        pessoas: pessoas,
        criadoEm: s.criadoEm,
      );
    }).toList();
    if (changed) {
      await _storage.saveAttendance(attendance);
      notifyListeners();
    }
  }

  Future<void> setAttendancePresent({
    required String sessionId,
    required String alunoId,
    required bool presente,
  }) async {
    attendance = attendance.map((s) {
      if (s.id != sessionId) return s;
      final pessoas = s.pessoas.map((p) {
        final key = p.alunoId ?? p.id;
        return key == alunoId ? p.copyWith(presente: presente) : p;
      }).toList();
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
