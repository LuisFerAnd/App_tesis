import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'local_segment_store.dart';
import 'segment_file.dart';

class BackendRecordingSession {
  const BackendRecordingSession({
    required this.consultationId,
    required this.sessionUuid,
    this.consultationCode,
  });

  final int consultationId;
  final String sessionUuid;
  final String? consultationCode;
}

class ProcessingSnapshot {
  const ProcessingSnapshot({
    required this.consultationId,
    required this.sessionUuid,
    required this.status,
    required this.soapStatus,
    required this.progress,
    required this.message,
    required this.expectedSegments,
    required this.receivedSegments,
    required this.transcribedSegments,
    required this.failedSegments,
    this.consultationCode,
    this.processingTimeMs,
    this.processingTimeSeconds,
    this.processingTimeRange,
    this.processingTimeLabel,
    this.errorCode,
    this.errorStage,
    this.retryCount = 0,
    this.soapGenerated = false,
    this.soap,
  });

  final int consultationId;
  final String sessionUuid;
  final String status;
  final String soapStatus;
  final int progress;
  final String message;
  final int expectedSegments;
  final int receivedSegments;
  final int transcribedSegments;
  final int failedSegments;
  final String? consultationCode;
  final int? processingTimeMs;
  final double? processingTimeSeconds;
  final int? processingTimeRange;
  final String? processingTimeLabel;
  final String? errorCode;
  final String? errorStage;
  final int retryCount;
  final bool soapGenerated;
  final Map<String, dynamic>? soap;

  bool get isTerminal =>
      status == 'completed' ||
      status == 'failed' ||
      status == 'timeout' ||
      status == 'cancelled';
}

abstract interface class SegmentBackendClient {
  Future<BackendRecordingSession> startRecordingSession({
    required String sessionUuid,
    required int patientId,
    required DateTime startedAt,
    required String localConsultationCode,
    required bool createdOffline,
  });

  Future<String> uploadAudioSegment({
    required int consultationId,
    required LocalAudioSegment segment,
  });

  Future<void> finalizeRecordingSession({
    required int consultationId,
    required String sessionUuid,
    required int expectedSegments,
  });

  Future<ProcessingSnapshot> processingStatus(int consultationId);

  Future<void> retryProcessing(int consultationId);

  Future<void> cancelProcessing(int consultationId);

  Future<void> reportConsultationFailure({
    required int consultationId,
    required String stage,
    required String code,
    required String message,
  });
}

abstract interface class ConnectivityMonitor {
  Stream<bool> get changes;

  Future<bool> isConnected();
}

class PluginConnectivityMonitor implements ConnectivityMonitor {
  PluginConnectivityMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<bool> get changes => _connectivity.onConnectivityChanged.map(
    (results) => !results.contains(ConnectivityResult.none),
  );

  @override
  Future<bool> isConnected() async => !(await _connectivity.checkConnectivity())
      .contains(ConnectivityResult.none);
}

class ProgressiveUploadService extends ChangeNotifier {
  ProgressiveUploadService({
    LocalSegmentStore? store,
    ConnectivityMonitor? connectivity,
  }) : _store = store ?? SqliteLocalSegmentStore(),
       _connectivity = connectivity ?? PluginConnectivityMonitor();

  static final ProgressiveUploadService instance = ProgressiveUploadService();
  static const _retryDelays = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  final LocalSegmentStore _store;
  final ConnectivityMonitor _connectivity;
  SegmentBackendClient? _client;
  Timer? _retryTimer;
  bool _initialized = false;
  bool _processing = false;
  final Set<String> _cancelledSessions = <String>{};
  String? _message;
  int _pendingCount = 0;

  String? get message => _message;
  int get pendingCount => _pendingCount;
  bool get isUploading => _processing;

  void configure(SegmentBackendClient client) {
    _client = client;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _store.initialize();
    await _store.recoverInterruptedUploads();
    _connectivity.changes.listen((connected) {
      if (!connected) {
        _message =
            'La grabación continúa. Algunos fragmentos están pendientes de '
            'envío y se subirán cuando se restablezca la conexión.';
        notifyListeners();
        return;
      }
      unawaited(_resumeAfterConnectivity());
    });
    unawaited(processPending());
  }

  Future<void> beginSession({
    required String sessionUuid,
    required int patientId,
    required DateTime startedAt,
  }) async {
    await initialize();
    final connected = await _connectivity.isConnected();
    await _store.saveSession(
      LocalRecordingSession(
        sessionUuid: sessionUuid,
        patientId: patientId,
        startedAt: startedAt,
        recordingStatus: 'recording',
        processingStatus: connected ? 'recording' : 'pending_sync',
        localConsultationCode: _localCode(startedAt, sessionUuid),
      ),
    );
    await _ensureRemoteSession(sessionUuid);
  }

  String _localCode(DateTime startedAt, String sessionUuid) {
    final date =
        '${startedAt.year.toString().padLeft(4, '0')}${startedAt.month.toString().padLeft(2, '0')}${startedAt.day.toString().padLeft(2, '0')}';
    return 'LOCAL-$date-${sessionUuid.replaceAll('-', '').substring(0, 8).toUpperCase()}';
  }

  Future<void> registerSegment({
    required String sessionUuid,
    required int segmentNumber,
    required String localPath,
    required Duration duration,
    required bool isFinal,
  }) async {
    await initialize();
    try {
      final metadata = await inspectSegmentFile(localPath);
      final session = await _store.session(sessionUuid);
      await _store.insertSegment(
        LocalAudioSegment(
          sessionUuid: sessionUuid,
          consultationId: session?.consultationId,
          segmentNumber: segmentNumber,
          localPath: localPath,
          durationSeconds: duration.inSeconds,
          fileSize: metadata.size,
          checksum: metadata.sha256,
          uploadStatus: SegmentUploadStatus.pending,
          retryCount: 0,
          isFinal: isFinal,
          createdAt: DateTime.now(),
        ),
      );
      _message = 'El audio fue guardado. Hay fragmentos pendientes de envío.';
      notifyListeners();
      unawaited(processPending());
    } catch (error) {
      _message = error.toString().contains('empty')
          ? 'El fragmento de audio quedó vacío y no puede enviarse.'
          : 'No se encontró un fragmento local. Los demás audios se conservaron.';
      debugPrint(
        '[RecordingUpload] Segment registration failed: ${error.runtimeType}',
      );
      await recordFailure(
        sessionUuid: sessionUuid,
        stage: 'local_storage',
        code: 'SEGMENT_REGISTRATION_FAILED',
        message: 'No se pudo registrar un fragmento local.',
      );
      notifyListeners();
    }
  }

  Future<void> finishSession({
    required String sessionUuid,
    required int expectedSegments,
  }) async {
    await _store.finishSession(sessionUuid, expectedSegments);
    await _ensureRemoteSession(sessionUuid);
    await _tryFinalize(sessionUuid);
    unawaited(processPending());
  }

  Future<void> recordFailure({
    required String sessionUuid,
    required String stage,
    required String code,
    required String message,
  }) async {
    await _store.setSessionFailure(sessionUuid, stage, message);
    final remote = await _ensureRemoteSession(sessionUuid);
    if (remote == null || _client == null) return;
    try {
      await _client!.reportConsultationFailure(
        consultationId: remote.consultationId,
        stage: stage,
        code: code,
        message: message,
      );
      await _store.setProcessingStatus(sessionUuid, 'failed');
    } catch (error) {
      debugPrint(
        '[RecordingUpload] Failure report pending: ${error.runtimeType}',
      );
    }
  }

  Future<void> processPending() async {
    final client = _client;
    if (_processing || client == null) return;
    if (!await _connectivity.isConnected()) {
      _message =
          'La grabación continúa. Algunos fragmentos están pendientes de '
          'envío y se subirán cuando se restablezca la conexión.';
      notifyListeners();
      return;
    }

    _processing = true;
    notifyListeners();
    try {
      while (true) {
        final candidates = await _store.uploadCandidates();
        _pendingCount = candidates.length;
        if (candidates.isEmpty) break;
        final segment = candidates.first;
        if (_cancelledSessions.contains(segment.sessionUuid)) break;
        final id = segment.id;
        if (id == null) break;
        final session = await _ensureRemoteSession(segment.sessionUuid);
        if (session == null) break;

        await _store.updateSegmentUpload(
          id,
          SegmentUploadStatus.uploading,
          consultationId: session.consultationId,
        );
        _message = 'Enviando segmentos';
        notifyListeners();
        try {
          final confirmedChecksum = await client.uploadAudioSegment(
            consultationId: session.consultationId,
            segment: LocalAudioSegment(
              id: segment.id,
              sessionUuid: segment.sessionUuid,
              consultationId: session.consultationId,
              segmentNumber: segment.segmentNumber,
              localPath: segment.localPath,
              durationSeconds: segment.durationSeconds,
              fileSize: segment.fileSize,
              checksum: segment.checksum,
              uploadStatus: SegmentUploadStatus.uploading,
              retryCount: segment.retryCount,
              isFinal: segment.isFinal,
              createdAt: segment.createdAt,
            ),
          );
          if (_cancelledSessions.contains(segment.sessionUuid)) break;
          if (confirmedChecksum.toLowerCase() !=
              segment.checksum.toLowerCase()) {
            throw StateError('server_checksum_mismatch');
          }
          await _store.updateSegmentUpload(
            id,
            SegmentUploadStatus.uploaded,
            retryCount: segment.retryCount,
            consultationId: session.consultationId,
          );
        } catch (error) {
          if (_cancelledSessions.contains(segment.sessionUuid)) break;
          await _handleUploadFailure(segment, error);
        }
      }
    } finally {
      _processing = false;
      final remaining = await _store.uploadCandidates(includeFailed: true);
      _pendingCount = remaining.length;
      notifyListeners();
    }
  }

  Future<void> retryNow() async {
    await _store.retryFailedSegments();
    _retryTimer?.cancel();
    await processPending();
    final client = _client;
    if (client == null) return;
    for (final session in await _store.recoverableSessions()) {
      if (session.consultationId != null &&
          session.processingStatus == 'failed') {
        try {
          await client.retryProcessing(session.consultationId!);
          await _store.setProcessingStatus(session.sessionUuid, 'transcribing');
        } catch (error) {
          debugPrint(
            '[RecordingUpload] Processing retry failed: ${error.runtimeType}',
          );
        }
      }
    }
  }

  Future<void> cancelSession(String sessionUuid) async {
    _cancelledSessions.add(sessionUuid);
    _retryTimer?.cancel();
    final local = await _store.session(sessionUuid);
    await _store.cancelSession(sessionUuid);
    if (local?.consultationId != null && _client != null) {
      try {
        await _client!.cancelProcessing(local!.consultationId!);
      } catch (error) {
        debugPrint(
          '[RecordingUpload] Remote cancellation pending: ${error.runtimeType}',
        );
      }
    }
    _pendingCount = (await _store.uploadCandidates(includeFailed: true)).length;
    _message =
        'Envío cancelado. El audio permanece guardado en el dispositivo.';
    notifyListeners();
  }

  Future<ProcessingSnapshot?> pollStatus(String sessionUuid) async {
    final session = await _store.session(sessionUuid);
    final client = _client;
    if (session?.consultationId == null || client == null) return null;
    try {
      final snapshot = await client.processingStatus(session!.consultationId!);
      await _store.setProcessingStatus(sessionUuid, snapshot.status);
      _message = snapshot.message;
      notifyListeners();
      return snapshot;
    } catch (error) {
      _message =
          'No se pudo consultar el servidor. El audio permanece guardado y '
          'se volverá a intentar automáticamente.';
      debugPrint('[RecordingUpload] Status poll failed: ${error.runtimeType}');
      notifyListeners();
      return null;
    }
  }

  Future<LocalRecordingSession?> session(String sessionUuid) =>
      _store.session(sessionUuid);

  Future<int> totalDurationSeconds(String sessionUuid) =>
      _store.totalDurationSeconds(sessionUuid);

  Future<List<LocalRecordingSession>> recoverableSessions() =>
      _store.recoverableSessions();

  Future<BackendRecordingSession?> _ensureRemoteSession(
    String sessionUuid,
  ) async {
    final local = await _store.session(sessionUuid);
    final client = _client;
    if (local == null || client == null) return null;
    if (local.consultationId != null) {
      return BackendRecordingSession(
        consultationId: local.consultationId!,
        sessionUuid: sessionUuid,
      );
    }
    if (!await _connectivity.isConnected()) return null;
    try {
      final remote = await client.startRecordingSession(
        sessionUuid: sessionUuid,
        patientId: local.patientId,
        startedAt: local.startedAt,
        localConsultationCode: local.localConsultationCode!,
        createdOffline: local.processingStatus == 'pending_sync',
      );
      await _store.setRemoteConsultation(
        sessionUuid,
        remote.consultationId,
        consultationCode: remote.consultationCode,
      );
      if (local.failureStage != null) {
        await client.reportConsultationFailure(
          consultationId: remote.consultationId,
          stage: local.failureStage!,
          code: 'RECOVERED_LOCAL_FAILURE',
          message: local.failureMessage ?? 'Fallo registrado localmente.',
        );
      }
      return remote;
    } catch (error) {
      _message =
          'No se pudo conectar con el servidor. El audio permanece guardado '
          'en el dispositivo y se volverá a intentar automáticamente.';
      debugPrint(
        '[RecordingUpload] Session start failed: ${error.runtimeType}',
      );
      _retryTimer?.cancel();
      _retryTimer = Timer(
        _retryDelays.first,
        () => unawaited(_resumeAfterConnectivity()),
      );
      notifyListeners();
      return null;
    }
  }

  Future<void> _tryFinalize(String sessionUuid) async {
    final local = await _store.session(sessionUuid);
    final client = _client;
    if (local == null ||
        client == null ||
        local.consultationId == null ||
        local.expectedSegments == null ||
        local.processingStatus != 'uploading') {
      return;
    }
    try {
      await client.finalizeRecordingSession(
        consultationId: local.consultationId!,
        sessionUuid: sessionUuid,
        expectedSegments: local.expectedSegments!,
      );
      await _store.setProcessingStatus(sessionUuid, 'waiting_segments');
    } catch (error) {
      _message =
          'La finalización quedó pendiente. Se volverá a intentar cuando haya conexión.';
      debugPrint('[RecordingUpload] Finalize failed: ${error.runtimeType}');
      notifyListeners();
    }
  }

  Future<void> _handleUploadFailure(
    LocalAudioSegment segment,
    Object error,
  ) async {
    final retry = segment.retryCount + 1;
    if (retry >= 5) {
      await _store.updateSegmentUpload(
        segment.id!,
        SegmentUploadStatus.failed,
        retryCount: retry,
        errorMessage: error.runtimeType.toString(),
      );
      _message =
          'El audio fue guardado. Quedan fragmentos pendientes de envío.';
      await recordFailure(
        sessionUuid: segment.sessionUuid,
        stage: 'segment_upload',
        code: 'SEGMENT_UPLOAD_RETRIES_EXHAUSTED',
        message: 'Se agotaron los reintentos de envío de un segmento.',
      );
      return;
    }
    final delay = _retryDelays[retry - 1];
    final nextAttempt = DateTime.now().add(delay);
    await _store.updateSegmentUpload(
      segment.id!,
      SegmentUploadStatus.pending,
      retryCount: retry,
      errorMessage: error.runtimeType.toString(),
      nextAttemptAt: nextAttempt,
    );
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(processPending()));
    _message =
        'No se pudo conectar con el servidor. El audio permanece guardado y '
        'se volverá a intentar automáticamente.';
  }

  Future<void> _resumeAfterConnectivity() async {
    await _store.retryFailedSegments();
    await processPending();
    final sessions = await _store.recoverableSessions();
    for (final session in sessions) {
      await _ensureRemoteSession(session.sessionUuid);
      await _tryFinalize(session.sessionUuid);
    }
  }
}
