import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/app/app_providers.dart';
import 'package:voice_trainer/app/router/route_names.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_config.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_engine.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_frame.dart';
import 'package:voice_trainer/core/domain/analysis/analysis_quality_flag.dart';
import 'package:voice_trainer/core/domain/analysis/feature_series.dart';
import 'package:voice_trainer/core/domain/analysis/session_summary.dart';
import 'package:voice_trainer/core/domain/audio/audio_capture.dart';
import 'package:voice_trainer/core/domain/audio/capture_format.dart';
import 'package:voice_trainer/core/domain/audio/pcm_chunk.dart';
import 'package:voice_trainer/core/domain/persistence/recording_locator.dart';
import 'package:voice_trainer/core/domain/persistence/recording_sink.dart';
import 'package:voice_trainer/core/domain/persistence/session_repository.dart';
import 'package:voice_trainer/core/domain/practice/practice_target.dart';
import 'package:voice_trainer/core/domain/practice/practice_template.dart';
import 'package:voice_trainer/core/domain/reference/song_reference.dart';
import 'package:voice_trainer/core/errors/failure.dart';
import 'package:voice_trainer/features/live_practice/application/live_practice_controller.dart';
import 'package:voice_trainer/features/live_practice/presentation/live_practice_page.dart';
import 'package:voice_trainer/infrastructure/audio/fake_audio_capture.dart';
import 'package:voice_trainer/infrastructure/dsp/fake_analysis_engine.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_recording_store.dart';
import 'package:voice_trainer/infrastructure/persistence/in_memory_session_repository.dart';

import '../../integration_test/support/p4_12_ui_fixture.dart';

void main() {
  const portraitProfiles = <P412UiProfile>[
    P412UiProfile.windowsPortrait,
    P412UiProfile.androidPortrait,
    P412UiProfile.webPortrait,
  ];
  const fiveRoutes = <String>[
    RoutePaths.home,
    RoutePaths.livePractice,
    RoutePaths.result,
    RoutePaths.history,
    RoutePaths.settings,
  ];

  testWidgets(
    'Windows Android and Web five-page portrait matrix survives dark 200% text',
    (tester) async {
      final fixture = P412UiFixture(tester);
      for (final profile in portraitProfiles) {
        for (final route in fiveRoutes) {
          await fixture.pump(
            profile: profile,
            route: route,
            textScaleFactor: 2,
            brightness: Brightness.dark,
          );
          expect(
            find.byType(Scaffold),
            findsWidgets,
            reason: '${profile.name} $route',
          );
          expect(find.byType(NavigationBar), findsOneWidget);
          expect(
            Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
            Brightness.dark,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${profile.name} $route',
          );
        }
      }
    },
  );

  testWidgets('song import stays usable across profiles at dark 200% text', (
    tester,
  ) async {
    final fixture = P412UiFixture(tester);
    for (final profile in portraitProfiles) {
      await fixture.pump(
        profile: profile,
        route: RoutePaths.songImport,
        textScaleFactor: 2,
        brightness: Brightness.dark,
        extraOverrides: <Override>[
          songFilePickerProvider.overrideWithValue(
            const _SongPicker(_SongSource()),
          ),
          songSeparatorProvider.overrideWithValue(
            const UnavailableSongSeparator(),
          ),
          songModelManagerProvider.overrideWithValue(
            const UnavailableSongSeparator(),
          ),
        ],
      );
      expect(tester.takeException(), isNull, reason: profile.name);
      expect(find.textContaining('不会上传云端'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('select-song-file')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const Key('select-song-file')),
        findsOneWidget,
        reason: profile.name,
      );
    }
  });

  testWidgets(
    'song import covers rights runtime progress and cancellation states',
    (tester) async {
      final fixture = P412UiFixture(tester);
      await fixture.pump(
        profile: P412UiProfile.androidPortrait,
        route: RoutePaths.songImport,
        extraOverrides: <Override>[
          songFilePickerProvider.overrideWithValue(
            const _SongPicker(_SongSource()),
          ),
          songSeparatorProvider.overrideWithValue(
            const UnavailableSongSeparator(),
          ),
          songModelManagerProvider.overrideWithValue(
            const UnavailableSongSeparator(),
          ),
        ],
      );
      await tester.tap(find.byKey(const Key('select-song-file')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('separate-song-vocals')));
      await tester.pumpAndSettle();
      expect(find.text('请先确认本地处理权利。'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('separate-song-vocals')));
      await tester.pumpAndSettle();
      expect(find.text('自动人声分离运行时尚未就绪。'), findsOneWidget);

      final separator = _ControlledSongSeparator();
      await fixture.pump(
        profile: P412UiProfile.webPortrait,
        route: RoutePaths.songImport,
        extraOverrides: <Override>[
          songFilePickerProvider.overrideWithValue(
            const _SongPicker(_SongSource()),
          ),
          songSeparatorProvider.overrideWithValue(separator),
          songModelManagerProvider.overrideWithValue(separator),
        ],
      );
      await tester.tap(find.byKey(const Key('select-song-file')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('separate-song-vocals')));
      await tester.pump();
      separator.reportProgress(0.4);
      await tester.pump();
      expect(find.text('正在本地分离 40%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('已取消分离。'), findsOneWidget);
      expect(separator.cancelled, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  group('typed live-practice error fixture matrix', () {
    testWidgets('permission denied', (tester) async {
      await _pumpAndStart(
        tester,
        capture: FakeAudioCapture(
          permissionResult: const PermissionDenied(
            PermissionDeniedFailure(canRequestAgain: true),
          ),
        ),
      );
      expect(find.text('无法开始：未授予麦克风权限。'), findsOneWidget);
    });

    testWidgets('no device or input', (tester) async {
      await _pumpAndStart(
        tester,
        capture: FakeAudioCapture(
          startFailure: const CaptureFailure(
            CaptureFailureReason.deviceUnavailable,
          ),
        ),
      );
      expect(find.text('无法开始：未检测到可用的麦克风输入。'), findsOneWidget);
    });

    testWidgets('unsupported effective format', (tester) async {
      await _pumpAndStart(
        tester,
        analysis: FakeAnalysisEngine(
          initializeFailure: const AnalysisFailure(
            AnalysisFailureReason.unsupportedFormat,
          ),
        ),
      );
      expect(find.text('无法开始：当前麦克风格式不受支持，请更换输入设备或浏览器。'), findsOneWidget);
    });

    testWidgets('worker terminal processing failure', (tester) async {
      final capture = FakeAudioCapture();
      await _pumpAndStart(
        tester,
        capture: capture,
        analysis: FakeAnalysisEngine(failPushes: 1),
      );
      capture.emit(_chunk());
      await _drainTester(tester);
      expect(find.text('分析 worker 暂时不可用，请重试。'), findsOneWidget);
    });

    testWidgets('recording append failure', (tester) async {
      final capture = FakeAudioCapture();
      final store = InMemoryRecordingStore();
      await _pumpAndStart(
        tester,
        capture: capture,
        store: store,
        sink: _FailingSink(
          InMemoryRecordingSink(store),
          const RecordingFailure(),
        ),
      );
      capture.emit(_chunk());
      await _drainTester(tester);
      expect(find.text('录音数据未能保存，本次练习已停止。'), findsOneWidget);
    });

    testWidgets('persistence quota failure', (tester) async {
      final store = InMemoryRecordingStore();
      await _pumpAndStart(
        tester,
        store: store,
        sink: _FailingSink(
          InMemoryRecordingSink(store),
          const PersistenceFailure(
            reason: PersistenceFailureReason.quotaExceeded,
          ),
          failOnOpen: true,
        ),
      );
      expect(find.text('本地存储空间不足，无法保存练习结果。'), findsOneWidget);
    });
  });

  testWidgets('worker restart and fallback remain visible but non-diagnostic', (
    tester,
  ) async {
    final analysis = _MetricAnalysisEngine();
    await _pumpAndStart(tester, analysis: analysis);

    analysis.emit(
      const AnalysisWorkerMetrics(
        droppedSamples: 0,
        restartCount: 1,
        usingFallback: true,
        state: AnalysisWorkerState.fallback,
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('worker-status')), findsOneWidget);
    expect(find.text('分析 worker 已切换到兼容模式'), findsOneWidget);
    expect(find.textContaining('稳定性将分开计算'), findsOneWidget);
  });

  testWidgets('low quality and no voiced frames suppress interpretation', (
    tester,
  ) async {
    final fixture = P412UiFixture(tester);
    for (final record in <PracticeSessionRecord>[
      _qualityRecord(
        'low-quality',
        validFrames: 4,
        flags: const {
          AnalysisQualityFlag.clipping,
          AnalysisQualityFlag.inputTooLow,
        },
      ),
      _qualityRecord(
        'no-voiced',
        validFrames: 0,
        flags: const {AnalysisQualityFlag.insufficientValidFrames},
      ),
    ]) {
      await fixture.pump(
        profile: P412UiProfile.webPortrait,
        route: RoutePaths.result,
        repository: InMemorySessionRepository(),
        extraOverrides: [
          // The result page consumes the selected record directly.
          latestPracticeSessionProvider.overrideWith((ref) => record),
        ],
      );
      expect(find.textContaining('已抑制进一步解释'), findsOneWidget);
      expect(find.textContaining('目标命中率：录音质量不足'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('result-recommendation-REC-QUALITY-01')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.textContaining('先改善录音条件'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('completed result history and confirmed delete stay connected', (
    tester,
  ) async {
    final capture = FakeAudioCapture();
    final store = InMemoryRecordingStore();
    final repository = InMemorySessionRepository(recordingStore: store);
    final fixture = P412UiFixture(tester);
    await fixture.pump(
      profile: P412UiProfile.androidPortrait,
      route: RoutePaths.livePractice,
      capture: capture,
      recordingStore: store,
      repository: repository,
    );
    await tester.tap(find.byKey(const Key('start-practice')));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LivePracticePage)),
    );
    await tester.runAsync(
      () => container.read(livePracticeControllerProvider.notifier).stop(),
    );
    await tester.pump();
    expect(find.text('练习已完成。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('view-practice-result')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('result-valid-frames')), findsOneWidget);

    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('history-session-p4-12-fixture-session')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('delete-session-p4-12-fixture-session')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-session')));
    await tester.pumpAndSettle();
    expect(find.text('暂无历史练习记录。'), findsOneWidget);
  });

  testWidgets('touch mouse keyboard and system back share the shell contract', (
    tester,
  ) async {
    final fixture = P412UiFixture(tester);
    await fixture.pump(
      profile: P412UiProfile.androidPortrait,
      route: RoutePaths.home,
    );
    await tester.tap(find.text('练习'));
    await tester.pumpAndSettle();
    expect(find.text('实时练习'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('目标音练习'), findsOneWidget);

    await fixture.pump(
      profile: P412UiProfile.windowsWide,
      route: RoutePaths.home,
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('历史')));
    await mouse.down(tester.getCenter(find.text('历史')));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.text('历史记录'), findsOneWidget);

    final settings = find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text('设置'),
    );
    Focus.of(tester.element(settings)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('设置与能力'), findsOneWidget);
  });

  testWidgets('live readout exposes one bounded semantic container', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await P412UiFixture(
      tester,
    ).pump(profile: P412UiProfile.webPortrait, route: RoutePaths.livePractice);

    final node = tester.getSemantics(
      find.byKey(const Key('live-analysis-readout')),
    );
    expect(node.label, contains('实时音高与信号质量'));
    expect(node.label, contains('RMS：等待输入'));
    expect(node.childrenCount, lessThanOrEqualTo(1));
    semantics.dispose();
  });
}

Future<void> _pumpAndStart(
  WidgetTester tester, {
  AudioCapture? capture,
  AnalysisEngine? analysis,
  InMemoryRecordingStore? store,
  RecordingSink? sink,
}) async {
  final actualStore = store ?? InMemoryRecordingStore();
  await P412UiFixture(tester).pump(
    profile: P412UiProfile.webPortrait,
    route: RoutePaths.livePractice,
    capture: capture,
    analysis: analysis,
    recordingStore: actualStore,
    recordingSink: sink,
  );
  await tester.tap(find.byKey(const Key('start-practice')));
  await tester.pumpAndSettle();
}

PcmChunk _chunk() => PcmChunk(
  sequenceNumber: 0,
  firstSampleIndex: 0,
  format: const CaptureFormat(sampleRate: 48000, channels: 1),
  bytes: Uint8List(2048),
  captureMonotonicTime: Duration.zero,
);

Future<void> _drainTester(WidgetTester tester) async {
  for (var index = 0; index < 8; index += 1) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

PracticeSessionRecord _qualityRecord(
  String id, {
  required int validFrames,
  required Set<AnalysisQualityFlag> flags,
}) => PracticeSessionRecord(
  id: id,
  template: const PracticeTemplate(
    id: 'p4-12-quality',
    version: 1,
    kind: PracticeKind.targetNote,
    target: PracticeTarget(targetMidiNote: 57),
    reviewStatus: ContentReviewStatus.reviewed,
  ),
  startedAt: DateTime.utc(2026, 8, 27),
  summary: SessionSummary(
    validFrameCount: validFrames,
    totalFrameCount: 100,
    qualityFlags: flags,
  ),
  features: FeatureSeries(frameRateHz: 100, frames: const []),
);

final class _FailingSink implements RecordingSink {
  _FailingSink(this.delegate, this.error, {this.failOnOpen = false});

  final RecordingSink delegate;
  final Object error;
  final bool failOnOpen;

  @override
  Future<void> open(RecordingMetadata metadata) {
    if (failOnOpen) return Future<void>.error(error);
    return delegate.open(metadata);
  }

  @override
  Future<void> append(PcmChunk chunk) => Future<void>.error(error);

  @override
  Future<RecordingLocator> finalize() => delegate.finalize();

  @override
  Future<void> abort() => delegate.abort();
}

final class _MetricAnalysisEngine implements AnalysisEngine {
  final _delegate = FakeAnalysisEngine();
  final _metrics = StreamController<AnalysisWorkerMetrics>.broadcast(
    sync: true,
  );
  AnalysisWorkerMetrics _current = const AnalysisWorkerMetrics(
    droppedSamples: 0,
    restartCount: 0,
    usingFallback: false,
    state: AnalysisWorkerState.primary,
  );

  void emit(AnalysisWorkerMetrics metrics) {
    _current = metrics;
    _metrics.add(metrics);
  }

  @override
  AnalysisWorkerMetrics get workerMetrics => _current;

  @override
  Stream<AnalysisWorkerMetrics> get workerMetricsStream => _metrics.stream;

  @override
  Future<void> initialize(AnalysisConfig config) =>
      _delegate.initialize(config);

  @override
  Future<AnalysisBatch> pushPcm(PcmBatch batch) => _delegate.pushPcm(batch);

  @override
  Future<AnalysisFinalization> finish() => _delegate.finish();

  @override
  Future<void> reset() => _delegate.reset();

  @override
  Future<void> dispose() async {
    await _delegate.dispose();
    await _metrics.close();
  }
}

final class _SongPicker implements SongFilePicker {
  const _SongPicker(this.source);

  final SongFileSource? source;

  @override
  Future<SongFileSource?> pickSong() async => source;
}

final class _SongSource implements SongFileSource {
  const _SongSource();

  @override
  String get displayName => 'p4-12-song.wav';

  @override
  Future<int> length() async => 4096;

  @override
  Stream<List<int>> openRead() => Stream<List<int>>.value(Uint8List(4096));
}

final class _ControlledSongSeparator
    implements SongSeparator, SongModelManager {
  final _result = Completer<SeparatedSongReference>();
  void Function(double progress)? _onProgress;
  bool cancelled = false;

  @override
  bool get automaticSeparationAvailable => true;

  @override
  Future<SongModelStatus> installModel(SongFileSource source) async =>
      const SongModelStatus(availability: SongModelAvailability.ready);

  @override
  Future<SongModelStatus> probe() async =>
      const SongModelStatus(availability: SongModelAvailability.ready);

  void reportProgress(double progress) => _onProgress?.call(progress);

  @override
  Future<void> cancel() async {
    cancelled = true;
    if (!_result.isCompleted) {
      _result.completeError(
        const SongSeparationFailure(SongSeparationFailureReason.cancelled),
      );
    }
  }

  @override
  Future<SeparatedSongReference> separate({
    required SongFileSource source,
    required bool rightsAcknowledged,
    required void Function(double progress) onProgress,
  }) {
    _onProgress = onProgress;
    return _result.future;
  }
}
