import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sanare_mobile/recording/local_segment_store.dart';
import 'package:sanare_mobile/recording/progressive_upload_service.dart';

void main() {
  late MemorySegmentStore store;
  late FakeConnectivity connectivity;
  late FakeSegmentBackend backend;
  late ProgressiveUploadService service;
  late Directory temporaryDirectory;

  setUp(() async {
    store = MemorySegmentStore();
    connectivity = FakeConnectivity();
    backend = FakeSegmentBackend();
    service = ProgressiveUploadService(store: store, connectivity: connectivity)
      ..configure(backend);
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'sanare_segments_test',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
    await connectivity.close();
  });

  Future<File> audio(String name, {List<int> bytes = const [1, 2, 3]}) async {
    final file = File('${temporaryDirectory.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> begin() => service.beginSession(
    sessionUuid: '550e8400-e29b-41d4-a716-446655440000',
    patientId: 9,
    startedAt: DateTime(2026, 7, 13, 10),
  );

  Future<void> settle() async {
    for (var index = 0; index < 10; index++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('guarda localmente y sube un segmento con checksum', () async {
    await begin();
    final file = await audio('segment_001.m4a');

    await service.registerSegment(
      sessionUuid: '550e8400-e29b-41d4-a716-446655440000',
      segmentNumber: 1,
      localPath: file.path,
      duration: const Duration(seconds: 60),
      isFinal: false,
    );
    await settle();

    expect(store.segments, hasLength(1));
    expect(store.segments.single.fileSize, 3);
    expect(store.segments.single.checksum, hasLength(64));
    expect(store.segments.single.uploadStatus, SegmentUploadStatus.uploaded);
    expect(backend.uploaded.single.segmentNumber, 1);
  });

  test('recupera uploading como pending después de reiniciar', () async {
    store.segments.add(
      segment(status: SegmentUploadStatus.uploading, path: '/pending.m4a'),
    );
    connectivity.connected = false;

    await service.initialize();

    expect(store.segments.single.uploadStatus, SegmentUploadStatus.pending);
  });

  test('reanuda automáticamente cuando vuelve Internet', () async {
    connectivity.connected = false;
    await begin();
    final file = await audio('offline.m4a');
    await service.registerSegment(
      sessionUuid: '550e8400-e29b-41d4-a716-446655440000',
      segmentNumber: 1,
      localPath: file.path,
      duration: const Duration(seconds: 60),
      isFinal: false,
    );
    expect(store.segments.single.uploadStatus, SegmentUploadStatus.pending);

    connectivity.emit(true);
    await settle();

    expect(store.segments.single.uploadStatus, SegmentUploadStatus.uploaded);
  });

  test('no reactiva automáticamente un segmento que ya falló', () async {
    await begin();
    store.segments.add(
      segment(status: SegmentUploadStatus.failed, path: '/failed.m4a'),
    );

    connectivity.emit(true);
    await settle();

    expect(store.segments.single.uploadStatus, SegmentUploadStatus.failed);
    expect(backend.uploaded, isEmpty);
  });

  test('reactiva una consulta fallida solamente por acción manual', () async {
    await begin();
    final file = await audio('manual_retry.m4a');
    store.segments.add(
      segment(status: SegmentUploadStatus.failed, path: file.path),
    );
    await store.setProcessingStatus(
      '550e8400-e29b-41d4-a716-446655440000',
      'failed',
    );

    final retried = await service.retryConsultation(41);

    expect(retried, isTrue);
    expect(store.segments.single.uploadStatus, SegmentUploadStatus.uploaded);
    expect(backend.retriedConsultationId, 41);
    expect(store.sessions.single.processingStatus, 'transcribing');
  });

  test(
    'crea código local offline y lo sincroniza sin cambiar el UUID',
    () async {
      connectivity.connected = false;
      await begin();
      final local = store.sessions.single;
      expect(local.localConsultationCode, startsWith('LOCAL-'));
      expect(local.processingStatus, 'pending_sync');

      connectivity.emit(true);
      await settle();

      final synced = store.sessions.single;
      expect(backend.receivedLocalCode, local.localConsultationCode);
      expect(backend.receivedCreatedOffline, isTrue);
      expect(synced.consultationCode, 'C-13-07-2026-000041');
      expect(synced.sessionUuid, local.sessionUuid);
    },
  );

  test(
    'conserva localmente el fallo aunque el servidor no esté disponible',
    () async {
      connectivity.connected = false;
      await begin();
      await service.recordFailure(
        sessionUuid: '550e8400-e29b-41d4-a716-446655440000',
        stage: 'recording',
        code: 'MICROPHONE_START_FAILED',
        message: 'No se pudo iniciar la grabación.',
      );

      expect(store.sessions.single.processingStatus, 'failed');
      expect(store.sessions.single.failureStage, 'recording');
    },
  );

  test('no elimina el archivo después de confirmarlo', () async {
    await begin();
    final file = await audio('keep.m4a');
    await service.registerSegment(
      sessionUuid: '550e8400-e29b-41d4-a716-446655440000',
      segmentNumber: 1,
      localPath: file.path,
      duration: const Duration(seconds: 10),
      isFinal: true,
    );
    await settle();

    expect(await file.exists(), isTrue);
  });

  test('registra y finaliza el último segmento', () async {
    await begin();
    final file = await audio('final.m4a');
    await service.registerSegment(
      sessionUuid: '550e8400-e29b-41d4-a716-446655440000',
      segmentNumber: 1,
      localPath: file.path,
      duration: const Duration(seconds: 12),
      isFinal: true,
    );
    await service.finishSession(
      sessionUuid: '550e8400-e29b-41d4-a716-446655440000',
      expectedSegments: 1,
    );

    expect(store.segments.single.isFinal, isTrue);
    expect(store.sessions.single.expectedSegments, 1);
    expect(backend.finalizedExpectedSegments, 1);
  });

  test('calcula duración total desde segmentos persistidos', () async {
    store.segments.addAll([
      segment(number: 1, duration: 60),
      segment(number: 2, duration: 18),
    ]);

    expect(
      await service.totalDurationSeconds(
        '550e8400-e29b-41d4-a716-446655440000',
      ),
      78,
    );
  });

  test('maneja archivo inexistente sin crear registro', () async {
    await begin();
    await service.registerSegment(
      sessionUuid: '550e8400-e29b-41d4-a716-446655440000',
      segmentNumber: 1,
      localPath: '${temporaryDirectory.path}/missing.m4a',
      duration: const Duration(seconds: 60),
      isFinal: false,
    );

    expect(store.segments, isEmpty);
    expect(service.message, contains('No se encontró'));
  });

  test('maneja archivo vacío sin intentar subirlo', () async {
    await begin();
    final file = await audio('empty.m4a', bytes: const []);
    await service.registerSegment(
      sessionUuid: '550e8400-e29b-41d4-a716-446655440000',
      segmentNumber: 1,
      localPath: file.path,
      duration: Duration.zero,
      isFinal: true,
    );

    expect(store.segments, isEmpty);
    expect(service.message, contains('vacío'));
    expect(backend.uploaded, isEmpty);
  });

  test('conserva el segmento si la subida falla', () async {
    backend.failUploads = true;
    await begin();
    final file = await audio('failure.m4a');
    await service.registerSegment(
      sessionUuid: '550e8400-e29b-41d4-a716-446655440000',
      segmentNumber: 1,
      localPath: file.path,
      duration: const Duration(seconds: 60),
      isFinal: false,
    );
    await settle();

    expect(store.segments.single.uploadStatus, SegmentUploadStatus.pending);
    expect(await file.exists(), isTrue);
    expect(service.message, contains('permanece guardado'));
  });

  test('expone estados visuales de procesamiento', () async {
    await begin();
    backend.snapshot = const ProcessingSnapshot(
      consultationId: 41,
      sessionUuid: '550e8400-e29b-41d4-a716-446655440000',
      status: 'transcribing',
      soapStatus: 'pending',
      progress: 70,
      message: 'Transcribiendo audio',
      expectedSegments: 3,
      receivedSegments: 3,
      transcribedSegments: 2,
      failedSegments: 0,
    );

    final snapshot = await service.pollStatus(
      '550e8400-e29b-41d4-a716-446655440000',
    );

    expect(snapshot!.status, 'transcribing');
    expect(snapshot.progress, 70);
    expect(service.message, 'Transcribiendo audio');
  });

  test('recupera una consulta pendiente persistida', () async {
    await begin();
    await store.finishSession('550e8400-e29b-41d4-a716-446655440000', 2);

    final sessions = await service.recoverableSessions();

    expect(sessions.single.recordingStatus, 'finished');
    expect(sessions.single.expectedSegments, 2);
  });

  test('cancela los envíos pendientes sin borrar el audio local', () async {
    await begin();
    connectivity.connected = false;
    final file = await audio('cancelled.m4a');
    await service.registerSegment(
      sessionUuid: '550e8400-e29b-41d4-a716-446655440000',
      segmentNumber: 1,
      localPath: file.path,
      duration: const Duration(seconds: 60),
      isFinal: true,
    );

    await service.cancelSession('550e8400-e29b-41d4-a716-446655440000');

    expect(store.sessions.single.processingStatus, 'discarded');
    expect(store.segments.single.uploadStatus, SegmentUploadStatus.cancelled);
    expect(await file.exists(), isTrue);
    expect(backend.cancelledConsultationId, 41);
    expect(service.pendingCount, 0);
  });
}

LocalAudioSegment segment({
  int number = 1,
  int duration = 60,
  String path = '/segment.m4a',
  SegmentUploadStatus status = SegmentUploadStatus.pending,
}) => LocalAudioSegment(
  id: number,
  sessionUuid: '550e8400-e29b-41d4-a716-446655440000',
  consultationId: 41,
  segmentNumber: number,
  localPath: path,
  durationSeconds: duration,
  fileSize: 3,
  checksum: 'a' * 64,
  uploadStatus: status,
  retryCount: 0,
  isFinal: false,
  createdAt: DateTime(2026, 7, 13, 10, number),
);

class MemorySegmentStore implements LocalSegmentStore {
  final sessions = <LocalRecordingSession>[];
  final segments = <LocalAudioSegment>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> recoverInterruptedUploads() async {
    for (var index = 0; index < segments.length; index++) {
      if (segments[index].uploadStatus == SegmentUploadStatus.uploading) {
        segments[index] = copySegment(
          segments[index],
          status: SegmentUploadStatus.pending,
        );
      }
    }
  }

  @override
  Future<void> saveSession(LocalRecordingSession session) async {
    sessions.removeWhere((item) => item.sessionUuid == session.sessionUuid);
    sessions.add(session);
  }

  @override
  Future<LocalRecordingSession?> session(String sessionUuid) async {
    final matches = sessions.where((item) => item.sessionUuid == sessionUuid);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<List<LocalRecordingSession>> recoverableSessions() async =>
      sessions.where((item) => item.processingStatus != 'completed').toList();

  @override
  Future<void> setRemoteConsultation(
    String sessionUuid,
    int consultationId, {
    String? consultationCode,
  }) async {
    final current = await session(sessionUuid);
    if (current == null) return;
    await saveSession(
      LocalRecordingSession(
        sessionUuid: current.sessionUuid,
        patientId: current.patientId,
        consultationId: consultationId,
        startedAt: current.startedAt,
        recordingStatus: current.recordingStatus,
        processingStatus: current.processingStatus,
        expectedSegments: current.expectedSegments,
        consultationCode: consultationCode,
        localConsultationCode: current.localConsultationCode,
      ),
    );
  }

  @override
  Future<void> finishSession(String sessionUuid, int expectedSegments) async {
    final current = await session(sessionUuid);
    if (current == null) return;
    await saveSession(
      LocalRecordingSession(
        sessionUuid: current.sessionUuid,
        patientId: current.patientId,
        consultationId: current.consultationId,
        startedAt: current.startedAt,
        recordingStatus: 'finished',
        processingStatus: 'uploading',
        expectedSegments: expectedSegments,
      ),
    );
  }

  @override
  Future<void> setProcessingStatus(String sessionUuid, String status) async {
    final current = await session(sessionUuid);
    if (current == null) return;
    await saveSession(
      LocalRecordingSession(
        sessionUuid: current.sessionUuid,
        patientId: current.patientId,
        consultationId: current.consultationId,
        startedAt: current.startedAt,
        recordingStatus: current.recordingStatus,
        processingStatus: status,
        expectedSegments: current.expectedSegments,
      ),
    );
  }

  @override
  Future<void> cancelSession(String sessionUuid) async {
    await setProcessingStatus(sessionUuid, 'discarded');
    for (var index = 0; index < segments.length; index++) {
      final item = segments[index];
      if (item.sessionUuid == sessionUuid &&
          item.uploadStatus != SegmentUploadStatus.uploaded) {
        segments[index] = copySegment(
          item,
          status: SegmentUploadStatus.cancelled,
        );
      }
    }
  }

  @override
  Future<void> setSessionFailure(
    String sessionUuid,
    String stage,
    String message,
  ) async {
    final current = await session(sessionUuid);
    if (current == null) return;
    await saveSession(
      LocalRecordingSession(
        sessionUuid: current.sessionUuid,
        patientId: current.patientId,
        consultationId: current.consultationId,
        startedAt: current.startedAt,
        recordingStatus: current.recordingStatus,
        processingStatus: 'failed',
        expectedSegments: current.expectedSegments,
        consultationCode: current.consultationCode,
        localConsultationCode: current.localConsultationCode,
        failureStage: stage,
        failureMessage: message,
      ),
    );
  }

  @override
  Future<void> insertSegment(LocalAudioSegment value) async {
    if (segments.any(
      (item) =>
          item.sessionUuid == value.sessionUuid &&
          item.segmentNumber == value.segmentNumber,
    )) {
      return;
    }
    segments.add(
      copySegment(value, id: segments.length + 1, useProvidedId: true),
    );
  }

  @override
  Future<List<LocalAudioSegment>> uploadCandidates({
    bool includeFailed = false,
  }) async => segments
      .where(
        (item) =>
            item.uploadStatus == SegmentUploadStatus.pending ||
            (includeFailed && item.uploadStatus == SegmentUploadStatus.failed),
      )
      .where(
        (item) =>
            item.nextAttemptAt == null ||
            !item.nextAttemptAt!.isAfter(DateTime.now()),
      )
      .toList();

  @override
  Future<List<LocalAudioSegment>> segmentsForSession(
    String sessionUuid,
  ) async => segments.where((item) => item.sessionUuid == sessionUuid).toList();

  @override
  Future<void> retryFailedSegments(String sessionUuid) async {
    for (var index = 0; index < segments.length; index++) {
      if (segments[index].sessionUuid == sessionUuid &&
          segments[index].uploadStatus == SegmentUploadStatus.failed) {
        segments[index] = copySegment(
          segments[index],
          status: SegmentUploadStatus.pending,
          retryCount: 0,
        );
      }
    }
  }

  @override
  Future<void> updateSegmentUpload(
    int id,
    SegmentUploadStatus status, {
    int? retryCount,
    int? consultationId,
    String? errorMessage,
    DateTime? nextAttemptAt,
  }) async {
    final index = segments.indexWhere((item) => item.id == id);
    if (index < 0) return;
    segments[index] = copySegment(
      segments[index],
      status: status,
      retryCount: retryCount,
      consultationId: consultationId,
      errorMessage: errorMessage,
      nextAttemptAt: nextAttemptAt,
    );
  }

  @override
  Future<int> totalDurationSeconds(String sessionUuid) async {
    var total = 0;
    for (final item in segments.where(
      (item) => item.sessionUuid == sessionUuid,
    )) {
      total += item.durationSeconds;
    }
    return total;
  }
}

LocalAudioSegment copySegment(
  LocalAudioSegment source, {
  int? id,
  bool useProvidedId = false,
  SegmentUploadStatus? status,
  int? retryCount,
  int? consultationId,
  String? errorMessage,
  DateTime? nextAttemptAt,
}) => LocalAudioSegment(
  id: useProvidedId ? id : source.id,
  sessionUuid: source.sessionUuid,
  consultationId: consultationId ?? source.consultationId,
  segmentNumber: source.segmentNumber,
  localPath: source.localPath,
  durationSeconds: source.durationSeconds,
  fileSize: source.fileSize,
  checksum: source.checksum,
  uploadStatus: status ?? source.uploadStatus,
  retryCount: retryCount ?? source.retryCount,
  isFinal: source.isFinal,
  createdAt: source.createdAt,
  errorMessage: errorMessage,
  nextAttemptAt: nextAttemptAt,
);

class FakeConnectivity implements ConnectivityMonitor {
  final _controller = StreamController<bool>.broadcast();
  bool connected = true;

  @override
  Stream<bool> get changes => _controller.stream;

  @override
  Future<bool> isConnected() async => connected;

  void emit(bool value) {
    connected = value;
    _controller.add(value);
  }

  Future<void> close() => _controller.close();
}

class FakeSegmentBackend implements SegmentBackendClient {
  final uploaded = <LocalAudioSegment>[];
  bool failUploads = false;
  int? finalizedExpectedSegments;
  String? receivedLocalCode;
  bool? receivedCreatedOffline;
  int? cancelledConsultationId;
  int? retriedConsultationId;
  ProcessingSnapshot snapshot = const ProcessingSnapshot(
    consultationId: 41,
    sessionUuid: '550e8400-e29b-41d4-a716-446655440000',
    status: 'recording',
    soapStatus: 'pending',
    progress: 0,
    message: 'Grabando consulta',
    expectedSegments: 0,
    receivedSegments: 0,
    transcribedSegments: 0,
    failedSegments: 0,
  );

  @override
  Future<BackendRecordingSession> startRecordingSession({
    required String sessionUuid,
    required int patientId,
    required DateTime startedAt,
    required String localConsultationCode,
    required bool createdOffline,
  }) async {
    receivedLocalCode = localConsultationCode;
    receivedCreatedOffline = createdOffline;
    return BackendRecordingSession(
      consultationId: 41,
      sessionUuid: sessionUuid,
      consultationCode: 'C-13-07-2026-000041',
    );
  }

  @override
  Future<String> uploadAudioSegment({
    required int consultationId,
    required LocalAudioSegment segment,
  }) async {
    if (failUploads) throw const SocketException('offline');
    uploaded.add(segment);
    return segment.checksum;
  }

  @override
  Future<void> finalizeRecordingSession({
    required int consultationId,
    required String sessionUuid,
    required int expectedSegments,
  }) async => finalizedExpectedSegments = expectedSegments;

  @override
  Future<ProcessingSnapshot> processingStatus(int consultationId) async =>
      snapshot;

  @override
  Future<void> retryProcessing(int consultationId) async {
    retriedConsultationId = consultationId;
  }

  @override
  Future<void> cancelProcessing(int consultationId) async {
    cancelledConsultationId = consultationId;
  }

  @override
  Future<void> reportConsultationFailure({
    required int consultationId,
    required String stage,
    required String code,
    required String message,
  }) async {}
}
