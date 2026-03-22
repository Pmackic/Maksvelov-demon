extends AudioStreamPlayer
class_name AudioFeedback

# Placeholder synthetic tones. This avoids hiding UX feedback inside imported assets while
# still giving clearly swappable feedback points. Replace with samples later if preferred.

var _generator := AudioStreamGenerator.new()
var _playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	_generator.mix_rate = 22050.0
	_generator.buffer_length = 0.1
	stream = _generator
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback

func play_good() -> void:
	_emit_tone(880.0, 0.08, 0.22)
	_emit_tone(1174.0, 0.08, 0.16)

func play_bad() -> void:
	_emit_tone(280.0, 0.12, 0.18)

func _emit_tone(freq: float, duration: float, amplitude: float) -> void:
	if _playback == null:
		return
	var frames := int(_generator.mix_rate * duration)
	for i in range(frames):
		var envelope := 1.0 - float(i) / float(max(frames, 1))
		var sample := sin(TAU * freq * float(i) / _generator.mix_rate) * amplitude * envelope
		_playback.push_frame(Vector2(sample, sample))
