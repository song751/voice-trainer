import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/app/app.dart';
import 'package:voice_trainer/app/app_providers.dart';
import 'package:voice_trainer/app/router/app_router.dart';
import 'package:voice_trainer/app/router/route_names.dart';
import 'package:voice_trainer/core/domain/analysis/feature_series.dart';
import 'package:voice_trainer/core/domain/analysis/session_summary.dart';
import 'package:voice_trainer/core/domain/persistence/recording_locator.dart';
import 'package:voice_trainer/core/domain/persistence/session_repository.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';
import 'package:voice_trainer/features/live_practice/application/live_practice_controller.dart';
import 'package:voice_trainer/infrastructure/audio/fake_audio_capture.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_recording_store.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_session_repository.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    required String route,
    required InMemorySessionRepository repository,
    PracticeSessionRecord? selectedRecord,
    PlatformCapabilities capabilities = PlatformCapabilities.windows,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appInitialLocationProvider.overrideWithValue(route),
          platformCapabilitiesProvider.overrideWithValue(capabilities),
          audioCaptureProvider.overrideWithValue(FakeAudioCapture()),
          sessionRepositoryProvider.overrideWithValue(repository),
          if (selectedRecord != null)
            latestPracticeSessionProvider.overrideWith((ref) => selectedRecord),
        ],
        child: const VoiceTrainerApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home shows quick start, history, and the latest result', (
    tester,
  ) async {
    final repository = InMemorySessionRepository();
    await repository.save(_record());

    await pumpApp(tester, route: RoutePaths.home, repository: repository);

    expect(find.byKey(const Key('open-live-practice')), findsOneWidget);
    expect(find.byKey(const Key('open-history')), findsOneWidget);
    expect(find.byKey(const Key('home-recent-result')), findsOneWidget);
    expect(find.textContaining('目标命中率 68%'), findsOneWidget);
  });

  testWidgets('result exposes stored measurements and rule provenance', (
    tester,
  ) async {
    final repository = InMemorySessionRepository();
    final record = _record();
    await repository.save(record);

    await pumpApp(
      tester,
      route: RoutePaths.result,
      repository: repository,
      selectedRecord: record,
    );

    expect(find.byKey(const Key('result-pitch-stability')), findsOneWidget);
    expect(find.byKey(const Key('result-level-stability')), findsOneWidget);
    expect(find.byKey(const Key('result-onset')), findsOneWidget);
    expect(find.textContaining('置信度 92%'), findsOneWidget);
    expect(find.textContaining('范围：会话'), findsOneWidget);
    expect(find.textContaining('证据：目标命中率'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.textContaining('练习 ID：repeat-target-note'), findsOneWidget);
  });

  testWidgets('history opens details and deletes only after confirmation', (
    tester,
  ) async {
    final store = InMemoryRecordingStore();
    final repository = InMemorySessionRepository(recordingStore: store);
    await repository.save(_record());

    await pumpApp(tester, route: RoutePaths.history, repository: repository);

    expect(find.text('已保存录音'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete-session-session-1')));
    await tester.pumpAndSettle();
    expect(find.text('删除这次练习？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-delete-session')));
    await tester.pumpAndSettle();
    expect(repository.records, hasLength(1));

    await tester.tap(find.byKey(const Key('delete-session-session-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-session')));
    await tester.pumpAndSettle();

    expect(repository.records, isEmpty);
    expect(find.text('暂无历史练习记录。'), findsOneWidget);
  });

  testWidgets('settings reports capabilities and local privacy facts', (
    tester,
  ) async {
    await pumpApp(
      tester,
      route: RoutePaths.settings,
      repository: InMemorySessionRepository(),
      capabilities: PlatformCapabilities.web,
    );

    expect(find.text('Web'), findsOneWidget);
    expect(find.textContaining('最长 60 秒'), findsOneWidget);
    expect(find.textContaining('当前使用测试适配器'), findsOneWidget);
    expect(find.textContaining('默认不上传网络'), findsOneWidget);
    expect(find.textContaining('设置将在后续'), findsNothing);
  });
}

PracticeSessionRecord _record() => PracticeSessionRecord(
  id: 'session-1',
  template: const PracticeTemplate(
    id: 'target-a3',
    version: 1,
    kind: PracticeKind.targetNote,
    target: PracticeTarget(targetMidiNote: 57),
    reviewStatus: ContentReviewStatus.reviewed,
  ),
  startedAt: DateTime.utc(2026, 8, 26, 8, 30),
  summary: SessionSummary(
    validFrameCount: 92,
    totalFrameCount: 100,
    targetHitRate: .68,
    pitchStability: const StabilitySummary(
      median: 6902,
      medianAbsoluteDeviation: 7.5,
      slopePerSecond: -1.25,
      frameCount: 92,
    ),
    levelStability: const StabilitySummary(
      median: -18,
      medianAbsoluteDeviation: 1.8,
      slopePerSecond: -.4,
      frameCount: 92,
    ),
    onsetDelaySamples: 3840,
    qualityFlags: const {},
  ),
  features: FeatureSeries(frameRateHz: 100, frames: const []),
  recording: const RecordingLocator(
    value: 'memory://session-1.wav',
    storageKind: RecordingStorageKind.file,
  ),
);
