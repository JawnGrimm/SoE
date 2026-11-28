extends Node
## Era/scene music selection. Playback and crossfades are handled by Maaack's MusicController.

const TIGRIS_AT_DAWN: AudioStreamMP3 = preload("res://assets/audio/Tigris at Dawn.mp3")
const CANAL_SIDE_COORDINATION: AudioStreamMP3 = preload("res://assets/audio/Canal-Side Coordination.mp3")
const BUREAUCRATIC_STASIS: AudioStreamMP3 = preload("res://assets/audio/Bureaucratic Stasis.mp3")
const UNOBTRUSIVE_BACKGROUND: AudioStreamMP3 = preload("res://assets/audio/Unobtrusive Background.mp3")

# Only deliberate scene boundaries select a new score. Routine desk phases
# (investigation, disposition, result, queue, etc.) inherit the current track.
const PHASE_TRACKS: Dictionary = {
	"case": &"tigris_at_dawn",
	"character_creation": &"unobtrusive_background",
	"era_complete": &"unobtrusive_background",
}

var _tracks: Dictionary = {}
var _current_track: StringName = &""

func _ready() -> void:
	_tracks = {
		&"tigris_at_dawn": TIGRIS_AT_DAWN,
		&"canal_side_coordination": CANAL_SIDE_COORDINATION,
		&"bureaucratic_stasis": BUREAUCRATIC_STASIS,
		&"unobtrusive_background": UNOBTRUSIVE_BACKGROUND,
	}
	for stream: AudioStreamMP3 in _tracks.values():
		stream.loop = true
	MusicController.fade_in_duration = 1.8
	MusicController.fade_out_duration = 1.8

func play_for_phase(game_phase: String) -> void:
	if not PHASE_TRACKS.has(game_phase):
		return
	var track_id: StringName = PHASE_TRACKS[game_phase]
	play_track(track_id)

func play_track(track_id: StringName) -> void:
	if track_id == _current_track:
		return
	var stream: AudioStream = _tracks.get(track_id)
	if stream == null:
		push_warning("MusicDirector: unknown track '%s'." % track_id)
		return
	_current_track = track_id
	var player: AudioStreamPlayer = MusicController.play_stream(stream)
	if is_instance_valid(player):
		player.volume_db = -7.0
