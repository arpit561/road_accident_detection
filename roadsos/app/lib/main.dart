
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:roadsos_app/ui/theme.dart';
import 'package:roadsos_app/ui/app_shell.dart';
import 'package:roadsos_app/accident_detection/engine_builder.dart';
import 'package:roadsos_app/accident_detection/engine/detection_engine.dart';
import 'package:roadsos_app/emergency_handling/emergency_service.dart';
import 'package:roadsos_app/services/socket_service.dart';
import 'package:roadsos_app/config/app_config.dart';

import 'firebase_options.dart';

// Global singletons for active sensor streams and command orchestration.
late final DetectionEngine globalDetectionEngine;
late final EmergencyService globalEmergencyService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase using the generated platform-specific options.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[Firebase] Initialized successfully.');
  } catch (e, stackTrace) {
    debugPrint('[Firebase] Initialization failed: $e');
    debugPrint('$stackTrace');
  }

  // Connect to the RoadSoS backend for live updates.
  SocketService().connect();

  // Initialize the accident detection engine.
  globalDetectionEngine = EngineBuilder.build(
    confidenceThreshold: 0.7,
    eventCorrelationWindow: const Duration(seconds: 90),
  );

  // Initialize the emergency orchestration service.
  globalEmergencyService = EmergencyService(
    detectionEngine: globalDetectionEngine,
    emergencyContacts: AppConfig.emergencyContacts,
  );

  // Listen for accident detection events.
  globalEmergencyService.listen();

  // Launch the application.
  runApp(const RoadSoSApp());
}

class RoadSoSApp extends StatelessWidget {
  const RoadSoSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoadSoS',
      debugShowCheckedModeBanner: false,
      theme: RoadSoSTheme.dark,
      home: const AppShell(),
    );
  }
}




// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:roadsos_app/ui/theme.dart';
// import 'package:roadsos_app/ui/app_shell.dart';
// import 'package:roadsos_app/accident_detection/engine_builder.dart';
// import 'package:roadsos_app/accident_detection/engine/detection_engine.dart';
// import 'package:roadsos_app/emergency_handling/emergency_service.dart';
// import 'package:roadsos_app/services/socket_service.dart';
// import 'package:roadsos_app/config/app_config.dart';
// import 'firebase_options.dart'; // newly added

// // Global singletons for active sensor streams and command orchestration
// late final DetectionEngine globalDetectionEngine;
// late final EmergencyService globalEmergencyService;

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   // Initialize Firebase (for incident storage)
//   try {
//     await Firebase.initializeApp();
//   } catch (e) {
//     debugPrint('[Warning] Firebase initialization failed: $e');
//   }

//   // Connect backend WebSocket server (for live tracker and dispatcher loops)
//   SocketService().connect();

//   // Initialize Detection Engine
//   globalDetectionEngine = EngineBuilder.build(
//     confidenceThreshold: 0.7,
//     eventCorrelationWindow: const Duration(seconds: 90),
//   );

//   // Initialize Emergency Orchestrator Service
//   globalEmergencyService = EmergencyService(
//     detectionEngine: globalDetectionEngine,
//     // Shared, editable contact list (AppConfig is the single source of truth).
//     emergencyContacts: AppConfig.emergencyContacts,
//   );

//   // Mount listeners to receive crash events
//   globalEmergencyService.listen();

//   runApp(const RoadSoSApp());
// }

// class RoadSoSApp extends StatelessWidget {
//   const RoadSoSApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'RoadSoS',
//       debugShowCheckedModeBanner: false,
//       theme: RoadSoSTheme.dark,
//       home: const AppShell(),
//     );
//   }
// }
