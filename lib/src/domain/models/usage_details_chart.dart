enum UsageDetailsChart {
  bars,
  area;

  static UsageDetailsChart fromStorage(String? value) {
    return value == area.name ? area : bars;
  }
}
