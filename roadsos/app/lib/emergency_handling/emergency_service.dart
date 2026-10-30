import 'dart:async';
import 'countdown_manager.dart';
import 'location_service.dart';
import 'sms_service.dart';
import '../accident_detection/events/event_dispatcher.dart';
import '../accident_detection/engine/detection_engine.dart';
import '../core/severity_engine.dart';
import '../services/voice_alert_service.dart';
import '../services/plus_code_service.dart';
import '../services/live_tracking_service.dart';
import '../services/socket_service.dart';

import 'package:flutter/foundation.dart';

enum EmergencyState { idle, countdown, alerting, completed, cancelled }

class EmergencyService {
  final DetectionEngine detectionEngine;
  final CountdownManager _countdownManager;
  final LocationService _locationService;
  final SMSService _smsService;
  final SocketService _socketService;

  final List<String> emergencyContacts;

  bool _isEmergencyActive = false;
  StreamSubscription? _accidentSub;
  Timer? _cooldownTimer;

  // State stream for UI reactivity
  final _stateController = StreamController<EmergencyState>.broadcast();
  Stream<EmergencyState> get stateStream => _stateController.stream;

  /// Exposes the countdown tick stream for UI rendering
  Stream<CountdownTick> get countdownTicks => _countdownManager.tickStream;

  EmergencyState _currentState = EmergencyState.idle;
  EmergencyState get currentState => _currentState;

  EmergencyService({
    required this.detectionEngine,
    required this.emergencyContacts,
    CountdownManager? countdownManager,
    LocationService? locationService,
    SMSService? smsService,
    SocketService? socketService,
  }) : _countdownManager = countdownManager ?? CountdownManager(),
       _locationService = locationService ?? LocationService(),
       _smsService = smsService ?? SMSService(),
       _socketService = socketService ?? SocketService();

  /// Starts listening to the DetectionEngine streams for accident trigger
  void listen() {
    _accidentSub = detectionEngine.accidentEvents.listen((eventData) {
      if (eventData.type == EngineEvent.accidentDetected) {
        _handleAccidentDetected();
      }
    });
    print('[Emergency] Listening for accident events...');
  }

  void _emitState(EmergencyState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  Future<void> _handleAccidentDetected() async {
    // Cooldown/Concurrency check
    if (_isEmergencyActive) {
      print(
        '[Emergency] Emergency already active, ignoring duplicate trigger.',
      );
      return;
    }

    _isEmergencyActive = true;
    print('[Emergency] Accident detected event received');

    // Phase 1: Countdown + Voice Alert
    _emitState(EmergencyState.countdown);
    await VoiceAlertService().announceAccidentDetected();
    bool completed = await _countdownManager.startCountdown();

    if (!completed) {
      print('[Emergency] Flow cancelled by user');
      _isEmergencyActive = false;
      _emitState(EmergencyState.cancelled);
      // Auto-return to idle after a brief delay
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer(const Duration(seconds: 3), () {
        _emitState(EmergencyState.idle);
      });
      return;
    }

    // Phase 2: Alerting
    _emitState(EmergencyState.alerting);

    // Fetch GPS Location
    final position = await _locationService.fetchLocation();

    if (position == null) {
      print(
        '[Error][Emergency] Critical failure: Location unavailable, falling back gracefully.',
      );
    }

    final lat = position?.latitude ?? 0.0;
    final lng = position?.longitude ?? 0.0;
    final confidence = detectionEngine.confidenceScore;

    // Compute severity from detection engine metrics
    final severityResult = SeverityEngine.compute(
      peakAccelGs: confidence * 8.0, // approximate from confidence
      peakGyroRads: confidence * 10.0,
      preImpactSpeedKmh: 0.0,
    );

    // Compute Plus Code
    // final plusCode = PlusCodeService.encode(lat, lng);

    // Compute Plus Code; continue even if generation fails.
    String plusCode = '';

    try {
      plusCode = PlusCodeService.encode(lat, lng);
    } catch (e) {
      debugPrint('[Emergency] Plus Code generation failed: $e');
    }

    // Phase 3: Alert the command centre (socket) and emergency contacts (SMS)
    // in parallel with error isolation. The socket emit is the primary,
    // always-available path: it works with or without Firebase configured
    // on the phone, queues while offline, and returns the authoritative
    // incident id for live tracking.
    final results = await Future.wait([
      _safeSendSMS(lat, lng, confidence),
      _safeCreateIncidentViaSocket(
        lat,
        lng,
        confidence,
        severityResult,
        plusCode,
      ),
    ]);

    bool smsOk = results[0];
    bool incidentOk = results[1];

    if (incidentOk) {
      await VoiceAlertService().announceHelpDispatched();
    }

    if (smsOk || incidentOk) {
      print(
        '[Emergency] Alert triggered (SMS: $smsOk, CommandCentre: $incidentOk)',
      );
    } else {
      print('[Error][Emergency] Both SMS and command-centre dispatch failed');
    }

    // Phase 4: Completed
    _emitState(EmergencyState.completed);
    print('[Emergency] Flow completed');

    // Cooldown: properly tracked and cancellable
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(minutes: 5), () {
      _isEmergencyActive = false;
      _emitState(EmergencyState.idle);
    });
  }

  Future<bool> _safeSendSMS(double lat, double lng, double confidence) async {
    try {
      await _smsService.sendEmergencySMS(
        contacts: emergencyContacts,
        latitude: lat,
        longitude: lng,
        confidenceScore: confidence,
      );
      return true;
    } catch (e) {
      print('[Error][Emergency] SMS dispatch failed: $e');
      return false;
    }
  }

  /// Creates the incident on the command centre over Socket.IO (primary
  /// path) and starts live location tracking with the authoritative id
  /// returned by the backend ACK. Never throws - returns false on failure.
  Future<bool> _safeCreateIncidentViaSocket(
    double lat,
    double lng,
    double confidence,
    SeverityResult severityResult,
    String plusCode,
  ) async {
    try {
      final completer = Completer<bool>();
      _socketService.emitCreateIncidentWithAck(
        {
          'latitude': lat,
          'longitude': lng,
          'confidence': confidence,
          'severity': severityResult.label,
          'severityScore': severityResult.score,
          'plusCode': plusCode,
        },
        (ack) {
          if (ack is Map && ack['success'] == true) {
            final id = ack['incidentId'];
            final queued = ack['queued'] == true;
            // Start live tracking with the backend-assigned id. When the
            // event was only queued (offline), tracking starts after the
            // reconnect flush - the ACK then carries the real id, which the
            // backend's incident_created broadcast mirrors.
            if (!queued && id is String && id.isNotEmpty) {
              LiveTrackingService().startTracking(id);
            }
            completer.complete(true);
          } else {
            completer.complete(false);
          }
        },
      );
      return await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
    } catch (e) {
      print('[Error][Emergency] Socket incident creation failed: $e');
      return false;
    }
  }

  /// Cancels the ongoing countdown or resets active emergency states programmatically
  void cancelEmergency() {
    if (_currentState == EmergencyState.countdown) {
      _countdownManager.cancel();
    } else if (_currentState == EmergencyState.alerting ||
        _currentState == EmergencyState.completed) {
      _cooldownTimer?.cancel();
      _isEmergencyActive = false;
      _emitState(EmergencyState.idle);
    }
  }

  void dispose() {
    _accidentSub?.cancel();
    _cooldownTimer?.cancel();
    _countdownManager.dispose();
    _stateController.close();
  }
}
