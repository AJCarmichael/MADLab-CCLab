import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dashboard.dart'; // Make sure this exists and is properly implemented

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await initDatabase();
  runApp(MyApp(database: database));
}

// SQLite initialization
Future<Database> initDatabase() async {
  final dbPath = await getDatabasesPath();
  return openDatabase(join(dbPath, 'app.db'), version: 1,
      onCreate: (db, version) async {
    await db.execute('''
      CREATE TABLE user(
        id INTEGER PRIMARY KEY,
        name TEXT,
        age INTEGER,
        gender TEXT,
        state TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE appliances(
        id INTEGER PRIMARY KEY,
        imagePath TEXT,
        name TEXT,
        description TEXT,
        efficiencyStars INTEGER,
        powerDraw INTEGER,
        monthlyKWh REAL,
        yearlyKWh REAL,
        createdAt TEXT
      )
    ''');
  });
}

class MyApp extends StatelessWidget {
  final Database database;
  const MyApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Appliance Tracker',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        fontFamily: 'MyCustomFont',
      ),
      home: UserOnboarding(database: database),
    );
  }
}

// Onboarding Screen
class UserOnboarding extends StatefulWidget {
  final Database database;
  const UserOnboarding({super.key, required this.database});

  @override
  _UserOnboardingState createState() => _UserOnboardingState();
}

class _UserOnboardingState extends State<UserOnboarding> {
  final _formKey = GlobalKey<FormState>();
  String name = '', gender = 'Male', state = '';
  int age = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Name'),
                onSaved: (val) => name = val ?? '',
                validator: (val) => val!.isEmpty ? 'Enter your name' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
                onSaved: (val) => age = int.tryParse(val ?? '0') ?? 0,
                validator: (val) => val!.isEmpty ? 'Enter age' : null,
              ),
              DropdownButtonFormField(
                initialValue: gender,
                items: ['Male', 'Female', 'Other']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (val) => gender = val.toString(),
                decoration: const InputDecoration(labelText: 'Gender'),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'State'),
                onSaved: (val) => state = val ?? '',
                validator: (val) => val!.isEmpty ? 'Enter state' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      await widget.database.insert('user', {
                        'name': name,
                        'age': age,
                        'gender': gender,
                        'state': state
                      });
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ApplianceScreen(database: widget.database)),
                      );
                    }
                  },
                  child: const Text('Start'))
            ],
          ),
        ),
      ),
    );
  }
}

// Appliance Capture & Dashboard
class ApplianceScreen extends StatefulWidget {
  final Database database;
  const ApplianceScreen({super.key, required this.database});

  @override
  _ApplianceScreenState createState() => _ApplianceScreenState();
}

class _ApplianceScreenState extends State<ApplianceScreen> {
  XFile? _pickedImage;
  List<Map<String, dynamic>> appliances = [];

  @override
  void initState() {
    super.initState();
    loadAppliances();
  }

  Future<void> loadAppliances() async {
    final data =
        await widget.database.query('appliances', orderBy: 'createdAt DESC');
    setState(() => appliances = data);
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file != null) {
      final dir = await getApplicationDocumentsDirectory();
      final savedPath =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.png';
      await File(file.path).copy(savedPath);
      setState(() => _pickedImage = XFile(savedPath));
    }
  }

  Future<void> sendToBackend() async {
    if (_pickedImage == null) return;
    try {
      final user = (await widget.database.query('user')).first;
      final response = await http.post(
        Uri.parse('http://YOUR_VPS_IP:5678/webhook/appliance-info'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image_path': _pickedImage!.path,
          'state': user['state'],
          'name': user['name'],
          'age': user['age'],
          'gender': user['gender'],
        }),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        await widget.database.insert('appliances', {
          'imagePath': _pickedImage!.path,
          'name': json['name'],
          'description': json['description'],
          'efficiencyStars': json['efficiencyStars'],
          'powerDraw': json['powerDraw'],
          'monthlyKWh': json['monthlyKWh'],
          'yearlyKWh': json['yearlyKWh'],
          'createdAt': DateTime.now().toIso8601String(),
        });
        loadAppliances();
        setState(() => _pickedImage = null);
      }
    } catch (e) {
      ScaffoldMessenger.of(this.context)
          .showSnackBar(SnackBar(content: Text('Failed to reach backend: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Appliances Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Capture'),
              Tab(text: 'Dashboard'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Capture Tab
            Column(
              children: [
                if (_pickedImage != null)
                  Image.file(File(_pickedImage!.path), height: 200),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(onPressed: pickImage, child: const Text('Take Photo')),
                    const SizedBox(width: 20),
                    ElevatedButton(onPressed: sendToBackend, child: const Text('Identify')),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: appliances.length,
                    itemBuilder: (context, i) {
                      final a = appliances[i];
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          leading: Image.file(File(a['imagePath'])),
                          title: Text('${a['name']} (${a['efficiencyStars']}★)'),
                          subtitle: Text(
                              'Power: ${a['powerDraw']}W\nMonthly: ${a['monthlyKWh'].toStringAsFixed(1)} kWh'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Dashboard Tab
            Dashboard(appliances: appliances),
          ],
        ),
      ),
    );
  }
}
