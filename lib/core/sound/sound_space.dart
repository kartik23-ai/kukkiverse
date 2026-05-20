enum SoundSpace {
  normal('Normal', 'Original mix'),
  wide('Wide', 'Expanded stereo field'),
  bass('Bass Boost', 'Extra low-end punch'),
  vocal('Vocal Forward', 'Clearer vocals'),
  eightD('8D Audio', 'Orbital pan effect');

  const SoundSpace(this.label, this.subtitle);
  final String label;
  final String subtitle;
}
