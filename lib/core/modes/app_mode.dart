enum RottyAppMode {
  normal('Normal', 'Full ROTTY experience'),
  focus('Focus', 'Minimal UI • timer • soft sounds'),
  drive('Drive', 'Huge controls • high contrast'),
  sleep('Sleep', 'Fade timer • dim lyrics');

  const RottyAppMode(this.label, this.subtitle);
  final String label;
  final String subtitle;
}
