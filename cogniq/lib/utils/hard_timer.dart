import 'dart:async';
import 'audio_manager.dart';

class HardTimer {
  /// Starts a periodic 1-second timer.
  /// When it reaches 0, it plays the fail sound and triggers [onTimeout].
  static Timer start({
    required int durationSeconds,
    required void Function(int timeLeft) onTick,
    required void Function() onTimeout,
  }) {
    int timeLeft = durationSeconds;
    onTick(timeLeft);
    
    return Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft > 0) {
        timeLeft--;
        onTick(timeLeft);
      } else {
        timer.cancel();
        AudioManager.playFail();
        onTimeout();
      }
    });
  }
}
