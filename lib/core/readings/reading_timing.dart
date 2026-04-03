class ReadingTiming {
  static Duration initialWaitFor(String type) {
    switch (type) {
      case 'coffee':
        return const Duration(minutes: 10);
      case 'tarot':
        return const Duration(minutes: 8);
      case 'palm':
        return const Duration(minutes: 10);
      case 'astro':
        return const Duration(minutes: 5);
      case 'dream':
        return const Duration(minutes: 10);
      case 'motivation':
        return const Duration(minutes: 5);
      default:
        return Duration.zero;
    }
  }

  static Duration speedupTargetFor(String type) {
    switch (type) {
      case 'coffee':
        return const Duration(minutes: 5);
      case 'tarot':
        return const Duration(minutes: 4);
      case 'palm':
        return const Duration(minutes: 5);
      case 'astro':
        return const Duration(minutes: 2, seconds: 30);
      case 'dream':
        return const Duration(minutes: 5);
      case 'motivation':
        return const Duration(minutes: 2, seconds: 30);
      default:
        return Duration.zero;
    }
  }

  static bool supportsPendingTimer(String type) {
    return initialWaitFor(type) > Duration.zero;
  }

  static String speedupTargetLabel(String type) {
    final target = speedupTargetFor(type);
    final minutes = target.inSeconds / 60;
    final wholeMinutes = minutes.truncateToDouble() == minutes;
    final value =
        wholeMinutes ? minutes.toStringAsFixed(0) : minutes.toStringAsFixed(1);
    return '$value dk';
  }
}
