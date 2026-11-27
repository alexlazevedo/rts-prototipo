extends Node3D
## Protótipo jogável: liga simulação, bot, tela, HUD e toque.
## Simulação a 10 ticks/s; a tela interpola entre ticks.
## Toque no mundo:
##   toque no chão = mover atacando · segurar no chão = só mover (recuar)
##   toque em inimigo = atacar · toque em prédio seu = painel de produção
##   arrastar = câmera · pinça = zoom
## Toque na barra de 10: 1 toque = unidade · arrastar = grupo · 2 toques = todas · segurar = ir até ela

const STEP := 1.0 / Defs.TICK_HZ
const HUMAN := 0
const TAP_MOVE := 16.0
const LONG_PRESS := 0.45
const DOUBLE_TAP := 0.32

var world: SimWorld
var bots: Array[SimBot] = []
var view: GameView
var hud: GameHUD
var cam_rig: Node3D
var state := "menu"                 # menu, playing, over
var watch_mode := false
var difficulty := "normal"
var speed := 1.0
var _acc := 0.0

var selected: Dictionary = {}       # ids das unidades selecionadas
var placing := ""
var ghost_pos := Vector3.ZERO

# gesto em andamento
var _touches: Dictionary = {}       # index -> Vector2
var _g_kind := ""                   # "", world, slots, map, ghost, pinch
var _g_start := Vector2.ZERO
var _g_time := 0.0
var _g_moved := false
var _g_slots: Array[int] = []
var _pinch_d0 := 0.0
var _pinch_dist0 := 0.0
var _last_slot_tap := -10.0
var _clock := 0.0


func _ready() -> void:
	_setup_world()
	view = GameView.new()
	add_child(view)
	cam_rig = Node3D.new()
	cam_rig.set_script(preload("res://scripts/rts_camera.gd"))
	cam_rig.set("handle_input", false)
	cam_rig.set("distance", 70.0)
	cam_rig.set("bounds", Rect2(-110, -70, 220, 140))
	add_child(cam_rig)
	cam_rig.position = Vector3(-60, 0, 0)
	hud = GameHUD.new()
	hud.game = self
	add_child(hud)
	hud.start_pressed.connect(_on_start)
	hud.restart_pressed.connect(_on_restart)
	hud.build_pressed.connect(_on_build_pressed)
	hud.place_confirmed.connect(_on_place_confirm)
	hud.place_cancelled.connect(_on_place_cancel)
	hud.train_pressed.connect(_on_train)
	world = SimWorld.new(1)             # mundo de fundo enquanto o menu está aberto
	view.selected = selected
	hud.show_menu(true)
	if "--quickshot" in OS.get_cmdline_user_args():
		var q := Node.new()
		q.set_script(load("res://tests/quick_shot.gd"))
		add_child(q)
	if "--autotest" in OS.get_cmdline_user_args():
		var t := Node.new()
		t.set_script(load("res://tests/autotest_input.gd"))
		add_child(t)


func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b89566")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e1e6ee")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffeccc")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	sun.transform = Transform3D(Basis(), Vector3(-40, 70, -30)).looking_at(Vector3.ZERO, Vector3.UP)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(Defs.HALF_W * 2 / 100.0, Defs.HALF_H * 2 / 100.0)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("c4a06a")
	gm.roughness = 0.97
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.86, 0.84, 0.8))
	ramp.set_color(1, Color(1.0, 1.0, 1.0))
	tex.color_ramp = ramp
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	gm.detail_enabled = true
	gm.detail_albedo = tex
	gm.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	gm.uv2_triplanar = true
	gm.uv2_scale = Vector3(0.05, 0.05, 0.05)
	gm.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	ground.material_override = gm
	add_child(ground)
	# moldura de platôs em volta do mapa (só cenário)
	var plato: PackedScene = load("res://assets/models/terreno_plato.glb")
	var hw := Defs.HALF_W / 100.0
	var hh := Defs.HALF_H / 100.0
	var x := -hw - 8.0
	while x <= hw + 8.0:
		for z in [-hh - 8.0, hh + 8.0]:
			var n: Node3D = plato.instantiate()
			n.position = Vector3(x, 0, z)
			add_child(n)
		x += 16.0
	var z2 := -hh + 8.0
	while z2 <= hh - 8.0:
		for xx in [-hw - 8.0, hw + 8.0]:
			var n: Node3D = plato.instantiate()
			n.position = Vector3(xx, 0, z2)
			add_child(n)
		z2 += 16.0


# ------------------------------------------------------------------ partida
func _on_start(diff: String, watch: bool) -> void:
	difficulty = diff
	watch_mode = watch
	_new_match()


func _on_restart() -> void:
	hud.hide_over()
	hud.show_menu(true)
	state = "menu"


func _new_match() -> void:
	view.clear_all()
	world = SimWorld.new(int(Time.get_unix_time_from_system()) % 100000)
	bots.clear()
	bots.append(SimBot.new(world, 1, difficulty))
	if watch_mode:
		bots.append(SimBot.new(world, HUMAN, "normal"))
	selected.clear()
	view.selected = selected
	hud.slot_ids.fill(-1)
	hud.close_panels()
	hud.show_menu(false)
	hud.hide_over()
	placing = ""
	_acc = 0.0
	cam_rig.call("focus", Vector3(-80, 0, 0))
	state = "playing"


func _process(delta: float) -> void:
	_clock += delta
	if state == "playing":
		_acc += delta * speed
		var steps := 0
		while _acc >= STEP and not world.over and steps < 40:
			for b in bots:
				b.think()
			world.step()
			view.on_events(world, world.events)
			for ev in world.events:
				if ev["t"] == "die":
					selected.erase(ev["id"])
			_acc -= STEP
			steps += 1
		if world.over:
			_game_over()
	view.sync(world, clampf(_acc / STEP, 0.0, 1.0) if state == "playing" else 1.0, delta)
	hud.refresh(world, HUMAN, selected, delta)
	if placing != "":
		view.show_ghost(placing, ghost_pos, _place_error() == "")
	# segurar na barra = ir até a unidade
	if _g_kind == "slots" and not _g_moved and _g_slots.size() == 1 and _clock - _g_time > LONG_PRESS:
		var e: SimEnt = world.by_id.get(hud.slot_ids[_g_slots[0]])
		if e:
			selected.clear()
			selected[e.id] = true
			cam_rig.call("focus", Vector3(e.x / 100.0, 0, e.y / 100.0))
		_g_kind = "done"


func _game_over() -> void:
	state = "over"
	var title := "Empate"
	if world.winner == HUMAN:
		title = "Vitória"
	elif world.winner >= 0:
		title = "Derrota"
	if watch_mode:
		title = "Fim — vence %s" % ("Azul" if world.winner == 0 else ("Vermelho" if world.winner == 1 else "ninguém"))
	var me: Dictionary = world.players[HUMAN]
	var secs := world.tick / Defs.TICK_HZ
	hud.show_over(title, "%s · %02d:%02d\nMinério coletado %d · Abates %d · Perdas %d · Pontos %d x %d" % [
		world.end_reason, secs / 60, secs % 60, me["mined"], me["killed"], me["lost"], world.score(0), world.score(1)])


# ------------------------------------------------------------------ comandos do jogador
func _ids() -> Array:
	var out: Array = []
	for id in selected:
		if world.by_id.has(id):
			out.append(id)
	return out


func _on_build_pressed(type: String) -> void:
	placing = type
	ghost_pos = _screen_to_ground(get_viewport().get_visible_rect().size / 2.0)
	hud.start_placing(type)


func _place_error() -> String:
	return world.can_build(HUMAN, placing, int(ghost_pos.x * 100), int(ghost_pos.z * 100))


func _on_place_confirm() -> void:
	var err := _place_error()
	if err != "":
		hud.show_toast("Não dá para construir aqui: " + err)
		return
	world.issue(HUMAN, {"kind": "build", "type": placing, "x": int(ghost_pos.x * 100), "y": int(ghost_pos.z * 100)})
	placing = ""
	view.hide_ghost()
	hud.close_panels()


func _on_place_cancel() -> void:
	placing = ""
	view.hide_ghost()
	hud.close_panels()


func _on_train(type: String) -> void:
	var b: SimEnt = world.by_id.get(hud.prod_building)
	var err := world.can_train(HUMAN, b, type)
	if err != "":
		hud.show_toast(err.capitalize() if err.length() < 3 else err)
		return
	world.issue(HUMAN, {"kind": "train", "building": b.id, "type": type})


# ------------------------------------------------------------------ toque
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_rig.call("zoom_by", 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_rig.call("zoom_by", 1.1)
		return
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)


func _on_touch(ev: InputEventScreenTouch) -> void:
	if ev.pressed:
		_touches[ev.index] = ev.position
		if _touches.size() == 2:
			var v: Array = _touches.values()
			_pinch_d0 = (v[0] as Vector2).distance_to(v[1])
			_pinch_dist0 = cam_rig.get("distance")
			_g_kind = "pinch"
			return
		if _touches.size() > 2 or state != "playing":
			return
		_g_start = ev.position
		_g_time = _clock
		_g_moved = false
		var s := hud.slot_at(ev.position)
		if s >= 0:
			_g_kind = "slots"
			_g_slots = [s]
		elif GameHUD.MAP_RECT.has_point(ev.position):
			_g_kind = "map"
			cam_rig.call("focus", hud.map_to_world(ev.position))
		elif hud.blocks(ev.position):
			_g_kind = ""
		elif placing != "" and _near_ghost(ev.position):
			_g_kind = "ghost"
		else:
			_g_kind = "world"
		return
	# soltou
	_touches.erase(ev.index)
	if _g_kind == "pinch":
		if _touches.is_empty():
			_g_kind = ""
		return
	if state == "playing":
		match _g_kind:
			"slots":
				_release_slots()
			"world":
				if not _g_moved:
					if _clock - _g_time >= LONG_PRESS:
						_world_long_press(ev.position)
					else:
						_world_tap(ev.position)
	_g_kind = ""


func _on_drag(ev: InputEventScreenDrag) -> void:
	_touches[ev.index] = ev.position
	if _g_kind == "pinch" and _touches.size() >= 2:
		var v: Array = _touches.values()
		var d := (v[0] as Vector2).distance_to(v[1])
		cam_rig.set("distance", _pinch_dist0 * _pinch_d0 / maxf(d, 1.0))
		cam_rig.call("zoom_by", 1.0)
		return
	if ev.position.distance_to(_g_start) > TAP_MOVE:
		_g_moved = true
	match _g_kind:
		"world":
			if _g_moved:
				cam_rig.call("pan", ev.relative)
		"ghost":
			ghost_pos = _screen_to_ground(ev.position)
		"map":
			cam_rig.call("focus", hud.map_to_world(ev.position))
		"slots":
			var s := hud.slot_at(ev.position)
			if s >= 0 and not (s in _g_slots):
				_g_slots.append(s)


func _release_slots() -> void:
	if _g_slots.size() > 1:
		selected.clear()
		for s in _g_slots:
			if hud.slot_ids[s] >= 0:
				selected[hud.slot_ids[s]] = true
		return
	var id := hud.slot_ids[_g_slots[0]]
	if _clock - _last_slot_tap < DOUBLE_TAP:
		selected.clear()
		for i in hud.slot_ids:
			if i >= 0:
				selected[i] = true
		_last_slot_tap = -10.0
		return
	_last_slot_tap = _clock
	if id >= 0:
		selected.clear()
		selected[id] = true


func _world_tap(pos: Vector2) -> void:
	if placing != "":
		ghost_pos = _screen_to_ground(pos)
		return
	var e := _pick(pos)
	if e and e.owner == HUMAN and e.kind == "unit" and not Defs.UNITS[e.type].get("worker", false):
		selected.clear()
		selected[e.id] = true
		return
	if e and e.owner == HUMAN and e.kind == "building":
		hud.open_production(e)
		return
	var ids := _ids()
	if ids.is_empty():
		hud.close_panels()
		return
	if e and e.owner >= 0 and e.owner != HUMAN:
		world.issue(HUMAN, {"kind": "attack", "ids": ids, "target": e.id})
		view.marker(Vector3(e.x / 100.0, 0, e.y / 100.0), Color(2.4, 0.4, 0.3))
		return
	var g := _screen_to_ground(pos)
	world.issue(HUMAN, {"kind": "amove", "ids": ids, "x": int(g.x * 100), "y": int(g.z * 100)})
	view.marker(g, Color(2.2, 1.4, 0.3))


func _world_long_press(pos: Vector2) -> void:
	var ids := _ids()
	if ids.is_empty() or placing != "":
		return
	var g := _screen_to_ground(pos)
	world.issue(HUMAN, {"kind": "move", "ids": ids, "x": int(g.x * 100), "y": int(g.z * 100)})
	view.marker(g, Color(0.4, 1.6, 2.4))


func _pick(pos: Vector2) -> SimEnt:
	var cam: Camera3D = cam_rig.get("cam")
	var best: SimEnt = null
	var best_d := INF
	var px_per_m := get_viewport().get_visible_rect().size.y / (2.0 * float(cam_rig.get("distance")) * tan(deg_to_rad(cam.fov) / 2.0))
	for e in world.ents:
		var c := Vector3(e.x / 100.0, GameView.height_of(e) * 0.7, e.y / 100.0)
		if cam.is_position_behind(c):
			continue
		var d := cam.unproject_position(c).distance_to(pos)
		var lim := maxf(42.0, e.radius / 100.0 * px_per_m * 1.1)
		if d < lim and d < best_d:
			best = e
			best_d = d
	return best


func _near_ghost(pos: Vector2) -> bool:
	var cam: Camera3D = cam_rig.get("cam")
	return cam.unproject_position(ghost_pos).distance_to(pos) < 110.0


func _screen_to_ground(pos: Vector2) -> Vector3:
	var cam: Camera3D = cam_rig.get("cam")
	var o := cam.project_ray_origin(pos)
	var d := cam.project_ray_normal(pos)
	if absf(d.y) < 0.0001:
		return Vector3(o.x, 0, o.z)
	var t := -o.y / d.y
	var p := o + d * t
	return Vector3(clampf(p.x, -Defs.HALF_W / 100.0, Defs.HALF_W / 100.0), 0, clampf(p.z, -Defs.HALF_H / 100.0, Defs.HALF_H / 100.0))
