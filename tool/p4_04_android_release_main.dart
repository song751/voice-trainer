import 'package:flutter/material.dart';
import 'package:voice_trainer/app/default_persistence.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/analysis/feature_series.dart';
import 'package:voice_trainer/core/domain/analysis/session_summary.dart';
import 'package:voice_trainer/core/domain/persistence/session_repository.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var status = 'P4_04_RELEASE_PERSISTENCE_FAILED';
  final adapters = createDefaultPersistenceAdapters(
    PlatformCapabilities.android,
  );
  try {
    const sessionId = 'p4-04-release-restart';
    final existing = await adapters.sessionRepository.findById(sessionId);
    if (existing == null) {
      await adapters.sessionRepository.save(_record(sessionId));
      status = 'P4_04_RELEASE_PERSISTENCE_CREATED';
    } else {
      status = 'P4_04_RELEASE_PERSISTENCE_RESTORED';
    }
  } catch (_) {
    // The visible sentinel deliberately excludes exception text and paths.
  } finally {
    await adapters.dispose();
  }

  runApp(_ReleaseProbeApp(status: status));
}

PracticeSessionRecord _record(String id) => PracticeSessionRecord(
  id: id,
  template: const PracticeTemplate(
    id: 'p4-04-target-note',
    version: 1,
    kind: PracticeKind.targetNote,
    target: PracticeTarget(targetMidiNote: 57),
    reviewStatus: ContentReviewStatus.reviewed,
  ),
  startedAt: DateTime.utc(2026, 8, 26),
  summary: SessionSummary(
    validFrameCount: 1,
    totalFrameCount: 1,
    qualityFlags: const {},
  ),
  features: FeatureSeries(
    frameRateHz: 100,
    frames: <AnalysisFrame>[
      AnalysisFrame(
        sampleIndex: 0,
        rmsDbfs: -18,
        peakDbfs: -4,
        pitchClarity: .95,
        voiced: true,
        f0Hz: 220,
        pitchCents: 5700,
        algorithmVersion: 'p4-04-test',
      ),
    ],
  ),
);

final class _ReleaseProbeApp extends StatelessWidget {
  const _ReleaseProbeApp({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: Center(child: Text(status))),
  );
}
