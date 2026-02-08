# Robot Voice - Google Colab Build

Goal
- Build flite on Google Colab for the Merlin robot voice pipeline.
- Bestiole only uses non-verbal SFX, not TTS.
- Export a zipped build folder for later integration in Godot.

Files
- scripts/voice_robot/colab_build_flite.sh
- scripts/voice_robot/colab_pack_flite.sh
- Compile_RobotVoice_Colab.ipynb (one-click notebook)

Colab steps (copy/paste)

1) Upload your project ZIP to Colab, or git clone it.

2) Build flite:

bash scripts/voice_robot/colab_build_flite.sh /content/Godot-MCP

3) Pack build artifacts:

bash scripts/voice_robot/colab_pack_flite.sh /content/Godot-MCP

4) Download flite_linux_build.zip from the Colab file browser.

Notes
- Output path: native/third_party/flite_build
- For Godot, keep mix_rate consistent with AudioStreamGenerator (default 22050).
- The GDExtension binding is a separate step and will link against this build.

Windows dev note
- Colab builds Linux binaries only. These cannot be used on Windows Godot.
- For Windows development, build flite with your Windows toolchain (MSVC) or
  compile flite sources as part of the GDExtension on Windows.
- Keep the Colab artifacts only for Linux testing or CI.

Windows build on Colab (MinGW cross-compile)
- Use this when you cannot compile on Windows locally.
- This produces a Windows DLL using the MinGW toolchain.

Commands:

bash scripts/voice_robot/colab_build_windows_mingw.sh /content/Godot-MCP
bash scripts/voice_robot/colab_pack_windows_addon.sh /content/Godot-MCP

Output:
- robot_voice_windows_addon.zip (drop into your Godot project)

Notes:
- MinGW builds are intended for the Windows Godot editor/runtime.
- Make sure godot-cpp is built with use_mingw=yes (handled by the script).
- The script expects a GDExtension source folder at native/robot_voice.
