import 'package:sqflite/sqflite.dart';

enum SegmentUploadStatus { pending, uploading, uploaded, failed, cancelled }

const terminalProcessingStatuses = <String>{
  'completed',
  'failed',
  'timeout',
  'cancelled',
  'discarded',
};

bool isTerminalProcessingStatus(String status) =>
    terminalProcessingStatuses.contains(status);

class LocalRecordingSession {
  const LocalRecordingSession({
    required this.sessionUuid,
    required this.patientId,
    required this.startedAt,
    required this.recordingStatus,
    required this.processingStatus,
    this.consultationId,
    this.expectedSegments,
    this.consultationCode,
    this.localConsultationCode,
    this.failureStage,
    this.failureMessage,
  });

  final String sessionUuid;
  final int patientId;
  final int? consultationId;
  final DateTime startedAt;
  final String recordingStatus;
  final String processingStatus;
  final int? expectedSegments;
  final String? consultationCode;
  final String? localConsultationCode;
  final String? failureStage;
  final String? failureMessage;

  factory LocalRecordingSession.fromMap(Map<String, Object?> map) =>
      LocalRecordingSession(
        sessionUuid: map['session_uuid']! as String,
        patientId: map['patient_id']! as int,
        consultationId: map['consultation_id'] as int?,
        startedAt: DateTime.parse(map['started_at']! as String),
        recordingStatus: map['recording_status']! as String,
        processingStatus: map['processing_status']! as String,
        expectedSegments: map['expected_segments'] as int?,
        consultationCode: map['consultation_code'] as String?,
        localConsultationCode: map['local_consultation_code'] as String?,
        failureStage: map['failure_stage'] as String?,
        failureMessage: map['failure_message'] as String?,
      );
}

class LocalAudioSegment {
  const LocalAudioSegment({
    required this.sessionUuid,
    required this.segmentNumber,
    required this.localPath,
    required this.durationSeconds,
    required this.fileSize,
    required this.checksum,
    required this.uploadStatus,
    required this.retryCount,
    required this.isFinal,
    required this.createdAt,
    this.id,
    this.consultationId,
    this.errorMessage,
    this.nextAttemptAt,
  });

  final int? id;
  final String sessionUuid;
  final int? consultationId;
  final int segmentNumber;
  final String localPath;
  final int durationSeconds;
  final int fileSize;
  final String checksum;
  final SegmentUploadStatus uploadStatus;
  final int retryCount;
  final bool isFinal;
  final DateTime createdAt;
  final String? errorMessage;
  final DateTime? nextAttemptAt;

  factory LocalAudioSegment.fromMap(Map<String, Object?> map) =>
      LocalAudioSegment(
        id: map['id'] as int?,
        sessionUuid: map['session_uuid']! as String,
        consultationId: map['consultation_id'] as int?,
        segmentNumber: map['segment_number']! as int,
        localPath: map['local_path']! as String,
        durationSeconds: map['duration_seconds']! as int,
        fileSize: map['file_size']! as int,
        checksum: map['checksum']! as String,
        uploadStatus: SegmentUploadStatus.values.byName(
          map['upload_status']! as String,
        ),
        retryCount: map['retry_count']! as int,
        isFinal: (map['is_final']! as int) == 1,
        createdAt: DateTime.parse(map['created_at']! as String),
        errorMessage: map['error_message'] as String?,
        nextAttemptAt: map['next_attempt_at'] == null
            ? null
            : DateTime.parse(map['next_attempt_at']! as String),
      );
}

abstract interface class LocalSegmentStore {
  Future<void> initialize();

  Future<void> recoverInterruptedUploads();

  Future<void> saveSession(LocalRecordingSession session);

  Future<LocalRecordingSession?> session(String sessionUuid);

  Future<LocalRecordingSession?> sessionForConsultation(int consultationId);

  Future<List<LocalRecordingSession>> recoverableSessions();

  Future<void> setRemoteConsultation(
    String sessionUuid,
    int consultationId, {
    String? consultationCode,
  });

  Future<void> finishSession(String sessionUuid, int expectedSegments);

  Future<void> setProcessingStatus(String sessionUuid, String status);

  Future<void> cancelSession(String sessionUuid);

  Future<void> setSessionFailure(
    String sessionUuid,
    String stage,
    String message,
  );

  Future<void> insertSegment(LocalAudioSegment segment);

  Future<List<LocalAudioSegment>> uploadCandidates({
    bool includeFailed = false,
  });

  Future<List<LocalAudioSegment>> segmentsForSession(String sessionUuid);

  Future<void> retryFailedSegments(String sessionUuid);

  Future<void> updateSegmentUpload(
    int id,
    SegmentUploadStatus status, {
    int? retryCount,
    int? consultationId,
    String? errorMessage,
    DateTime? nextAttemptAt,
  });

  Future<int> totalDurationSeconds(String sessionUuid);
}

class SqliteLocalSegmentStore implements LocalSegmentStore {
  Database? _database;

  Future<Database> get _db async {
    await initialize();
    return _database!;
  }

  @override
  Future<void> initialize() async {
    if (_database != null) return;
    final base = await getDatabasesPath();
    _database = await openDatabase(
      '$base/sanare_recordings.db',
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE recording_sessions (
            session_uuid TEXT PRIMARY KEY,
            patient_id INTEGER NOT NULL,
            consultation_id INTEGER,
            started_at TEXT NOT NULL,
            recording_status TEXT NOT NULL,
            processing_status TEXT NOT NULL,
            expected_segments INTEGER
            ,consultation_code TEXT
            ,local_consultation_code TEXT
            ,failure_stage TEXT
            ,failure_message TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE audio_segments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_uuid TEXT NOT NULL,
            consultation_id INTEGER,
            segment_number INTEGER NOT NULL,
            local_path TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL,
            file_size INTEGER NOT NULL,
            checksum TEXT NOT NULL,
            upload_status TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            is_final INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            error_message TEXT,
            next_attempt_at TEXT,
            UNIQUE(session_uuid, segment_number)
          )
        ''');
        await db.execute(
          'CREATE INDEX audio_segments_upload_status_idx '
          'ON audio_segments(upload_status)',
        );
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE recording_sessions ADD COLUMN consultation_code TEXT',
          );
          await db.execute(
            'ALTER TABLE recording_sessions ADD COLUMN local_consultation_code TEXT',
          );
          await db.execute(
            'ALTER TABLE recording_sessions ADD COLUMN failure_stage TEXT',
          );
          await db.execute(
            'ALTER TABLE recording_sessions ADD COLUMN failure_message TEXT',
          );
        }
      },
    );
  }

  @override
  Future<void> recoverInterruptedUploads() async {
    final db = await _db;
    await db.update(
      'audio_segments',
      {'upload_status': SegmentUploadStatus.pending.name},
      where: 'upload_status = ?',
      whereArgs: [SegmentUploadStatus.uploading.name],
    );
  }

  @override
  Future<void> saveSession(LocalRecordingSession session) async {
    final db = await _db;
    await db.insert('recording_sessions', {
      'session_uuid': session.sessionUuid,
      'patient_id': session.patientId,
      'consultation_id': session.consultationId,
      'started_at': session.startedAt.toIso8601String(),
      'recording_status': session.recordingStatus,
      'processing_status': session.processingStatus,
      'expected_segments': session.expectedSegments,
      'consultation_code': session.consultationCode,
      'local_consultation_code': session.localConsultationCode,
      'failure_stage': session.failureStage,
      'failure_message': session.failureMessage,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<LocalRecordingSession?> session(String sessionUuid) async {
    final db = await _db;
    final rows = await db.query(
      'recording_sessions',
      where: 'session_uuid = ?',
      whereArgs: [sessionUuid],
      limit: 1,
    );
    return rows.isEmpty ? null : LocalRecordingSession.fromMap(rows.first);
  }

  @override
  Future<LocalRecordingSession?> sessionForConsultation(
    int consultationId,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'recording_sessions',
      where: 'consultation_id = ?',
      whereArgs: [consultationId],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : LocalRecordingSession.fromMap(rows.first);
  }

  @override
  Future<List<LocalRecordingSession>> recoverableSessions() async {
    final db = await _db;
    final rows = await db.query(
      'recording_sessions',
      where:
          "processing_status NOT IN "
          "('completed', 'failed', 'timeout', 'cancelled', 'discarded')",
      orderBy: 'started_at DESC',
    );
    return rows.map(LocalRecordingSession.fromMap).toList();
  }

  @override
  Future<void> setRemoteConsultation(
    String sessionUuid,
    int consultationId, {
    String? consultationCode,
  }) async {
    final db = await _db;
    await db.transaction((transaction) async {
      await transaction.update(
        'recording_sessions',
        {
          'consultation_id': consultationId,
          'consultation_code': consultationCode,
        },
        where: 'session_uuid = ?',
        whereArgs: [sessionUuid],
      );
      await transaction.update(
        'audio_segments',
        {'consultation_id': consultationId},
        where: 'session_uuid = ?',
        whereArgs: [sessionUuid],
      );
    });
  }

  @override
  Future<void> finishSession(String sessionUuid, int expectedSegments) async {
    final db = await _db;
    await db.update(
      'recording_sessions',
      {
        'recording_status': 'finished',
        'processing_status': 'uploading',
        'expected_segments': expectedSegments,
      },
      where: 'session_uuid = ?',
      whereArgs: [sessionUuid],
    );
  }

  @override
  Future<void> setProcessingStatus(String sessionUuid, String status) async {
    final db = await _db;
    await db.update(
      'recording_sessions',
      {'processing_status': status},
      where: 'session_uuid = ?',
      whereArgs: [sessionUuid],
    );
  }

  @override
  Future<void> cancelSession(String sessionUuid) async {
    final db = await _db;
    await db.transaction((transaction) async {
      await transaction.update(
        'recording_sessions',
        {'processing_status': 'discarded'},
        where: 'session_uuid = ?',
        whereArgs: [sessionUuid],
      );
      await transaction.update(
        'audio_segments',
        {
          'upload_status': SegmentUploadStatus.cancelled.name,
          'next_attempt_at': null,
        },
        where: 'session_uuid = ? AND upload_status != ?',
        whereArgs: [sessionUuid, SegmentUploadStatus.uploaded.name],
      );
    });
  }

  @override
  Future<void> setSessionFailure(
    String sessionUuid,
    String stage,
    String message,
  ) async {
    final db = await _db;
    await db.transaction((transaction) async {
      await transaction.update(
        'recording_sessions',
        {
          'processing_status': 'failed',
          'failure_stage': stage,
          'failure_message': message,
        },
        where: 'session_uuid = ?',
        whereArgs: [sessionUuid],
      );
      await transaction.update(
        'audio_segments',
        {
          'upload_status': SegmentUploadStatus.failed.name,
          'next_attempt_at': null,
        },
        where: 'session_uuid = ? AND upload_status IN (?, ?)',
        whereArgs: [
          sessionUuid,
          SegmentUploadStatus.pending.name,
          SegmentUploadStatus.uploading.name,
        ],
      );
    });
  }

  @override
  Future<void> insertSegment(LocalAudioSegment segment) async {
    final db = await _db;
    await db.insert('audio_segments', {
      'session_uuid': segment.sessionUuid,
      'consultation_id': segment.consultationId,
      'segment_number': segment.segmentNumber,
      'local_path': segment.localPath,
      'duration_seconds': segment.durationSeconds,
      'file_size': segment.fileSize,
      'checksum': segment.checksum,
      'upload_status': segment.uploadStatus.name,
      'retry_count': segment.retryCount,
      'is_final': segment.isFinal ? 1 : 0,
      'created_at': segment.createdAt.toIso8601String(),
      'error_message': segment.errorMessage,
      'next_attempt_at': segment.nextAttemptAt?.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<List<LocalAudioSegment>> uploadCandidates({
    bool includeFailed = false,
  }) async {
    final db = await _db;
    final statuses = includeFailed
        ? [SegmentUploadStatus.pending.name, SegmentUploadStatus.failed.name]
        : [SegmentUploadStatus.pending.name];
    final placeholders = List.filled(statuses.length, '?').join(',');
    final rows = await db.query(
      'audio_segments',
      where:
          'upload_status IN ($placeholders) AND '
          '(next_attempt_at IS NULL OR next_attempt_at <= ?)',
      whereArgs: [...statuses, DateTime.now().toIso8601String()],
      orderBy: 'created_at ASC, segment_number ASC',
    );
    return rows.map(LocalAudioSegment.fromMap).toList();
  }

  @override
  Future<List<LocalAudioSegment>> segmentsForSession(String sessionUuid) async {
    final db = await _db;
    final rows = await db.query(
      'audio_segments',
      where: 'session_uuid = ?',
      whereArgs: [sessionUuid],
      orderBy: 'segment_number ASC',
    );
    return rows.map(LocalAudioSegment.fromMap).toList();
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
    final db = await _db;
    await db.update(
      'audio_segments',
      {
        'upload_status': status.name,
        'retry_count': ?retryCount,
        'consultation_id': ?consultationId,
        'error_message': errorMessage,
        'next_attempt_at': nextAttemptAt?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> retryFailedSegments(String sessionUuid) async {
    final db = await _db;
    await db.update(
      'audio_segments',
      {
        'upload_status': SegmentUploadStatus.pending.name,
        'retry_count': 0,
        'next_attempt_at': null,
      },
      where: 'session_uuid = ? AND upload_status = ?',
      whereArgs: [sessionUuid, SegmentUploadStatus.failed.name],
    );
  }

  @override
  Future<int> totalDurationSeconds(String sessionUuid) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(duration_seconds), 0) total '
      'FROM audio_segments WHERE session_uuid = ?',
      [sessionUuid],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }
}
