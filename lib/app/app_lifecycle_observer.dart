import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/live_practice/application/live_practice_controller.dart';
import '../core/platform/application_lifecycle.dart';
import 'app_providers.dart';

abstract interface class ApplicationLifecycleSource {
  ApplicationLifecyclePhase get currentPhase;

  Stream<ApplicationLifecyclePhase> get phases;

  void dispose();
}

/// The only adapter that translates Flutter lifecycle callbacks into the
/// application's small, platform-neutral lifecycle vocabulary.
final class WidgetsBindingApplicationLifecycleSource
    with WidgetsBindingObserver
    implements ApplicationLifecycleSource {
  WidgetsBindingApplicationLifecycleSource({WidgetsBinding? binding})
    : _binding = binding ?? WidgetsBinding.instance,
      _currentPhase = mapFlutterLifecycleState(
        (binding ?? WidgetsBinding.instance).lifecycleState,
      ) {
    _binding.addObserver(this);
  }

  final WidgetsBinding _binding;
  final StreamController<ApplicationLifecyclePhase> _phases =
      StreamController<ApplicationLifecyclePhase>.broadcast(sync: true);
  ApplicationLifecyclePhase _currentPhase;
  bool _disposed = false;

  @override
  ApplicationLifecyclePhase get currentPhase => _currentPhase;

  @override
  Stream<ApplicationLifecyclePhase> get phases => _phases.stream;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final next = mapFlutterLifecycleState(state);
    if (_disposed || next == _currentPhase) return;
    _currentPhase = next;
    _phases.add(next);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _binding.removeObserver(this);
    unawaited(_phases.close());
  }
}

final class DisabledApplicationLifecycleSource
    implements ApplicationLifecycleSource {
  const DisabledApplicationLifecycleSource();

  @override
  ApplicationLifecyclePhase get currentPhase =>
      ApplicationLifecyclePhase.foreground;

  @override
  Stream<ApplicationLifecyclePhase> get phases => const Stream.empty();

  @override
  void dispose() {}
}

ApplicationLifecyclePhase mapFlutterLifecycleState(AppLifecycleState? state) {
  return switch (state) {
    AppLifecycleState.resumed || null => ApplicationLifecyclePhase.foreground,
    AppLifecycleState.detached => ApplicationLifecyclePhase.detached,
    AppLifecycleState.inactive ||
    AppLifecycleState.hidden ||
    AppLifecycleState.paused => ApplicationLifecyclePhase.background,
  };
}

final applicationLifecycleSourceProvider = Provider<ApplicationLifecycleSource>(
  (ref) {
    final capabilities = ref.watch(platformCapabilitiesProvider);
    final source = capabilities.supportsLifecycleEvents
        ? WidgetsBindingApplicationLifecycleSource()
        : const DisabledApplicationLifecycleSource();
    ref.onDispose(source.dispose);
    return source;
  },
);

final applicationLifecyclePhaseProvider =
    StreamProvider<ApplicationLifecyclePhase>((ref) async* {
      final source = ref.watch(applicationLifecycleSourceProvider);
      yield source.currentPhase;
      yield* source.phases;
    });

/// Activates the application-level lifecycle policy. Presentation pages never
/// observe WidgetsBinding directly and only see the resulting session state.
final applicationLifecycleBindingProvider = Provider<void>((ref) {
  if (!ref.watch(platformCapabilitiesProvider).supportsLifecycleEvents) return;
  ref.listen(applicationLifecyclePhaseProvider, (_, next) {
    final phase = next.valueOrNull;
    if (phase == null) return;
    unawaited(
      ref
          .read(livePracticeControllerProvider.notifier)
          .handleApplicationLifecycle(phase),
    );
  }, fireImmediately: true);
});
