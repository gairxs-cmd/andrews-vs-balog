extends Node2D
## Arena 2D de teste. Separar arte, combate, controles e sons facilita expansoes.
## Projeto pensado para 1280 x 720. Sem plugins e sem dependencias externas.

const Fighter = preload("res://scripts/fighter.gd")
const WIDTH: float = 1280.0
const HEIGHT: float = 720.0
const FLOOR: float = 615.0
const BLUE: Color = Color("5fd9ff")
const RED: Color = Color("ff5277")
const GOLD: Color = Color("ffe18a")
const INK: Color = Color("0b1120")

var backdrop: Texture2D = preload("res://assets/scenes/night_city_realistic.jpg")
var cinematic_menu: Texture2D = preload("res://assets/scenes/menu_poster.jpg")
var hud_top: Texture2D = preload("res://assets/scenes/hud_top.png")
var hud_bottom: Texture2D = preload("res://assets/scenes/hud_super.png")
var timer_digits: Texture2D = preload("res://assets/ui/timer_digits.png")
# Both visual sources are approved; bars are controlled at runtime, not baked screenshots.
var hp_visual_a: float = 100.0
var hp_visual_b: float = 100.0
var damage_trail_a: float = 100.0
var damage_trail_b: float = 100.0
var portrait_a: Texture2D = preload("res://assets/fighters/andrews_portrait.png")
var portrait_b: Texture2D = preload("res://assets/fighters/balog_portrait.png")
var sprites_a: Array[Texture2D] = []
var sprites_b: Dictionary = {}
var fighter_a: Fighter
var fighter_b: Fighter
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var raindrops: Array[Dictionary] = []
var audio_players: Dictionary = {}
var font: Font
var phase: String = "menu"
var game_mode: int = 0 # 0 = computador, 1 = dois jogadores
var selected_mode: int = 0
var round_number: int = 1
var remaining: float = 99.0
var ending_clock: float = 0.0
var winner_message: String = ""
var shake: float = 0.0
var global_clock: float = 0.0
var ai_think: float = 0.0
var ai_tactic: Dictionary = {}
var show_hitboxes: bool = false

func _ready() -> void:
	font = ThemeDB.fallback_font
	for n in range(1, 7):
		sprites_a.append(load("res://assets/fighters/andrews_%02d.png" % n))
	# Separate poses for genuine Balog animation; each PNG shares the same baseline.
	var approved_poses: Dictionary = {
		"idle": [0, 1, 2], "walk": [2, 3], "crouch": [0, 1],
		"jump": [0], "knife": [0, 1, 2], "shot": [1, 3],
		"block": [0, 1], "hurt": [0, 1], "victory": [0, 1]
	}
	for state in approved_poses.keys():
		sprites_b[state] = []
		for n in approved_poses[state]:
			sprites_b[state].append(load("res://assets/fighters/balog_animated/%s_%02d.png" % [state, n]))
	fighter_a = Fighter.new(0, "ANDREWS", 355.0)
	fighter_b = Fighter.new(1, "BALOG", 925.0)
	for sound_name in ["light", "heavy", "water", "shot", "special", "hit", "block", "ko"]:
		var player := AudioStreamPlayer.new()
		player.name = "Audio_" + sound_name
		player.stream = load("res://assets/audio/%s.wav" % sound_name)
		player.volume_db = -8.0 if sound_name != "shot" else -11.0
		add_child(player)
		audio_players[sound_name] = player
	for i in range(78):
		raindrops.append({"x": randf_range(0.0, WIDTH), "y": randf_range(160.0, HEIGHT), "v": randf_range(90.0, 245.0)})
	set_process(true)
	set_physics_process(true)

func _play_sound(name: String) -> void:
	if audio_players.has(name):
		var player: AudioStreamPlayer = audio_players[name]
		player.stop()
		player.play()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return
		match event.keycode:
			KEY_1:
				if phase == "menu": selected_mode = 0
			KEY_2:
				if phase == "menu": selected_mode = 1
			KEY_ENTER, KEY_KP_ENTER:
				if phase == "menu" or phase == "matchover": start_match(selected_mode)
			KEY_ESCAPE, KEY_P:
				if phase == "fight": phase = "paused"
				elif phase == "paused": phase = "fight"
			KEY_R:
				if phase != "menu": start_match(game_mode)
			KEY_F3:
				show_hitboxes = not show_hitboxes
	elif event is InputEventJoypadButton:
		if not event.pressed: return
		if event.button_index == JOY_BUTTON_START:
			if phase == "menu" or phase == "matchover": start_match(selected_mode)
			elif phase == "fight": phase = "paused"
			elif phase == "paused": phase = "fight"
		elif event.button_index == JOY_BUTTON_Y and phase == "menu":
			selected_mode = 1 - selected_mode
	queue_redraw()

func start_match(mode: int) -> void:
	game_mode = mode
	selected_mode = mode
	round_number = 1
	fighter_a.rounds = 0
	fighter_b.rounds = 0
	fighter_a.meter = 70.0
	fighter_b.meter = 70.0
	start_round()

func start_round() -> void:
	fighter_a.reset_for_round(352.0)
	fighter_b.reset_for_round(928.0)
	remaining = 99.0
	ending_clock = 0.0
	winner_message = ""
	projectiles.clear()
	effects.clear()
	ai_tactic = {}
	ai_think = 0.0
	phase = "fight"
	hp_visual_a = 100.0
	hp_visual_b = 100.0
	damage_trail_a = 100.0
	damage_trail_b = 100.0
	_play_sound("special")

func _physics_process(dt: float) -> void:
	global_clock += dt
	shake = maxf(0.0, shake - dt * 29.0)
	for p in raindrops:
		p["x"] = float(p["x"]) - dt * 48.0
		p["y"] = float(p["y"]) + float(p["v"]) * dt
		if float(p["y"]) > 715.0:
			p["y"] = 130.0
			p["x"] = randf_range(0.0, WIDTH)
	for idx in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[idx]
		effect["t"] = float(effect["t"]) - dt
		if float(effect["t"]) <= 0.0: effects.remove_at(idx)
	if phase == "roundover":
		ending_clock -= dt
		if ending_clock <= 0.0:
			if fighter_a.rounds >= 2 or fighter_b.rounds >= 2:
				phase = "matchover"
			else:
				round_number += 1
				start_round()
		return
	if phase != "fight": return
	remaining = maxf(0.0, remaining - dt)
	var pads: Array[int] = Input.get_connected_joypads()
	var pad_a: int = int(pads[0]) if pads.size() > 0 else -1
	var pad_b: int = int(pads[1]) if pads.size() > 1 else -1
	var input_a: Dictionary = read_controls(0, pad_a)
	var input_b: Dictionary = get_ai_input(dt) if game_mode == 0 else read_controls(1, pad_b)
	var action_a: String = fighter_a.advance(dt, input_a, fighter_b.x)
	var action_b: String = fighter_b.advance(dt, input_b, fighter_a.x)
	fighter_a.x = clampf(fighter_a.x, 58.0, 1222.0)
	fighter_b.x = clampf(fighter_b.x, 58.0, 1222.0)
	# Impede que os lutadores atravessem o mesmo ponto.
	if absf(fighter_a.x - fighter_b.x) < 80.0:
		var center: float = (fighter_a.x + fighter_b.x) * 0.5
		var dir: float = -1.0 if fighter_a.x <= fighter_b.x else 1.0
		fighter_a.x = clampf(center + 40.0 * dir, 55.0, 1225.0)
		fighter_b.x = clampf(center - 40.0 * dir, 55.0, 1225.0)
	if action_a != "": fire_attack(fighter_a, fighter_b, action_a)
	if action_b != "": fire_attack(fighter_b, fighter_a, action_b)
	update_projectiles(dt)
	if fighter_a.hp <= 0.0 or fighter_b.hp <= 0.0 or remaining <= 0.0:
		finish_round()

func read_controls(player: int, joy_id: int) -> Dictionary:
	var move: float = 0.0
	var jump: bool = false
	var crouch: bool = false
	var light: bool = false
	var heavy: bool = false
	var special: bool = false
	var block: bool = false
	if player == 0:
		move = float(int(Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_A)))
		jump = Input.is_key_pressed(KEY_W)
		crouch = Input.is_key_pressed(KEY_S)
		light = Input.is_key_pressed(KEY_F)
		heavy = Input.is_key_pressed(KEY_G)
		special = Input.is_key_pressed(KEY_H)
		block = Input.is_key_pressed(KEY_SHIFT)
	else:
		move = float(int(Input.is_key_pressed(KEY_RIGHT)) - int(Input.is_key_pressed(KEY_LEFT)))
		jump = Input.is_key_pressed(KEY_UP)
		crouch = Input.is_key_pressed(KEY_DOWN)
		light = Input.is_key_pressed(KEY_J)
		heavy = Input.is_key_pressed(KEY_K)
		special = Input.is_key_pressed(KEY_L)
		block = Input.is_key_pressed(KEY_I)
	if joy_id >= 0:
		var analog: float = Input.get_joy_axis(joy_id, JOY_AXIS_LEFT_X)
		if absf(analog) > 0.22: move = signf(analog)
		if Input.is_joy_button_pressed(joy_id, JOY_BUTTON_DPAD_LEFT): move = -1.0
		if Input.is_joy_button_pressed(joy_id, JOY_BUTTON_DPAD_RIGHT): move = 1.0
		jump = jump or Input.is_joy_button_pressed(joy_id, JOY_BUTTON_DPAD_UP) or Input.is_joy_button_pressed(joy_id, JOY_BUTTON_A)
		crouch = crouch or Input.is_joy_button_pressed(joy_id, JOY_BUTTON_DPAD_DOWN) or Input.get_joy_axis(joy_id, JOY_AXIS_LEFT_Y) > 0.68
		light = light or Input.is_joy_button_pressed(joy_id, JOY_BUTTON_X)
		heavy = heavy or Input.is_joy_button_pressed(joy_id, JOY_BUTTON_Y)
		special = special or Input.is_joy_button_pressed(joy_id, JOY_BUTTON_B)
		block = block or Input.is_joy_button_pressed(joy_id, JOY_BUTTON_RIGHT_SHOULDER)
	return {"move": move, "jump": jump, "crouch": crouch, "light": light, "heavy": heavy, "special": special, "block": block}

func get_ai_input(dt: float) -> Dictionary:
	ai_think -= dt
	if ai_think <= 0.0:
		ai_think = randf_range(0.17, 0.42)
		var distance: float = absf(fighter_a.x - fighter_b.x)
		var target_dir: float = 1.0 if fighter_a.x > fighter_b.x else -1.0
		ai_tactic = {"move": target_dir if distance > 150.0 else (0.0 if randf() > 0.32 else -target_dir), "jump": randf() < 0.04, "crouch": false, "light": false, "heavy": false, "special": false, "block": randf() < 0.09}
		if distance < 180.0 and randf() < 0.70:
			if randf() < 0.55: ai_tactic["light"] = true
			else: ai_tactic["heavy"] = true
		elif distance < 610.0 and randf() < 0.48:
			ai_tactic["heavy"] = true
		if fighter_b.meter > 60.0 and randf() < 0.21:
			ai_tactic["special"] = true
	# Alterna periodicamente as entradas para que ataques na IA tenham borda.
	return ai_tactic if not ai_tactic.is_empty() else {"move": 0.0}

func fire_attack(owner: Fighter, enemy: Fighter, attack: String) -> void:
	var is_andrews: bool = owner.side == 0
	if attack == "light":
		if is_andrews:
			spawn_projectile(owner, "water", 9.0, 620.0, 0.65, 28.0)
			_play_sound("water")
		else:
			_play_sound("light")
			spawn_fx("slash", Vector2(owner.x + owner.facing * 65.0, FLOOR - owner.altitude - 164.0), RED, 0.23)
			try_melee(owner, enemy, 12.0, 132.0, 18.0)
	elif attack == "heavy":
		if is_andrews:
			owner.x = clampf(owner.x + owner.facing * 65.0, 70.0, 1210.0)
			spawn_fx("burst", Vector2(owner.x + owner.facing * 68.0, FLOOR - owner.altitude - 160.0), BLUE, 0.34)
			try_melee(owner, enemy, 24.0, 179.0, 52.0)
			_play_sound("heavy")
		else:
			spawn_projectile(owner, "bullet", 20.0, 1050.0, 0.9, 12.0)
			_play_sound("shot")
	else:
		shake = 13.0
		if is_andrews:
			spawn_projectile(owner, "tsunami", 34.0, 440.0, 2.25, 78.0)
			spawn_fx("burst", Vector2(owner.x, FLOOR - owner.altitude - 145), BLUE, 0.92)
		else:
			spawn_projectile(owner, "chaos", 31.0, 520.0, 1.55, 65.0)
			spawn_fx("burst", Vector2(owner.x, FLOOR - owner.altitude - 140), RED, 0.92)
		_play_sound("special")
		owner.meter = maxf(0.0, owner.meter)

func try_melee(owner: Fighter, enemy: Fighter, amount: float, reach: float, knockback: float) -> void:
	var distance: float = enemy.x - owner.x
	if signf(distance) == float(owner.facing) and absf(distance) <= reach and absf(owner.altitude - enemy.altitude) < 125.0:
		deal_hit(owner, enemy, amount, knockback, "melee")
	else:
		spawn_fx("air", Vector2(owner.x + owner.facing * reach * 0.58, FLOOR - owner.altitude - 180.0), BLUE if owner.side == 0 else RED, 0.17)

func spawn_projectile(owner: Fighter, kind: String, dmg: float, speed: float, life: float, radius: float) -> void:
	projectiles.append({"x": owner.x + owner.facing * 90.0, "y": FLOOR - owner.altitude - 171.0, "vx": owner.facing * speed, "ttl": life, "max_ttl": life, "kind": kind, "dmg": dmg, "radius": radius, "owner": owner.side, "phase": randf() * 10.0})
	spawn_fx("burst", Vector2(owner.x + owner.facing * 83.0, FLOOR - 175), BLUE if owner.side == 0 else RED, 0.24)

func update_projectiles(dt: float) -> void:
	for i in range(projectiles.size()-1, -1, -1):
		var p: Dictionary = projectiles[i]
		p["x"] = float(p["x"]) + float(p["vx"]) * dt
		p["ttl"] = float(p["ttl"]) - dt
		p["phase"] = float(p["phase"]) + dt * 14.0
		var target: Fighter = fighter_b if int(p["owner"]) == 0 else fighter_a
		var owner: Fighter = fighter_a if int(p["owner"]) == 0 else fighter_b
		if absf(float(p["x"]) - target.x) < (float(p["radius"]) + 37.0) and absf(float(p["y"]) - (FLOOR - target.altitude - 165.0)) < (105.0 + float(p["radius"]) * 0.5) and target.hp > 0.0:
			deal_hit(owner, target, float(p["dmg"]), 35.0 if str(p["kind"]) != "bullet" else 42.0, str(p["kind"]))
			projectiles.remove_at(i)
		elif float(p["ttl"]) <= 0.0 or float(p["x"]) < -120.0 or float(p["x"]) > WIDTH + 120.0:
			projectiles.remove_at(i)

func deal_hit(owner: Fighter, target: Fighter, amount: float, force: float, kind: String) -> void:
	var guarded: bool = target.receive_hit(amount, force, owner.facing)
	owner.meter = minf(100.0, owner.meter + (5.0 if guarded else 12.0))
	spawn_fx("block" if guarded else "hit", Vector2(target.x, FLOOR - target.altitude - 174.0), BLUE if owner.side == 0 else RED, 0.30)
	shake = 3.0 if guarded else (9.5 if amount > 23.0 else 5.0)
	_play_sound("block" if guarded else "hit")

func spawn_fx(kind: String, pos: Vector2, tint: Color, duration: float) -> void:
	effects.append({"kind": kind, "pos": pos, "color": tint, "t": duration, "life": duration, "seed": randf() * 19.0})

func finish_round() -> void:
	phase = "roundover"
	ending_clock = 2.45
	var winner: Fighter
	if fighter_a.hp > fighter_b.hp: winner = fighter_a
	elif fighter_b.hp > fighter_a.hp: winner = fighter_b
	else:
		winner_message = "EMPATE!"
		_play_sound("ko")
		return
	winner.rounds += 1
	winner_message = "%s VENCEU!" % winner.fighter_name
	_play_sound("ko")

func _process(dt: float) -> void:
	# Smooth damage transition: delayed gold damage trail like a modern fighting game.
	hp_visual_a = move_toward(hp_visual_a, fighter_a.hp, dt * 72.0)
	hp_visual_b = move_toward(hp_visual_b, fighter_b.hp, dt * 72.0)
	damage_trail_a = move_toward(damage_trail_a, hp_visual_a, dt * 26.0)
	damage_trail_b = move_toward(damage_trail_b, hp_visual_b, dt * 26.0)
	queue_redraw()

func _draw() -> void:
	# The menu uses the approved illustration, while the playable scene is clean,
	# allowing characters and HUD to move independently without duplicated figures.
	if phase == "menu":
		draw_texture_rect(cinematic_menu, Rect2(0, 0, WIDTH, HEIGHT), false)
		draw_menu()
		return
	var offset: Vector2 = Vector2(randf_range(-shake, shake), randf_range(-shake * 0.25, shake * 0.25)) if shake > 0.0 else Vector2.ZERO
	draw_set_transform(offset)
	draw_texture_rect(backdrop, Rect2(0, 0, WIDTH, HEIGHT), false)
	# Scene atmosphere: distant rain and streetlamp bloom, behind fighters.
	for rain in raindrops:
		var px: float = float(rain["x"])
		var py: float = float(rain["y"])
		draw_line(Vector2(px, py), Vector2(px - 3.0, py + 14.0), Color(0.69, 0.86, 1.0, 0.20), 1.0)
	draw_shadow(fighter_a)
	draw_shadow(fighter_b)
	if fighter_a.x < fighter_b.x:
		draw_fighter(fighter_a)
		draw_fighter(fighter_b)
	else:
		draw_fighter(fighter_b)
		draw_fighter(fighter_a)
	for p in projectiles: draw_projectile(p)
	for fx in effects: draw_effect(fx)
	# Subtle blue/red ambient ground light under each actor.
	for f in [fighter_a, fighter_b]:
		var tint: Color = BLUE if f.side == 0 else RED
		for i in range(3):
			draw_arc(Vector2(f.x, FLOOR + 9.0), 28.0 + i * 19.0, 0.06, PI - 0.06, 24, Color(tint.r, tint.g, tint.b, 0.14 - i * 0.037), 2.0, true)
	if show_hitboxes:
		for f in [fighter_a, fighter_b]:
			draw_rect(Rect2(f.x - 35, FLOOR - f.altitude - 300, 70, 280), Color(1,0.4,0.3,0.5), false, 2.0)
	draw_set_transform(Vector2.ZERO)
	draw_hud()
	if phase == "paused": draw_overlay("PAUSADO", "P / ESC / START PARA CONTINUAR")
	elif phase == "roundover": draw_overlay(winner_message, "ROUND %d FINALIZADO" % round_number)
	elif phase == "matchover": draw_overlay(winner_message, "FIM DA PARTIDA  -  ENTER / START = REVANCHE")

func draw_shadow(f: Fighter) -> void:
	var shadow_width: float = 72.0 + f.altitude * 0.13
	draw_set_transform(Vector2(f.x, FLOOR + 2.0), 0.0, Vector2(1.9, 0.19))
	draw_circle(Vector2.ZERO, shadow_width, Color(0.0, 0.0, 0.02, 0.37))
	draw_set_transform(Vector2.ZERO)

func _balog_pose(f: Fighter) -> Texture2D:
	var state: String = "idle"
	var clock: float = f.idle_clock
	var fps: float = 6.0
	if f.hp <= 0.0 or f.hitstun > 0.0:
		state = "hurt"
		clock = f.idle_clock
		fps = 9.0
	elif f.action == "light":
		state = "knife"
		clock = f.action_clock
		fps = 12.0
	elif f.action == "heavy":
		state = "shot"
		clock = f.action_clock
		fps = 8.5
	elif f.action == "special":
		state = "victory"
		clock = f.action_clock
		fps = 5.0
	elif f.altitude > 0.0:
		state = "jump"
		clock = f.idle_clock
	elif f.is_blocking:
		state = "block"
		clock = f.idle_clock
	elif f.is_crouching:
		state = "crouch"
		clock = f.idle_clock
	elif f.is_moving:
		state = "walk"
		clock = f.idle_clock
		fps = 10.0
	var frames: Array = sprites_b[state]
	# Frame selection loops on idle/walk, but holds the last frame on a strike.
	var idx: int = int(clock * fps) % frames.size()
	if f.action != "" and state in ["knife", "shot", "victory"]:
		idx = mini(int(clock * fps), frames.size()-1)
	return frames[idx]

func draw_fighter(f: Fighter) -> void:
	var texture: Texture2D
	var width: float
	var height: float = 326.0
	if f.side == 0:
		var index: int = 0
		if f.hitstun > 0.0: index = 5
		elif f.action == "light": index = 2
		elif f.action == "heavy" or f.action == "special": index = 4
		elif f.is_blocking or f.is_crouching: index = 3
		elif f.is_moving: index = 1
		texture = sprites_a[index]
		width = height * float(texture.get_width()) / float(texture.get_height())
	else:
		texture = _balog_pose(f)
		width = height * float(texture.get_width()) / float(texture.get_height())
	# Balog's crouching and jumping frames contain the actual body posture;
	# do not vertically squash those pose textures.
	if f.side == 0 and f.is_crouching: height *= 0.80
	var breathing: float = sin(f.idle_clock * 4.0 + f.side) * 2.2 if f.action == "" and f.altitude <= 0.0 else 0.0
	var impact_push: float = 8.0 * sin(f.action_clock * 8.0) if f.action == "heavy" else 0.0
	var flip: float = 1.0 if f.facing == 1 else -1.0
	var tint: Color = Color(1.0, 0.68, 0.75, 1.0) if f.flash > 0.0 else Color.WHITE
	draw_set_transform(Vector2(f.x + f.facing * impact_push, FLOOR - f.altitude + breathing), 0.0, Vector2(flip, 1.0))
	draw_texture_rect(texture, Rect2(-width * 0.5, -height, width, height), false, tint)
	draw_set_transform(Vector2.ZERO)
	if f.is_blocking:
		var color: Color = BLUE if f.side == 0 else RED
		draw_arc(Vector2(f.x + f.facing * 51.0, FLOOR - f.altitude - 161.0), 87.0, -1.2, 1.2, 25, Color(color.r, color.g, color.b, 0.72), 5.0, true)

func draw_projectile(p: Dictionary) -> void:
	var center := Vector2(float(p["x"]), float(p["y"]))
	var radius: float = float(p["radius"])
	var phase_time: float = float(p["phase"])
	var kind: String = str(p["kind"])
	var tint: Color = BLUE if int(p["owner"]) == 0 else RED
	if kind == "bullet":
		draw_line(center - Vector2(signf(float(p["vx"])) * 75.0, 0), center, Color(1.0,0.34,0.19,0.40), 10.0, true)
		draw_circle(center, 12.0, Color("fff3c0"))
		draw_circle(center, 7.0, Color("ffc14c"))
	else:
		draw_circle(center, radius * 1.48, Color(tint.r, tint.g, tint.b, 0.12))
		draw_circle(center, radius * 0.91, Color(tint.r, tint.g, tint.b, 0.33))
		draw_circle(center, radius * 0.5, Color(0.82, 0.98, 1.0, 0.65) if int(p["owner"]) == 0 else Color(1.0,0.51,0.65,0.70))
		for j in range(9):
			var theta: float = phase_time + float(j) * TAU / 9.0
			var point := center + Vector2(cos(theta), sin(theta)) * radius * (1.0 + 0.3 * sin(phase_time))
			draw_circle(point, 4.0 if kind == "water" else 6.0, Color(tint.r, tint.g, tint.b, 0.77))
		if kind == "tsunami" or kind == "chaos":
			for n in range(3):
				draw_arc(center, radius + 13.0 * n, phase_time * 0.18 + n, phase_time * 0.18 + n + 3.1, 26, Color(tint.r,tint.g,tint.b,0.66), 5.0, true)

func draw_effect(fx: Dictionary) -> void:
	var t: float = float(fx["t"])
	var life: float = float(fx["life"])
	var progress: float = 1.0 - t / life
	var center: Vector2 = fx["pos"]
	var tint: Color = fx["color"]
	var alpha: float = maxf(0.0, 1.0 - progress)
	var r: float = 17.0 + 88.0 * progress
	draw_circle(center, r * 0.36, Color(tint.r, tint.g, tint.b, 0.12 * alpha))
	if str(fx["kind"]) == "slash":
		draw_arc(center, 78.0, -1.65 + progress, 1.1 + progress, 35, Color(1.0,0.36,0.46,alpha), 12.0 * alpha, true)
	else:
		draw_arc(center, r, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, 0.78 * alpha), 3.0 + (1.0 - progress)*3.0, true)
		for j in range(8):
			var theta: float = float(j) * TAU/8.0 + float(fx["seed"])
			var dir: Vector2 = Vector2(cos(theta), sin(theta))
			draw_line(center + dir*r*0.5, center+dir*r*1.55, Color(tint.r,tint.g,tint.b,alpha*0.7), 2.0 + 3.0 * alpha, true)

func draw_label(text: String, at: Vector2, size: int, tint: Color = Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var pos: Vector2 = at
	if align != HORIZONTAL_ALIGNMENT_LEFT:
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if align == HORIZONTAL_ALIGNMENT_CENTER: pos.x -= w * 0.5
		elif align == HORIZONTAL_ALIGNMENT_RIGHT: pos.x -= w
	draw_string(font, pos + Vector2(2,2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0,0,0,0.55))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, tint)

func draw_health_degradation(left: bool, hp: float, trail: float) -> void:
	# The hand-painted approved bar supplies the metallic bevel and portraits.
	# Cover the missing life using a dark glass recess; flash a slower gold trail.
	var x: float = 179.0 if left else 772.0
	var w: float = 323.0 if left else 324.0
	var y: float = 55.0
	var fraction: float = clampf(hp / 100.0, 0.0, 1.0)
	var missing: float = (1.0 - fraction) * w
	if missing > 0.0:
		var mask_x: float = x + w - missing if left else x
		draw_rect(Rect2(mask_x, y, missing, 23.0), Color(0.055, 0.07, 0.10, 0.97))
		draw_rect(Rect2(mask_x, y+18, missing, 3), Color(0.11,0.15,0.22,1.0))
	var lag: float = maxf(0.0, (trail - hp) / 100.0 * w)
	if lag > 1.0:
		var lag_x: float = x + w * fraction if left else x + w * (1.0 - trail / 100.0)
		draw_rect(Rect2(lag_x, y+2, lag, 17), Color(1.0,0.67,0.22,0.72))
	# Notches remain visible at each quarter.
	for i in range(1,4):
		var nx: float = x + float(i) * (w/4.0)
		draw_line(Vector2(nx,y+2), Vector2(nx-2,y+21), Color(0,0,0,0.35), 2.0)

func draw_super_degradation(left: bool, power: float) -> void:
	var x: float = 77.0 if left else 752.0
	var w: float = 413.0 if left else 430.0
	var fraction: float = clampf(power / 100.0, 0.0, 1.0)
	# Meter sections drain from outer edge toward the middle.
	var hidden: float = (1.0 - fraction) * w
	if hidden > 0.0:
		var px: float = x + w - hidden if left else x
		draw_rect(Rect2(px, 633.0, hidden, 37.0), Color(0.035,0.05,0.09,0.93))

func draw_timer_plate() -> void:
	# The original painting contains a static 99: replace only its clock portion.
	draw_rect(Rect2(546, 20, 190, 100), Color(0.025, 0.03, 0.06, 0.99))
	draw_rect(Rect2(551, 25, 180, 92), Color(0.37,0.40,0.45,0.95), false, 4.0)
	draw_rect(Rect2(556, 29, 170, 84), Color(0.07,0.08,0.12,1.0))
	draw_line(Vector2(555,29),Vector2(725,29),Color(0.88,0.91,0.98,0.83),3.0)
	draw_line(Vector2(556,113),Vector2(725,113),Color(0.27,0.32,0.40,1),3.0)
	var val: int = clampi(int(ceil(remaining)), 0, 99)
	var atlas_x: int = (val % 10) * 132
	var atlas_y: int = int(val / 10) * 110
	draw_texture_rect_region(timer_digits, Rect2(583, 30, 114, 84), Rect2(atlas_x, atlas_y, 132, 110))
	draw_label("ROUND %d" % round_number, Vector2(640,137),17, Color("e6edf9"), HORIZONTAL_ALIGNMENT_CENTER)

func draw_hud() -> void:
	# Approved visual assets kept separately from dynamic gameplay elements.
	draw_texture_rect(hud_top, Rect2(0, 0, WIDTH, 194.0), false)
	draw_health_degradation(true, hp_visual_a, damage_trail_a)
	draw_health_degradation(false, hp_visual_b, damage_trail_b)
	# Round markers placed near the center, above fighters.
	for k in range(2):
		var c1: Color = BLUE if k < fighter_a.rounds else Color(0.02,0.02,0.04,0.90)
		var c2: Color = RED if k < fighter_b.rounds else Color(0.02,0.02,0.04,0.90)
		draw_circle(Vector2(518.0+k*18,153),7.0,c1)
		draw_circle(Vector2(762.0-k*18,153),7.0,c2)
	draw_timer_plate()
	draw_texture_rect(hud_bottom, Rect2(0, 550, WIDTH, 170), false)
	draw_super_degradation(true, fighter_a.meter)
	draw_super_degradation(false, fighter_b.meter)
	# Small, non-intrusive controller hint.
	if phase != "fight":
		draw_label("F / G / H  •  X / Y / B  •  RB DEFESA", Vector2(640,718),12,Color(0.85,0.88,0.95,0.8),HORIZONTAL_ALIGNMENT_CENTER)

func draw_overlay(heading: String, detail: String) -> void:
	draw_rect(Rect2(0,0,WIDTH,HEIGHT),Color(0.015,0.03,0.08,0.65))
	draw_rect(Rect2(225,280,830,176),Color(0.018,0.04,0.085,0.96))
	draw_rect(Rect2(225,280,830,176),BLUE,false,3.0)
	draw_label(heading, Vector2(640,361),50,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	draw_label(detail,Vector2(640,410),19,Color("c6d9e8"),HORIZONTAL_ALIGNMENT_CENTER)

func draw_menu() -> void:
	# Preview-quality splash background, with playable modes on one readable panel.
	draw_rect(Rect2(0,0,WIDTH,HEIGHT), Color(0.0,0.015,0.04,0.44))
	draw_rect(Rect2(245,205,790,335),Color(0.018,0.022,0.055,0.91))
	draw_rect(Rect2(245,205,790,335),Color("4ac5ff"),false,2.0)
	draw_rect(Rect2(248,208,784,6),Color("ef304f"))
	draw_label("ANDREWS  VS  BALOG", Vector2(640,283),48,Color("f3f7ff"),HORIZONTAL_ALIGNMENT_CENTER)
	draw_label("NEON FIGHT  -  ALPHA 0.2",Vector2(640,316),17,Color("ffd46d"),HORIZONTAL_ALIGNMENT_CENTER)
	var cpu_color: Color = BLUE if selected_mode == 0 else Color("91a6b6")
	var pvp_color: Color = RED if selected_mode == 1 else Color("91a6b6")
	draw_label("1  -  CONTRA O COMPUTADOR",Vector2(640,378),24,cpu_color,HORIZONTAL_ALIGNMENT_CENTER)
	draw_label("2  -  DOIS JOGADORES",Vector2(640,419),24,pvp_color,HORIZONTAL_ALIGNMENT_CENTER)
	draw_label("ENTER / START PARA LUTAR",Vector2(640,474),26,Color("ffe5a5"),HORIZONTAL_ALIGNMENT_CENTER)
	draw_label("A/D, W, F G H  |  SETAS, J K L  |  CONTROLE: X Y B",Vector2(640,510),13,Color("b3cedb"),HORIZONTAL_ALIGNMENT_CENTER)
