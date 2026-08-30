import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

import 'settings_controller.dart';

/// Which piece of music is wanted.
enum MusicTrack {
  /// The menu, and anywhere else that is not a game being played.
  menu,

  /// A game in progress.
  match,
}

/// The app's background music: one looping track at a time.
///
/// Holds the players and the fade; a screen only says which track it wants.
/// Nothing listens to this, so unlike [SettingsController] it is not a
/// [ChangeNotifier] — the settings are what the player edits, and this
/// follows them.
///
/// **Nothing here throws.** Music is the one part of the app that is allowed
/// to simply not happen: a missing asset, a codec the device will not take, a
/// phone with the session already claimed. Every one of those is a line in the
/// log and silence, never a broken game.
class MusicService with WidgetsBindingObserver {
  /// Plays [menuAsset] and [matchAsset], at the volume [settings] asks for.
  ///
  /// The assets are passed in rather than named here: this layer is shared by
  /// every game and has no business knowing what the app's music is called.
  MusicService({
    required this.settings,
    required String menuAsset,
    required String matchAsset,
  }) : _assets = <MusicTrack, String>{
          MusicTrack.menu: menuAsset,
          MusicTrack.match: matchAsset,
        } {
    WidgetsBinding.instance.addObserver(this);
    settings.addListener(_onSettingsChanged);
  }

  /// Long enough to hear as a change of scene, short enough that tapping
  /// straight from the menu into a game does not spend a full second with
  /// both tracks going at once.
  static const Duration _crossfade = Duration(milliseconds: 800);

  /// Twenty-five steps across the fade. Under a frame at 60Hz, and far too
  /// small a change in level to hear as stepping.
  static const Duration _fadeTick = Duration(milliseconds: 32);

  /// How much of its volume the music keeps while something else is talking
  /// over it — a navigation prompt, a notification read aloud.
  static const double _duckedShare = 0.2;

  /// The preferences this follows: how loud, and whether at all.
  final SettingsController settings;

  final Map<MusicTrack, String> _assets;
  final Map<MusicTrack, AudioPlayer> _players = <MusicTrack, AudioPlayer>{};

  /// Tracks whose asset would not load. Never tried again: a file that is
  /// missing at the first attempt will not appear later in the session, and
  /// retrying on every screen change would only fill the log.
  final Set<MusicTrack> _broken = <MusicTrack>{};

  MusicTrack? _wanted;
  bool _suspended = false;
  bool _ducked = false;
  bool _sessionConfigured = false;
  bool _closed = false;
  Timer? _fade;

  /// Which track the app has asked for, or null before anything has.
  ///
  /// This is the intent, and it survives muting and backgrounding — which is
  /// what lets the right track come back when the sound does.
  MusicTrack? get wanted => _wanted;

  /// What a track at full mix should be set to at this moment.
  double get _audibleVolume {
    if (settings.musicMuted || _suspended) return 0;
    final double volume = settings.musicVolume;
    return _ducked ? volume * _duckedShare : volume;
  }

  /// Plays the menu loop, fading over from whatever is playing.
  Future<void> playMenu() => _want(MusicTrack.menu);

  /// Plays the in-game loop, fading over from whatever is playing.
  Future<void> playMatch() => _want(MusicTrack.match);

  /// Stops everything and lets the players go.
  ///
  /// The app itself never calls this — the music lasts as long as the app
  /// does — but a test that builds a service should be able to put it down
  /// again without leaving a ticker running.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _fade?.cancel();
    settings.removeListener(_onSettingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    for (final player in _players.values) {
      await _quiet('close', player.dispose);
    }
    _players.clear();
  }

  /// Pauses when the app goes away and picks up again when it comes back.
  ///
  /// Music that carries on over whatever the player switched to reads as a
  /// bug, and on a phone it is also somebody's battery.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final bool away = state != AppLifecycleState.resumed;
    if (away == _suspended) return;
    _suspended = away;
    unawaited(_settle());
  }

  /// The volume or the mute changed under us.
  void _onSettingsChanged() => unawaited(_settle());

  /// Asks for [track].
  Future<void> _want(MusicTrack track) async {
    if (_closed || track == _wanted) return;
    final MusicTrack? leaving = _wanted;
    _wanted = track;
    if (_audibleVolume == 0) {
      // Remember the choice, make no sound. Muting and then starting a game
      // still leaves the game's music queued up for when the sound returns.
      if (leaving != null) {
        await _quiet('pause', () => _players[leaving]?.pause());
      }
      return;
    }
    await _run(to: track, from: leaving);
  }

  /// Brings the sound into line with the settings, without changing track.
  Future<void> _settle() async {
    final MusicTrack? track = _wanted;
    if (_closed || track == null) return;
    if (_audibleVolume == 0) {
      _fade?.cancel();
      await _quiet('pause', () => _players[track]?.pause());
      return;
    }
    await _run(to: track, from: null);
  }

  /// Fades [to] up and, if there is one, [from] down.
  Future<void> _run({required MusicTrack to, MusicTrack? from}) async {
    _fade?.cancel();
    final AudioPlayer? arriving = await _open(to);
    if (arriving == null || _closed) return;

    final AudioPlayer? leaving = from == null ? null : _players[from];
    await _quiet(
      'volume',
      () => arriving.setVolume(leaving == null ? _audibleVolume : 0),
    );
    // Deliberately not awaited: under LoopMode.one the track never ends, so
    // this future never completes and awaiting it would hang the caller.
    if (!arriving.playing) {
      unawaited(_quiet('play', arriving.play));
    }
    if (leaving == null) return;

    final int steps = _crossfade.inMilliseconds ~/ _fadeTick.inMilliseconds;
    int step = 0;
    _fade = Timer.periodic(_fadeTick, (Timer timer) {
      if (_closed) {
        timer.cancel();
        return;
      }
      step++;
      final double progress = (step / steps).clamp(0, 1).toDouble();
      // Read fresh each tick, so dragging the volume slider mid-fade is
      // followed rather than overwritten when the fade lands.
      final double peak = _audibleVolume;
      unawaited(_quiet('fade', () => arriving.setVolume(peak * progress)));
      unawaited(_quiet('fade', () => leaving.setVolume(peak * (1 - progress))));
      if (progress == 1) {
        timer.cancel();
        unawaited(_quiet('pause', leaving.pause));
        // Back to the top, so returning to the menu later starts the loop at
        // the beginning rather than halfway through a phrase.
        unawaited(_quiet('rewind', () => leaving.seek(Duration.zero)));
      }
    });
  }

  /// The loaded, looping player for [track], or null if there cannot be one.
  Future<AudioPlayer?> _open(MusicTrack track) async {
    if (_broken.contains(track)) return null;
    final AudioPlayer? already = _players[track];
    if (already != null) return already;

    await _configureSession();
    final AudioPlayer player = AudioPlayer();
    try {
      // Looped on the player rather than by restarting it when it ends: the
      // loops were written to join seamlessly, and anything that reloads at
      // the seam puts a gap in exactly the place the music was built to hide.
      await player.setLoopMode(LoopMode.one);
      await player.setAsset(_assets[track]!);
      await player.setVolume(0);
    } catch (error) {
      debugPrint('MusicService: no $track music ($error). Carrying on '
          'without it.');
      _broken.add(track);
      unawaited(_quiet('close', player.dispose));
      return null;
    }
    if (_closed) {
      unawaited(_quiet('close', player.dispose));
      return null;
    }
    _players[track] = player;
    return player;
  }

  /// Says how this app expects to share the device's sound.
  ///
  /// `ambient` rather than `playback`, deliberately: it is silenced by the iOS
  /// ringer switch, and it leaves whatever the player already had going
  /// alone. Someone doing a sudoku while listening to a podcast should keep
  /// the podcast. The game's music is the part that gives way.
  Future<void> _configureSession() async {
    if (_sessionConfigured) return;
    _sessionConfigured = true;
    try {
      final AudioSession session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.ambient,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.game,
          ),
          // Ask for the kind of focus we are willing to hand straight back,
          // and drop to a murmur rather than stopping when something
          // short-lived talks over us.
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ),
      );
      session.interruptionEventStream.listen(_onInterruption);
      // Headphones pulled out. Stop, rather than putting the music through
      // the room.
      session.becomingNoisyEventStream.listen((void _) {
        _ducked = false;
        _suspended = true;
        unawaited(_settle());
      });
    } catch (error) {
      debugPrint('MusicService: audio session left at its defaults ($error).');
    }
  }

  /// Something else wants the sound.
  void _onInterruption(AudioInterruptionEvent event) {
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          _ducked = true;
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          _suspended = true;
      }
    } else {
      switch (event.type) {
        case AudioInterruptionType.duck:
          _ducked = false;
        case AudioInterruptionType.pause:
          _suspended = false;
        case AudioInterruptionType.unknown:
          // May never end. Staying quiet is the safe way to be wrong.
          break;
      }
    }
    unawaited(_settle());
  }

  /// Runs a call at the audio plugin and swallows whatever it throws.
  Future<void> _quiet(String what, FutureOr<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('MusicService: $what failed ($error).');
    }
  }
}

/// Hands a [MusicService] to everything below it.
///
/// Put around the whole app, once, so a game asks for its music rather than
/// being handed a player to look after — the same bargain `CelebrationScope`
/// makes for thrown colour.
class MusicScope extends InheritedWidget {
  /// Offers [music] to [child] and everything under it.
  const MusicScope({
    required this.music,
    required super.child,
    super.key,
  });

  /// The service in scope.
  final MusicService music;

  /// The music in scope, or null when there is none.
  ///
  /// Nullable on purpose, exactly as the celebration cue is: a test that
  /// builds one screen on its own has no app around it, and silence should
  /// cost that test nothing.
  static MusicService? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MusicScope>()?.music;

  @override
  bool updateShouldNotify(MusicScope oldWidget) => oldWidget.music != music;
}

/// Plays the in-game loop for as long as a game screen is up.
///
/// Mixed into a game's [State] rather than written out in each of them: every
/// game wants the same two things, its own music while it is on show and the
/// menu's back when it is gone.
///
/// The service is looked up once and kept, because by the time [State.dispose]
/// runs the element is on its way out and the scope above it can no longer be
/// reached — which is exactly when the menu loop needs asking for.
mixin GameMusic<T extends StatefulWidget> on State<T> {
  MusicService? _music;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_music != null) return;
    final MusicService? music = MusicScope.maybeOf(context);
    _music = music;
    if (music != null) unawaited(music.playMatch());
  }

  @override
  void dispose() {
    final MusicService? music = _music;
    if (music != null) unawaited(music.playMenu());
    super.dispose();
  }
}
