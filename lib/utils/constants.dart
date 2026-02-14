class AppConstants {
  // Audio settings
  static const int sampleRate = 44100;
  static const int numChannels = 1; // Mono for voice
  static const int bitRate = 128000;

  // Bluetooth scan duration
  static const Duration scanDuration = Duration(seconds: 10);

  // Default volumes (0.0 to 1.0)
  static const double defaultMicVolume = 0.8;
  static const double defaultMusicDuckingVolume = 0.9; // 90% - music level when mic is active
  static const double minVolume = 0.0;
  static const double maxVolume = 1.0;

  // UI
  static const double micButtonSize = 120.0;
  static const double volumeSliderWidth = 280.0;
}
