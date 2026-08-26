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
}

final class _FakePicker implements SongFilePicker {
  const _FakePicker(this.source);
  final SongFileSource source;

  @override
  Future<SongFileSource?> pickSong() async => source;
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
