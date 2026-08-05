import 'dart:typed_data';

const featureBlobMagic = 'VTFS';
const featureBlobVersion = 1;
const featureBlobHeaderBytes = 32;

class DecodedFeatureBlob {
  const DecodedFeatureBlob({
    required this.values,
    required this.validity,
    required this.samplePeriodMicros,
  });

  final Float32List values;
  final List<bool> validity;
  final int samplePeriodMicros;
}

class FeatureBlobCodec {
  const FeatureBlobCodec();

  Uint8List encode({
    required Float32List values,
    required List<bool> validity,
    required int samplePeriodMicros,
  }) {
    if (values.length != validity.length) {
      throw ArgumentError(
        'Values and validity must have the same frame count.',
      );
    }
    final floatBytes = values.length * Float32List.bytesPerElement;
    final validityBytes = (validity.length + 7) ~/ 8;
    final output = Uint8List(
      featureBlobHeaderBytes + floatBytes + validityBytes,
    );
    final data = ByteData.sublistView(output);
    for (var index = 0; index < featureBlobMagic.length; index++) {
      output[index] = featureBlobMagic.codeUnitAt(index);
    }
    data
      ..setUint16(4, featureBlobVersion, Endian.little)
      ..setUint16(6, 0, Endian.little)
      ..setUint32(8, values.length, Endian.little)
      ..setUint32(12, samplePeriodMicros, Endian.little)
      ..setUint32(16, floatBytes, Endian.little)
      ..setUint32(20, validityBytes, Endian.little)
      ..setUint32(24, featureBlobHeaderBytes, Endian.little)
      ..setUint32(28, 0, Endian.little);
    for (var index = 0; index < values.length; index++) {
      data.setFloat32(
        featureBlobHeaderBytes + index * Float32List.bytesPerElement,
        values[index],
        Endian.little,
      );
      if (validity[index]) {
        final byteOffset = featureBlobHeaderBytes + floatBytes + index ~/ 8;
        output[byteOffset] |= 1 << (index % 8);
      }
    }
    return output;
  }

  DecodedFeatureBlob decode(Uint8List bytes) {
    if (bytes.lengthInBytes < featureBlobHeaderBytes) {
      throw const FormatException('Feature BLOB is shorter than its header.');
    }
    final data = ByteData.sublistView(bytes);
    final magic = String.fromCharCodes(bytes.sublist(0, 4));
    if (magic != featureBlobMagic) {
      throw FormatException('Unknown magic: $magic');
    }
    final version = data.getUint16(4, Endian.little);
    if (version != featureBlobVersion) {
      throw FormatException('Unsupported feature BLOB version: $version');
    }
    final frameCount = data.getUint32(8, Endian.little);
    final samplePeriodMicros = data.getUint32(12, Endian.little);
    final floatBytes = data.getUint32(16, Endian.little);
    final validityBytes = data.getUint32(20, Endian.little);
    final headerBytes = data.getUint32(24, Endian.little);
    final expectedFloatBytes = frameCount * Float32List.bytesPerElement;
    final expectedValidityBytes = (frameCount + 7) ~/ 8;
    if (headerBytes != featureBlobHeaderBytes ||
        floatBytes != expectedFloatBytes ||
        validityBytes != expectedValidityBytes ||
        headerBytes + floatBytes + validityBytes != bytes.lengthInBytes) {
      throw const FormatException('Feature BLOB lengths are inconsistent.');
    }
    final values = Float32List(frameCount);
    final validity = List<bool>.filled(frameCount, false);
    for (var index = 0; index < frameCount; index++) {
      values[index] = data.getFloat32(
        headerBytes + index * Float32List.bytesPerElement,
        Endian.little,
      );
      final byte = bytes[headerBytes + floatBytes + index ~/ 8];
      validity[index] = byte & (1 << (index % 8)) != 0;
    }
    return DecodedFeatureBlob(
      values: values,
      validity: validity,
      samplePeriodMicros: samplePeriodMicros,
    );
  }
}
