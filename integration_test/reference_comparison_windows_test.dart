import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/analysis/feature_series.dart';
import 'package:voice_trainer/core/domain/analysis/session_summary.dart';
import 'package:voice_trainer/core/domain/persistence/recording_locator.dart';
import 'package:voice_trainer/core/domain/persistence/audio_content_identity.dart';
import 'package:voice_trainer/core/domain/persistence/session_repository.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/core/domain/reference/reference_comparison.dart';
import 'package:voice_trainer/core/domain/reference/song_reference.dart';
import 'package:voice_trainer/infrastructure/reference_comparison/default_reference_comparison_native.dart';
import 'package:voice_trainer/infrastructure/persistence/recordings/native_managed_audio_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows extracts, compares and plays local phrase windows', (
    tester,
  ) async {
    expect(
      Platform.isWindows,
      isTrue,
      reason: 'This is a Windows product gate.',
    );
    final directory = await Directory.systemTemp.createTemp(
      'voice_trainer_reference_comparison_',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final wav = File('${directory.path}${Platform.pathSeparator}vocals.wav');
    await wav.writeAsBytes(_stereoToneWav(), flush: true);
    final identity = await NativeManagedAudioStore.identify(wav);
    final lease = _FixtureLease(await wav.readAsBytes(), identity);
    final stem = SongStemReference(
      locator: wav.path,
      sha256: identity.sha256,
      byteLength: identity.byteLength,
    );

    final extractor = NativeReferenceFeatureExtractor();
    final referenceFeatures = await extractor.analyze(
      vocals: lease,
      onProgress: (_) {},
    );
    expect(referenceFeatures.algorithmVersion, 'reference-yin-14k7-v1');
    expect(referenceFeatures.frames.length, greaterThan(250));
    expect(
      referenceFeatures.frames.where((frame) => frame.voiced).length,
      greaterThan(240),
    );
    final medianPitch =
        referenceFeatures.frames
            .where((frame) => frame.pitchCents != null)
            .map((frame) => frame.pitchCents!)
            .toList()
          ..sort();
    expect(medianPitch[medianPitch.length ~/ 2], closeTo(5700, 2));

    final userFrames = referenceFeatures.frames.indexed
        .map((entry) {
          final (index, frame) = entry;
          return AnalysisFrame(
            sampleIndex: index * 480,
            rmsDbfs: frame.rmsDbfs,
            peakDbfs: frame.rmsDbfs,
            pitchClarity: frame.pitchClarity,
            voiced: frame.voiced,
            algorithmVersion: 'p3-production-v1',
            pitchCents: frame.pitchCents == null
                ? null
                : frame.pitchCents! + 200,
            qualityFlags: frame.qualityFlags,
          );
        })
        .toList(growable: false);
    final session = PracticeSessionRecord(
      id: 'windows-reference-gate',
      template: const PracticeTemplate(
        id: 'phrase',
        version: 1,
        kind: PracticeKind.sustainedNote,
        target: PracticeTarget(targetMidiNote: 57),
        reviewStatus: ContentReviewStatus.draft,
      ),
      startedAt: DateTime.utc(2026, 8, 27),
      summary: SessionSummary(
        validFrameCount: userFrames.length,
        totalFrameCount: userFrames.length,
        targetHitRate: 1,
        qualityFlags: {},
      ),
      features: FeatureSeries(
        frameRateHz: 100,
        frames: userFrames,
        sourceAudioIdentity: identity,
      ),
      recording: RecordingLocator(
        value: wav.path,
        storageKind: RecordingStorageKind.file,
        identity: identity,
      ),
    );
    final report = const ReferenceComparisonEngine().compare(
      ComparisonInputSnapshot(
        reference: SeparatedSongReference(
          displayName: 'deterministic-local-fixture.wav',
          generatedByModel: true,
          modelId: 'integration-fixture',
          algorithmVersion: 'srd04-umxhq-waveform-v1',
          sampleRate: 44100,
          channels: 2,
          durationSamples: 44100 * 3,
          artifactWarning: true,
          vocals: stem,
        ),
        referenceFeatures: referenceFeatures,
        userFeatures: ReferenceAnalysisSeries(
          sampleRate: 48000,
          frameRateHz: 100,
          algorithmVersion: referenceFeatures.algorithmVersion,
          frames: userFrames,
          sourceAudioIdentity: identity,
        ),
        session: session,
        referenceRange: const PhraseRange(startSeconds: 0, endSeconds: 2.5),
        userRange: const PhraseRange(startSeconds: 0, endSeconds: 2.5),
        review: const ReferenceComparisonReview(
          artifactsAcceptable: true,
          monophonicLeadConfirmed: true,
        ),
        referenceLeaseIdentity: identity,
        userLeaseIdentity: identity,
      ),
    );
    expect(report.suppressed, isFalse);
    expect(report.alignment!.transpositionSemitones, 2);
    expect(report.metrics!.pitchContourMedianAbsoluteCents, closeTo(0, 0.1));

    final preview = NativeAudioPreview();
    addTearDown(preview.dispose);
    await preview.playFile(
      source: lease,
      range: const PhraseRange(startSeconds: 0.1, endSeconds: 0.25),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await preview.stop();
  });
}

final class _FixtureLease implements VerifiedAudioLease {
  const _FixtureLease(this._bytes, this.identity);

  @override
  Uint8List get bytes => Uint8List.fromList(_bytes);

  final Uint8List _bytes;

  @override
  final AudioContentIdentity identity;

  @override
  Future<void> dispose() async {}
}

Uint8List _stereoToneWav() {
  const sampleRate = 44100;
  const frames = sampleRate * 3;
  const channels = 2;
  const bitsPerSample = 16;
  final dataBytes = frames * channels * 2;
  final output = ByteData(44 + dataBytes);
  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      output.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  output.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  output.setUint32(16, 16, Endian.little);
  output.setUint16(20, 1, Endian.little);
  output.setUint16(22, channels, Endian.little);
  output.setUint32(24, sampleRate, Endian.little);
  output.setUint32(28, sampleRate * channels * 2, Endian.little);
  output.setUint16(32, channels * 2, Endian.little);
  output.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  output.setUint32(40, dataBytes, Endian.little);
  var offset = 44;
  for (var frame = 0; frame < frames; frame++) {
    final sample = (math.sin(math.pi * 2 * 220 * frame / sampleRate) * 8192)
        .round();
    output.setInt16(offset, sample, Endian.little);
    output.setInt16(offset + 2, sample, Endian.little);
    offset += 4;
  }
  return output.buffer.asUint8List();
}
