extends MainMenu

func _ready() -> void:
	super._ready()
	# Null autoplay players on inherited menu scenes must not interrupt the
	# MusicDirector/MusicController handoff. Start the menu track explicitly.
	MusicDirector.play_track(&"unobtrusive_background")
	if SaveManager.has_save():
		var continue_button := Button.new()
		continue_button.name = "ContinueButton"
		continue_button.text = "Continue"
		continue_button.custom_minimum_size = new_game_button.custom_minimum_size
		menu_buttons_box_container.add_child(continue_button)
		menu_buttons_box_container.move_child(continue_button, 0)
		continue_button.pressed.connect(_on_continue_button_pressed)

func _on_continue_button_pressed() -> void:
	SaveManager.request_load_on_start()
	load_game_scene()
