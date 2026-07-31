import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const ProviderScope(child: NexoraApp()));
  } catch (e) {
    // Most likely: Firebase not configured yet (see firebase_options.dart).
    runApp(_FirebaseSetupApp(error: e.toString()));
  }
}

/// Shown when Firebase fails to initialize — usually because
/// `flutterfire configure` hasn't been run yet.
class _FirebaseSetupApp extends StatelessWidget {
  const _FirebaseSetupApp({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  const SizedBox(height: 16),
                  const Text('Firebase not configured',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text(
                    'Run this in the project root, then restart the app:',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const SelectableText(
                    'flutterfire configure',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Text(error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
