extends RefCounted
## Estado independente de um lutador. Nao depende do desenho nem do teclado.

const WALK_SPEED: float = 275.0
const JUMP_SPEED: float = 680.0
const GRAVITY: float = 1820.0

var side: int = 0
var fighter_name: String = ""
var x: float = 0.0
var altitude: float = 0.0
var vertical_speed: float = 0.0
var facing: int = 1
var hp: float = 100.0
var meter: float = 70.0
var rounds: int = 0
var is_blocking: bool = false
var is_crouching: bool = false
var is_moving: bool = false
var hitstun: float = 0.0
var flash: float = 0.0
var action: String = ""
var action_clock: float = 0.0
var action_duration: float = 0.0
var attack_fired: bool = false
var prev_light: bool = false
var prev_heavy: bool = false
var prev_special: bool = false
var prev_jump: bool = false
var idle_clock: float = 0.0

func _init(new_side: int, new_name: String, start_x: float) -> void:
	side = new_side
	fighter_name = new_name
	x = start_x

func reset_for_round(start_x: float) -> void:
	x = start_x
	altitude = 0.0
	vertical_speed = 0.0
	hp = 100.0
	meter = maxf(meter, 45.0)
	facing = 1 if side == 0 else -1
	is_blocking = false
	is_crouching = false
	is_moving = false
	hitstun = 0.0
	flash = 0.0
	action = ""
	action_clock = 0.0
	attack_fired = false
	prev_light = false
	prev_heavy = false
	prev_special = false
	prev_jump = false

func start_attack(which: String) -> void:
	action = which
	action_clock = 0.0
	attack_fired = false
	match which:
		"light": action_duration = 0.35
		"heavy": action_duration = 0.62
		"special": action_duration = 1.0
		_: action_duration = 0.3
	if which == "special":
		meter -= 60.0
	elif which == "heavy":
		meter = minf(100.0, meter + 3.0)
	else:
		meter = minf(100.0, meter + 2.0)

## Retorna o ataque no exato quadro de impacto; "" caso contrario.
func advance(dt: float, controls: Dictionary, enemy_x: float) -> String:
	idle_clock += dt
	flash = maxf(0.0, flash - dt)
	meter = minf(100.0, meter + dt * 2.4)
	facing = 1 if x <= enemy_x else -1
	if altitude > 0.0 or vertical_speed > 0.0:
		altitude += vertical_speed * dt
		vertical_speed -= GRAVITY * dt
		if altitude <= 0.0:
			altitude = 0.0
			vertical_speed = 0.0
	else:
		altitude = 0.0

	var light_now: bool = bool(controls.get("light", false))
	var heavy_now: bool = bool(controls.get("heavy", false))
	var special_now: bool = bool(controls.get("special", false))
	var jump_now: bool = bool(controls.get("jump", false))
	var new_light: bool = light_now and not prev_light
	var new_heavy: bool = heavy_now and not prev_heavy
	var new_special: bool = special_now and not prev_special
	var new_jump: bool = jump_now and not prev_jump
	prev_light = light_now
	prev_heavy = heavy_now
	prev_special = special_now
	prev_jump = jump_now

	is_blocking = false
	is_crouching = false
	is_moving = false
	if hp <= 0.0:
		return ""
	if hitstun > 0.0:
		hitstun = maxf(0.0, hitstun - dt)
		return ""
	if action != "":
		action_clock += dt
		var startup: float = 0.1
		if action == "heavy": startup = 0.20
		if action == "special": startup = 0.26
		var fired_action: String = ""
		if not attack_fired and action_clock >= startup:
			attack_fired = true
			fired_action = action
		if action_clock >= action_duration:
			action = ""
		return fired_action

	is_blocking = bool(controls.get("block", false)) and altitude == 0.0
	is_crouching = bool(controls.get("crouch", false)) and altitude == 0.0
	if not is_blocking and not is_crouching:
		var dir: float = float(controls.get("move", 0.0))
		if absf(dir) > 0.1:
			x += dir * WALK_SPEED * dt
			is_moving = true
		if new_jump and altitude <= 0.0:
			vertical_speed = JUMP_SPEED
			altitude = 1.0
	if not is_blocking:
		if new_special and meter >= 60.0:
			start_attack("special")
		elif new_heavy:
			start_attack("heavy")
		elif new_light:
			start_attack("light")
	return ""

## Retorna true quando o ataque foi defendido.
func receive_hit(damage: float, knockback: float, attack_direction: int) -> bool:
	var guarded: bool = is_blocking and altitude == 0.0
	if guarded:
		hp = maxf(0.0, hp - damage * 0.14)
		hitstun = 0.12
		x += attack_direction * knockback * 0.22
		meter = minf(100.0, meter + 6.0)
	else:
		hp = maxf(0.0, hp - damage)
		hitstun = 0.23 if damage < 21.0 else 0.38
		x += attack_direction * knockback
		meter = minf(100.0, meter + 8.0)
		action = ""
	flash = 0.12
	return guarded
