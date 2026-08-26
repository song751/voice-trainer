import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/domain/persistence/session_repository.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_page_body.dart';
import '../../live_practice/application/live_practice_controller.dart';
import '../application/history_records_provider.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(historyRecordsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('历史记录')),
      body: ResponsivePageBody(
        child: records.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => EmptyState(
            icon: Icons.error_outline,
            title: '历史记录暂时无法读取。',
            action: FilledButton.tonal(
              onPressed: () =>
                  ref.read(historyRecordsProvider.notifier).refresh(),
              child: const Text('重试'),
            ),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.history,
                  title: '暂无历史练习记录。',
                  message: '完成一次练习后，结果和录音状态会显示在这里。',
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _SessionItem(
                    record: items[index],
                    onOpen: () {
                      ref.read(latestPracticeSessionProvider.notifier).state =
                          items[index];
                      context.go(RoutePaths.result);
                    },
                    onDelete: () => _confirmDelete(context, ref, items[index]),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    PracticeSessionRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这次练习？'),
        content: Text(
          record.recording == null ? '这会删除本次练习的指标和结果。' : '这会删除本次练习、分析指标和已保存录音。',
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('cancel-delete-session'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-delete-session'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final succeeded = await ref
        .read(historyRecordsProvider.notifier)
        .deleteSession(record.id);
    if (!succeeded && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试。')));
    }
  }
}

class _SessionItem extends StatelessWidget {
  const _SessionItem({
    required this.record,
    required this.onOpen,
    required this.onDelete,
  });

  final PracticeSessionRecord record;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hitRate = record.summary.targetHitRate;
    return Card(
      child: ListTile(
        key: Key('history-session-${record.id}'),
        onTap: onOpen,
        leading: const Icon(Icons.graphic_eq),
        title: Text(_practiceLabel(record)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              hitRate == null
                  ? '录音质量不足，未计算命中率'
                  : '目标命中率 ${(hitRate * 100).toStringAsFixed(0)}%',
            ),
            Text(record.recording == null ? '仅保存指标' : '已保存录音'),
          ],
        ),
        trailing: IconButton(
          key: Key('delete-session-${record.id}'),
          tooltip: '删除这次练习',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }

  String _practiceLabel(PracticeSessionRecord record) =>
      '目标音 ${_noteName(record.template.target.targetMidiNote)}';

  String _noteName(int midi) {
    const names = <String>[
      'C',
      'C♯',
      'D',
      'D♯',
      'E',
      'F',
      'F♯',
      'G',
      'G♯',
      'A',
      'A♯',
      'B',
    ];
    return '${names[midi % 12]}${midi ~/ 12 - 1}';
  }
}
