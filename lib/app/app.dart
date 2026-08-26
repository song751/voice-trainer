import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class VoiceTrainerApp extends ConsumerWidget {
  const VoiceTrainerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: '练声助手',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      highContrastTheme: AppTheme.highContrastLight,
      highContrastDarkTheme: AppTheme.highContrastDark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
