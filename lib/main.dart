import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/stream_provider.dart';
import 'screens/home_screen.dart';

/// MicStream - Phase 1: Basic UDP Streaming
/// Streams raw PCM audio from Android to Windows PC
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations (portrait only)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system UI overlay style (status bar, navigation bar)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MicStreamApp());
}

class MicStreamApp extends StatelessWidget {
  const MicStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AudioStreamProvider(),
      child: MaterialApp(
        title: 'MicStream',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.black,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
