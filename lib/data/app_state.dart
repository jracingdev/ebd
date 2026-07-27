import 'package:flutter/foundation.dart';
import 'package:livro_registro/data/engagement/engagement_store.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/data/storage.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:livro_registro/services/betel_sync_service.dart';
import 'package:uuid/uuid.dart';

class AppState extends ChangeNotifier {
  AppState(this._storage, {this.engagement});

  final EbdStorage _storage;
  final EngagementStore? engagement;
  final _uuid = const Uuid();
  final _betelSync = BetelSyncService();

  List<Edition> editions = [];
  List<DeliveryRecord> records = [];
  List<FinanceEntry> finances = [];
  List<AttendanceSession> attendance = [];
  List<Student> students = [];
  List<Lesson> lessons = [];
  List<BetelCatalogItem> betelItems = [];
  List<String> customGroups = [];

  String selectedGroup = kGroups.first;
  String modeView = 'revistas';

  /// Classes padrão + turmas extras cadastradas.
  List<String> get groups {
    final extras = <String>[];
    final seen = <String>{...kGroups};
    for (final g in customGroups) {
      final name = g.trim();
      if (name.isEmpty || seen.contains(name)) continue;
      seen.add(name);
      extras.add(name);
    }
    return [...kGroups, ...extras];
  }

  Future<void> load() async {
    editions = _storage.loadEditions();
    records = _storage.loadRecords();
    finances = _storage.loadFinances();
    attendance = _storage.loadAttendance();
    final loadedStudents = _storage.loadStudents();
    students = _normalizeStudents(loadedStudents);
    lessons = _storage.loadLessons();
    betelItems = _storage.loadBetelCatalog();
    customGroups = _storage.loadCustomGroups();
    await _absorbOrphanGroups();
    if (!groups.contains(selectedGroup)) {
      selectedGroup = groups.first;
    }
    if (!_sameStudents(loadedStudents, students)) {
      await _storage.saveStudents(students);
    }
    notifyListeners();
  }

  bool _sameStudents(List<Student> a, List<Student> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Garante id único e campos íntegros (backups antigos / imports frágeis).
  List<Student> _normalizeStudents(List<Student> raw) {
    final seen = <String>{};
    final out = <Student>[];
    for (final s in raw) {
      var id = s.id.trim();
      if (id.isEmpty || seen.contains(id)) {
        id = _uuid.v4().replaceAll('-', '').substring(0, 12);
      }
      seen.add(id);
      final nome = s.nome.trim().isEmpty ? 'Aluno' : s.nome.trim();
      final grupo = s.grupo.trim().isEmpty ? kGroups.first : s.grupo.trim();
      out.add(
        Student(
          id: id,
          nome: nome,
          grupo: grupo,
          criadoEm: s.criadoEm,
          matricula: s.matricula?.trim().isEmpty == true ? null : s.matricula?.trim(),
          telefone: s.telefone?.trim().isEmpty == true ? null : s.telefone?.trim(),
          aniversario: s.aniversario,
          fotoUrl: s.fotoUrl?.trim().isEmpty == true ? null : s.fotoUrl?.trim(),
        ),
      );
    }
    return out;
  }

  /// Inclui na lista de custom grupos encontrados nos dados (ex.: backup antigo).
  Future<void> _absorbOrphanGroups() async {
    final known = <String>{...kGroups, ...customGroups};
    final orphans = <String>{};
    void consider(String? g) {
      final name = g?.trim() ?? '';
      if (name.isEmpty || known.contains(name)) return;
      orphans.add(name);
    }

    for (final s in students) {
      consider(s.grupo);
    }
    for (final e in editions) {
      consider(e.grupo);
    }
    for (final f in finances) {
      consider(f.grupo);
    }
    for (final a in attendance) {
      consider(a.grupo);
    }
    for (final r in records) {
      consider(r.grupo);
    }
    for (final l in lessons) {
      consider(l.grupo);
    }
    if (orphans.isEmpty) return;
    customGroups = [...customGroups, ...orphans];
    await _storage.saveCustomGroups(customGroups);
  }

  void selectGroup(String group) {
    selectedGroup = group;
    notifyListeners();
  }

  /// Retorna `null` se ok, ou mensagem de erro.
  Future<String?> addGroup(String nome) async {
    final name = nome.trim();
    if (name.isEmpty) return 'Informe o nome da classe.';
    final lower = name.toLowerCase();
    if (groups.any((g) => g.toLowerCase() == lower)) {
      return 'Já existe uma classe com esse nome.';
    }
    customGroups = [...customGroups, name];
    await _storage.saveCustomGroups(customGroups);
    selectedGroup = name;
    notifyListeners();
    return null;
  }

  bool groupHasData(String grupo) {
    return students.any((s) => s.grupo == grupo) ||
        editions.any((e) => e.grupo == grupo) ||
        finances.any((f) => f.grupo == grupo) ||
        attendance.any((a) => a.grupo == grupo) ||
        records.any((r) => r.grupo == grupo) ||
        lessons.any((l) => l.grupo == grupo);
  }

  /// Remove apenas classe custom. Retorna mensagem de erro ou `null`.
  Future<String?> removeGroup(String grupo, {bool force = false}) async {
    if (isDefaultGroup(grupo)) {
      return 'Classes padrão não podem ser removidas.';
    }
    if (!customGroups.contains(grupo)) {
      return 'Classe não encontrada.';
    }
    if (!force && groupHasData(grupo)) {
      return 'Esta classe possui dados cadastrados. Confirme a exclusão.';
    }
    customGroups = customGroups.where((g) => g != grupo).toList();
    await _storage.saveCustomGroups(customGroups);
    if (selectedGroup == grupo) {
      selectedGroup = groups.first;
    }
    notifyListeners();
    return null;
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
    return {for (final g in groups) g: lessonForGroupOn(g, now)};
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
          trouxeBiblia: prev?.trouxeBiblia ?? false,
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
              a.alunoId != b.alunoId ||
              a.trouxeBiblia != b.trouxeBiblia) {
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
          trouxeBiblia: p.trouxeBiblia,
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

  Future<void> setAttendanceBroughtBible({
    required String sessionId,
    required String alunoId,
    required bool trouxeBiblia,
  }) async {
    attendance = attendance.map((s) {
      if (s.id != sessionId) return s;
      final pessoas = s.pessoas.map((p) {
        final key = p.alunoId ?? p.id;
        return key == alunoId ? p.copyWith(trouxeBiblia: trouxeBiblia) : p;
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

  AppBackup exportBackup({List<Map<String, dynamic>> users = const []}) {
    final base = _storage.exportBackup();
    final eng = engagement?.exportMap() ?? const <String, dynamic>{};
    return AppBackup(
      version: base.version,
      exportedAt: base.exportedAt,
      editions: base.editions,
      records: base.records,
      finances: base.finances,
      attendance: base.attendance,
      students: base.students,
      lessons: base.lessons,
      customGroups: base.customGroups,
      engagement: eng,
      users: users,
    );
  }

  Future<void> importBackup(AppBackup backup) async {
    await _storage.importBackup(backup);
    if (engagement != null && backup.engagement.isNotEmpty) {
      await engagement!.importMap(backup.engagement);
    }
    await load();
  }
}

