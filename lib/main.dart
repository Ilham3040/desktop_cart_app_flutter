import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Import FFI
import 'model/database_helper.dart'; // Import the database helper
import 'package:intl/intl.dart'; // Import for formatting dates
import 'inventory.dart'; // Import the inventory page
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/projectinfo_provider.dart';

void main() {
  sqfliteFfiInit(); // Initialize FFI for desktop platforms
  databaseFactory = databaseFactoryFfi;
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplikasi Penjualan',
      home: MyHomePage(title: 'Aplikasi Penjualan'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Map<String, dynamic>> projects = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController projectController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeDatabaseAndLoadProjects();
  }

  @override
  void dispose() {
    projectController.dispose(); // Properly dispose of the controller
    super.dispose();
  }

  // Initialize the database and load existing projects from it
  void _initializeDatabaseAndLoadProjects() async {
    await _dbHelper.database;
    final data = await _dbHelper.getProjects();
    setState(() {
      projects = data;
    });
  }

  // Insert a new project into the database
  void _addNewProject(String projectName) async {
    if (projectName.isEmpty) return;

    await _dbHelper.insertProject(projectName);
    _initializeDatabaseAndLoadProjects(); // Reload data after inserting
  }

  // Show dialog to add a new project
  void _showAddProjectDialog() {
    projectController.clear(); // Clear the controller to reset the input

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Buat Data Baru'),
          content: TextField(
            controller: projectController,
            decoration: const InputDecoration(hintText: "Enter project name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (projectController.text.isNotEmpty) {
                  _addNewProject(projectController.text);
                  Navigator.of(context).pop(); // Close the dialog
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Format the timestamp into a readable date-time string
  String _formatDate(String timestamp) {
    final DateTime dateTime = DateTime.parse(timestamp);
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  // Navigate to Inventory Page and pass the project ID and name
  void _navigateToInventory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InventoryPage(),
      ),
    );
    _initializeDatabaseAndLoadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
        title: Padding(
          padding: const EdgeInsets.only(left: 32.0),
          child: Text(
            widget.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      body: Consumer(
        builder: (context, ref, child) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: ListView.builder(
              itemCount: projects.isEmpty ? 1 : projects.length + 1,
              itemBuilder: (context, index) {
                if (index == projects.length) {
                  return GestureDetector(
                    onTap: _showAddProjectDialog,
                    child: Container(
                      height: 75,
                      color: Colors.blue[900],
                      child: const Center(
                        child: Text(
                          'Buat Data Baru',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  );
                } else {
                  final project = projects[index];
                  final String formattedDate =
                      _formatDate(project['created_at']);

                  return GestureDetector(
                    onTap: () {
                      ref.read(projectInfoProvider.notifier).state =
                          ProjectInfo(
                              id: project['id'],
                              name: project['name'],
                              dateCreated: _formatDate(project['created_at']));
                      _navigateToInventory();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Container(
                        height: 75,
                        color: Colors.white,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                project['name'],
                                style: const TextStyle(
                                    fontSize: 18, color: Colors.black),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Dibuat pada $formattedDate',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}
