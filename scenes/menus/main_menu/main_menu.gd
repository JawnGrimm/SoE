extends MainMenu

func _ready() -> void:
	super._ready()
	# Null autoplay players on inherited menu scenes must not interrupt the
	# MusicDirector/MusicController handoff. Start the menu track explicitly.
	MusicDirector.play_track(&"unobtrusive_background")
