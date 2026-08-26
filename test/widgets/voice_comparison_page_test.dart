import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/app/app.dart';
import 'package:voice_trainer/app/app_providers.dart';
import 'package:voice_trainer/app/router/app_router.dart';
import 'package:voice_trainer/app/router/route_names.dart';
import 'package:voice_trainer/core/platform/platform_capabilities.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/analysis/feature_series.dart';
import 'package:voice_trainer/core/domain/analysis/session_summary.dart';
import 'package:voice_trainer/core/domain/analysis/voice_comparison.dart';
import 'package:voice_trainer/core/domain/analysis/voice_production_profile.dart';
import 'package:voice_trainer/core/domain/persistence/session_repository.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/features/voice_comparison/presentation/voice_comparison_evidence_card.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_session_repository.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_voice_comparison_plan_store.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    required String route,
    Size size = const Size(393, 852),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appInitialLocationProvider.overrideWithValue(route),
          platformCapabilitiesProvider.overrideWithValue(
            PlatformCapabilities.android,
          ),
          sessionRepositoryProvider.overrideWithValue(
            InMemorySessionRepository(),
          ),
          voiceComparisonPlanStoreProvider.overrideWithValue(
            InMemoryVoiceComparisonPlanStore(),
          ),
        ],
        child: const VoiceTrainerApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('saves human labels and exposes A/B recording actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, route: RoutePaths.voiceComparison);

    expect(find.bySemanticsLabel('发声对比练习设置'), findsOneWidget);
    expect(find.textContaining('不会从录音自动判定'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('voice-comparison-scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-voice-comparison')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('record-voice-a')), findsOneWidget);
    expect(find.byKey(const Key('record-voice-b')), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('narrow 200 percent layout stays scrollable without overflow', (
    tester,
  ) async {
    await pumpApp(
      tester,
      route: RoutePaths.voiceComparison,
      size: const Size(360, 640),
      textScale: 2,
    );

    expect(find.byKey(const Key('voice-comparison-scroll')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home comparison entry is keyboard reachable', (tester) async {
    await pumpApp(tester, route: RoutePaths.home);
    final entry = find.byKey(const Key('open-voice-comparison'));
    await tester.scrollUntilVisible(entry, 200);
    for (var index = 0; index < 4; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('发声对比练习'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('result evidence card lists dimensions and non-inference scope', (
    tester,
  ) async {
    final plan = _plan();
    final repository = InMemorySessionRepository();
    await repository.save(_take('a', plan, VoiceComparisonSide.a, 5700, -20));
    await repository.save(_take('b', plan, VoiceComparisonSide.b, 5710, -18));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sessionRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VoiceComparisonEvidenceCard(plan: plan),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('voice-comparison-deltas')), findsOneWidget);
    expect(find.textContaining('音高中位数：+10.00 cents'), findsOneWidget);
    expect(find.textContaining('周期性/清晰度'), findsOneWidget);
    expect(find.textContaining('2–4 kHz 相对能量'), findsOneWidget);
    expect(find.textContaining('未测量声带闭合、喉位'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

VoiceComparisonPlan _plan() => VoiceComparisonPlan(
  id: 'widget-plan',
  labelA: PedagogicalVoiceLabel(
    labelKey: VoiceIntentKey.weakMix.name,
    vocabularyId: 'teacher-li',
    vocabularyVersion: '2',
    source: PedagogicalLabelSource.teacherPrompt,
  ),
  labelB: PedagogicalVoiceLabel(
    labelKey: VoiceIntentKey.strongMix.name,
    vocabularyId: 'teacher-li',
    vocabularyVersion: '2',
    source: PedagogicalLabelSource.teacherPrompt,
  ),
  scope: VoiceProductionScope(
    protocolId: 'VP-MIX-01@1',
    taskKind: VoiceProductionTaskKind.matchedPitchContrast,
    pitchContextKey: 'A3',
    vowelIpa: 'a',
    loudnessConditionKey: 'medium',
    styleContextKey: 'pop',
    captureProfileKey: 'same-device-15cm',
    algorithmVersion: 'realtime-analysis-v1',
  ),
  updatedAt: DateTime.utc(2026, 8, 27),
);

PracticeSessionRecord _take(
  String id,
  VoiceComparisonPlan plan,
  VoiceComparisonSide side,
  double pitch,
  double level,
) => PracticeSessionRecord(
  id: id,
  template: const PracticeTemplate(
    id: 'comparison',
    version: 1,
    kind: PracticeKind.targetNote,
    target: PracticeTarget(targetMidiNote: 57),
    reviewStatus: ContentReviewStatus.draft,
  ),
  startedAt: DateTime.utc(2026, 8, 27),
  summary: SessionSummary(
    validFrameCount: 90,
    totalFrameCount: 100,
    qualityFlags: const {},
    pitchStability: StabilitySummary(
      median: pitch,
      medianAbsoluteDeviation: 4,
      slopePerSecond: 0,
      frameCount: 90,
    ),
    levelStability: StabilitySummary(
      median: level,
      medianAbsoluteDeviation: 1,
      slopePerSecond: 0,
      frameCount: 90,
    ),
    onsetDelaySamples: side == VoiceComparisonSide.a ? 3000 : 3300,
  ),
  features: FeatureSeries(
    frameRateHz: 100,
    frames: <AnalysisFrame>[
      AnalysisFrame(
        sampleIndex: 0,
        rmsDbfs: level,
        peakDbfs: -4,
        pitchClarity: side == VoiceComparisonSide.a ? .8 : .9,
        voiced: true,
        f0Hz: 220,
        pitchCents: pitch,
        bandPowersDb: <double>[
          -30,
          -31,
          -32,
          -33,
          side == VoiceComparisonSide.a ? -24 : -20,
          -35,
          -36,
          -37,
        ],
        algorithmVersion: 'realtime-analysis-v1',
      ),
    ],
  ),
  voiceComparison: VoiceComparisonTakeContext(plan: plan, side: side),
);
