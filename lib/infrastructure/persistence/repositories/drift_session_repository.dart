import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/domain/analysis/analysis_frame.dart';
import '../../../core/domain/analysis/analysis_quality_flag.dart';
import '../../../core/domain/analysis/feature_series.dart';
import '../../../core/domain/analysis/session_summary.dart';
import '../../../core/domain/persistence/recording_locator.dart';
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
    this.codec = const FeatureBlobCodec(),
  });
  final AppDatabase _database;
  final FeatureBlobCodec codec;

  @override
  Future<void> save(PracticeSessionRecord record) async {
    final frames = record.features.frames;
    final values = Float32List.fromList(
      frames.map((frame) => frame.f0Hz ?? 0).toList(),
    );
    final payload = codec.encode(
      values: values,
      validity: frames.map((frame) => frame.voiced).toList(),
      samplePeriodMicros:
          (Duration.microsecondsPerSecond / record.features.frameRateHz)
              .round(),
    );
    final template = jsonEncode({
      'id': record.template.id,
      'version': record.template.version,
      'kind': record.template.kind.name,
      'midi': record.template.target.targetMidiNote,
      'tolerance': record.template.target.toleranceCents,
      'review': record.template.reviewStatus.name,
    });
    await _database.saveSessionWithFeature(
      session: PracticeSessionsCompanion.insert(
        id: record.id,
        templateJson: template,
        startedAt: record.startedAt,
        validFrameCount: record.summary.validFrameCount,
        totalFrameCount: record.summary.totalFrameCount,
        qualityFlagsJson: jsonEncode(
          record.summary.qualityFlags.map((flag) => flag.name).toList(),
        ),
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
      feature: FeatureSeriesTableCompanion.insert(
        runId: 0,
        kind: 'pitch_hz',
        frameCount: frames.length,
        codecVersion: featureBlobVersion,
        payload: payload,
        sha256: sha256.convert(payload).toString(),
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
    if (features.isEmpty) return null;
    final decoded = codec.decode(features.single.payload);
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
      summary: SessionSummary(
        validFrameCount: session.validFrameCount,
        totalFrameCount: session.totalFrameCount,
        qualityFlags: flags,
      ),
      features: FeatureSeries(
        frameRateHz:
            (Duration.microsecondsPerSecond / decoded.samplePeriodMicros)
                .round(),
        frames: List<AnalysisFrame>.generate(
          decoded.values.length,
          (i) => AnalysisFrame(
            sampleIndex: i,
            rmsDbfs: 0,
            peakDbfs: 0,
            pitchClarity: 0,
            voiced: decoded.validity[i],
            algorithmVersion: 'phase1-v1',
            f0Hz: decoded.validity[i] ? decoded.values[i] : null,
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
}
