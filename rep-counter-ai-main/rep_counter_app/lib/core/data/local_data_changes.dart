import 'dart:async';

/// Which local store changed (see [LocalDataChanges]).
enum LocalDataKind { workouts, plans }

/// Fires after a workout or plan is written on this phone, so cloud sync
/// (A-2) can upload it soon. Costs nothing when nobody listens; the stores
/// never wait for a listener.
abstract final class LocalDataChanges {
  static final _controller = StreamController<LocalDataKind>.broadcast();

  static Stream<LocalDataKind> get stream => _controller.stream;

  static void notify(LocalDataKind kind) => _controller.add(kind);
}
