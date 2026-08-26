import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/domain/reference/song_reference.dart';

enum SongReferenceStatus {
  idle,
  selected,
  installingModel,
  separating,
  deleting,
  ready,
  failed,
}

final class SongReferenceState {
  const SongReferenceState({
    this.status = SongReferenceStatus.idle,
    this.displayName,
    this.sizeBytes,
    this.rightsAcknowledged = false,
    this.progress = 0,
    this.reference,
    this.failureReason,
    this.modelStatus,
  });

  final SongReferenceStatus status;
  final String? displayName;
  final int? sizeBytes;
  final bool rightsAcknowledged;
  final double progress;
  final SeparatedSongReference? reference;
  final SongSeparationFailureReason? failureReason;
  final SongModelStatus? modelStatus;

  SongReferenceState copyWith({
    SongReferenceStatus? status,
    String? displayName,
    int? sizeBytes,
    bool? rightsAcknowledged,
    double? progress,
    SeparatedSongReference? reference,
    SongSeparationFailureReason? failureReason,
    bool clearFailure = false,
    bool clearReference = false,
    SongModelStatus? modelStatus,
  }) => SongReferenceState(
    status: status ?? this.status,
    displayName: displayName ?? this.displayName,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    rightsAcknowledged: rightsAcknowledged ?? this.rightsAcknowledged,
    progress: progress ?? this.progress,
    reference: clearReference ? null : reference ?? this.reference,
    failureReason: clearFailure ? null : failureReason ?? this.failureReason,
    modelStatus: modelStatus ?? this.modelStatus,
  );
}

final songReferenceControllerProvider =
    NotifierProvider<SongReferenceController, SongReferenceState>(
      SongReferenceController.new,
    );

final class SongReferenceController extends Notifier<SongReferenceState> {
  SongFileSource? _source;
  bool _restorationAttempted = false;

  SongFilePicker get _picker => ref.read(songFilePickerProvider);
  SongSeparator get _separator => ref.read(songSeparatorProvider);
  SongModelManager get _modelManager => ref.read(songModelManagerProvider);

  @override
  SongReferenceState build() => const SongReferenceState();

  Future<void> refreshModelStatus() async {
    try {
      final status = await _modelManager.probe();
      state = state.copyWith(modelStatus: status);
    } catch (_) {
      state = state.copyWith(
        modelStatus: const SongModelStatus(
          availability: SongModelAvailability.unavailable,
        ),
      );
    }
    if (!_restorationAttempted) {
      _restorationAttempted = true;
      await _restoreManagedReference();
    }
  }

  Future<void> _restoreManagedReference() async {
    final separator = _separator;
    if (separator is! ManagedSongReferenceLifecycle) return;
    final lifecycle = separator as ManagedSongReferenceLifecycle;
    try {
      final reference = await lifecycle.restoreReference();
      if (reference != null && state.reference == null) {
        state = state.copyWith(
          status: SongReferenceStatus.ready,
          displayName: reference.displayName,
          reference: reference,
          clearFailure: true,
        );
      }
    } on SongSeparationFailure catch (failure) {
      state = state.copyWith(failureReason: failure.reason);
    } catch (_) {
      state = state.copyWith(
        failureReason: SongSeparationFailureReason.outputFailed,
      );
    }
  }

  Future<void> installModel() async {
    final source = await ref.read(songModelFilePickerProvider).pickModel();
    if (source == null) return;
    state = state.copyWith(
      status: SongReferenceStatus.installingModel,
      clearFailure: true,
    );
    try {
      final status = await _modelManager.installModel(source);
      state = state.copyWith(
        status: _source == null
            ? SongReferenceStatus.idle
            : SongReferenceStatus.selected,
        modelStatus: status,
        failureReason: status.availability == SongModelAvailability.ready
            ? null
            : SongSeparationFailureReason.runtimeUnavailable,
        clearFailure: status.availability == SongModelAvailability.ready,
      );
    } on SongSeparationFailure catch (failure) {
      state = state.copyWith(
        status: SongReferenceStatus.failed,
        failureReason: failure.reason,
      );
    } catch (_) {
      state = state.copyWith(
        status: SongReferenceStatus.failed,
        failureReason: SongSeparationFailureReason.processingFailed,
      );
    }
  }

  Future<void> selectSong() async {
    final source = await _picker.pickSong();
    if (source == null) return;
    final length = await source.length();
    _source = source;
    if (length == 0) {
      state = state.copyWith(
        status: SongReferenceStatus.failed,
        displayName: source.displayName,
        sizeBytes: length,
        failureReason: SongSeparationFailureReason.emptyFile,
      );
      return;
    }
    if (length > 500 * 1024 * 1024) {
      state = state.copyWith(
        status: SongReferenceStatus.failed,
        displayName: source.displayName,
        sizeBytes: length,
        failureReason: SongSeparationFailureReason.fileTooLarge,
      );
      return;
    }
    state = state.copyWith(
      status: SongReferenceStatus.selected,
      displayName: source.displayName,
      sizeBytes: length,
      rightsAcknowledged: false,
      progress: 0,
      clearFailure: true,
    );
  }

  void setRightsAcknowledged(bool value) {
    state = state.copyWith(rightsAcknowledged: value, clearFailure: true);
  }

  Future<void> separate() async {
    final source = _source;
    if (source == null) return;
    state = state.copyWith(
      status: SongReferenceStatus.separating,
      progress: 0,
      clearFailure: true,
    );
    try {
      final reference = await _separator.separate(
        source: source,
        rightsAcknowledged: state.rightsAcknowledged,
        onProgress: (progress) {
          if (state.status == SongReferenceStatus.separating) {
            state = state.copyWith(progress: progress.clamp(0, 1));
          }
        },
      );
      state = state.copyWith(
        status: SongReferenceStatus.ready,
        progress: 1,
        reference: reference,
        clearFailure: true,
      );
    } on SongSeparationFailure catch (failure) {
      state = state.copyWith(
        status: SongReferenceStatus.failed,
        failureReason: failure.reason,
      );
    } catch (_) {
      state = state.copyWith(
        status: SongReferenceStatus.failed,
        failureReason: SongSeparationFailureReason.processingFailed,
      );
    }
  }

  Future<void> cancel() async {
    await _separator.cancel();
    state = state.copyWith(
      status: SongReferenceStatus.selected,
      progress: 0,
      failureReason: SongSeparationFailureReason.cancelled,
    );
  }

  Future<void> deleteReference() async {
    final reference = state.reference;
    final separator = _separator;
    if (reference == null || separator is! ManagedSongReferenceLifecycle) {
      return;
    }
    final lifecycle = separator as ManagedSongReferenceLifecycle;
    state = state.copyWith(
      status: SongReferenceStatus.deleting,
      clearFailure: true,
    );
    try {
      await lifecycle.deleteReference(reference);
      state = _source == null
          ? SongReferenceState(modelStatus: state.modelStatus)
          : state.copyWith(
              status: SongReferenceStatus.selected,
              progress: 0,
              clearReference: true,
              clearFailure: true,
            );
    } on SongSeparationFailure catch (failure) {
      state = state.copyWith(
        status: SongReferenceStatus.failed,
        failureReason: failure.reason,
      );
    } catch (_) {
      state = state.copyWith(
        status: SongReferenceStatus.failed,
        failureReason: SongSeparationFailureReason.outputFailed,
      );
    }
  }
}
