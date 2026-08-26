import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/app/app_providers.dart';
import 'package:voice_trainer/core/domain/reference/song_reference.dart';
import 'package:voice_trainer/features/song_reference/application/song_reference_controller.dart';

void main() {
  test('cancelled selection leaves the controller idle', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        songFilePickerProvider.overrideWithValue(const _FakePicker(null)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(songReferenceControllerProvider.notifier).selectSong();

    expect(
      container.read(songReferenceControllerProvider).status,
      SongReferenceStatus.idle,
    );
  });

  test('empty and oversized files are rejected before separation', () async {
    final empty = ProviderContainer(
      overrides: <Override>[
        songFilePickerProvider.overrideWithValue(
          const _FakePicker(_FakeSource('empty.wav', 0)),
        ),
      ],
    );
    addTearDown(empty.dispose);
    await empty.read(songReferenceControllerProvider.notifier).selectSong();
    expect(
      empty.read(songReferenceControllerProvider).failureReason,
      SongSeparationFailureReason.emptyFile,
    );

    final oversized = ProviderContainer(
      overrides: <Override>[
        songFilePickerProvider.overrideWithValue(
          const _FakePicker(_FakeSource('huge.wav', 501 * 1024 * 1024)),
        ),
      ],
    );
    addTearDown(oversized.dispose);
    await oversized.read(songReferenceControllerProvider.notifier).selectSong();
    expect(
      oversized.read(songReferenceControllerProvider).failureReason,
      SongSeparationFailureReason.fileTooLarge,
    );
  });

  test('rights gate and runtime unavailable remain typed', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        songFilePickerProvider.overrideWithValue(
          const _FakePicker(_FakeSource('song.wav', 1024)),
        ),
        songSeparatorProvider.overrideWithValue(
          const UnavailableSongSeparator(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(songReferenceControllerProvider.notifier);
    await controller.selectSong();

    await controller.separate();
    expect(
      container.read(songReferenceControllerProvider).failureReason,
      SongSeparationFailureReason.rightsNotAcknowledged,
    );

    controller.setRightsAcknowledged(true);
    await controller.separate();
    expect(
      container.read(songReferenceControllerProvider).failureReason,
      SongSeparationFailureReason.runtimeUnavailable,
    );
  });

  test('validated separator progress produces a ready reference', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        songFilePickerProvider.overrideWithValue(
          const _FakePicker(_FakeSource('song.wav', 4096)),
        ),
        songSeparatorProvider.overrideWithValue(_FakeSeparator()),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(songReferenceControllerProvider.notifier);
    await controller.refreshModelStatus();
    await controller.selectSong();
    controller.setRightsAcknowledged(true);
    await controller.separate();

    final state = container.read(songReferenceControllerProvider);
    expect(state.status, SongReferenceStatus.ready);
    expect(state.progress, 1);
    expect(state.reference?.generatedByModel, isTrue);
    expect(state.reference?.artifactWarning, isTrue);
    expect(
      state.modelStatus?.availability,
      SongModelAvailability.ready,
      reason: 'selecting a song must preserve the completed runtime probe',
    );
  });

  test(
    'failed replacement preserves the last valid managed reference',
    () async {
      final separator = _ManagedFakeSeparator(
        current: _reference('old.wav'),
        separationFailure: const SongSeparationFailure(
          SongSeparationFailureReason.decodeFailed,
        ),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          songFilePickerProvider.overrideWithValue(
            const _FakePicker(_FakeSource('new.wav', 4096)),
          ),
          songSeparatorProvider.overrideWithValue(separator),
          songModelManagerProvider.overrideWithValue(separator),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        songReferenceControllerProvider.notifier,
      );

      await controller.refreshModelStatus();
      expect(
        container.read(songReferenceControllerProvider).reference?.displayName,
        'old.wav',
      );
      await controller.selectSong();
      controller.setRightsAcknowledged(true);
      await controller.separate();

      final state = container.read(songReferenceControllerProvider);
      expect(state.failureReason, SongSeparationFailureReason.decodeFailed);
      expect(state.reference?.displayName, 'old.wav');
      expect(separator.deleted, isEmpty);
    },
  );

  test(
    'managed deletion is typed, keeps the reference, and can be retried',
    () async {
      final separator = _ManagedFakeSeparator(
        current: _reference('saved.wav'),
        deleteFailuresRemaining: 1,
      );
      final container = ProviderContainer(
        overrides: <Override>[
          songSeparatorProvider.overrideWithValue(separator),
          songModelManagerProvider.overrideWithValue(separator),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        songReferenceControllerProvider.notifier,
      );
      await controller.refreshModelStatus();

      await controller.deleteReference();
      var state = container.read(songReferenceControllerProvider);
      expect(state.failureReason, SongSeparationFailureReason.outputFailed);
      expect(state.reference?.displayName, 'saved.wav');

      await controller.deleteReference();
      state = container.read(songReferenceControllerProvider);
      expect(state.status, SongReferenceStatus.idle);
      expect(state.reference, isNull);
      expect(state.displayName, isNull);
      expect(separator.deleted, hasLength(1));
    },
  );
}

SeparatedSongReference _reference(String displayName) => SeparatedSongReference(
  displayName: displayName,
  generatedByModel: true,
  modelId: 'fake-test-model',
  sampleRate: 44100,
  channels: 2,
  durationSamples: 44100,
  artifactWarning: true,
  vocals: const SongStemReference(
    locator: 'vocals.wav',
    sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    byteLength: 1,
  ),
  accompaniment: const SongStemReference(
    locator: 'accompaniment.wav',
    sha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    byteLength: 1,
  ),
);

final class _FakePicker implements SongFilePicker {
  const _FakePicker(this.source);
  final SongFileSource? source;

  @override
  Future<SongFileSource?> pickSong() async => source;
}

final class _FakeSource implements SongFileSource {
  const _FakeSource(this.displayName, this.byteLength);

  @override
  final String displayName;
  final int byteLength;

  @override
  Future<int> length() async => byteLength;

  @override
  Stream<List<int>> openRead() => Stream<List<int>>.value(Uint8List(0));
}

final class _FakeSeparator implements SongSeparator, SongModelManager {
  @override
  bool get automaticSeparationAvailable => true;

  @override
  Future<void> cancel() async {}

  @override
  Future<SongModelStatus> installModel(SongFileSource source) async =>
      const SongModelStatus(availability: SongModelAvailability.ready);

  @override
  Future<SongModelStatus> probe() async => const SongModelStatus(
    availability: SongModelAvailability.ready,
    modelId: 'fake-test-model',
  );

  @override
  Future<SeparatedSongReference> separate({
    required SongFileSource source,
    required bool rightsAcknowledged,
    required void Function(double progress) onProgress,
  }) async {
    if (!rightsAcknowledged) {
      throw const SongSeparationFailure(
        SongSeparationFailureReason.rightsNotAcknowledged,
      );
    }
    onProgress(.5);
    return SeparatedSongReference(
      displayName: source.displayName,
      generatedByModel: true,
      modelId: 'fake-test-model',
      sampleRate: 44100,
      channels: 2,
      durationSamples: 44100,
      artifactWarning: true,
    );
  }
}

final class _ManagedFakeSeparator
    implements SongSeparator, SongModelManager, ManagedSongReferenceLifecycle {
  _ManagedFakeSeparator({
    this.current,
    this.separationFailure,
    this.deleteFailuresRemaining = 0,
  });

  SeparatedSongReference? current;
  final SongSeparationFailure? separationFailure;
  int deleteFailuresRemaining;
  final List<SeparatedSongReference> deleted = <SeparatedSongReference>[];

  @override
  bool get automaticSeparationAvailable => true;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> deleteReference(SeparatedSongReference reference) async {
    if (deleteFailuresRemaining > 0) {
      deleteFailuresRemaining -= 1;
      throw const SongSeparationFailure(
        SongSeparationFailureReason.outputFailed,
      );
    }
    deleted.add(reference);
    if (identical(current, reference)) current = null;
  }

  @override
  Future<SongModelStatus> installModel(SongFileSource source) async =>
      const SongModelStatus(availability: SongModelAvailability.ready);

  @override
  Future<SongModelStatus> probe() async => const SongModelStatus(
    availability: SongModelAvailability.ready,
    modelId: 'fake-test-model',
  );

  @override
  Future<SeparatedSongReference?> restoreReference() async => current;

  @override
  Future<SeparatedSongReference> separate({
    required SongFileSource source,
    required bool rightsAcknowledged,
    required void Function(double progress) onProgress,
  }) async {
    final failure = separationFailure;
    if (failure != null) throw failure;
    return current = _reference(source.displayName);
  }
}
