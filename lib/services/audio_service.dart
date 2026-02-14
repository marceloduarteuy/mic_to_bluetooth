import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../utils/constants.dart';

enum MicState {
  idle,
  starting,
  active,
  stopping,
  error,
}

class AudioService extends ChangeNotifier {
  // Audio components
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  AudioSession? _audioSession;

  // State
  MicState _micState = MicState.idle;
  double _micVolume = AppConstants.defaultMicVolume;
  double _musicDuckingVolume = AppConstants.defaultMusicDuckingVolume;
  String? _errorMessage;
  bool _isInitialized = false;

  // Stream controllers for audio data
  StreamController<Food>? _playerStreamController;
  StreamController<Uint8List>? _recordingDataController;
  StreamSubscription<Uint8List>? _recorderSubscription;

  // Platform channel for native audio routing
  static const _audioChannel = MethodChannel('com.example.mic_to_bluetooth/audio');

  // Getters
  MicState get micState => _micState;
  double get micVolume => _micVolume;
  double get musicDuckingVolume => _musicDuckingVolume;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;
  bool get isMicActive => _micState == MicState.active;

  AudioService() {
    _init();
  }

  Future<void> _init() async {
    try {
      // Initialize recorder and player
      _recorder = FlutterSoundRecorder();
      _player = FlutterSoundPlayer();

      await _recorder!.openRecorder();
      await _player!.openPlayer();

      // Configure audio session for ducking
      _audioSession = await AudioSession.instance;
      await _configureAudioSession();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to initialize audio: ${e.toString()}';
      _micState = MicState.error;
      notifyListeners();
    }
  }

  Future<void> _configureAudioSession() async {
    // Combine options using their integer values
    final combinedOptions = AVAudioSessionCategoryOptions(
      AVAudioSessionCategoryOptions.allowBluetooth.value |
      AVAudioSessionCategoryOptions.defaultToSpeaker.value |
      AVAudioSessionCategoryOptions.duckOthers.value,
    );

    await _audioSession?.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: combinedOptions,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
        flags: AndroidAudioFlags.none,
      ),
      androidAudioFocusGainType:
          AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: false,
    ));
  }

  /// Start microphone streaming to Bluetooth
  Future<bool> startMicStreaming() async {
    if (!_isInitialized) {
      _errorMessage = 'Audio service not initialized';
      notifyListeners();
      return false;
    }

    if (_micState == MicState.active) {
      return true; // Already active
    }

    _errorMessage = null;
    _micState = MicState.starting;
    notifyListeners();

    try {
      // Request audio focus with ducking
      await _audioSession?.setActive(true);

      // Route audio to Bluetooth if available
      await _routeAudioToBluetooth();

      // Create stream controller for player
      _playerStreamController = StreamController<Food>();

      // Start playback from stream first
      await _player!.startPlayerFromStream(
        codec: Codec.pcm16,
        sampleRate: AppConstants.sampleRate,
        numChannels: AppConstants.numChannels,
        bufferSize: 8192,
        interleaved: true,
      );

      // Create a stream controller for recorder output (store it for cleanup)
      _recordingDataController = StreamController<Uint8List>();

      // Start recording from microphone to our stream
      await _recorder!.startRecorder(
        toStream: _recordingDataController!.sink,
        codec: Codec.pcm16,
        sampleRate: AppConstants.sampleRate,
        numChannels: AppConstants.numChannels,
      );

      // Connect mic input to speaker output
      _recorderSubscription = _recordingDataController!.stream.listen((audioData) {
        if (_player != null && _player!.isPlaying) {
          // Apply volume adjustment
          final adjustedData = _applyVolume(audioData, _micVolume);
          // Feed data to player
          _player!.uint8ListSink?.add(adjustedData);
        }
      });

      _micState = MicState.active;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to start mic: ${e.toString()}';
      _micState = MicState.error;
      notifyListeners();
      await stopMicStreaming();
      return false;
    }
  }

  /// Stop microphone streaming
  Future<void> stopMicStreaming() async {
    if (_micState == MicState.idle) {
      return;
    }

    _micState = MicState.stopping;
    notifyListeners();

    // Release audio focus FIRST (allows other apps to resume full volume immediately)
    try {
      await _audioSession?.setActive(false);
    } catch (e) {
      debugPrint('Error releasing audio focus: $e');
    }

    // Update UI immediately
    _micState = MicState.idle;
    notifyListeners();

    // Clean up audio resources in background (don't block UI)
    _cleanupAudioResources();
  }

  /// Clean up audio resources without blocking
  Future<void> _cleanupAudioResources() async {
    try {
      // Cancel subscription first to stop data flow
      await _recorderSubscription?.cancel();
      _recorderSubscription = null;

      // Stop recording with timeout
      if (_recorder != null && _recorder!.isRecording) {
        await _recorder!.stopRecorder().timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );
      }

      // Stop playback with timeout
      if (_player != null && _player!.isPlaying) {
        await _player!.stopPlayer().timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );
      }

      // Close stream controllers
      await _recordingDataController?.close();
      _recordingDataController = null;

      await _playerStreamController?.close();
      _playerStreamController = null;
    } catch (e) {
      debugPrint('Error cleaning up audio resources: $e');
    }
  }

  /// Toggle microphone streaming
  Future<bool> toggleMicStreaming() async {
    if (_micState == MicState.active) {
      await stopMicStreaming();
      return false;
    } else {
      return await startMicStreaming();
    }
  }

  /// Set microphone volume (0.0 to 1.0)
  void setMicVolume(double volume) {
    _micVolume = volume.clamp(AppConstants.minVolume, AppConstants.maxVolume);
    notifyListeners();
  }

  /// Set music ducking volume (0.0 to 1.0)
  /// This controls how much the background music is reduced when mic is active
  void setMusicDuckingVolume(double volume) {
    _musicDuckingVolume = volume.clamp(AppConstants.minVolume, AppConstants.maxVolume);
    notifyListeners();
    // Note: Android ducking level is typically controlled by the system
    // This value can be used for display purposes or future platform channel implementation
  }

  /// Apply volume to audio data
  Uint8List _applyVolume(Uint8List audioData, double volume) {
    if (volume == 1.0) return audioData;

    // PCM 16-bit audio: each sample is 2 bytes (little-endian)
    final result = Uint8List(audioData.length);
    for (int i = 0; i < audioData.length - 1; i += 2) {
      // Read 16-bit sample (little-endian)
      int sample = audioData[i] | (audioData[i + 1] << 8);

      // Convert to signed
      if (sample > 32767) sample -= 65536;

      // Apply volume
      sample = (sample * volume).round();

      // Clamp to prevent clipping
      sample = sample.clamp(-32768, 32767);

      // Convert back to unsigned
      if (sample < 0) sample += 65536;

      // Write back (little-endian)
      result[i] = sample & 0xFF;
      result[i + 1] = (sample >> 8) & 0xFF;
    }
    return result;
  }

  /// Route audio output to Bluetooth device
  Future<void> _routeAudioToBluetooth() async {
    try {
      // Use platform channel to set audio routing on Android
      await _audioChannel.invokeMethod('routeToBluetooth');
    } catch (e) {
      // Platform channel might not be implemented, fall back to default routing
      debugPrint('Bluetooth routing via platform channel failed: $e');
      // The audio_session configuration should handle Bluetooth routing as fallback
    }
  }

  @override
  void dispose() {
    stopMicStreaming();
    _recorder?.closeRecorder();
    _player?.closePlayer();
    super.dispose();
  }
}
