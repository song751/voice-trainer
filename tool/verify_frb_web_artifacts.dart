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
  final workerClient = File('web/analysis_worker_client.js');
  final workerRuntime = File('web/analysis_worker.js');
  final webIndex = File('web/index.html');
  final webComposition = File('lib/app/default_adapters_web.dart');
  final webWorkerComposition = File(
    'lib/infrastructure/dsp/platform_analysis_worker_web.dart',
  );

  for (final artifact in [
    packageFile,
    javascriptFile,
    wasmFile,
    workerSnippet,
    workerClient,
    workerRuntime,
    webIndex,
    webComposition,
    webWorkerComposition,
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

  _requireContracts(workerClient, const [
    'new Worker(new URL(\'analysis_worker.js\', document.baseURI))',
    'this._pending = new Map()',
    'this._worker.onerror',
    'this._pending.delete(id)',
    '[pcm.buffer]',
  ]);
  _requireContracts(workerRuntime, const [
    "importScripts('pkg/rust_lib_voice_trainer.js')",
    "await wasm_bindgen('pkg/rust_lib_voice_trainer_bg.wasm')",
    'new wasm_bindgen.WorkerRealtimeAnalyzer(data.sampleRate)',
    "kind === 'pushPcm'",
    'pcm.length > 1024',
    'Unknown analysis worker operation',
  ]);
  _requireContracts(webComposition, const [
    'RecordAudioCapture(fallbackStreamBufferSamples: 1024)',
    'AnalysisWorkerCapability.dedicatedWebWorker',
    'RustAnalysisEngine()',
  ]);
  _requireContracts(webWorkerComposition, const [
    'WebWorkerAnalysisWorker()',
    'createFallbackAnalysisWorker()',
    'FrbAnalysisWorker()',
  ]);
  for (final source in [workerClient, workerRuntime]) {
    if (source.readAsStringSync().contains('SharedArrayBuffer')) {
      _fail('${source.path} must not require SharedArrayBuffer.');
    }
  }
  final index = webIndex.readAsStringSync();
  final workerClientOffset = index.indexOf('analysis_worker_client.js');
  final bootstrapOffset = index.indexOf('flutter_bootstrap.js');
  if (workerClientOffset < 0 ||
      bootstrapOffset < 0 ||
      workerClientOffset > bootstrapOffset) {
    _fail('Web worker client must load before the Flutter bootstrap.');
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

void _requireContracts(File source, List<String> contracts) {
  final contents = source.readAsStringSync();
  for (final contract in contracts) {
    if (!contents.contains(contract)) {
      _fail('${source.path} is missing required contract: $contract');
    }
  }
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
