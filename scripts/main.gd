extends Node3D
## Соль и Железо — главный контроллер игры.
## Связывает Дом, Игрока, Призрака и HUD. Собирает сцену из скриптов,
## ведёт сюжет: реликвии → подвал → останки → Победа.

const HouseScript := preload("res://scripts/house.gd")
const PlayerScript := preload("res://scripts/player.gd")
const GhostScript := preload("res://scripts/ghost.gd")
const HudScript := preload("res://scripts/hud.gd")

const ST_LOADING := 0
const ST_TITLE := 1
const ST_CARDS := 2
const ST_PLAY := 3
const ST_DEAD := 4
const ST_WIN := 5

const INTERACT_DIST := 2.4
const BURN_TIME := 6.0

var state := ST_LOADING
var house
var player
var ghost
var hud
var moon: DirectionalLight3D

var _cards: Array[String] = [
	"Дом Холлисов. Нейт Колдер приехал расследовать исчезновение семьи. В кармане — железная кочерга, в рюкзаке — соль. Эдит Холлис не умерла. Она ждёт.",
	"Найдите три реликвии: медальон, фотографию и музыкальную шкатулку. Каждая делает Эдит злее. Соль и железо — единственная защита.",
	"Когда реликвии будут у вас, подвал откроется. Сожгите останки Эдит в подвале — и дом отпустит вас. Не дайте ей коснуться вас.",
]
var _card_idx := 0
var _health := 100.0
var _salt := 0
var _relics := 0
var _burn := 0.0
var _subtitle_t := 0.0
var _lightning := 0.0
var _lightning_t := 6.0
var _flicker := 0.0
var _interact_held := false
var _nearest: Dictionary = {}
var _dead_t := 0.0
var _win_t := 0.0


func _ready() -> void:
	_make_environment()
	_make_moon()

	house = HouseScript.new()
	add_child(house)
	house.build()

	player = PlayerScript.new()
	add_child(player)
	player.global_position = house.start_pos
	player.set_look(0.0, 0.0)
	player.enabled = false

	ghost = GhostScript.new()
	add_child(ghost)
	ghost.target = player
	ghost.bounds_main = house.bounds_main
	ghost.bounds_cellar = house.bounds_cellar
	ghost.manifested.connect(_on_ghost_manifested)
	ghost.hit_player.connect(_on_ghost_hit_player)
	ghost.stunned.connect(_on_ghost_stunned)

	hud = HudScript.new()
	add_child(hud)
	hud.action_down.connect(_on_action_down)
	hud.action_up.connect(_on_action_up)
	hud.mode = "title"
	hud.health = _health
	hud.salt = _salt
	hud.relics = _relics
	hud.objective = "Найдите реликвии: 0/3"
	hud.loading = 1.0

	state = ST_TITLE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _make_environment() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.015, 0.02, 0.035)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.22, 0.26, 0.36)
	e.ambient_light_energy = 0.55
	e.fog_enabled = true
	e.fog_light_color = Color(0.05, 0.06, 0.09)
	e.fog_light_energy = 0.6
	e.fog_sun_scatter = 0.1
	e.fog_density = 0.018
	e.fog_sky_affect = 0.3
	e.fog_height = 2.0
	e.fog_height_density = 0.01
	we.environment = e
	add_child(we)


func _make_moon() -> void:
	moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	add_child(moon)


# ------------------------------------------------------------------ ввод

func _input(event: InputEvent) -> void:
	if state == ST_PLAY:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var mm: InputEventMouseMotion = event
			player.apply_look(mm.relative * 0.0025)
		elif event is InputEventKey:
			var k: InputEventKey = event
			if k.keycode == KEY_E:
				_interact_held = k.pressed
				if k.pressed:
					_try_interact_press()
			elif k.keycode == KEY_F and k.pressed and not k.echo:
				player.toggle_flash()
			elif k.keycode == KEY_Q and k.pressed and not k.echo:
				_do_poker()
			elif k.keycode == KEY_R and k.pressed and not k.echo:
				_do_salt()
			elif k.keycode == KEY_ESCAPE and k.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	# вне игры — касание / клик / пробел листает экраны
	var advance := false
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			advance = true
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			advance = true
	elif event is InputEventKey:
		var k2: InputEventKey = event
		if k2.pressed and not k2.echo and (k2.keycode == KEY_SPACE or k2.keycode == KEY_ENTER):
			advance = true
	if not advance:
		return

	match state:
		ST_TITLE:
			_card_idx = 0
			hud.mode = "cards"
			hud.card_text = _cards[0]
			hud.card_opaque = false
			state = ST_CARDS
		ST_CARDS:
			_card_idx += 1
			if _card_idx >= _cards.size():
				_start_play()
			else:
				hud.card_text = _cards[_card_idx]
				hud.card_opaque = _card_idx == _cards.size() - 1
		ST_DEAD:
			if _dead_t > 1.0:
				_respawn()
		ST_WIN:
			if _win_t > 1.0:
				get_tree().reload_current_scene()


func _on_action_down(action_name: String) -> void:
	if state != ST_PLAY:
		return
	match action_name:
		"interact":
			_interact_held = true
			_try_interact_press()
		"poker":
			_do_poker()
		"salt":
			_do_salt()
		"flash":
			player.toggle_flash()


func _on_action_up(action_name: String) -> void:
	if action_name == "interact":
		_interact_held = false


# ------------------------------------------------------------------ действия

func _try_interact_press() -> void:
	if state != ST_PLAY or _nearest.is_empty():
		return
	var kind := str(_nearest.get("kind", ""))
	if kind == "relic":
		var display := str(_nearest.get("name", "Реликвия"))
		house.take_item(_nearest)
		_relics += 1
		hud.relics = _relics
		ghost.aggression = _relics
		ghost.provoke(4.0)
		if _relics >= 3:
			ghost.enraged = true
			house.unlock_cellar()
			hud.objective = "Сожгите останки в подвале"
			_show_subtitle("Подвал открыт! Спускайтесь к останкам. Эдит в ярости!")
		else:
			hud.objective = "Найдите реликвии: %d/3" % _relics
			_show_subtitle("Реликвия найдена: %s (%d/3). Эдит злится…" % [display, _relics])
	elif kind == "salt":
		house.take_item(_nearest)
		_salt += 1
		hud.salt = _salt
		_show_subtitle("Соль взята (+1). Бросьте её в Эдит кнопкой СОЛЬ.")
	elif kind == "remains":
		if _relics < 3:
			_show_subtitle("Нужны все 3 реликвии, чтобы открыть подвал.")
		else:
			_show_subtitle("Удерживайте ДЕЙСТВИЕ, чтобы сжечь останки.")


func _do_poker() -> void:
	if state != ST_PLAY:
		return
	player.swing()
	if ghost.state == 2:  # ST_MANIFEST
		var d := player.global_position.distance_to(ghost.global_position)
		if d < 2.8:
			ghost.stun(3.0, player.global_position)
			_show_subtitle("Кочерга отогнала Эдит!")


func _do_salt() -> void:
	if state != ST_PLAY:
		return
	if _salt <= 0:
		_show_subtitle("Нет соли! Ищите банки в доме.")
		return
	if ghost.state == 2:  # ST_MANIFEST
		var d := player.global_position.distance_to(ghost.global_position)
		if d < 9.0:
			_salt -= 1
			hud.salt = _salt
			ghost.stun(4.0, player.global_position)
			_show_subtitle("Соль обожгла Эдит!")
			return
	_show_subtitle("Эдит не рядом — берегите соль.")


func _show_subtitle(text: String, duration: float = 4.0) -> void:
	hud.subtitle = text
	_subtitle_t = duration


# ------------------------------------------------------------------ призрак

func _on_ghost_manifested() -> void:
	if state != ST_PLAY:
		return
	player.shake = 0.6
	_show_subtitle("Эдит проявилась! Соль и железо — защищайтесь!")


func _on_ghost_hit_player() -> void:
	if state != ST_PLAY:
		return
	_health = maxf(0.0, _health - 18.0)
	hud.health = _health
	hud.hurt = 1.0
	player.shake = 1.0
	if _health <= 0.0:
		_die()


func _on_ghost_stunned() -> void:
	if state != ST_PLAY:
		return
	_show_subtitle("Эдит оглушена!")


# ------------------------------------------------------------------ состояния

func _start_play() -> void:
	state = ST_PLAY
	hud.mode = "play"
	hud.objective = "Найдите реликвии: 0/3"
	player.enabled = true
	ghost.start(12.0)
	_show_subtitle("Дом Холлисов. Найдите три реликвии.")
	if not OS.has_feature("mobile") and not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _die() -> void:
	state = ST_DEAD
	_dead_t = 0.0
	player.enabled = false
	ghost.dissolve()
	hud.mode = "dead"
	hud.prompt = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _respawn() -> void:
	_health = 100.0
	hud.health = _health
	hud.hurt = 0.0
	hud.fade = 0.0
	player.global_position = house.start_pos
	player.velocity = Vector3.ZERO
	player.set_look(0.0, 0.0)
	player.enabled = true
	ghost.dissolve()
	ghost.start(10.0)
	hud.mode = "play"
	state = ST_PLAY
	_show_subtitle("Вы поднялись. Эдит ещё рядом…")
	if not OS.has_feature("mobile") and not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _win() -> void:
	state = ST_WIN
	_win_t = 0.0
	player.enabled = false
	ghost.dissolve()
	hud.mode = "winning"
	hud.objective = "Победа!"
	hud.prompt = ""
	hud.whiteout = 0.7
	hud.subtitle = "Останки сожжены. Дом Холлисов молчит. Вы уходите в ночь."
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ------------------------------------------------------------------ кадр

func _process(delta: float) -> void:
	# атмосфера: молнии и мерцание
	_lightning_t -= delta
	if _lightning_t <= 0.0:
		_lightning = 1.0
		_lightning_t = randf_range(6.0, 14.0)
	_lightning = maxf(0.0, _lightning - delta * 3.5)
	var ghost_dist := 999.0
	if ghost != null and ghost.state != 0:  # ST_DORMANT
		ghost_dist = player.global_position.distance_to(ghost.global_position)
	if ghost.state == 2:  # ST_MANIFEST
		_flicker = 0.45
	elif ghost.state == 1:  # ST_FADED
		_flicker = 0.12
	else:
		_flicker = 0.05
	moon.light_energy = 0.35 + _lightning * 2.6
	house.update_lamps(delta, _flicker, _lightning)

	if _subtitle_t > 0.0:
		_subtitle_t -= delta
		if _subtitle_t <= 0.0 and state == ST_PLAY:
			hud.subtitle = ""

	if state == ST_DEAD:
		_dead_t += delta
		return
	if state == ST_WIN:
		_win_t += delta
		return
	if state != ST_PLAY:
		return

	# движение: джойстик + клавиатура
	var kb := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		kb.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		kb.y -= 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		kb.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		kb.x += 1.0
	if kb.length() > 1.0:
		kb = kb.normalized()
	if kb != Vector2.ZERO:
		player.move_input = kb
	else:
		player.move_input = hud.move_vec
	if hud.look_accum != Vector2.ZERO:
		player.apply_look(hud.look_accum * 0.004)
		hud.look_accum = Vector2.ZERO

	# ближайший предмет
	_nearest = {}
	var best := 1e9
	for it in house.interactables:
		if it.get("taken", false):
			continue
		var p: Vector3 = it.get("pos", Vector3.ZERO)
		var d := player.global_position.distance_to(p)
		if d < INTERACT_DIST and d < best:
			best = d
			_nearest = it
	if _nearest.is_empty():
		hud.prompt = ""
	else:
		var kind := str(_nearest.get("kind", ""))
		if kind == "relic":
			hud.prompt = "Взять: %s" % str(_nearest.get("name", "Реликвия"))
		elif kind == "salt":
			hud.prompt = "Взять соль"
		elif kind == "remains":
			if _relics < 3:
				hud.prompt = "Останки Эдит. Нужны 3 реликвии."
			else:
				hud.prompt = "Удерживайте ДЕЙСТВИЕ, чтобы сжечь останки"

	# сжигание останков
	if not _nearest.is_empty() and str(_nearest.get("kind", "")) == "remains" and _relics >= 3:
		if _interact_held:
			_burn += delta / BURN_TIME
			hud.burn = clampf(_burn, 0.0, 1.0)
			if _burn >= 1.0:
				_win()
				return
	else:
		hud.burn = clampf(_burn, 0.0, 1.0)

	# EMF и фонарь
	if ghost.state == 0:  # ST_DORMANT
		hud.emf = 0.0
		player.flash_flicker = 0.0
	else:
		hud.emf = clampf(1.0 - ghost_dist / 18.0, 0.0, 1.0)
		if ghost.state == 2:  # ST_MANIFEST
			player.flash_flicker = clampf(1.0 - ghost_dist / 12.0, 0.0, 1.0)
		else:
			player.flash_flicker = 0.0
