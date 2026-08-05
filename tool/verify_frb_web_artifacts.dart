import 'dart:convert';
import 'dart:io';

const _packageDirectory = 'web/pkg';
const _wasmFileName = 'rust_lib_voice_trainer_bg.wasm';
const _javascriptFileName = 'rust_lib_voice_trainer.js';

void main() {
  final packageFile = File('$_packageDirectory/package.json');
  final javascriptFile = File('$_packageDirectory/$_javascriptFileName');
  final wasmFile = File('$_packageDirectory/$_wasmFileName');
  final workerSnippet = File(
    '$_packageDirectory/snippets/'
    'wasm-bindgen-futures-f2cfeab8864dd175/src/task/worker.js',
  );

  for (final artifact in [
    packageFile,
    javascriptFile,
    wasmFile,
    workerSnippet,
  ]) {
    if (!artifact.existsSync()) {
      _fail('Missing FRB Web artifact: ${artifact.path}');
    }
    if (artifact.lengthSync() == 0) {
      _fail('Empty FRB Web artifact: ${artifact.path}');
    }
  }

  final package = jsonDecode(packageFile.readAsStringSync());
  if (package is! Map<String, dynamic> ||
      package['name'] != 'rust_lib_voice_trainer' ||
      package['browser'] != _javascriptFileName) {
    _fail('Unexpected FRB Web package metadata in ${packageFile.path}');
  }

  final files = package['files'];
  if (files is! List ||
      !files.contains(_wasmFileName) ||
      !files.contains(_javascriptFileName)) {
    _fail('FRB Web package metadata does not publish the JS and WASM pair');
  }

  final javascript = javascriptFile.readAsStringSync();
  const requiredJavaScriptContracts = [
    'let wasm_bindgen =',
    'class WorkerRealtimeAnalyzer',
    'exports.WorkerRealtimeAnalyzer = WorkerRealtimeAnalyzer',
    'return Object.assign(__wbg_init, { initSync }, exports)',
  ];
  for (final contract in requiredJavaScriptContracts) {
    if (!javascript.contains(contract)) {
      _fail(
        '${javascriptFile.path} is missing required binding contract: $contract',
      );
    }
  }

  final wasmHeader = wasmFile.openSync();
  late final List<int> header;
  try {
    header = wasmHeader.readSync(8);
  } finally {
    wasmHeader.closeSync();
  }
  const expectedHeader = [0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00];
  if (header.length != expectedHeader.length ||
      !_sameBytes(header, expectedHeader)) {
    _fail('${wasmFile.path} is not a WebAssembly v1 module');
  }

  stdout.writeln(
    'Verified FRB Web package: WorkerRealtimeAnalyzer JS binding and '
    '${wasmFile.lengthSync()} byte WASM payload.',
  );
}

bool _sameBytes(List<int> actual, List<int> expected) {
  for (var index = 0; index < expected.length; index += 1) {
    if (actual[index] != expected[index]) return false;
  }
  return true;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
