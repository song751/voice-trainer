import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/widgets/responsive_page_body.dart';
import '../application/settings_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(platformCapabilitiesProvider);
    final devices = capabilities.supportsDeviceSelection
        ? ref.watch(captureDevicesProvider)
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('设置与能力')),
      body: ResponsivePageBody(
        child: ListView(
          children: <Widget>[
            _Section(
              title: '当前平台',
              children: <Widget>[
                _Fact(label: '平台', value: _platformLabel(capabilities.target)),
                _Fact(
                  label: '音频采集',
                  value: capabilities.capture == PlatformAdapterMode.production
                      ? '已接入产品适配器'
                      : '当前使用测试适配器',
                ),
                _Fact(
                  label: '分析执行',
                  value: _workerLabel(capabilities.analysisWorker),
                ),
                _Fact(
                  label: '本地存储',
                  value:
                      capabilities.persistence == PlatformAdapterMode.production
                      ? '持久化录音与指标'
                      : '临时内存，退出后可能丢失',
                ),
                if (capabilities.maximumRecordingDuration != null)
                  _Fact(
                    label: '录音上限',
                    value:
                        '最长 ${capabilities.maximumRecordingDuration!.inSeconds} 秒',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: '麦克风',
              children: <Widget>[
                if (!capabilities.supportsDeviceSelection)
                  const Text('当前平台暂不提供应用内设备选择。')
                else
                  devices!.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('麦克风列表暂时无法读取。'),
                    data: (items) => items.isEmpty
                        ? const Text('没有发现可用麦克风。')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: items
                                .map(
                                  (device) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.mic_outlined),
                                    title: Text(
                                      device.label?.trim().isNotEmpty == true
                                          ? device.label!
                                          : '未命名麦克风',
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                  ),
                const SizedBox(height: 8),
                const Text('采集请求：48 kHz、单声道、PCM16。实际格式以会话报告为准。'),
              ],
            ),
            const SizedBox(height: 16),
            const _Section(
              title: '隐私与范围',
              children: <Widget>[
                Text('分析默认在本机完成，录音和声学指标默认不上传网络。'),
                SizedBox(height: 8),
                Text('本应用提供描述性练习观察，不用于医疗诊断，也不推断声带状态。'),
                SizedBox(height: 8),
                Text('录音文件与结构化指标分开保存；当前页面只展示已实现事实，不提供无效开关。'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _platformLabel(PlatformTarget target) => switch (target) {
    PlatformTarget.windows => 'Windows',
    PlatformTarget.android => 'Android',
    PlatformTarget.web => 'Web',
    PlatformTarget.otherNative => '其他原生平台',
  };

  String _workerLabel(AnalysisWorkerCapability worker) => switch (worker) {
    AnalysisWorkerCapability.nativeWorker => '原生 Rust worker',
    AnalysisWorkerCapability.dedicatedWebWorker => '独立 Web Worker',
    AnalysisWorkerCapability.fallback => '测试/单线程 fallback',
  };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: 88, child: Text(label)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
