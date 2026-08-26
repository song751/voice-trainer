import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/domain/persistence/recording_locator.dart';
import '../../../core/domain/persistence/session_repository.dart';
import '../../../core/domain/reference/reference_comparison.dart';
import '../../song_reference/application/song_reference_controller.dart';

enum ReferenceComparisonStatus {
  idle,
  loading,
  ready,
  analyzing,
  completed,
  failed,
}

final class ReferenceComparisonState {
  const ReferenceComparisonState({
    this.status = ReferenceComparisonStatus.idle,
    this.sessions = const <PracticeSessionRecord>[],
    this.selectedSessionId,
    this.referenceRange = const PhraseRange(startSeconds: 0, endSeconds: 8),
    this.userRange = const PhraseRange(startSeconds: 0, endSeconds: 8),
    this.artifactsAcceptable = false,
    this.monophonicLeadConfirmed = false,
    this.progress = 0,
    this.report,
    this.failure,
    this.previewFailure,
  });

  final ReferenceComparisonStatus status;
  final List<PracticeSessionRecord> sessions;
  final String? selectedSessionId;
  final PhraseRange referenceRange;
  final PhraseRange userRange;
  final bool artifactsAcceptable;
  final bool monophonicLeadConfirmed;
  final double progress;
  final ReferenceComparisonReport? report;
  final ReferenceAnalysisFailureReason? failure;
  final AudioPreviewFailureReason? previewFailure;

  PracticeSessionRecord? get selectedSession {
    for (final session in sessions) {
      if (session.id == selectedSessionId) return session;
    }
    return null;
  }

  ReferenceComparisonState copyWith({
    ReferenceComparisonStatus? status,
    List<PracticeSessionRecord>? sessions,
    String? selectedSessionId,
    PhraseRange? referenceRange,
    PhraseRange? userRange,
    bool? artifactsAcceptable,
    bool? monophonicLeadConfirmed,
    double? progress,
    ReferenceComparisonReport? report,
    ReferenceAnalysisFailureReason? failure,
    AudioPreviewFailureReason? previewFailure,
    bool clearReport = false,
    bool clearFailure = false,
    bool clearPreviewFailure = false,
  }) => ReferenceComparisonState(
    status: status ?? this.status,
    sessions: sessions ?? this.sessions,
    selectedSessionId: selectedSessionId ?? this.selectedSessionId,
    referenceRange: referenceRange ?? this.referenceRange,
    userRange: userRange ?? this.userRange,
    artifactsAcceptable: artifactsAcceptable ?? this.artifactsAcceptable,
    monophonicLeadConfirmed:
        monophonicLeadConfirmed ?? this.monophonicLeadConfirmed,
    progress: progress ?? this.progress,
    report: clearReport ? null : report ?? this.report,
    failure: clearFailure ? null : failure ?? this.failure,
    previewFailure: clearPreviewFailure
        ? null
        : previewFailure ?? this.previewFailure,
  );
}

final referenceComparisonControllerProvider =
    AutoDisposeNotifierProvider<
      ReferenceComparisonController,
      ReferenceComparisonState
    >(ReferenceComparisonController.new);

final class ReferenceComparisonController
    extends AutoDisposeNotifier<ReferenceComparisonState> {
  late ReferenceFeatureExtractor _extractor;
  late AudioPreview _preview;
  var _operationEpoch = 0;
  var _previewGeneration = 0;
  var _disposed = false;
  Future<void> _previewSerial = Future<void>.value();

  @override
  ReferenceComparisonState build() {
    _extractor = ref.read(referenceFeatureExtractorProvider);
    _preview = ref.read(audioPreviewProvider);
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _operationEpoch++;
      _previewGeneration++;
      unawaited(_extractor.cancel().catchError((_) {}));
      unawaited(_enqueuePreview(_preview.stop).catchError((_) {}));
    });
    return const ReferenceComparisonState();
  }

  Future<void> loadSessions() async {
    final epoch = ++_operationEpoch;
    state = state.copyWith(
      status: ReferenceComparisonStatus.loading,
      clearFailure: true,
      clearReport: true,
    );
    try {
      final sessions = (await ref.read(sessionRepositoryProvider).listRecent())
          .where(
            (session) =>
                session.recording?.storageKind == RecordingStorageKind.file,
          )
          .toList(growable: false);
      final selected = sessions.isEmpty ? null : sessions.first;
      final reference = ref.read(songReferenceControllerProvider).reference;
      final referenceDuration = reference == null
          ? 8.0
          : reference.durationSamples / reference.sampleRate;
      final userDuration = selected == null
          ? 8.0
          : selected.features.frames.length / selected.features.frameRateHz;
      if (!_isCurrent(epoch)) return;
      state = state.copyWith(
        status: ReferenceComparisonStatus.ready,
        sessions: sessions,
        selectedSessionId: selected?.id,
        referenceRange: _initialRange(referenceDuration),
        userRange: _initialRange(userDuration),
      );
    } catch (_) {
      if (!_isCurrent(epoch)) return;
      state = state.copyWith(status: ReferenceComparisonStatus.failed);
    }
  }

  void selectSession(String sessionId) {
    final selected = state.sessions.firstWhere(
      (session) => session.id == sessionId,
    );
    state = state.copyWith(
      selectedSessionId: sessionId,
      userRange: _initialRange(
        selected.features.frames.length / selected.features.frameRateHz,
      ),
      clearReport: true,
      clearFailure: true,
    );
  }

  void setReferenceRange(PhraseRange range) {
    state = state.copyWith(
      referenceRange: range,
      artifactsAcceptable: false,
      monophonicLeadConfirmed: false,
      clearReport: true,
    );
  }

  void setUserRange(PhraseRange range) {
    state = state.copyWith(userRange: range, clearReport: true);
  }

  void setArtifactsAcceptable(bool value) {
    state = state.copyWith(artifactsAcceptable: value, clearReport: true);
  }

  void setMonophonicLeadConfirmed(bool value) {
    state = state.copyWith(monophonicLeadConfirmed: value, clearReport: true);
  }

  Future<void> compare() async {
    final reference = ref.read(songReferenceControllerProvider).reference;
    final vocals = reference?.vocals;
    final session = state.selectedSession;
    if (reference == null || vocals == null || session == null) {
      state = state.copyWith(status: ReferenceComparisonStatus.failed);
      return;
    }
    final epoch = ++_operationEpoch;
    final referenceRange = state.referenceRange;
    final userRange = state.userRange;
    final review = ReferenceComparisonReview(
      artifactsAcceptable: state.artifactsAcceptable,
      monophonicLeadConfirmed: state.monophonicLeadConfirmed,
    );
    state = state.copyWith(
      status: ReferenceComparisonStatus.analyzing,
      progress: 0,
      clearFailure: true,
      clearReport: true,
    );
    try {
      final referenceFeatures = await _extractor.analyze(
        vocals: vocals,
        onProgress: (progress) {
          if (_isCurrent(epoch) &&
              state.status == ReferenceComparisonStatus.analyzing) {
            state = state.copyWith(progress: progress);
          }
        },
      );
      if (!_isCurrent(epoch)) return;
      final report = ref
          .read(referenceComparisonEngineProvider)
          .compare(
            reference: reference,
            referenceFeatures: referenceFeatures,
            session: session,
            referenceRange: referenceRange,
            userRange: userRange,
            review: review,
          );
      if (!_isCurrent(epoch)) return;
      state = state.copyWith(
        status: ReferenceComparisonStatus.completed,
        progress: 1,
        report: report,
      );
    } on ReferenceAnalysisFailure catch (failure) {
      if (!_isCurrent(epoch)) return;
      state = state.copyWith(
        status: ReferenceComparisonStatus.failed,
        failure: failure.reason,
      );
    } catch (_) {
      if (!_isCurrent(epoch)) return;
      state = state.copyWith(
        status: ReferenceComparisonStatus.failed,
        failure: ReferenceAnalysisFailureReason.processingFailed,
      );
    }
  }

  Future<void> cancel() async {
    await _extractor.cancel();
  }

  Future<void> previewReference() async {
    final vocals = ref.read(songReferenceControllerProvider).reference?.vocals;
    if (vocals == null) return;
    await _play(vocals.locator, state.referenceRange);
  }

  Future<void> previewUser() async {
    final locator = state.selectedSession?.recording;
    if (locator?.storageKind != RecordingStorageKind.file) {
      state = state.copyWith(
        previewFailure: AudioPreviewFailureReason.unsupportedLocator,
      );
      return;
    }
    await _play(locator!.value, state.userRange);
  }

  Future<void> stopPreview() {
    final generation = ++_previewGeneration;
    return _enqueuePreview(() async {
      if (!_isPreviewCurrent(generation)) return;
      await _preview.stop();
    });
  }

  Future<void> _play(String path, PhraseRange range) async {
    final generation = ++_previewGeneration;
    if (!_disposed) state = state.copyWith(clearPreviewFailure: true);
    await _enqueuePreview(() async {
      if (!_isPreviewCurrent(generation)) return;
      try {
        await _preview.stop();
        if (!_isPreviewCurrent(generation)) return;
        await _preview.playFile(path: path, range: range);
        if (!_isPreviewCurrent(generation)) await _preview.stop();
      } on AudioPreviewFailure catch (failure) {
        if (_isPreviewCurrent(generation)) {
          state = state.copyWith(previewFailure: failure.reason);
        }
      } catch (_) {
        if (_isPreviewCurrent(generation)) {
          state = state.copyWith(
            previewFailure: AudioPreviewFailureReason.playbackFailed,
          );
        }
      }
    });
  }

  Future<void> _enqueuePreview(Future<void> Function() operation) {
    final queued = _previewSerial.then((_) => operation());
    _previewSerial = queued.catchError((_) {});
    return queued;
  }

  bool _isCurrent(int epoch) => !_disposed && epoch == _operationEpoch;

  bool _isPreviewCurrent(int generation) =>
      !_disposed && generation == _previewGeneration;

  PhraseRange _initialRange(double durationSeconds) => PhraseRange(
    startSeconds: 0,
    endSeconds: durationSeconds.clamp(0.1, 8.0).toDouble(),
  );
}
