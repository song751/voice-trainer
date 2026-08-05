import 'dart:io';

Future<String?> writeDspReport(String contents, int batchSize) async {
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'voice_trainer_phase0_dsp_$batchSize.json',
  );
  await file.writeAsString(contents, flush: true);
  return file.path;
}
