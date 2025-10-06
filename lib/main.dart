import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

const String SERVER_URL = "https://YOUR_SERVER_URL/"; // change me

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "ApplianceID",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.white,
        textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: "CustomFont",
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade900,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  XFile? _picked;
  Map<String, dynamic>? _result;
  bool _loading = false;
  String? _error;

  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
      );
      if (img == null) return;
      setState(() {
        _picked = img;
        _result = null;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = "Failed to pick image: $e");
    }
  }

  Future<void> uploadAndIdentify() async {
    if (_picked == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse("${SERVER_URL}identify");
      final req = http.MultipartRequest("POST", uri);
      req.files.add(await http.MultipartFile.fromPath("file", _picked!.path));

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        setState(() => _result = json.decode(resp.body));
      } else {
        setState(() => _error =
            "Server error: ${resp.statusCode}\n${resp.body.substring(0, 200)}");
      }
    } catch (e) {
      setState(() => _error = "Upload failed: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("ApplianceID", style: textTheme.headlineSmall),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_picked != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(File(_picked!.path),
                      height: 220, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      "Take a photo of an appliance",
                      style: textTheme.bodyLarge,
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                      onPressed: pickImage, child: const Text("📷 Take Photo")),
                  ElevatedButton(
                    onPressed: _picked == null ? null : uploadAndIdentify,
                    child: const Text("☁️ Identify"),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_loading) const CircularProgressIndicator(),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: textTheme.bodyMedium?.copyWith(color: Colors.red),
                  ),
                ),

              if (_result != null)
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        JsonEncoder.withIndent("  ").convert(_result),
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
