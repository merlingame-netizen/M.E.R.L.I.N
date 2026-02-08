#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

THIRD_PARTY="$REPO_ROOT/native/third_party"
FLITE_DIR="$THIRD_PARTY/flite"

mkdir -p "$THIRD_PARTY"

if [ ! -d "$FLITE_DIR" ]; then
  echo "Cloning flite into $FLITE_DIR"
  git clone https://github.com/festvox/flite.git "$FLITE_DIR"
else
  echo "flite already present: $FLITE_DIR"
fi

ADDON_DIR="$REPO_ROOT/addons/robot_voice"
mkdir -p "$ADDON_DIR"

cat > "$ADDON_DIR/robot_voice_player.gd" <<'GDS'
extends Node
class_name RobotVoicePlayer

@export var mix_rate: int = 22050
@export var buffer_seconds: float = 0.5

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback

func _ready() -> void:
    var generator = AudioStreamGenerator.new()
    generator.mix_rate = mix_rate
    generator.buffer_length = buffer_seconds
    _player = AudioStreamPlayer.new()
    _player.stream = generator
    add_child(_player)
    _player.play()
    _playback = _player.get_stream_playback()

func push_mono(samples: PackedFloat32Array) -> void:
    if _playback == null:
        return
    for s in samples:
        _playback.push_frame(Vector2(s, s))

func push_stereo(samples: PackedVector2Array) -> void:
    if _playback == null:
        return
    for frame in samples:
        _playback.push_frame(frame)

func reset() -> void:
    if _player == null:
        return
    _player.stop()
    _player.play()
    _playback = _player.get_stream_playback()
GDS

echo "Robot voice helper created: $ADDON_DIR/robot_voice_player.gd"
