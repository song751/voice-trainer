import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_trainer/app/app.dart';
import 'package:voice_trainer/app/app_providers.dart';
import 'package:voice_trainer/app/router/app_router.dart';
import 'package:voice_trainer/app/router/route_names.dart';
import 'package:voice_trainer/core/domain/reference/song_reference.dart';

void main() {
  testWidgets('song import exposes rights, privacy and honest runtime state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appInitialLocationProvider.overrideWithValue(RoutePaths.songImport),
          songFilePickerProvider.overrideWithValue(
            const _FakePicker(_FakeSource()),
          ),
          songSeparatorProvider.overrideWithValue(
            const UnavailableSongSeparator(),
          ),
        ],
        child: const VoiceTrainerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('不会上传云端'), findsOneWidget);
    await tester.tap(find.byKey(const Key('select-song-file')));
    await tester.pumpAndSettle();
    expect(find.text('authorized-song.wav'), findsOneWidget);
    expect(find.textContaining('DRM'), findsOneWidget);

    await tester.tap(find.byKey(const Key('separate-song-vocals')));
    await tester.pumpAndSettle();
    expect(find.text('请先确认本地处理权利。'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('separate-song-vocals')));
    await tester.pumpAndSettle();
    expect(find.text('自动人声分离运行时尚未就绪。'), findsOneWidget);
    expect(find.textContaining('不会用伪结果'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved stems have a confirmed local deletion entry point', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final separator = _ManagedUiSeparator();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appInitialLocationProvider.overrideWithValue(RoutePaths.songImport),
          songFilePickerProvider.overrideWithValue(
            const _FakePicker(_FakeSource()),
          ),
          songSeparatorProvider.overrideWithValue(separator),
          songModelManagerProvider.overrideWithValue(separator),
        ],
        child: const VoiceTrainerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('song-reference-ready')), findsOneWidget);
    await tester.tap(find.byKey(const Key('select-song-file')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('当前仍保留旧参考'), 100);
    expect(find.textContaining('authorized-song.wav'), findsWidgets);
    expect(find.textContaining('saved-song.wav'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('直到你删除'), 100);
    expect(find.textContaining('直到你删除'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('delete-song-reference')));
    await tester.tap(find.byKey(const Key('delete-song-reference')));
    await tester.pumpAndSettle();
    expect(find.textContaining('同时删除本机保存的人声与伴奏'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete-song-reference')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('正在删除本地分离结果'), findsOneWidget);
    expect(find.textContaining('正在本地分离'), findsNothing);
    expect(find.byKey(const Key('cancel-song-separation')), findsNothing);

    separator.completeDelete();
    await tester.pumpAndSettle();

    expect(separator.deleteCalls, 1);
    expect(find.byKey(const Key('song-reference-ready')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('model installation has distinct non-cancellable status copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final separator = _InstallingUiSeparator();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appInitialLocationProvider.overrideWithValue(RoutePaths.songImport),
          songModelFilePickerProvider.overrideWithValue(
            const _FakeModelPicker(_FakeSource()),
          ),
          songSeparatorProvider.overrideWithValue(separator),
          songModelManagerProvider.overrideWithValue(separator),
        ],
        child: const VoiceTrainerApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('install-song-model')));
    await tester.pump();

    expect(find.text('正在校验并安装本地模型'), findsOneWidget);
    expect(find.textContaining('正在本地分离'), findsNothing);
    expect(find.byKey(const Key('cancel-song-separation')), findsNothing);

    separator.completeInstall();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

final class _FakePicker implements SongFilePicker {
  const _FakePicker(this.source);
  final SongFileSource source;

  @override
  Future<SongFileSource?> pickSong() async => source;
}

final class _FakeModelPicker implements SongModelFilePicker {
  const _FakeModelPicker(this.source);
  final SongFileSource source;

  @override
  Future<SongFileSource?> pickModel() async => source;
}

final class _FakeSource implements SongFileSource {
  const _FakeSource();

  @override
  String get displayName => 'authorized-song.wav';

  @override
  Future<int> length() async => 1024 * 1024;

  @override
  Stream<List<int>> openRead() => Stream<List<int>>.value(Uint8List(0));
}

final class _ManagedUiSeparator
    implements SongSeparator, SongModelManager, ManagedSongReferenceLifecycle {
  int deleteCalls = 0;
  final Completer<void> _deleteCompleter = Completer<void>();
  SeparatedSongReference? current = const SeparatedSongReference(
    displayName: 'saved-song.wav',
    generatedByModel: true,
    modelId: 'reviewed-model',
    sampleRate: 44100,
    channels: 2,
    durationSamples: 44100,
    artifactWarning: true,
  );

  @override
  bool get automaticSeparationAvailable => true;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> deleteReference(SeparatedSongReference reference) async {
    deleteCalls += 1;
    await _deleteCompleter.future;
    current = null;
  }

  void completeDelete() => _deleteCompleter.complete();

  @override
  Future<SongModelStatus> installModel(SongFileSource source) async =>
      const SongModelStatus(availability: SongModelAvailability.ready);

  @override
  Future<SongModelStatus> probe() async => const SongModelStatus(
    availability: SongModelAvailability.ready,
    modelId: 'reviewed-model',
  );

  @override
  Future<SeparatedSongReference?> restoreReference() async => current;

  @override
  Future<SeparatedSongReference> separate({
    required SongFileSource source,
    required bool rightsAcknowledged,
    required void Function(double progress) onProgress,
  }) async => throw UnimplementedError();
}

final class _InstallingUiSeparator implements SongSeparator, SongModelManager {
  final Completer<void> _installCompleter = Completer<void>();

  @override
  bool get automaticSeparationAvailable => false;

  @override
  Future<void> cancel() async {}

  void completeInstall() => _installCompleter.complete();

  @override
  Future<SongModelStatus> installModel(SongFileSource source) async {
    await _installCompleter.future;
    return const SongModelStatus(
      availability: SongModelAvailability.ready,
      modelId: 'reviewed-model',
    );
  }

  @override
  Future<SongModelStatus> probe() async =>
      const SongModelStatus(availability: SongModelAvailability.notInstalled);

  @override
  Future<SeparatedSongReference> separate({
    required SongFileSource source,
    required bool rightsAcknowledged,
    required void Function(double progress) onProgress,
  }) async => throw UnimplementedError();
}
