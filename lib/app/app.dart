import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';

class VoiceTrainerApp extends ConsumerWidget {
  const VoiceTrainerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: '练声助手',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      routerConfig: router,
    );
  }
}
