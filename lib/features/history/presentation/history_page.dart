import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/history_records_provider.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(historyRecordsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('历史记录')),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('历史记录暂时无法读取。')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('暂无历史练习记录。'))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final record = items[index];
                  final hitRate = record.summary.targetHitRate;
                  return ListTile(
                    key: Key('history-session-${record.id}'),
                    title: Text(record.template.id),
                    subtitle: Text(
                      hitRate == null
                          ? '录音质量不足，未计算命中率'
                          : '目标命中率 ${(hitRate * 100).toStringAsFixed(0)}%',
                    ),
                    trailing: Text(
                      '${record.summary.validFrameCount}/${record.summary.totalFrameCount}',
                    ),
                  );
                },
              ),
      ),
    );
  }
}
