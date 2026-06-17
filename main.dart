import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance Tracker',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

// =========================================================================
// DATABASE HELPER LAYER
// =========================================================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('attendance_manager.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');

    await db.execute('''
      CREATE TABLE students (
        student_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        course TEXT NOT NULL,
        year INTEGER NOT NULL,
        phone_number TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (student_id) ON DELETE CASCADE
      )
    ''');
  }

  // Insert Student
  Future<int> insertStudent(Map<String, dynamic> student) async {
    final db = await instance.database;
    return await db.insert('students', student, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Get All Students
  Future<List<Map<String, dynamic>>> getStudents() async {
    final db = await instance.database;
    return await db.query('students');
  }

  // Record Attendance
  Future<int> recordAttendance(String studentId, String date, String status) async {
    final db = await instance.database;

    // Check if entry already exists for this student on this day to update it, otherwise insert new
    final existing = await db.query(
      'attendance',
      where: 'student_id = ? AND date = ?',
      whereArgs: [studentId, date],
    );

    if (existing.isNotEmpty) {
      return await db.update(
        'attendance',
        {'status': status},
        where: 'student_id = ? AND date = ?',
        whereArgs: [studentId, date],
      );
    } else {
      return await db.insert('attendance', {
        'student_id': studentId,
        'date': date,
        'status': status,
      });
    }
  }

  // Generate Report Data
  Future<List<Map<String, dynamic>>> getAttendanceReport() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        s.student_id, 
        s.name, 
        s.course,
        COUNT(a.id) as total_days,
        SUM(CASE WHEN a.status = 'Present' THEN 1 ELSE 0 END) as days_present
      FROM students s
      LEFT JOIN attendance a ON s.student_id = a.student_id
      GROUP BY s.student_id
    ''');
  }
}

// =========================================================================
// PRESENTATION LAYER (UI)
// =========================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const RegisterStudentScreen(),
    const TakeAttendanceScreen(),
    const ReportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person_add), label: 'Register'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: 'Attendance'),
          BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'Reports'),
        ],
      ),
    );
  }
}

// 1. REGISTER STUDENT SCREEN
class RegisterStudentScreen extends StatefulWidget {
  const RegisterStudentScreen({super.key});

  @override
  State<RegisterStudentScreen> createState() => _RegisterStudentScreenState();
}

class _RegisterStudentScreenState extends State<RegisterStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _courseController = TextEditingController();
  final _yearController = TextEditingController();
  final _phoneController = TextEditingController();

  void _saveStudent() async {
    if (_formKey.currentState!.validate()) {
      Map<String, dynamic> student = {
        'student_id': _idController.text.trim(),
        'name': _nameController.text.trim(),
        'course': _courseController.text.trim(),
        'year': int.parse(_yearController.text),
        'phone_number': _phoneController.text.trim(),
      };

      await DatabaseHelper.instance.insertStudent(student);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student Registered Successfully!')),
        );
        _formKey.currentState!.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Student')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(controller: _idController, decoration: const InputDecoration(labelText: 'Student ID'), validator: (v) => v!.isEmpty ? 'Required' : null),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
              TextFormField(controller: _courseController, decoration: const InputDecoration(labelText: 'Course'), validator: (v) => v!.isEmpty ? 'Required' : null),
              TextFormField(controller: _yearController, decoration: const InputDecoration(labelText: 'Year of Study'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
              TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone Number'), keyboardType: TextInputType.phone),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _saveStudent, child: const Text('Save Student')),
            ],
          ),
        ),
      ),
    );
  }
}

// 2. TAKE ATTENDANCE SCREEN
class TakeAttendanceScreen extends StatefulWidget {
  const TakeAttendanceScreen({super.key});

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  List<Map<String, dynamic>> _students = [];
  final String _todayDate = DateTime.now().toIso8601String().split('T')[0];
  final Map<String, String> _attendanceStatus = {}; // Stores student_id -> status

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  void _loadStudents() async {
    final data = await DatabaseHelper.instance.getStudents();
    setState(() {
      _students = data;
      for (var student in _students) {
        _attendanceStatus[student['student_id']] = 'Present'; // default value
      }
    });
  }

  void _submitAttendance() async {
    for (var studentId in _attendanceStatus.keys) {
      await DatabaseHelper.instance.recordAttendance(studentId, _todayDate, _attendanceStatus[studentId]!);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance Saved for $_todayDate!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Attendance ($_todayDate)')),
      body: _students.isEmpty
          ? const Center(child: Text('No students registered yet.'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final id = student['student_id'];
                      return ListTile(
                        title: Text(student['name']),
                        subtitle: Text('${student['course']} - Year ${student['year']}'),
                        trailing: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'Present', label: Text('P')),
                            ButtonSegment(value: 'Absent', label: Text('A')),
                          ],
                          selected: {_attendanceStatus[id] ?? 'Present'},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              _attendanceStatus[id] = newSelection.first;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: _submitAttendance,
                    child: const Text('Submit Today\'s Attendance'),
                  ),
                )
              ],
            ),
    );
  }
}

// 3. REPORT SCREEN
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<Map<String, dynamic>> _reportData = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  void _loadReport() async {
    final data = await DatabaseHelper.instance.getAttendanceReport();
    setState(() {
      _reportData = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Summary')),
      body: _reportData.isEmpty
          ? const Center(child: Text('No records found.'))
          : ListView.builder(
              itemCount: _reportData.length,
              itemBuilder: (context, index) {
                final record = _reportData[index];
                int total = record['total_days'] ?? 0;
                int present = record['days_present'] ?? 0;
                double percentage = total > 0 ? (present / total) * 100 : 0.0;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(record['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${record['student_id']} | ${record['course']}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$present/$total Days', style: const TextStyle(fontSize: 14)),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: percentage >= 75 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
