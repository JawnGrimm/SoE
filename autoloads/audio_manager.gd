extends Node

const BOOK_OPEN = preload("res://assets/audio/bookOpen.ogg")
const BOOK_CLOSE = preload("res://assets/audio/bookClose.ogg")
const BOOK_FLIP_1 = preload("res://assets/audio/bookFlip1.ogg")
const BOOK_FLIP_2 = preload("res://assets/audio/bookFlip2.ogg")
const BOOK_FLIP_3 = preload("res://assets/audio/bookFlip3.ogg")
const BOOK_PLACE_1 = preload("res://assets/audio/bookPlace1.ogg")
const BOOK_PLACE_2 = preload("res://assets/audio/bookPlace2.ogg")
const BOOK_PLACE_3 = preload("res://assets/audio/bookPlace3.ogg")
const METAL_CLICK = preload("res://assets/audio/metalClick.ogg")
const HANDLE_COINS = preload("res://assets/audio/handleCoins.ogg")

const SAMPLE_RATE: int = 22050

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}

func _ready() -> void:
	_streams[&"docket"] = [BOOK_FLIP_1, BOOK_FLIP_2, BOOK_FLIP_3, BOOK_PLACE_1, BOOK_PLACE_2, BOOK_PLACE_3]
	_streams[&"book_open"] = [BOOK_OPEN]
	_streams[&"book_close"] = [BOOK_CLOSE]
	_streams[&"stylus"] = [METAL_CLICK]
	_streams[&"seal"] = [METAL_CLICK, HANDLE_COINS]
	_streams[&"snap"] = [BOOK_CLOSE]
	_streams[&"roof_drip"] = [_make_roof_drip_stream()]
	for index in range(4):
		var player := AudioStreamPlayer.new()
		player.volume_db = -9.0
		add_child(player)
		_players.append(player)

func play_docket_slide() -> void:
	_play(&"docket")

func play_book_open() -> void:
	_play(&"book_open")

func play_book_close() -> void:
	_play(&"book_close")

func play_stylus_mark() -> void:
	_play(&"stylus")

func play_seal_press() -> void:
	_play(&"seal")

func play_tablet_snap() -> void:
	_play(&"snap")

func play_roof_drip() -> void:
	_play(&"roof_drip")

func _play(sound_id: StringName) -> void:
	var candidates: Array = _streams.get(sound_id, [])
	if candidates.is_empty():
		return
	var stream: AudioStream = candidates[randi() % candidates.size()]
	var player: AudioStreamPlayer = _players[0]
	for candidate in _players:
		if not candidate.playing:
			player = candidate
			break
	player.stream = stream
	player.pitch_scale = randf_range(0.94, 1.06)
	player.play()

func _make_roof_drip_stream() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.46)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for index in range(count):
		var time := float(index) / SAMPLE_RATE
		var first_age := time - 0.025
		var second_age := time - 0.235
		var first := 0.0
		var second := 0.0
		if first_age >= 0.0:
			first = sin(TAU * 1180.0 * first_age) * exp(-first_age * 34.0) * 0.62
		if second_age >= 0.0:
			second = sin(TAU * 860.0 * second_age) * exp(-second_age * 29.0) * 0.48
		_write_sample(bytes, index, first + second)
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
