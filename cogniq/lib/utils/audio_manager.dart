class AudioManager {
  // static final AudioPlayer _bgMusicPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
  // static final AudioPlayer _sfxPlayer = AudioPlayer();

  static bool _initialized = false;
  static bool isGameActive = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Disabled all audio players to resolve platform-channel latency and lagging.
    /*
    try {
      final AudioContext audioContext = AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.none,
        ),
      );
      await AudioPlayer.global.setAudioContext(audioContext);
      await _bgMusicPlayer.setAudioContext(audioContext);
      await _sfxPlayer.setAudioContext(audioContext);
    } catch (_) {
      // Ignore setting audio context exceptions
    }

    // Start background music loop if Focus Music is enabled in settings
    if (settingsNotifier.musicEnabled) {
      await startMusic();
    }
    */
  }

  static Future<void> playClick() async {
    // Disabled SFX
    /*
    if (!settingsNotifier.soundEnabled) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setVolume(1.0);
      await _sfxPlayer.play(AssetSource('audio/tactile_click.mp3'));
    } catch (_) {
      // Ignore playback exceptions
    }
    */
  }

  static Future<void> playSuccess() async {
    // Disabled SFX
    /*
    if (!settingsNotifier.soundEnabled) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setVolume(1.0);
      await _sfxPlayer.play(AssetSource('audio/level_clear.mp3'));
    } catch (_) {
      // Ignore playback exceptions
    }
    */
  }

  static Future<void> playFail() async {
    // Disabled SFX
    /*
    if (!settingsNotifier.soundEnabled) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setVolume(1.0);
      await _sfxPlayer.play(AssetSource('audio/wrong_answer.mp3'));
    } catch (_) {
      // Ignore playback exceptions
    }
    */
  }

  static Future<void> startMusic() async {
    // Disabled Music
    /*
    try {
      await _bgMusicPlayer.stop();
      await _bgMusicPlayer.play(AssetSource('audio/bg_music.mp3'));
      await _bgMusicPlayer.setVolume(settingsNotifier.musicEnabled ? 0.15 : 0.0);
    } catch (_) {
      // Ignore playback exceptions
    }
    */
  }

  static Future<void> stopSfx() async {
    // Disabled SFX
    /*
    try {
      await _sfxPlayer.stop();
    } catch (_) {
      // Ignore playback exceptions
    }
    */
  }

  static Future<void> stopMusic() async {
    isGameActive = false;
    // Disabled Music
    /*
    try {
      await _bgMusicPlayer.stop();
    } catch (_) {
      // Ignore playback exceptions
    }
    */
  }

  static Future<void> fadeOutMusic() async {
    isGameActive = true;
    // Disabled Music
    /*
    try {
      final double startVol = settingsNotifier.musicEnabled ? 0.15 : 0.0;
      if (startVol > 0) {
        for (int i = 10; i >= 0; i--) {
          await _bgMusicPlayer.setVolume(startVol * (i / 10.0));
          await Future.delayed(const Duration(milliseconds: 30));
        }
      }
      await _bgMusicPlayer.stop();
    } catch (_) {
      // Ignore playback exceptions
    }
    */
  }

  static Future<void> pauseMusic() async {
    isGameActive = true;
    // Disabled Music
  }

  static Future<void> resumeMusic() async {
    isGameActive = false;
    // Disabled Music
  }

  static Future<void> fadeInMusic() async {
    // Disabled Music
  }

  static Future<void> updateMusicSetting(bool enabled) async {
    // Disabled Music
  }

  static void updateVolume() {
    // Disabled Music
  }
}
