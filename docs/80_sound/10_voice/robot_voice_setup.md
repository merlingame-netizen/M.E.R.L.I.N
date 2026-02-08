# Robot Voice (Retro Style) Setup

Goal
- Real-time "robot mignon" voice for Merlin (LLM text).
- Bestiole only uses non-verbal sounds (SFX), not TTS.
- Use Flite (TTS) + Godot AudioStreamGenerator.
- Cross-platform friendly, open-source.

Scripts
- Windows: scripts/voice_robot/setup_robot_voice.ps1
- macOS/Linux: scripts/voice_robot/setup_robot_voice.sh
- Colab: scripts/voice_robot/colab_build_flite.sh
- Colab: scripts/voice_robot/colab_pack_flite.sh
- Colab (Windows build): scripts/voice_robot/colab_build_windows_mingw.sh
- Colab (Windows addon zip): scripts/voice_robot/colab_pack_windows_addon.sh

What the scripts do
- Clone flite into native/third_party/flite
- Create addons/robot_voice/robot_voice_player.gd (AudioStreamGenerator helper)
- Colab builds flite into native/third_party/flite_build and zips it

Godot usage (playback side)
- Add a Node and attach RobotVoicePlayer (class_name).
- Feed samples into push_mono or push_stereo.
- For native TTS, push PCM floats from the GDExtension.

Example (GDScript)
var rv = RobotVoice.new()
var samples = rv.speak("Salut voyageur")
$RobotVoicePlayer.push_mono(samples)

Robot presets (stable)
- Mignon: pitch 1.45, volume 0.85, chirp_strength 0.06, chirp_hz 1400, chirp_ms 12
- Doux: pitch 1.25, volume 0.78, chirp_strength 0.03, chirp_hz 1100, chirp_ms 10
- Clair: pitch 1.10, volume 0.90, chirp_strength 0.02, chirp_hz 900, chirp_ms 8
- Gazouillis: pitch 1.60, volume 0.82, chirp_strength 0.08, chirp_hz 1700, chirp_ms 14

Where to place the GDExtension in the Godot project
- Put everything under: addons/robot_voice/
- The .gdextension file must sit at: addons/robot_voice/robot_voice.gdextension
- Native libs go under: addons/robot_voice/bin/
  - Example:
    - addons/robot_voice/bin/robot_voice.windows.release.x86_64.dll
    - addons/robot_voice/bin/robot_voice.linux.release.x86_64.so
    - addons/robot_voice/bin/robot_voice.macos.release.universal.dylib

Native side plan (summary)
- Build flite as a static lib.
- In GDExtension, expose a method:
  - speak(text) -> returns PackedFloat32Array (mono) or pushes directly.
- Optional DSP: pitch up + short chirps (robot mignon).
- Source folder expected at: native/robot_voice (for the Colab build scripts).

If you see "GDExtension dynamic library not found"
- It means the DLL is missing in addons/robot_voice/bin/.
- Temporary fix (disable the extension): remove the line
  res://addons/robot_voice/robot_voice.gdextension
  from .godot/extension_list.cfg.
- Re-enable after you place the compiled DLL.

Notes
- Keep mix_rate consistent across native and Godot (default 22050).
- Use AudioStreamGeneratorPlayback.push_frame for streaming.
- Avoid blocking the main thread; use a ring buffer or queue.
- Windows dev: use the MinGW cross-compile script on Colab
  (scripts/voice_robot/colab_build_windows_mingw.sh).
