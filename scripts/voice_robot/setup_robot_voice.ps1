$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")

$thirdParty = Join-Path $repoRoot "native\third_party"
$fliteDir = Join-Path $thirdParty "flite"

if (-not (Test-Path $thirdParty)) {
    New-Item -ItemType Directory -Force -Path $thirdParty | Out-Null
}

if (-not (Test-Path $fliteDir)) {
    Write-Host "Cloning flite into $fliteDir" -ForegroundColor Yellow
    git clone https://github.com/festvox/flite.git $fliteDir
} else {
    Write-Host "flite already present: $fliteDir" -ForegroundColor Green
}

$addonDir = Join-Path $repoRoot "addons\robot_voice"
if (-not (Test-Path $addonDir)) {
    New-Item -ItemType Directory -Force -Path $addonDir | Out-Null
}

$gdPath = Join-Path $addonDir "robot_voice_player.gd"
@"
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
"@ | Set-Content -Encoding Ascii -Path $gdPath

Write-Host "Robot voice helper created: $gdPath" -ForegroundColor Cyan
Write-Host "Next: build flite and wire it from a GDExtension (native side)." -ForegroundColor Yellow
