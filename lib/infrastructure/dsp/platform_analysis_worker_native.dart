import 'analysis_worker_supervisor.dart';
import 'frb_analysis_worker.dart';

Future<AnalysisWorker> createPrimaryAnalysisWorker() async =>
    FrbAnalysisWorker();

Future<AnalysisWorker> createFallbackAnalysisWorker() async =>
    FrbAnalysisWorker();
