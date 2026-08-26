import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/domain/reference/song_reference.dart';

enum SongReferenceStatus {
  idle,
  selected,
  installingModel,
  separating,
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
      state = SongReferenceState(
        status: SongReferenceStatus.failed,
        displayName: source.displayName,
        sizeBytes: length,
        failureReason: SongSeparationFailureReason.emptyFile,
        modelStatus: state.modelStatus,
      );
      return;
    }
    if (length > 500 * 1024 * 1024) {
      state = SongReferenceState(
        status: SongReferenceStatus.failed,
        displayName: source.displayName,
        sizeBytes: length,
        failureReason: SongSeparationFailureReason.fileTooLarge,
        modelStatus: state.modelStatus,
      );
      return;
    }
    state = SongReferenceState(
      status: SongReferenceStatus.selected,
      displayName: source.displayName,
      sizeBytes: length,
      modelStatus: state.modelStatus,
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
      clearReference: true,
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
}
