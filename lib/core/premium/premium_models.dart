class ListeningStreak {
  const ListeningStreak({required this.days, required this.listenedToday});
  final int days;
  final bool listenedToday;
}

class StudioEqState {
  const StudioEqState({
    this.bass = 0.5,
    this.treble = 0.5,
    this.vocal = 0.5,
    this.width = 0.5,
    this.orbitSpeed = 0.5,
    this.orbit8d = false,
  });

  final double bass;
  final double treble;
  final double vocal;
  final double width;
  final double orbitSpeed;
  final bool orbit8d;

  StudioEqState copyWith({
    double? bass,
    double? treble,
    double? vocal,
    double? width,
    double? orbitSpeed,
    bool? orbit8d,
  }) {
    return StudioEqState(
      bass: bass ?? this.bass,
      treble: treble ?? this.treble,
      vocal: vocal ?? this.vocal,
      width: width ?? this.width,
      orbitSpeed: orbitSpeed ?? this.orbitSpeed,
      orbit8d: orbit8d ?? this.orbit8d,
    );
  }
}
