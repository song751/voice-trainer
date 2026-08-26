import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/domain/audio/audio_capture.dart';

final captureDevicesProvider = FutureProvider.autoDispose<List<CaptureDevice>>(
  (ref) => ref.watch(audioCaptureProvider).listDevices(),
);
