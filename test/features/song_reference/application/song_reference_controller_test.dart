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
}

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
