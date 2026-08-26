import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/domain/persistence/recording_locator.dart';
import '../../../core/domain/persistence/audio_content_identity.dart';
import '../../../core/domain/persistence/session_repository.dart';
import '../../../core/domain/persistence/verified_recording_resolver.dart';
import '../../../core/domain/reference/reference_comparison.dart';
import '../../../core/domain/reference/song_reference.dart';
import '../../../core/domain/reference/wav_media_timeline.dart';
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
    this.userMediaDurations = const <String, double>{},
    this.loadingUserMedia = false,
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
  final Map<String, double> userMediaDurations;
  final bool loadingUserMedia;

  PracticeSessionRecord? get selectedSession {
    for (final session in sessions) {
      if (session.id == selectedSessionId) return session;
    }
    return null;
  }

  double? get selectedUserMediaDuration =>
      selectedSessionId == null ? null : userMediaDurations[selectedSessionId];

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
    Map<String, double>? userMediaDurations,
    bool? loadingUserMedia,
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
    userMediaDurations: userMediaDurations ?? this.userMediaDurations,
    loadingUserMedia: loadingUserMedia ?? this.loadingUserMedia,
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
  late VerifiedRecordingResolver _recordingResolver;
  late VerifiedSongStemResolver _stemResolver;
  var _operationEpoch = 0;
  var _previewGeneration = 0;
  var _disposed = false;
  Future<void> _previewSerial = Future<void>.value();

  @override
  ReferenceComparisonState build() {
    _extractor = ref.read(referenceFeatureExtractorProvider);
    _preview = ref.read(audioPreviewProvider);
    _recordingResolver = ref.read(verifiedRecordingResolverProvider);
    _stemResolver = ref.read(verifiedSongStemResolverProvider);
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
      final mediaDuration = selected == null
          ? null
          : await _verifiedMediaDuration(selected);
      final mediaDurations = mediaDuration == null
          ? const <String, double>{}
          : <String, double>{selected!.id: mediaDuration};
      final reference = ref.read(songReferenceControllerProvider).reference;
      final referenceDuration = reference == null
          ? 8.0
          : reference.durationSamples / reference.sampleRate;
      final userDuration = selected == null
          ? 8.0
          : mediaDurations[selected.id] ?? 0.1;
      if (!_isCurrent(epoch)) return;
      state = state.copyWith(
        status: ReferenceComparisonStatus.ready,
        sessions: sessions,
        selectedSessionId: selected?.id,
        userMediaDurations: mediaDurations,
        loadingUserMedia: false,
        referenceRange: _initialRange(referenceDuration),
        userRange: _initialRange(userDuration),
      );
    } catch (_) {
      if (!_isCurrent(epoch)) return;
      state = state.copyWith(status: ReferenceComparisonStatus.failed);
    }
  }

  Future<void> selectSession(String sessionId) async {
    final selected = state.sessions.firstWhere(
      (session) => session.id == sessionId,
    );
    final epoch = ++_operationEpoch;
    state = state.copyWith(
      selectedSessionId: sessionId,
      userRange: _initialRange(state.userMediaDurations[selected.id] ?? 0.1),
      loadingUserMedia: true,
      artifactsAcceptable: false,
      monophonicLeadConfirmed: false,
      clearReport: true,
      clearFailure: true,
    );
    final duration =
        state.userMediaDurations[sessionId] ??
        await _verifiedMediaDuration(selected);
    if (!_isCurrent(epoch)) return;
    final durations = <String, double>{...state.userMediaDurations};
    if (duration != null) durations[sessionId] = duration;
    state = state.copyWith(
      userMediaDurations: Map.unmodifiable(durations),
      userRange: _initialRange(duration ?? 0.1),
      loadingUserMedia: false,
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
    state = state.copyWith(
      userRange: range,
      artifactsAcceptable: false,
      monophonicLeadConfirmed: false,
      clearReport: true,
    );
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
    ReferenceAnalysisSeries? referenceFeatures;
    AudioContentIdentity? referenceLeaseIdentity;
    var verifyingReference = true;
    try {
      _validateReferenceIdentity(vocals);
      verifyingReference = false;
      _validateUserIdentity(session);
      verifyingReference = true;
      VerifiedAudioLease? referenceLease;
      try {
        referenceLease = await _stemResolver.openVerified(vocals);
        referenceLeaseIdentity = referenceLease.identity;
        referenceFeatures = await _extractor.analyze(
          vocals: referenceLease,
          onProgress: (progress) {
            if (_isCurrent(epoch) &&
                state.status == ReferenceComparisonStatus.analyzing) {
              state = state.copyWith(progress: progress * 0.5);
            }
          },
        );
      } finally {
        await referenceLease?.dispose();
      }
      if (!_isCurrent(epoch)) return;
      verifyingReference = false;
      VerifiedAudioLease? userLease;
      late final AudioContentIdentity userLeaseIdentity;
      late final ReferenceAnalysisSeries userFeatures;
      try {
        userLease = await _recordingResolver.openVerified(session.recording!);
        userLeaseIdentity = userLease.identity;
        userFeatures = await _extractor.analyze(
          vocals: userLease,
          onProgress: (progress) {
            if (_isCurrent(epoch) &&
                state.status == ReferenceComparisonStatus.analyzing) {
              state = state.copyWith(progress: 0.5 + progress * 0.5);
            }
          },
        );
      } finally {
        await userLease?.dispose();
      }
      if (!_isCurrent(epoch)) return;
      final report = ref
          .read(referenceComparisonEngineProvider)
          .compare(
            ComparisonInputSnapshot(
              reference: reference,
              referenceFeatures: referenceFeatures,
              userFeatures: userFeatures,
              session: session,
              referenceRange: referenceRange,
              userRange: userRange,
              review: review,
              referenceLeaseIdentity: referenceLeaseIdentity,
              userLeaseIdentity: userLeaseIdentity,
            ),
          );
      if (!_isCurrent(epoch)) return;
      state = state.copyWith(
        status: ReferenceComparisonStatus.completed,
        progress: 1,
        report: report,
      );
    } on AudioContentFailure catch (failure) {
      if (!_isCurrent(epoch)) return;
      final report = ref
          .read(referenceComparisonEngineProvider)
          .compare(
            ComparisonInputSnapshot(
              reference: reference,
              referenceFeatures: referenceFeatures,
              userFeatures: null,
              session: session,
              referenceRange: referenceRange,
              userRange: userRange,
              review: review,
              referenceLeaseIdentity: referenceLeaseIdentity,
              userLeaseIdentity: null,
              referenceIntegrityFailure: verifyingReference
                  ? failure.reason
                  : null,
              userIntegrityFailure: verifyingReference ? null : failure.reason,
            ),
          );
      state = state.copyWith(
        status: ReferenceComparisonStatus.completed,
        progress: 0,
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
    final generation = ++_previewGeneration;
    final vocals = ref.read(songReferenceControllerProvider).reference?.vocals;
    if (vocals == null) return;
    VerifiedAudioLease? lease;
    try {
      lease = await _stemResolver.openVerified(vocals);
      await _play(lease, state.referenceRange, generation: generation);
    } on AudioContentFailure catch (failure) {
      if (_isPreviewCurrent(generation)) _showContentPreviewFailure(failure);
    } finally {
      await lease?.dispose();
    }
  }

  Future<void> previewUser() async {
    final generation = ++_previewGeneration;
    final locator = state.selectedSession?.recording;
    if (locator?.storageKind != RecordingStorageKind.file) {
      state = state.copyWith(
        previewFailure: AudioPreviewFailureReason.unsupportedLocator,
      );
      return;
    }
    VerifiedAudioLease? lease;
    try {
      lease = await _recordingResolver.openVerified(locator!);
      await _play(lease, state.userRange, generation: generation);
    } on AudioContentFailure catch (failure) {
      if (_isPreviewCurrent(generation)) _showContentPreviewFailure(failure);
    } finally {
      await lease?.dispose();
    }
  }

  Future<void> stopPreview() {
    final generation = ++_previewGeneration;
    return _enqueuePreview(() async {
      if (!_isPreviewCurrent(generation)) return;
      await _preview.stop();
    });
  }

  Future<void> _play(
    VerifiedAudioLease source,
    PhraseRange range, {
    required int generation,
  }) async {
    if (!_disposed) state = state.copyWith(clearPreviewFailure: true);
    await _enqueuePreview(() async {
      if (!_isPreviewCurrent(generation)) return;
      try {
        await _preview.stop();
        if (!_isPreviewCurrent(generation)) return;
        await _preview.playFile(source: source, range: range);
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

  Future<double?> _verifiedMediaDuration(PracticeSessionRecord session) async {
    final recording = session.recording;
    if (recording == null) return null;
    VerifiedAudioLease? lease;
    try {
      lease = await _recordingResolver.openVerified(recording);
      return WavMediaTimeline.parse(lease.bytes).durationSeconds;
    } on AudioContentFailure catch (_) {
      // Keep the candidate: explicit preview/compare surfaces the same typed
      // identity or resource-limit failure.
      return null;
    } on FormatException catch (_) {
      // A malformed verified WAV has no honest seek timeline.
      return null;
    } finally {
      await lease?.dispose();
    }
  }

  void _validateReferenceIdentity(SongStemReference vocals) {
    if (!vocals.identity.isWellFormed) {
      throw const AudioContentFailure(AudioContentFailureReason.legacyUnbound);
    }
  }

  void _validateUserIdentity(PracticeSessionRecord session) {
    final recording = session.recording;
    if (recording?.identity == null ||
        session.features.sourceAudioIdentity == null) {
      throw const AudioContentFailure(AudioContentFailureReason.legacyUnbound);
    }
    if (recording!.identity != session.features.sourceAudioIdentity) {
      throw const AudioContentFailure(AudioContentFailureReason.hashMismatch);
    }
  }

  void _showContentPreviewFailure(AudioContentFailure failure) {
    if (_disposed) return;
    state = state.copyWith(
      previewFailure: switch (failure.reason) {
        AudioContentFailureReason.missing =>
          AudioPreviewFailureReason.sourceMissing,
        AudioContentFailureReason.unsupportedLocator ||
        AudioContentFailureReason.outsideManagedRoot ||
        AudioContentFailureReason.legacyUnbound ||
        AudioContentFailureReason.lengthMismatch ||
        AudioContentFailureReason.hashMismatch =>
          AudioPreviewFailureReason.unsupportedLocator,
        AudioContentFailureReason.resourceLimit =>
          AudioPreviewFailureReason.resourceLimit,
        _ => AudioPreviewFailureReason.playbackFailed,
      },
    );
  }

  PhraseRange _initialRange(double durationSeconds) => PhraseRange(
    startSeconds: 0,
    endSeconds: durationSeconds.clamp(0.1, 8.0).toDouble(),
  );
}
