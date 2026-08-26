import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;

import '../../../core/domain/analysis/analysis_frame.dart';
import '../../../core/domain/analysis/analysis_quality_flag.dart';
import '../../../core/domain/analysis/feature_series.dart';
import '../../../core/domain/analysis/session_summary.dart';
import '../../../core/domain/persistence/recording_locator.dart';
import '../../../core/domain/persistence/recording_store.dart';
import '../../../core/domain/persistence/session_repository.dart';
import '../../../core/domain/practice/practice_target.dart';
import '../../../core/domain/practice/practice_template.dart';
import '../codecs/feature_blob_codec.dart';
import '../database/app_database.dart';

/// Maps the minimal v1 session projection to Drift. Audio bytes are never part
/// of this repository or database; only a BlobStore locator is persisted.
final class DriftSessionRepository implements SessionRepository {
  DriftSessionRepository(
    this._database, {
    required this.recordingStore,
    this.codec = const FeatureBlobCodec(),
  });
  final AppDatabase _database;
  final RecordingStore recordingStore;
  final FeatureBlobCodec codec;

  @override
  Future<void> save(PracticeSessionRecord record) async {
    final frames = record.features.frames;
    final timeline = _timelineFor(record.features);
    _ensureSupportedFrames(frames);
    final featureSchemaVersion = _schemaVersionFor(frames);
    final template = jsonEncode({
      'id': record.template.id,
      'version': record.template.version,
      'kind': record.template.kind.name,
      'midi': record.template.target.targetMidiNote,
      'tolerance': record.template.target.toleranceCents,
      'review': record.template.reviewStatus.name,
    });
    await _database.saveSessionWithFeatures(
      session: PracticeSessionsCompanion.insert(
        id: record.id,
        templateJson: template,
        startedAt: record.startedAt,
        validFrameCount: record.summary.validFrameCount,
        totalFrameCount: record.summary.totalFrameCount,
        qualityFlagsJson: jsonEncode(
          record.summary.qualityFlags.map((flag) => flag.name).toList(),
        ),
        summaryJson: Value(_encodeSummary(record.summary)),
      ),
      recording: record.recording == null
          ? null
          : RecordingsCompanion.insert(
              sessionId: record.id,
              locator: record.recording!.value,
              storageKind: record.recording!.storageKind.name,
            ),
      run: AnalysisRunsCompanion.insert(
        sessionId: record.id,
        createdAt: record.startedAt,
        algorithmVersion: 'phase1-v1',
      ),
      metadata: FeatureSeriesMetadataCompanion.insert(
        runId: const Value(0),
        frameCount: frames.length,
        startSampleIndex: timeline.startSampleIndex,
        samplePeriodSamples: timeline.samplePeriodSamples,
        algorithmVersion: timeline.algorithmVersion,
        featureSchemaVersion: Value(featureSchemaVersion),
      ),
      features: _columnsFor(
        frames,
        record.features.frameRateHz,
        featureSchemaVersion,
      ),
    );
  }

  @override
  Future<PracticeSessionRecord?> findById(String id) async {
    final session = await (_database.select(
      _database.practiceSessions,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (session == null) return null;
    final features = await _database.featureColumnsForSession(id);
    final metadata = await _database.featureMetadataForSession(id);
    if (features.isEmpty || metadata == null) return null;
    final columns = <String, DecodedFeatureBlob>{
      for (final feature in features) feature.kind: _decode(feature),
    };
    final f0 = _column(columns, 'f0_hz', metadata.frameCount);
    final rms = _column(columns, 'rms_dbfs', metadata.frameCount);
    final peak = _column(columns, 'peak_dbfs', metadata.frameCount);
    final clarity = _column(columns, 'pitch_clarity', metadata.frameCount);
    final voiced = _column(columns, 'voiced', metadata.frameCount);
    final cents = _column(columns, 'pitch_cents', metadata.frameCount);
    final quality = _column(columns, 'quality_flags', metadata.frameCount);
    final templateMap =
        jsonDecode(session.templateJson) as Map<String, dynamic>;
    final flags = (jsonDecode(session.qualityFlagsJson) as List<dynamic>)
        .map((name) => AnalysisQualityFlag.values.byName(name as String))
        .toSet();
    final recording = await (_database.select(
      _database.recordings,
    )..where((row) => row.sessionId.equals(id))).getSingleOrNull();
    return PracticeSessionRecord(
      id: session.id,
      startedAt: session.startedAt,
      template: PracticeTemplate(
        id: templateMap['id'] as String,
        version: templateMap['version'] as int,
        kind: PracticeKind.values.byName(templateMap['kind'] as String),
        target: PracticeTarget(
          targetMidiNote: templateMap['midi'] as int,
          toleranceCents: (templateMap['tolerance'] as num).toDouble(),
        ),
        reviewStatus: ContentReviewStatus.values.byName(
          templateMap['review'] as String,
        ),
      ),
      summary: _decodeSummary(session.summaryJson, session, flags),
      features: FeatureSeries(
        frameRateHz: (Duration.microsecondsPerSecond / f0.samplePeriodMicros)
            .round(),
        frames: List<AnalysisFrame>.generate(
          metadata.frameCount,
          (i) => AnalysisFrame(
            sampleIndex:
                metadata.startSampleIndex + i * metadata.samplePeriodSamples,
            rmsDbfs: rms.values[i],
            peakDbfs: peak.values[i],
            pitchClarity: clarity.values[i],
            voiced: voiced.values[i] != 0,
            algorithmVersion: metadata.algorithmVersion,
            f0Hz: f0.validity[i] ? f0.values[i] : null,
            pitchCents: cents.validity[i] ? cents.values[i] : null,
            bandPowersDb: _bandPowersFor(
              columns,
              metadata.featureSchemaVersion,
              i,
              metadata.frameCount,
            ),
            qualityFlags: _qualityFlags(quality.values[i].round()),
          ),
        ),
      ),
      recording: recording == null
          ? null
          : RecordingLocator(
              value: recording.locator,
              storageKind: RecordingStorageKind.values.byName(
                recording.storageKind,
              ),
            ),
    );
  }

  @override
  Future<List<PracticeSessionRecord>> listRecent({int limit = 20}) async {
    if (limit <= 0) return const <PracticeSessionRecord>[];
    final sessions = await _database.recentSessions(limit: limit);
    final records = <PracticeSessionRecord>[];
    for (final session in sessions) {
      final record = await findById(session.id);
      if (record != null) records.add(record);
    }
    return List<PracticeSessionRecord>.unmodifiable(records);
  }

  @override
  Future<void> deleteRecording(String id) async {
    final recording = await _database.recordingForSession(id);
    if (recording == null) return;
    await _database.deleteRecordingWithTombstone(id);
    await recordingStore.delete(
      RecordingLocator(
        value: recording.locator,
        storageKind: RecordingStorageKind.values.byName(recording.storageKind),
      ),
    );
    await _database.finalizeRecordingDeletion(id);
  }

  @override
  Future<void> delete(String id) async {
    await deleteRecording(id);
    await _database.deleteSessionData(id);
  }

  List<FeatureSeriesTableCompanion> _columnsFor(
    List<AnalysisFrame> frames,
    int frameRateHz,
    int featureSchemaVersion,
  ) {
    FeatureSeriesTableCompanion column(
      String kind,
      List<double> values,
      List<bool> validity,
    ) {
      final payload = codec.encode(
        values: Float32List.fromList(values),
        validity: validity,
        samplePeriodMicros: (Duration.microsecondsPerSecond / frameRateHz)
            .round(),
      );
      return FeatureSeriesTableCompanion.insert(
        runId: 0,
        kind: kind,
        frameCount: frames.length,
        codecVersion: featureBlobVersion,
        payload: payload,
        sha256: sha256.convert(payload).toString(),
      );
    }

    return <FeatureSeriesTableCompanion>[
      column(
        'f0_hz',
        frames.map((frame) => frame.f0Hz ?? 0).toList(),
        frames.map((frame) => frame.f0Hz != null).toList(),
      ),
      column(
        'rms_dbfs',
        frames.map((frame) => frame.rmsDbfs).toList(),
        List<bool>.filled(frames.length, true),
      ),
      column(
        'peak_dbfs',
        frames.map((frame) => frame.peakDbfs).toList(),
        List<bool>.filled(frames.length, true),
      ),
      column(
        'pitch_clarity',
        frames.map((frame) => frame.pitchClarity).toList(),
        List<bool>.filled(frames.length, true),
      ),
      column(
        'voiced',
        frames.map((frame) => frame.voiced ? 1.0 : 0.0).toList(),
        List<bool>.filled(frames.length, true),
      ),
      column(
        'pitch_cents',
        frames.map((frame) => frame.pitchCents ?? 0).toList(),
        frames.map((frame) => frame.pitchCents != null).toList(),
      ),
      column(
        'quality_flags',
        frames
            .map((frame) => _qualityMask(frame.qualityFlags).toDouble())
            .toList(),
        List<bool>.filled(frames.length, true),
      ),
      if (featureSchemaVersion >= _featureSchemaVersion)
        for (var band = 0; band < _bandCount; band++)
          column(
            'band_${band}_db',
            frames.map((frame) => frame.bandPowersDb[band]).toList(),
            List<bool>.filled(frames.length, true),
          ),
    ];
  }

  DecodedFeatureBlob _decode(FeatureSeriesTableData feature) {
    if (sha256.convert(feature.payload).toString() != feature.sha256) {
      throw StateError('Feature BLOB checksum does not match ${feature.kind}.');
    }
    return codec.decode(feature.payload);
  }

  DecodedFeatureBlob _column(
    Map<String, DecodedFeatureBlob> columns,
    String kind,
    int expectedFrameCount,
  ) {
    final column = columns[kind];
    if (column == null || column.values.length != expectedFrameCount) {
      throw StateError('Missing or invalid feature column: $kind.');
    }
    return column;
  }

  _FeatureTimeline _timelineFor(FeatureSeries series) {
    final frames = series.frames;
    if (frames.isEmpty) {
      return const _FeatureTimeline(0, 1, 'phase1-v1');
    }
    final period = frames.length == 1
        ? 1
        : frames[1].sampleIndex - frames.first.sampleIndex;
    if (period <= 0 ||
        List<bool>.generate(
          frames.length - 1,
          (offset) =>
              frames[offset + 1].sampleIndex !=
              frames.first.sampleIndex + (offset + 1) * period,
        ).contains(true)) {
      throw ArgumentError(
        'Feature frames must have a regular sample timeline.',
      );
    }
    final version = frames.first.algorithmVersion;
    if (frames.any((frame) => frame.algorithmVersion != version)) {
      throw ArgumentError('Feature frames must share an algorithm version.');
    }
    return _FeatureTimeline(frames.first.sampleIndex, period, version);
  }

  void _ensureSupportedFrames(List<AnalysisFrame> frames) {
    final hasBands = frames.any((frame) => frame.bandPowersDb.isNotEmpty);
    if (frames.any(
      (frame) => frame.bandPowersDb.length != (hasBands ? _bandCount : 0),
    )) {
      throw UnsupportedError(
        'Feature-series must contain either no band powers or exactly '
        '$_bandCount powers per frame.',
      );
    }
    if (frames.any((frame) => frame.spectrumBinsDb.isNotEmpty)) {
      throw UnsupportedError('Feature-series v2 does not persist UI spectrum.');
    }
  }

  int _schemaVersionFor(List<AnalysisFrame> frames) =>
      frames.any((frame) => frame.bandPowersDb.isNotEmpty)
      ? _featureSchemaVersion
      : 1;

  List<double> _bandPowersFor(
    Map<String, DecodedFeatureBlob> columns,
    int schemaVersion,
    int frameIndex,
    int frameCount,
  ) {
    if (schemaVersion < _featureSchemaVersion) return const <double>[];
    return List<double>.generate(
      _bandCount,
      (band) =>
          _column(columns, 'band_${band}_db', frameCount).values[frameIndex],
    );
  }

  int _qualityMask(Set<AnalysisQualityFlag> flags) =>
      flags.fold(0, (mask, flag) => mask | (1 << flag.index));

  Set<AnalysisQualityFlag> _qualityFlags(int mask) => AnalysisQualityFlag.values
      .where((flag) => mask & (1 << flag.index) != 0)
      .toSet();

  String _encodeSummary(SessionSummary summary) => jsonEncode(<String, Object?>{
    'droppedSamples': summary.droppedSamples,
    'targetHitRate': summary.targetHitRate,
    'targetDeviationMedianCents': summary.targetDeviationMedianCents,
    'pitchStability': _encodeStability(summary.pitchStability),
    'levelStability': _encodeStability(summary.levelStability),
    'onsetDelaySamples': summary.onsetDelaySamples,
  });

  Map<String, Object>? _encodeStability(StabilitySummary? stability) =>
      stability == null
      ? null
      : <String, Object>{
          'median': stability.median,
          'medianAbsoluteDeviation': stability.medianAbsoluteDeviation,
          'slopePerSecond': stability.slopePerSecond,
          'frameCount': stability.frameCount,
        };

  SessionSummary _decodeSummary(
    String encoded,
    PracticeSession session,
    Set<AnalysisQualityFlag> flags,
  ) {
    final data = jsonDecode(encoded) as Map<String, dynamic>;
    return SessionSummary(
      validFrameCount: session.validFrameCount,
      totalFrameCount: session.totalFrameCount,
      droppedSamples: (data['droppedSamples'] as num?)?.toInt() ?? 0,
      targetHitRate: (data['targetHitRate'] as num?)?.toDouble(),
      targetDeviationMedianCents: (data['targetDeviationMedianCents'] as num?)
          ?.toDouble(),
      pitchStability: _decodeStability(data['pitchStability']),
      levelStability: _decodeStability(data['levelStability']),
      onsetDelaySamples: (data['onsetDelaySamples'] as num?)?.toInt(),
      qualityFlags: flags,
    );
  }

  StabilitySummary? _decodeStability(Object? raw) {
    if (raw == null) return null;
    final data = raw as Map<String, dynamic>;
    return StabilitySummary(
      median: (data['median'] as num).toDouble(),
      medianAbsoluteDeviation: (data['medianAbsoluteDeviation'] as num)
          .toDouble(),
      slopePerSecond: (data['slopePerSecond'] as num).toDouble(),
      frameCount: (data['frameCount'] as num).toInt(),
    );
  }
}

const _featureSchemaVersion = 2;
const _bandCount = 8;

final class _FeatureTimeline {
  const _FeatureTimeline(
    this.startSampleIndex,
    this.samplePeriodSamples,
    this.algorithmVersion,
  );

  final int startSampleIndex;
  final int samplePeriodSamples;
  final String algorithmVersion;
}
