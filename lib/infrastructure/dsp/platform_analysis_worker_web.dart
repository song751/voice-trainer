import 'analysis_worker_supervisor.dart';
import 'frb_analysis_worker.dart';
import 'web_worker_analysis_worker.dart';

Future<AnalysisWorker> createPrimaryAnalysisWorker() async =>
    WebWorkerAnalysisWorker();

/// Gate 0D's single-thread FRB/WASM path. It is used only after the dedicated
/// worker fails to start or crashes; it deliberately does not restore FRB's
/// incompatible WASM WorkerPool.
Future<AnalysisWorker> createFallbackAnalysisWorker() async =>
    FrbAnalysisWorker();
