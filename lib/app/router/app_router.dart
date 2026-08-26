import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/history/presentation/history_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/live_practice/presentation/live_practice_page.dart';
import '../../features/session_result/presentation/session_result_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/song_reference/presentation/song_import_page.dart';
import '../../features/voice_comparison/presentation/voice_comparison_page.dart';
import '../shell/adaptive_app_shell.dart';
import 'route_names.dart';

final appInitialLocationProvider = Provider<String>((ref) => RoutePaths.home);

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: ref.watch(appInitialLocationProvider),
    routes: <RouteBase>[
      ShellRoute(
        builder: (context, state, child) =>
            AdaptiveAppShell(currentPath: state.uri.path, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.home,
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: RoutePaths.livePractice,
            builder: (context, state) => const LivePracticePage(),
          ),
          GoRoute(
            path: RoutePaths.result,
            builder: (context, state) => const SessionResultPage(),
          ),
          GoRoute(
            path: RoutePaths.history,
            builder: (context, state) => const HistoryPage(),
          ),
          GoRoute(
            path: RoutePaths.settings,
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: RoutePaths.songImport,
            builder: (context, state) => const SongImportPage(),
          ),
          GoRoute(
            path: RoutePaths.voiceComparison,
            builder: (context, state) => const VoiceComparisonPage(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
