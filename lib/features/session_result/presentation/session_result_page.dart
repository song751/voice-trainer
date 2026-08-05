import 'package:flutter/material.dart';

class SessionResultPage extends StatelessWidget {
  const SessionResultPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('练习结果')),
    body: const Center(
      child: Text('暂无分析数据。完成练习后将在这里显示结果。', key: Key('result-no-data')),
    ),
  );
}
