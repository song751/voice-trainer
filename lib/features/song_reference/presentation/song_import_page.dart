import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/domain/reference/song_reference.dart';
import '../../../core/widgets/responsive_page_body.dart';
import '../application/song_reference_controller.dart';

class SongImportPage extends ConsumerStatefulWidget {
  const SongImportPage({super.key});

  @override
  ConsumerState<SongImportPage> createState() => _SongImportPageState();
}

class _SongImportPageState extends ConsumerState<SongImportPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref
          .read(songReferenceControllerProvider.notifier)
          .refreshModelStatus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(songReferenceControllerProvider);
    final controller = ref.read(songReferenceControllerProvider.notifier);
    final automaticAvailable =
        state.modelStatus?.availability == SongModelAvailability.ready;
    final busy =
        state.status == SongReferenceStatus.separating ||
        state.status == SongReferenceStatus.installingModel;
    return Scaffold(
      appBar: AppBar(title: const Text('导入歌曲参考')),
      body: ResponsivePageBody(
        child: ListView(
          children: <Widget>[
            Text('本地歌曲与原唱参考', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('只处理你主动选择并有权使用的本地音频；不会抓取流媒体，也不会上传云端。'),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.memory_outlined),
                title: Text(automaticAvailable ? '本地人声模型已就绪' : '本地人声模型未就绪'),
                subtitle: Text(
                  automaticAvailable
                      ? '仅在本机运行；模型不会上传。'
                      : '请选择经过项目校验的 UMX-HQ ONNX 文件；权重不随应用分发。',
                ),
                trailing: automaticAvailable
                    ? const Icon(Icons.verified_outlined)
                    : TextButton(
                        key: const Key('install-song-model'),
                        onPressed: busy ? null : controller.installModel,
                        child: const Text('导入模型'),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('select-song-file'),
              onPressed: busy ? null : controller.selectSong,
              icon: const Icon(Icons.audio_file_outlined),
              label: const Text('选择本地歌曲'),
            ),
            if (state.displayName != null) ...<Widget>[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.music_note),
                  title: Text(state.displayName!),
                  subtitle: Text(_sizeLabel(state.sizeBytes)),
                ),
              ),
              CheckboxListTile(
                key: const Key('song-rights-acknowledgement'),
                value: state.rightsAcknowledged,
                onChanged: busy
                    ? null
                    : (value) =>
                          controller.setRightsAcknowledged(value ?? false),
                title: const Text('我确认有权在本设备处理这份音频'),
                subtitle: const Text('仅用于本地练习；不要导入受 DRM 保护或无权复制的内容。'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('separate-song-vocals'),
                onPressed: busy ? null : controller.separate,
                icon: const Icon(Icons.graphic_eq),
                label: Text(automaticAvailable ? '自动分离歌手人声' : '检查自动分离能力'),
              ),
            ],
            if (busy) ...<Widget>[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: state.progress == 0 ? null : state.progress,
              ),
              const SizedBox(height: 8),
              Text('正在本地分离 ${(state.progress * 100).toStringAsFixed(0)}%'),
              TextButton(onPressed: controller.cancel, child: const Text('取消')),
            ],
            if (state.failureReason != null) ...<Widget>[
              const SizedBox(height: 16),
              Card(
                key: const Key('song-separation-failure'),
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(_failureTitle(state.failureReason!)),
                  subtitle: Text(_failureHelp(state.failureReason!)),
                ),
              ),
            ],
            if (state.reference != null) ...<Widget>[
              const SizedBox(height: 16),
              Card(
                key: const Key('song-reference-ready'),
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('人声参考已就绪'),
                  subtitle: Text(
                    '模型 ${state.reference!.modelId}；分离结果可能含伴奏串音或混响，比较时会降低相应置信度。',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('open-reference-comparison'),
                onPressed: () => context.go(RoutePaths.referenceComparison),
                icon: const Icon(Icons.compare_arrows),
                label: const Text('与我的练唱做 A/B 对比'),
              ),
            ],
            const SizedBox(height: 20),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '对比原则：原唱只是一种艺术参考。首版只比较双方高置信窗口中的音高轮廓与进入时机，不给“唱功总分”，也不把音色、颤音和表达差异判为错误。',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _sizeLabel(int? bytes) =>
    bytes == null ? '大小未知' : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

String _failureTitle(SongSeparationFailureReason reason) => switch (reason) {
  SongSeparationFailureReason.rightsNotAcknowledged => '请先确认本地处理权利。',
  SongSeparationFailureReason.emptyFile => '所选文件为空。',
  SongSeparationFailureReason.fileTooLarge => '文件超过 500 MB 上限。',
  SongSeparationFailureReason.unsupportedFormat => '暂不支持这种音频格式。',
  SongSeparationFailureReason.modelNotInstalled => '请先导入经过校验的人声模型。',
  SongSeparationFailureReason.modelIntegrityFailed => '模型文件校验失败。',
  SongSeparationFailureReason.runtimeUnavailable => '自动人声分离运行时尚未就绪。',
  SongSeparationFailureReason.backendIncompatible => '模型与本机运行时不兼容。',
  SongSeparationFailureReason.decodeFailed => '音频解码失败。',
  SongSeparationFailureReason.resourceLimitExceeded => '歌曲超过本机处理上限。',
  SongSeparationFailureReason.outputFailed => '分离结果无法写入本地存储。',
  SongSeparationFailureReason.cancelled => '已取消分离。',
  SongSeparationFailureReason.processingFailed => '本地分离失败。',
};

String _failureHelp(SongSeparationFailureReason reason) => switch (reason) {
  SongSeparationFailureReason.runtimeUnavailable =>
    '当前构建未包含已通过数值与许可验证的模型运行时；不会用伪结果冒充人声 stem。',
  SongSeparationFailureReason.rightsNotAcknowledged => '确认后可继续；文件不会上传。',
  SongSeparationFailureReason.cancelled => '原文件未被删除，可以重新开始。',
  SongSeparationFailureReason.modelIntegrityFailed =>
    '只接受项目记录的动态 UMX-HQ vocals core SHA-256；不会加载未知权重。',
  SongSeparationFailureReason.resourceLimitExceeded =>
    '当前设备的离线内存预算不允许处理这么长的音频，请先裁剪后重试。',
  _ => '请选择受支持的本地音频后重试。',
};
