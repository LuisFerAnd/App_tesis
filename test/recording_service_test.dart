import 'package:flutter_test/flutter_test.dart';
import 'package:sanare_mobile/recording/foreground_recording_bridge.dart';
import 'package:sanare_mobile/recording/recording_service.dart';

void main() {
  late FakeRecordingEngine engine;
  late FakeForegroundBridge foreground;
  late MemoryPersistence persistence;
  late RecordingService service;

  setUp(() {
    engine = FakeRecordingEngine();
    foreground = FakeForegroundBridge();
    persistence = MemoryPersistence();
    service = RecordingService(
      engine: engine,
      foregroundBridge: foreground,
      persistence: persistence,
      pathFactory: (name) async => '/recordings/$name',
      counterInterval: const Duration(milliseconds: 5),
      healthCheckInterval: const Duration(hours: 1),
    );
  });

  Future<void> start() async {
    expect(await service.startRecording(patientId: 17), isTrue);
  }

  tearDown(() async {
    if (service.hasRecoverableSession) await service.stopRecording();
  });

  test('inicia y detiene una grabación confirmada', () async {
    await start();
    expect(service.status, RecordingStatus.recording);
    expect(foreground.running, isTrue);

    final result = await service.stopRecording();

    expect(service.status, RecordingStatus.stopped);
    expect(result!.paths, hasLength(1));
    expect(result.paths.single, contains('_segment_001.m4a'));
    expect(foreground.running, isFalse);
  });

  test('pausa y continúa solo después de confirmar el micrófono', () async {
    await start();
    expect(await service.pauseRecording(), isTrue);
    expect(service.status, RecordingStatus.paused);
    expect(engine.paused, isTrue);

    expect(await service.resumeRecording(), isTrue);
    expect(service.status, RecordingStatus.recording);
    expect(engine.recording, isTrue);
    expect(engine.paused, isFalse);
  });

  test('el contador no avanza durante una pausa prolongada', () async {
    await start();
    await Future<void>.delayed(const Duration(milliseconds: 25));
    await service.pauseRecording();
    final pausedDuration = service.duration;

    await Future<void>.delayed(const Duration(milliseconds: 35));

    expect(service.duration, pausedDuration);
  });

  test('ignora pulsaciones duplicadas de continuar', () async {
    await start();
    await service.pauseRecording();
    engine.resumeDelay = const Duration(milliseconds: 30);

    final first = service.resumeRecording();
    final second = service.resumeRecording();

    expect(await second, isFalse);
    expect(await first, isTrue);
    expect(engine.resumeCalls, 1);
  });

  test('si resume falla crea automáticamente un segmento nuevo', () async {
    await start();
    await service.pauseRecording();
    engine.failNextResume = true;

    expect(await service.resumeRecording(), isTrue);

    expect(service.status, RecordingStatus.recording);
    expect(service.segments, hasLength(2));
    expect(service.segments[0], contains('_segment_001.m4a'));
    expect(service.segments[1], contains('_segment_002.m4a'));
    expect(engine.startCalls, 2);
  });

  test('nunca publica Grabando si el grabador no está activo', () async {
    engine.confirmStart = false;

    expect(await service.startRecording(patientId: 17), isFalse);

    expect(service.status, RecordingStatus.error);
    expect(service.status.label, isNot('Grabando'));
    expect(foreground.running, isFalse);
  });

  test('sin permiso de micrófono no inicia grabador ni servicio', () async {
    engine.permissionGranted = false;

    expect(await service.startRecording(patientId: 17), isFalse);

    expect(engine.startCalls, 0);
    expect(foreground.startCalls, 0);
    expect(service.hasRecoverableSession, isFalse);
  });

  test('al volver a primer plano recupera un grabador inactivo', () async {
    await start();
    engine.recording = false;

    await service.syncRecordingState();

    expect(service.status, RecordingStatus.recording);
    expect(service.segments, hasLength(2));
  });

  test('recupera también si Android perdió el servicio foreground', () async {
    await start();
    foreground.running = false;

    await service.syncRecordingState();

    expect(service.status, RecordingStatus.recording);
    expect(foreground.running, isTrue);
    expect(service.segments, hasLength(2));
  });

  test(
    'restaura una sesión incompleta sin asumir que sigue grabando',
    () async {
      persistence.value = {
        'session_id': 'session-1',
        'consultation_code': 'C-13-07-2026-001',
        'status': 'recording',
        'started_at': '2026-07-13T10:00:00.000',
        'duration_ms': 120000,
        'current_path': '/recordings/parte_002.m4a',
        'segments': ['/recordings/parte_001.m4a'],
        'part_number': 2,
        'patient_id': 17,
      };

      expect(await service.initialize(), isTrue);

      expect(service.status, RecordingStatus.paused);
      expect(service.duration, const Duration(minutes: 2));
      expect(service.segments, [
        '/recordings/parte_001.m4a',
        '/recordings/parte_002.m4a',
      ]);
    },
  );

  test('varias pausas y reanudaciones conservan una sola sesión', () async {
    await start();
    for (var index = 0; index < 3; index++) {
      expect(await service.pauseRecording(), isTrue);
      expect(await service.resumeRecording(), isTrue);
    }

    expect(engine.startCalls, 1);
    expect(service.segments, hasLength(1));
  });

  test('detener dos veces no duplica rutas ni operaciones', () async {
    await start();

    final first = await service.stopRecording();
    final second = await service.stopRecording();

    expect(first!.paths, hasLength(1));
    expect(second, isNull);
    expect(engine.stopCalls, 1);
  });

  test(
    'fallo total de recuperación conserva fragmentos y detiene servicio',
    () async {
      await start();
      await service.pauseRecording();
      engine.failNextResume = true;
      engine.failStartsAfter = 1;

      expect(await service.resumeRecording(), isFalse);

      expect(service.status, RecordingStatus.error);
      expect(service.segments.single, contains('_segment_001.m4a'));
      expect(foreground.running, isFalse);
      expect(service.errorMessage, contains('fragmentos'));
    },
  );

  test('finaliza varios segmentos conservando su orden', () async {
    await start();
    await service.pauseRecording();
    engine.failNextResume = true;
    await service.resumeRecording();

    final result = await service.stopRecording();

    expect(result!.paths[0], contains('_segment_001.m4a'));
    expect(result.paths[1], contains('_segment_002.m4a'));
  });

  test('persiste metadatos y rutas antes de procesos posteriores', () async {
    await start();
    await service.pauseRecording();

    expect(persistence.value!['status'], 'paused');
    expect(persistence.value!['session_id'], isNotEmpty);
    expect(persistence.value!['current_path'], contains('_segment_001.m4a'));
    expect(persistence.value!['patient_id'], 17);
  });

  test('cierra segmentos automáticamente sin detener la sesión', () async {
    final finalized = <RecordingSegmentEvent>[];
    service = RecordingService(
      engine: engine,
      foregroundBridge: foreground,
      persistence: persistence,
      pathFactory: (name) async => '/recordings/$name',
      counterInterval: const Duration(milliseconds: 5),
      healthCheckInterval: const Duration(hours: 1),
      segmentDuration: const Duration(milliseconds: 20),
    )..onSegmentFinalized = (segment) async => finalized.add(segment);

    await start();
    await Future<void>.delayed(const Duration(milliseconds: 55));

    expect(service.status, RecordingStatus.recording);
    expect(engine.startCalls, greaterThanOrEqualTo(3));
    expect(finalized, isNotEmpty);
    expect(finalized.first.isFinal, isFalse);
    expect(finalized.first.path, contains('_segment_001.m4a'));
  });

  test('usa segmentos de cinco minutos por defecto', () {
    final defaultService = RecordingService(
      engine: engine,
      foregroundBridge: foreground,
      persistence: persistence,
      pathFactory: (name) async => '/recordings/$name',
    );

    expect(defaultService.segmentDuration, const Duration(minutes: 5));
    defaultService.dispose();
  });
}

class FakeRecordingEngine implements RecordingEngine {
  bool permissionGranted = true;
  bool confirmStart = true;
  bool recording = false;
  bool paused = false;
  bool failNextResume = false;
  int? failStartsAfter;
  Duration resumeDelay = Duration.zero;
  int startCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  String? currentPath;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<void> start(String path) async {
    startCalls++;
    if (failStartsAfter != null && startCalls > failStartsAfter!) {
      throw StateError('start failed');
    }
    currentPath = path;
    recording = confirmStart;
    paused = false;
  }

  @override
  Future<void> pause() async {
    if (!recording) throw StateError('not recording');
    paused = true;
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    if (resumeDelay > Duration.zero) await Future<void>.delayed(resumeDelay);
    if (failNextResume) {
      failNextResume = false;
      recording = false;
      paused = false;
      throw StateError('resume failed');
    }
    recording = true;
    paused = false;
  }

  @override
  Future<String?> stop() async {
    stopCalls++;
    recording = false;
    paused = false;
    return currentPath;
  }

  @override
  Future<bool> isRecording() async => recording;

  @override
  Future<bool> isPaused() async => paused;
}

class FakeForegroundBridge implements ForegroundRecordingBridge {
  bool running = false;
  bool notifications = true;
  int startCalls = 0;

  @override
  Future<bool> start() async {
    startCalls++;
    running = true;
    return true;
  }

  @override
  Future<void> stop() async => running = false;

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<bool> ensureNotificationPermission() async => notifications;

  @override
  Future<bool> areNotificationsEnabled() async => notifications;
}

class MemoryPersistence implements RecordingSessionPersistence {
  Map<String, dynamic>? value;

  @override
  Future<Map<String, dynamic>?> read() async => value;

  @override
  Future<void> write(Map<String, dynamic> value) async {
    this.value = Map<String, dynamic>.from(value);
  }

  @override
  Future<void> clear() async => value = null;
}
