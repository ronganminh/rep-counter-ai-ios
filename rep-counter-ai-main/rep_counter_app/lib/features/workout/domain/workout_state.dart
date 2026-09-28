/// Vòng đời một buổi tập. IMPLEMENTATION_PLAN §4.1.
library;

enum WorkoutPhase {
  idle,
  initializingCamera,
  positioning,
  calibrating,
  countdown,
  active,
  paused,
  completing,
  completed,
  failed,
}

extension WorkoutPhaseX on WorkoutPhase {
  /// Chỉ `active` mới được đếm rep.
  ///
  /// Không có chốt này thì mỗi lần bước vào/ra khung đều tạo một cú vượt ngưỡng
  /// và cộng oan một rep — đúng kiểu dương tính giả đã đo được trên video thật
  /// (ADR 0002).
  bool get countsReps => this == WorkoutPhase.active;

  /// Camera đang chạy và cần khung hình.
  bool get needsCamera => const {
        WorkoutPhase.initializingCamera,
        WorkoutPhase.positioning,
        WorkoutPhase.calibrating,
        WorkoutPhase.countdown,
        WorkoutPhase.active,
        WorkoutPhase.paused,
      }.contains(this);

  bool get isTerminal =>
      this == WorkoutPhase.completed || this == WorkoutPhase.failed;
}
