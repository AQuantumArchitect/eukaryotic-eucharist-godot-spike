class_name GameInput
extends RefCounted
## Produces the same command Dictionary shape index.html's command() builds every frame
## (index.html:417-430), so KernelBridge.step_game() can hand it straight to K.step() unmodified.
## Reads raw keycodes via Input.is_key_pressed() (one-to-one with index.html's keydown table,
## index.html:383-395) plus the mouse for aim/fire — keyboard+mouse only, touch parity is a later
## phase. Deliberately skips project.godot's InputMap/action system: a single-binding-per-action
## custom action buys nothing over a direct keycode check here, and avoids hand-authoring Godot's
## verbose InputEventKey resource syntax for ~15 one-off bindings.

static func build(player_world_pos: Vector2, aim_world_pos: Vector2) -> Dictionary:
	var mx := 0.0
	var my := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		mx -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		mx += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		my -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		my += 1.0

	var aim := aim_world_pos - player_world_pos
	if aim.length() > 0.001:
		aim = aim.normalized()
	else:
		aim = Vector2.ZERO

	# One click/hold fires every owned weapon organelle at once, matching index.html's single
	# `fire` flag ORing into rasp/acid/sporeshot/harpoon/cloud/flame (index.html:428-429).
	var fire := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	return {
		"moveX": mx, "moveY": my,
		"feed": Input.is_key_pressed(KEY_F) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT),
		"repair": Input.is_key_pressed(KEY_Q),
		"rasp": fire,
		"dash": Input.is_key_pressed(KEY_SHIFT),
		"acid": fire or Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_X),
		"sporeshot": fire or Input.is_key_pressed(KEY_C),
		"harpoon": fire or Input.is_key_pressed(KEY_Z),
		"cloud": fire or Input.is_key_pressed(KEY_V),
		"mark": Input.is_key_pressed(KEY_G),
		"engulf": Input.is_key_pressed(KEY_B),
		"ward": Input.is_key_pressed(KEY_H),
		"jettison": Input.is_key_pressed(KEY_T),
		"flame": fire or Input.is_key_pressed(KEY_J),
		"divide": Input.is_key_pressed(KEY_M),
		"compact": Input.is_key_pressed(KEY_U),
		"aimX": aim.x, "aimY": aim.y,
	}
