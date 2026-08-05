enum PcmEncoding { signedPcm16LittleEndian }

final class CaptureFormat {
  const CaptureFormat({
    required this.sampleRate,
    required this.channels,
    this.encoding = PcmEncoding.signedPcm16LittleEndian,
  }) : assert(sampleRate > 0),
       assert(channels > 0);

  final int sampleRate;
  final int channels;
  final PcmEncoding encoding;

  int get bytesPerSample => 2;

  int get bytesPerFrame => bytesPerSample * channels;

  @override
  bool operator ==(Object other) =>
      other is CaptureFormat &&
      sampleRate == other.sampleRate &&
      channels == other.channels &&
      encoding == other.encoding;

  @override
  int get hashCode => Object.hash(sampleRate, channels, encoding);
}

final class CaptureProcessingConfig {
  const CaptureProcessingConfig({
    this.automaticGainControl = false,
    this.echoCancellation = false,
    this.noiseSuppression = false,
  });

  final bool automaticGainControl;
  final bool echoCancellation;
  final bool noiseSuppression;
}
