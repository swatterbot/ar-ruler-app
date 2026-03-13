import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ar_ruler.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE scanned_objects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        type INTEGER NOT NULL,
        width REAL NOT NULL,
        length REAL NOT NULL,
        height REAL NOT NULL,
        pos_x REAL DEFAULT 0,
        pos_y REAL DEFAULT 0,
        pos_z REAL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
      )
    ''');
  }

  // ── PROJECTS ──────────────────────────────────────────────────
  Future<List<Project>> getProjects() async {
    final db = await database;
    final maps = await db.query('projects', orderBy: 'created_at DESC');
    return maps.map((m) => Project.fromMap(m)).toList();
  }

  Future<Project> insertProject(Project project) async {
    final db = await database;
    final id = await db.insert('projects', project.toMap()..remove('id'));
    return project.copyWith(id: id);
  }

  Future<void> deleteProject(int id) async {
    final db = await database;
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateProject(Project project) async {
    final db = await database;
    await db.update(
      'projects',
      project.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  // ── SCANNED OBJECTS ───────────────────────────────────────────
  Future<List<ScannedObject>> getObjects(int projectId) async {
    final db = await database;
    final maps = await db.query(
      'scanned_objects',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => ScannedObject.fromMap(m)).toList();
  }

  Future<ScannedObject> insertObject(ScannedObject obj) async {
    final db = await database;
    final map = obj.toMap()..remove('id');
    final id = await db.insert('scanned_objects', map);
    return ScannedObject(
      id: id,
      projectId: obj.projectId,
      name: obj.name,
      type: obj.type,
      width: obj.width,
      length: obj.length,
      height: obj.height,
      posX: obj.posX,
      posY: obj.posY,
      posZ: obj.posZ,
      createdAt: obj.createdAt,
    );
  }

  Future<void> deleteObject(int id) async {
    final db = await database;
    await db.delete('scanned_objects', where: 'id = ?', whereArgs: [id]);
  }
}
