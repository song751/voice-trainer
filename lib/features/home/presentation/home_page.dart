import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../app/router/route_names.dart';
import '../../../core/domain/persistence/session_repository.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_page_body.dart';
import '../../history/application/history_records_provider.dart';
import '../../live_practice/application/live_practice_controller.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(historyRecordsProvider);
    final capabilities = ref.watch(platformCapabilitiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('练声助手')),
      body: ResponsivePageBody(
        child: ListView(
          children: <Widget>[
            Text('目标音练习', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('实时查看音高偏差、输入电平和信号质量，结束后获得可解释的描述性总结。'),
            if (capabilities.capture == PlatformAdapterMode.fallback) ...[
              const SizedBox(height: 12),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.science_outlined),
                  title: Text('当前使用测试适配器'),
                  subtitle: Text('此平台的真实麦克风链路尚未通过对应任务卡。'),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('open-live-practice'),
              onPressed: () => context.go(RoutePaths.livePractice),
              icon: const Icon(Icons.mic_none),
              label: Text(
                capabilities.capture == PlatformAdapterMode.fallback
                    ? '开始测试练习'
                    : '开始练习',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('open-history'),
              onPressed: () => context.go(RoutePaths.history),
              icon: const Icon(Icons.history),
              label: const Text('查看历史记录'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('open-song-import'),
              onPressed: () => context.go(RoutePaths.songImport),
              icon: const Icon(Icons.library_music_outlined),
              label: const Text('导入歌曲并准备原唱对比'),
            ),
            const SizedBox(height: 28),
            Text('最近结果', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            recent.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => EmptyState(
                icon: Icons.error_outline,
                title: '最近结果暂时无法读取。',
                action: TextButton(
                  onPressed: () =>
                      ref.read(historyRecordsProvider.notifier).refresh(),
                  child: const Text('重试'),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      icon: Icons.insights_outlined,
                      title: '还没有练习结果',
                      message: '完成一次练习后，这里会显示最近结果。',
                    )
                  : _RecentResult(
                      record: items.first,
                      onOpen: () {
                        ref.read(latestPracticeSessionProvider.notifier).state =
                            items.first;
                        context.go(RoutePaths.result);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentResult extends StatelessWidget {
  const _RecentResult({required this.record, required this.onOpen});

  final PracticeSessionRecord record;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final hitRate = record.summary.targetHitRate;
    return Card(
      key: const Key('home-recent-result'),
      child: ListTile(
        onTap: onOpen,
        leading: const Icon(Icons.summarize_outlined),
        title: Text('目标音 ${_noteName(record.template.target.targetMidiNote)}'),
        subtitle: Text(
          hitRate == null
              ? '录音质量不足，未计算命中率'
              : '目标命中率 ${(hitRate * 100).toStringAsFixed(0)}%',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

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
