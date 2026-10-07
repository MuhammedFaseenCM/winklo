import 'dart:async';

/// Fires when local progress (score, streak, hint quota) is written.
///
/// Created in DI before [ProgressSyncLifecycle] exists, so repository impls
/// can take [notify] as their `onChanged` callback; the lifecycle subscribes
/// to [changes] later and debounces a push-only sync.
class ProgressChangeSignal {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get changes => _controller.stream;

  void notify() {
    if (_controller.isClosed) return;
    _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}
