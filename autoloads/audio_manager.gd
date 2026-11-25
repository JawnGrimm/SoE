extends Node

const SAMPLE_RATE: int = 22050
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}

func _ready() -> void:
	_streams[&"docket"] = _make_noise_stream(0.16, 0.22, 1800.0, 0.0)
	_streams[&"stylus"] = _make_noise_stream(0.11, 0.38, 4200.0, 0.0)
	_streams[&"seal"] = _make_thud_stream()
	_streams[&"snap"] = _make_snap_stream()
	for index in range(4):
		var player := AudioStreamPlayer.new()
		player.volume_db = -9.0
		add_child(player)
		_players.append(player)

func play_docket_slide() -> void:
	_play(&"docket")

func play_stylus_mark() -> void:
	_play(&"stylus")

func play_seal_press() -> void:
	_play(&"seal")

func play_tablet_snap() -> void:
	_play(&"snap")

func _play(sound_id: StringName) -> void:
	if not _streams.has(sound_id):
		return
	var player: AudioStreamPlayer = _players[0]
	for candidate in _players:
		if not candidate.playing:
			player = candidate
			break
	player.stream = _streams[sound_id]
	player.pitch_scale = randf_range(0.94, 1.06)
	player.play()

func _make_noise_stream(duration: float, amplitude: float, cutoff: float, tone: float) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var previous := 0.0
	for index in range(count):
		var time := float(index) / SAMPLE_RATE
		var envelope := pow(1.0 - float(index) / count, 2.0)
		var noise := randf_range(-1.0, 1.0)
		previous += (noise - previous) * minf(1.0, cutoff / SAMPLE_RATE * 5.0)
		var sample := clampf(previous * amplitude * envelope + sin(TAU * tone * time) * 0.04 * envelope, -1.0, 1.0)
		_write_sample(bytes, index, sample)
	return _wav(bytes)

func _make_thud_stream() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.28)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for index in range(count):
		var time := float(index) / SAMPLE_RATE
		var envelope := exp(-time * 17.0)
		var sample := (sin(TAU * (82.0 - 22.0 * time) * time) * 0.72 + randf_range(-0.12, 0.12)) * envelope
		_write_sample(bytes, index, sample)
	return _wav(bytes)

func _make_snap_stream() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.19)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for index in range(count):
		var time := float(index) / SAMPLE_RATE
		var envelope := exp(-time * 28.0)
		var ceramic_ring := sin(TAU * 1450.0 * time) * 0.32 + sin(TAU * 2130.0 * time) * 0.16
		var sample := (randf_range(-0.8, 0.8) * 0.7 + ceramic_ring) * envelope
		_write_sample(bytes, index, sample)
	return _wav(bytes)

func _write_sample(bytes: PackedByteArray, index: int, value: float) -> void:
	var sample := int(round(clampf(value, -1.0, 1.0) * 32767.0))
	bytes.encode_s16(index * 2, sample)

func _wav(bytes: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
