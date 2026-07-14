import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../platform_files.dart';
import 'foreground_recording_bridge.dart';

enum RecordingStatus {
  idle,
  starting,
  recording,
  pausing,
  paused,
  resuming,
  recovering,
  stopping,
  stopped,
  error,
}

extension RecordingStatusX on RecordingStatus {
  bool get isBusy => switch (this) {
    RecordingStatus.starting ||
    RecordingStatus.pausing ||
    RecordingStatus.resuming ||
    RecordingStatus.recovering ||
    RecordingStatus.stopping => true,
    _ => false,
  };

  bool get hasActiveSession => switch (this) {
    RecordingStatus.starting ||
    RecordingStatus.recording ||
    RecordingStatus.pausing ||
    RecordingStatus.paused ||
    RecordingStatus.resuming ||
    RecordingStatus.recovering ||
    RecordingStatus.stopping => true,
    _ => false,
  };

  String get label => switch (this) {
    RecordingStatus.idle => 'Listo para grabar',
    RecordingStatus.starting => 'Preparando micrófono…',
    RecordingStatus.recording => 'Grabando',
    RecordingStatus.pausing => 'Pausando grabación…',
    RecordingStatus.paused => 'Grabación pausada',
    RecordingStatus.resuming => 'Reanudando…',
    RecordingStatus.recovering => 'Recuperando grabación…',
    RecordingStatus.stopping => 'Finalizando audio…',
    RecordingStatus.stopped => 'Audio guardado localmente en el dispositivo',
    RecordingStatus.error => 'Error de grabación',
  };
}

abstract interface class RecordingEngine {
  Future<bool> hasPermission();

  Future<void> start(String path);

  Future<void> pause();

  Future<void> resume();

  Future<String?> stop();

  Future<bool> isRecording();

  Future<bool> isPaused();
}

class RecordPluginEngine implements RecordingEngine {
  RecordPluginEngine([AudioRecorder? recorder])
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 48000,
      sampleRate: 16000,
      numChannels: 1,
      audioInterruption: AudioInterruptionMode.pauseResume,
    ),
    path: path,
  );

  @override
  Future<void> pause() => _recorder.pause();

  @override
  Future<void> resume() => _recorder.resume();

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<bool> isRecording() => _recorder.isRecording();

  @override
  Future<bool> isPaused() => _recorder.isPaused();
}

abstract interface class RecordingSessionPersistence {
  Future<Map<String, dynamic>?> read();

  Future<void> write(Map<String, dynamic> value);

  Future<void> clear();
}

class SecureRecordingSessionPersistence implements RecordingSessionPersistence {
  SecureRecordingSessionPersistence([
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  ]) : _storage = storage;

  static const _key = 'sanare.recording.active_session.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<Map<String, dynamic>?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  @override
  Future<void> write(Map<String, dynamic> value) =>
      _storage.write(key: _key, value: jsonEncode(value));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class RecordingResult {
  const RecordingResult({required this.paths, required this.duration});

  final List<String> paths;
  final Duration duration;
}

class RecordingSegmentEvent {
  const RecordingSegmentEvent({
    required this.sessionUuid,
    required this.segmentNumber,
    required this.path,
    required this.duration,
    required this.isFinal,
  });

  final String sessionUuid;
  final int segmentNumber;
  final String path;
  final Duration duration;
  final bool isFinal;
}

typedef RecordingSegmentCallback =
    Future<void> Function(RecordingSegmentEvent segment);

typedef RecordingPathFactory = Future<String> Function(String fileName);

class RecordingService extends ChangeNotifier {
  RecordingService({
    RecordingEngine? engine,
    ForegroundRecordingBridge? foregroundBridge,
    RecordingSessionPersistence? persistence,
    RecordingPathFactory? pathFactory,
    this.counterInterval = const Duration(seconds: 1),
    this.healthCheckInterval = const Duration(seconds: 4),
    this.segmentDuration = const Duration(minutes: 5),
  }) : _engine = engine ?? RecordPluginEngine(),
       _foregroundBridge =
           foregroundBridge ?? AndroidForegroundRecordingBridge(),
       _persistence = persistence ?? SecureRecordingSessionPersistence(),
       _pathFactory = pathFactory ?? createRecordingPath;

  static final RecordingService instance = RecordingService();

  final RecordingEngine _engine;
  final ForegroundRecordingBridge _foregroundBridge;
  final RecordingSessionPersistence _persistence;
  final RecordingPathFactory _pathFactory;
  final Duration counterInterval;
  final Duration healthCheckInterval;
  final Duration segmentDuration;

  RecordingStatus _status = RecordingStatus.idle;
  Duration _accumulatedDuration = Duration.zero;
  DateTime? _activeStartedAt;
  Timer? _counterTimer;
  Timer? _healthTimer;
  Timer? _segmentTimer;
  bool _operationInProgress = false;
  bool _initialized = false;
  String? _sessionId;
  String? _consultationCode;
  DateTime? _startedAt;
  String? _currentPath;
  int _partNumber = 0;
  int? _patientId;
  String? _professionalId;
  String? _errorMessage;
  Duration _segmentAccumulatedDuration = Duration.zero;
  DateTime? _segmentActiveStartedAt;
  RecordingSegmentCallback? onSegmentFinalized;
  final List<String> _segments = <String>[];

  RecordingStatus get status => _status;
  Duration get duration => _currentDuration;
  List<String> get segments => List.unmodifiable(_orderedPaths);
  String? get primaryPath => _orderedPaths.firstOrNull;
  String? get currentPath => _currentPath;
  String? get errorMessage => _errorMessage;
  String? get sessionId => _sessionId;
  bool get hasIncompleteSession =>
      _sessionId != null &&
      (_status.hasActiveSession || _status == RecordingStatus.error);
  bool get hasRecoverableSession =>
      _sessionId != null &&
      (_status.hasActiveSession || _status == RecordingStatus.error);
  bool get controlsLocked => _operationInProgress || _status.isBusy;

  List<String> get _orderedPaths {
    final paths = <String>[..._segments];
    final current = _currentPath;
    if (current != null && current.isNotEmpty && !paths.contains(current)) {
      paths.add(current);
    }
    return paths;
  }

  Duration get _currentDuration {
    final activeStartedAt = _activeStartedAt;
    if (_status != RecordingStatus.recording || activeStartedAt == null) {
      return _accumulatedDuration;
    }
    return _accumulatedDuration + DateTime.now().difference(activeStartedAt);
  }

  Future<bool> initialize() async {
    if (_initialized) return false;
    _initialized = true;
    try {
      final saved = await _persistence.read();
      if (saved == null) return false;
      _sessionId = saved['session_id']?.toString();
      _consultationCode = saved['consultation_code']?.toString();
      _startedAt = DateTime.tryParse(saved['started_at']?.toString() ?? '');
      _accumulatedDuration = Duration(
        milliseconds: (saved['duration_ms'] as num?)?.toInt() ?? 0,
      );
      _currentPath = saved['current_path']?.toString();
      _partNumber = (saved['part_number'] as num?)?.toInt() ?? 0;
      _segmentAccumulatedDuration = Duration(
        milliseconds: (saved['segment_duration_ms'] as num?)?.toInt() ?? 0,
      );
      _patientId = (saved['patient_id'] as num?)?.toInt();
      _professionalId = saved['professional_id']?.toString();
      _segments
        ..clear()
        ..addAll(
          (saved['segments'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .where((path) => path.isNotEmpty),
        );
      final restoredStatus = RecordingStatus.values.where(
        (value) => value.name == saved['status'],
      );
      _status = restoredStatus.isEmpty
          ? RecordingStatus.error
          : restoredStatus.first;
      if (_status == RecordingStatus.recording) {
        // A Dart recorder cannot be assumed alive after process restoration.
        _status = RecordingStatus.paused;
      }
      notifyListeners();
      return hasIncompleteSession;
    } catch (error) {
      _setError('No se pudo recuperar la sesión guardada.', error);
      return false;
    }
  }

  Future<bool> startRecording({
    required int patientId,
    String? professionalId,
    String? sessionUuid,
    String? consultationCode,
  }) async {
    if (!_beginOperation(
      allowed: {
        RecordingStatus.idle,
        RecordingStatus.stopped,
        RecordingStatus.error,
      },
    )) {
      return false;
    }
    _setStatus(RecordingStatus.starting);
    try {
      _sessionId = null;
      _currentPath = null;
      _segments.clear();
      _accumulatedDuration = Duration.zero;
      _activeStartedAt = null;
      if (!await _engine.hasPermission()) {
        throw StateError('El permiso del micrófono no fue concedido.');
      }
      final notificationsAllowed = await _foregroundBridge
          .ensureNotificationPermission();
      if (!notificationsAllowed) {
        debugPrint(
          '[Recording] Notifications disabled; foreground service remains visible in system controls',
        );
      }

      final startedAt = DateTime.now();
      _sessionId = sessionUuid ?? const Uuid().v4();
      _consultationCode = consultationCode ?? _buildConsultationCode(startedAt);
      _startedAt = startedAt;
      _partNumber = 1;
      _segmentAccumulatedDuration = Duration.zero;
      _patientId = patientId;
      _professionalId = professionalId;
      _errorMessage = null;
      _currentPath = await _newSegmentPath();

      if (!await _startAndConfirmForeground()) {
        throw StateError('No se pudo iniciar el servicio en primer plano.');
      }
      debugPrint('[Recording] Foreground service started');
      await _engine.start(_currentPath!);
      await _persist();
      if (!await _isActivelyRecording()) {
        throw StateError('El micrófono no confirmó una sesión activa.');
      }

      _activeStartedAt = DateTime.now();
      _segmentActiveStartedAt = _activeStartedAt;
      _setStatus(RecordingStatus.recording);
      _startTimers();
      await _persist();
      debugPrint('[Recording] Recording session started');
      return true;
    } catch (error) {
      await _safeStopForeground();
      _setError('No se pudo iniciar la grabación.', error);
      await _persist();
      return false;
    } finally {
      _endOperation();
    }
  }

  Future<bool> pauseRecording() async {
    if (!_beginOperation(allowed: {RecordingStatus.recording})) {
      return false;
    }
    _setStatus(RecordingStatus.pausing);
    try {
      if (!await _engine.isRecording() || await _engine.isPaused()) {
        throw StateError('La sesión no estaba grabando activamente.');
      }
      await _engine.pause();
      if (!await _engine.isRecording() || !await _engine.isPaused()) {
        throw StateError('El grabador no confirmó la pausa.');
      }
      _freezeDuration();
      _freezeSegmentDuration();
      _counterTimer?.cancel();
      _segmentTimer?.cancel();
      _setStatus(RecordingStatus.paused);
      await _persist();
      debugPrint('[Recording] Recording paused');
      return true;
    } catch (error) {
      _setError('No se pudo pausar la grabación.', error);
      await _persist();
      return false;
    } finally {
      _endOperation();
    }
  }

  Future<bool> resumeRecording() async {
    if (!_beginOperation(allowed: {RecordingStatus.paused})) {
      return false;
    }
    _setStatus(RecordingStatus.resuming);
    debugPrint('[Recording] Resume requested');
    try {
      await _engine.resume();
      if (!await _isActivelyRecording()) {
        throw StateError('El micrófono no confirmó la reanudación.');
      }
      _activeStartedAt = DateTime.now();
      _segmentActiveStartedAt = _activeStartedAt;
      _setStatus(RecordingStatus.recording);
      _startTimers();
      await _persist();
      debugPrint('[Recording] Resume confirmed');
      return true;
    } catch (error) {
      debugPrint('[Recording] Recorder became inactive');
      return _recoverWhileLocked(error);
    } finally {
      _endOperation();
    }
  }

  Future<bool> recoverRecording() async {
    if (_operationInProgress ||
        !{
          RecordingStatus.recording,
          RecordingStatus.paused,
          RecordingStatus.error,
        }.contains(_status)) {
      return false;
    }
    _operationInProgress = true;
    notifyListeners();
    try {
      return await _recoverWhileLocked();
    } finally {
      _endOperation();
    }
  }

  Future<bool> _recoverWhileLocked([Object? cause]) async {
    _freezeDuration();
    _freezeSegmentDuration();
    _setStatus(RecordingStatus.recovering);
    debugPrint('[Recording] Recovery started');
    try {
      final stoppedPath = await _safeStopRecorder();
      _preserveCurrentSegment(stoppedPath);
      final completedPath = stoppedPath ?? _currentPath;
      final completedPart = _partNumber;
      final completedDuration = _segmentAccumulatedDuration;
      if (completedPath != null) {
        unawaited(
          _notifySegment(
            path: completedPath,
            number: completedPart,
            duration: completedDuration,
            isFinal: false,
          ),
        );
      }
      _partNumber = (_partNumber < 1 ? 1 : _partNumber) + 1;
      _segmentAccumulatedDuration = Duration.zero;
      _currentPath = await _newSegmentPath();
      if (!await _foregroundBridge.isRunning() &&
          !await _startAndConfirmForeground()) {
        throw StateError('El servicio en primer plano no pudo recuperarse.');
      }
      await _engine.start(_currentPath!);
      await _persist();
      if (!await _isActivelyRecording()) {
        throw StateError('El nuevo segmento no activó el micrófono.');
      }
      _activeStartedAt = DateTime.now();
      _segmentActiveStartedAt = _activeStartedAt;
      _errorMessage = null;
      _setStatus(RecordingStatus.recording);
      _startTimers();
      await _persist();
      debugPrint('[Recording] New segment created');
      return true;
    } catch (error) {
      _currentPath = null;
      await _safeStopForeground();
      _setError(
        'La grabación fue interrumpida y no pudo reanudarse automáticamente. '
        'Los fragmentos grabados hasta el momento se conservaron.',
        cause ?? error,
      );
      await _persist();
      return false;
    }
  }

  Future<RecordingResult?> stopRecording() async {
    if (_operationInProgress || !hasRecoverableSession) return null;
    _operationInProgress = true;
    _setStatus(RecordingStatus.stopping);
    _freezeDuration();
    _freezeSegmentDuration();
    _cancelTimers();
    try {
      final stoppedPath = await _safeStopRecorder();
      _preserveCurrentSegment(stoppedPath);
      final completedPath = stoppedPath ?? _currentPath;
      if (completedPath != null) {
        await _notifySegment(
          path: completedPath,
          number: _partNumber,
          duration: _segmentAccumulatedDuration,
          isFinal: true,
        );
      }
      _currentPath = null;
      _setStatus(RecordingStatus.stopped);
      await _safeStopForeground();
      await _persist();
      debugPrint('[Recording] Recording finalized');
      return RecordingResult(paths: segments, duration: _accumulatedDuration);
    } catch (error) {
      await _safeStopForeground();
      _setError('No se pudo finalizar la grabación.', error);
      await _persist();
      return RecordingResult(paths: segments, duration: _accumulatedDuration);
    } finally {
      _endOperation();
    }
  }

  Future<void> syncRecordingState() async {
    if (_operationInProgress || !_status.hasActiveSession) return;
    try {
      final running = await _foregroundBridge.isRunning();
      final recording = await _engine.isRecording();
      final paused = recording && await _engine.isPaused();
      if (_status == RecordingStatus.recording &&
          (!running || !recording || paused)) {
        await recoverRecording();
      } else if (_status == RecordingStatus.paused && (!recording || !paused)) {
        _setError('La sesión pausada dejó de estar disponible.', null);
        await _persist();
      }
    } catch (error) {
      if (_status == RecordingStatus.recording) {
        await recoverRecording();
      }
    }
  }

  Future<void> discardRecoveredSession() async {
    if (_status.hasActiveSession) {
      await stopRecording();
    }
    _cancelTimers();
    _sessionId = null;
    _consultationCode = null;
    _startedAt = null;
    _currentPath = null;
    _segments.clear();
    _accumulatedDuration = Duration.zero;
    _partNumber = 0;
    _segmentAccumulatedDuration = Duration.zero;
    _segmentActiveStartedAt = null;
    _status = RecordingStatus.idle;
    _errorMessage = null;
    await _persistence.clear();
    notifyListeners();
  }

  Future<bool> notificationsEnabled() =>
      _foregroundBridge.areNotificationsEnabled();

  bool _beginOperation({required Set<RecordingStatus> allowed}) {
    if (_operationInProgress || !allowed.contains(_status)) return false;
    _operationInProgress = true;
    notifyListeners();
    return true;
  }

  void _endOperation() {
    _operationInProgress = false;
    notifyListeners();
  }

  Future<bool> _isActivelyRecording() async =>
      await _engine.isRecording() && !await _engine.isPaused();

  void _freezeDuration() {
    final activeStartedAt = _activeStartedAt;
    if (activeStartedAt != null) {
      _accumulatedDuration += DateTime.now().difference(activeStartedAt);
      _activeStartedAt = null;
    }
  }

  void _freezeSegmentDuration() {
    final activeStartedAt = _segmentActiveStartedAt;
    if (activeStartedAt != null) {
      _segmentAccumulatedDuration += DateTime.now().difference(activeStartedAt);
      _segmentActiveStartedAt = null;
    }
  }

  void _startTimers() {
    _counterTimer?.cancel();
    _counterTimer = Timer.periodic(counterInterval, (_) {
      if (_status != RecordingStatus.recording) return;
      notifyListeners();
      if (duration.inSeconds > 0 && duration.inSeconds % 15 == 0) {
        unawaited(_persist());
      }
    });
    _healthTimer ??= Timer.periodic(
      healthCheckInterval,
      (_) => unawaited(syncRecordingState()),
    );
    _scheduleSegmentRotation();
  }

  void _cancelTimers() {
    _counterTimer?.cancel();
    _counterTimer = null;
    _healthTimer?.cancel();
    _healthTimer = null;
    _segmentTimer?.cancel();
    _segmentTimer = null;
  }

  Future<String?> _safeStopRecorder() async {
    try {
      if (await _engine.isRecording()) return await _engine.stop();
    } catch (_) {
      // The current path is still retained when the native session is gone.
    }
    return _currentPath;
  }

  Future<void> _safeStopForeground() async {
    try {
      await _foregroundBridge.stop();
      for (var attempt = 0; attempt < 5; attempt++) {
        if (!await _foregroundBridge.isRunning()) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      debugPrint('[Recording] Foreground service stopped');
    } catch (error) {
      debugPrint(
        '[Recording] Foreground service stop failed: ${error.runtimeType}',
      );
    }
  }

  Future<bool> _startAndConfirmForeground() async {
    if (!await _foregroundBridge.start()) return false;
    for (var attempt = 0; attempt < 5; attempt++) {
      if (await _foregroundBridge.isRunning()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  void _preserveCurrentSegment(String? stoppedPath) {
    final path = stoppedPath == null || stoppedPath.isEmpty
        ? _currentPath
        : stoppedPath;
    if (path != null && path.isNotEmpty && !_segments.contains(path)) {
      _segments.add(path);
    }
  }

  Future<String> _newSegmentPath() => _pathFactory(
    '${_sessionId}_segment_${_partNumber.toString().padLeft(3, '0')}.m4a',
  );

  void _scheduleSegmentRotation() {
    _segmentTimer?.cancel();
    if (_status != RecordingStatus.recording) return;
    final remaining = segmentDuration - _segmentAccumulatedDuration;
    _segmentTimer = Timer(
      remaining <= Duration.zero ? const Duration(milliseconds: 1) : remaining,
      () => unawaited(_rotateSegment()),
    );
  }

  Future<void> _rotateSegment() async {
    if (_operationInProgress || _status != RecordingStatus.recording) return;
    _operationInProgress = true;
    notifyListeners();
    String? completedPath;
    var completedPart = _partNumber;
    var completedDuration = Duration.zero;
    try {
      _freezeDuration();
      _freezeSegmentDuration();
      final stoppedPath = await _engine.stop();
      _preserveCurrentSegment(stoppedPath);
      completedPath = stoppedPath ?? _currentPath;
      completedPart = _partNumber;
      completedDuration = _segmentAccumulatedDuration;

      _partNumber++;
      _segmentAccumulatedDuration = Duration.zero;
      _currentPath = await _newSegmentPath();
      await _engine.start(_currentPath!);
      if (!await _isActivelyRecording()) {
        throw StateError('El micrófono no confirmó el nuevo segmento.');
      }
      _activeStartedAt = DateTime.now();
      _segmentActiveStartedAt = _activeStartedAt;
      await _persist();
      _scheduleSegmentRotation();
      debugPrint('[Recording] New timed segment created');
    } catch (error) {
      _currentPath = null;
      await _safeStopForeground();
      _setError(
        'No se pudo continuar en un nuevo fragmento. '
        'Los audios anteriores se conservaron.',
        error,
      );
      await _persist();
    } finally {
      if (completedPath != null) {
        await _notifySegment(
          path: completedPath,
          number: completedPart,
          duration: completedDuration,
          isFinal: false,
        );
      }
      _endOperation();
    }
  }

  Future<void> _notifySegment({
    required String path,
    required int number,
    required Duration duration,
    required bool isFinal,
  }) async {
    final callback = onSegmentFinalized;
    final sessionUuid = _sessionId;
    if (callback == null || sessionUuid == null) return;
    try {
      await callback(
        RecordingSegmentEvent(
          sessionUuid: sessionUuid,
          segmentNumber: number,
          path: path,
          duration: duration,
          isFinal: isFinal,
        ),
      );
    } catch (error) {
      debugPrint(
        '[Recording] Segment persistence callback failed: ${error.runtimeType}',
      );
    }
  }

  String _buildConsultationCode(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    final sequence = (date.millisecondsSinceEpoch % 1000).toString().padLeft(
      3,
      '0',
    );
    return 'C-${two(date.day)}-${two(date.month)}-${date.year}-$sequence';
  }

  void _setStatus(RecordingStatus value) {
    _status = value;
    notifyListeners();
  }

  void _setError(String message, Object? error) {
    _freezeDuration();
    _cancelTimers();
    _errorMessage = message;
    _status = RecordingStatus.error;
    debugPrint(
      '[Recording] Recording error: ${error?.runtimeType ?? 'unknown'}',
    );
    notifyListeners();
  }

  Future<void> _persist() async {
    if (_sessionId == null) return;
    await _persistence.write({
      'session_id': _sessionId,
      'consultation_code': _consultationCode,
      'status': _status.name,
      'started_at': _startedAt?.toIso8601String(),
      'duration_ms': duration.inMilliseconds,
      'current_path': _currentPath,
      'segments': _segments,
      'part_number': _partNumber,
      'segment_duration_ms': _segmentAccumulatedDuration.inMilliseconds,
      'patient_id': _patientId,
      'professional_id': _professionalId,
    });
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
