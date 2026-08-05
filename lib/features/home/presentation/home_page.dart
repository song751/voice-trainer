import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('练声助手')),
      body: Center(
        child: FilledButton.icon(
          key: const Key('open-live-practice'),
          onPressed: () => context.go(RoutePaths.livePractice),
          icon: const Icon(Icons.mic_none),
          label: const Text('开始模拟练习'),
        ),
      ),
    );
  }
}
