import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Lane',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: MemoryLane(),
    );
  }
}

class MemoryLane extends StatefulWidget {
  @override
  _MemoryLaneState createState() => _MemoryLaneState();
}

class _MemoryLaneState extends State<MemoryLane> {
  List<Memory> _memories = [];
  final _captionController = TextEditingController();
  Database? _database;

  Future<void> _openDatabase() async {
    _database = await openDatabase(
      join(await getDatabasesPath(), 'memories.db'),
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE memories(id INTEGER PRIMARY KEY, photoPath TEXT, caption TEXT)',
        );
      },
    );
  }

  Future<void> _addMemory() async {
    final pickedFile = await ImagePicker().getImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(await pickedFile.readAsBytes());
      await _openDatabase();
      await _database!.insert(
        'memories',
        {
          'photoPath': file.path,
          'caption': _captionController.text,
        },
      );
      _captionController.clear();
      await _loadMemories();
    }
  }

  Future<void> _editMemory(int index) async {
    final pickedFile = await ImagePicker().getImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(await pickedFile.readAsBytes());
      await _openDatabase();
      await _database!.update(
        'memories',
        {
          'photoPath': file.path,
          'caption': _captionController.text,
        },
        where: 'id = ?',
        whereArgs: [index + 1],
      );
      _captionController.clear();
      await _loadMemories();
    }
  }

  Future<void> _deleteMemory(int index) async {
    await _openDatabase();
    await _database!.delete(
      'memories',
      where: 'id = ?',
      whereArgs: [index + 1],
    );
    await _loadMemories();
  }

  Future<void> _loadMemories() async {
    await _openDatabase();
    final memories = await _database!.query('memories');
    setState(() {
      _memories = memories.map((memory) => Memory(memory['photoPath'].toString(), memory['caption'].toString())).toList().reversed.toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Memory Lane'),
      ),
      body: Container(
      decoration: BoxDecoration(
      gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.pinkAccent,
        Colors.pink,
      ],
    ),
    ),
    child: _memories.isEmpty
    ? Center(
    child: Text(
    'No memories yet! 🐝',
    style: TextStyle(fontSize: 24, color: Colors.white),
    ),
    )
        : ListView.builder(
    itemCount: _memories.length,
    itemBuilder: (context, index) {
    final memory = _memories[index];
    final file = File(memory.photoPath);
    final date = file.lastModifiedSync(); // Get the date from the image file
    return MemoryCard(
    memory: memory,
    date: date, // Pass the date to the MemoryCard widget
    onEdit: () {
    _captionController.text = memory.caption; // Set the initial text here
    showDialog(
    context: context,
    builder: (context) {
    return AlertDialog(
    title: Text('Edit Memory'),
    content: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
    TextField(
    controller: _captionController,
    decoration: InputDecoration(
    labelText: 'Caption',
    ),
    ),
    ],
    ),
    actions: [
      ElevatedButton(
        child: Text('Edit'),
        onPressed: () {
          setState(() {
            _memories[index].caption = _captionController.text;
          });
          _editMemory(_memories.length - 1 - index);
        },
      ),
    ],
    );
    },
    );
    },
      onDelete: () => _deleteMemory(_memories.length - 1 - index),
    );
    },
    ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text('Add Memory'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _captionController,
                      decoration: InputDecoration(
                        labelText: 'Caption',
                      ),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    child: Text('Add'),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                      _addMemory();
                    },
                  ),
                ],
              );
            },
          );
        },
        tooltip: 'Add Memory',
        child: Icon(Icons.add),
      ),
    );
  }
}

class Memory {
  String photoPath;
  String caption;

  Memory(this.photoPath, this.caption);
}

class MemoryCard extends StatelessWidget {
  final Memory memory;
  final DateTime date;
  final void Function()? onEdit;
  final void Function()? onDelete;

  const MemoryCard({
    required this.memory,
    required this.date,
    this.onEdit,
    this.onDelete,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(memory.photoPath),
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.pink[100], // Light pink background
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.caption,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    DateFormat('yyyy-MM-dd').format(date), // Display the date
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: onEdit,
                  child: Text('Edit'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onDelete,
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}