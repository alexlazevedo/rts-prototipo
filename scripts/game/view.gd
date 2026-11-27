class_name GameView
extends Node3D
## Apresentação: lê o SimWorld e desenha. Nunca altera a simulação.
## Posições são interpoladas entre o tick anterior e o atual (a simulação roda a 10/s).

const MODELS := "res://assets/models/"
const TEAM_COLORS := [Color("2f7de1"), Color("d8402f"), Color("e8b52a"), Color("3fbf6a")]
const SHOT_COLORS := [Color(0.45, 0.85, 3.0), Color(3.0, 1.1, 0.35), Color(3.0, 2.4, 0.4), Color(0.5, 3.0, 0.8)]

var nodes: Dictionary = {}        # id -> Node3D
var info: Dictionary = {}         # id -> {turret, ring, yaw}
var selected: Dictionary = {}     # id -> true (definido pelo jogo)
var _scenes: Dictionary = {}
var _fx: Array[Dictionary] = []
var _ring_mat: StandardMaterial3D
var _shot_mats: Array[StandardMaterial3D] = []
var _fire_mat: StandardMaterial3D
var _smoke_mat: StandardMaterial3D
var _ghost: Node3D
var _ghost_type := ""
var _ghost_ok_mat: StandardMaterial3D
var _ghost_bad_mat: StandardMaterial3D


func _ready() -> void:
	_ring_mat = _unshaded(Color(0.35, 2.2, 0.6))
	for c in SHOT_COLORS:
		_shot_mats.append(_unshaded(c))
	_fire_mat = _unshaded(Color(3.2, 1.6, 0.4))
	_smoke_mat = StandardMaterial3D.new()
	_smoke_mat.albedo_color = Color(0.17, 0.16, 0.15, 0.6)
	_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_ok_mat = _unshaded(Color(0.3, 1.6, 0.5, 0.45))
	_ghost_ok_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_bad_mat = _unshaded(Color(1.8, 0.3, 0.25, 0.45))
	_ghost_bad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _scene(model: String) -> PackedScene:
	if not _scenes.has(model):
		_scenes[model] = load(MODELS + model + ".glb")
	return _scenes[model]


static func model_of(e: SimEnt) -> String:
	if e.kind == "ore":
		return "recurso_minerio"
	return Defs.def_of(e.type)["model"]


static func height_of(e: SimEnt) -> float:
	if e.air:
		return 6.3
	if e.kind == "building":
		return 3.0
	return 1.2


func clear_all() -> void:
	for id in nodes:
		nodes[id].queue_free()
	nodes.clear()
	info.clear()
	for f in _fx:
		f["node"].queue_free()
	_fx.clear()
	hide_ghost()


func _make(e: SimEnt) -> void:
	var n: Node3D = _scene(model_of(e)).instantiate()
	add_child(n)
	TeamColor.apply(n, TEAM_COLORS[maxi(e.owner, 0)])
	var anim := Node.new()
	anim.set_script(preload("res://scripts/asset_animator.gd"))
	n.add_child(anim)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	var r := e.radius / 100.0 + 0.5
	tm.inner_radius = r
	tm.outer_radius = r + 0.25
	tm.ring_segments = 6
	tm.rings = 24
	ring.mesh = tm
	ring.material_override = _ring_mat
	ring.position.y = 0.12
	ring.visible = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	var yaw := 0.0
	if e.kind == "building":
		yaw = -PI / 2 if e.x < 0 else PI / 2
	elif e.kind == "unit":
		yaw = -PI / 2 if e.owner == 0 else PI / 2
	else:
		yaw = float(e.id % 7)
	n.rotation.y = yaw
	nodes[e.id] = n
	info[e.id] = {"turret": n.find_child("Turret", true, false), "ring": ring, "yaw": yaw}
	n.position = Vector3(e.x / 100.0, 0, e.y / 100.0)


func sync(w: SimWorld, alpha: float, delta: float) -> void:
	var alive: Dictionary = {}
	for e in w.ents:
		alive[e.id] = true
		if not nodes.has(e.id):
			_make(e)
		var n: Node3D = nodes[e.id]
		var inf: Dictionary = info[e.id]
		var x := lerpf(e.px, e.x, alpha) / 100.0
		var z := lerpf(e.py, e.y, alpha) / 100.0
		n.position = Vector3(x, 0, z)
		(inf["ring"] as Node3D).visible = selected.has(e.id)
		if e.kind == "unit":
			var target_yaw: float = inf["yaw"]
			var vx := e.x - e.px
			var vz := e.y - e.py
			var aim: SimEnt = w.by_id.get(e.aim)
			if vx * vx + vz * vz > 4:
				target_yaw = atan2(-vx, -vz)
			elif aim and inf["turret"] == null:
				target_yaw = atan2(-(aim.x - e.x), -(aim.y - e.y))
			inf["yaw"] = lerp_angle(inf["yaw"], target_yaw, minf(1.0, delta * 7.0))
			n.rotation.y = inf["yaw"]
			_aim_turret(inf, e, aim, delta)
		elif e.kind == "building":
			if not e.built:
				var t: int = Defs.BUILDINGS[e.type]["time"]
				n.scale = Vector3(1, 0.2 + 0.8 * float(e.progress) / t, 1)
			elif n.scale.y < 1.0:
				n.scale = Vector3.ONE
			_aim_turret(inf, e, w.by_id.get(e.aim), delta)
		elif e.kind == "ore":
			var s := 0.5 + 0.5 * float(e.amount) / maxf(1.0, e.max_hp)
			n.scale = Vector3(s, s, s)
	for id in nodes.keys():
		if not alive.has(id):
			nodes[id].queue_free()
			nodes.erase(id)
			info.erase(id)
	_update_fx(delta)


func _aim_turret(inf: Dictionary, e: SimEnt, aim: SimEnt, delta: float) -> void:
	var tur: Node3D = inf["turret"]
	if tur == null:
		return
	var local := 0.0
	if aim:
		var world_yaw := atan2(-(aim.x - e.x), -(aim.y - e.y))
		local = world_yaw - (nodes[e.id] as Node3D).rotation.y
	tur.rotation.y = lerp_angle(tur.rotation.y, local, minf(1.0, delta * 8.0))


# ------------------------------------------------------------------ efeitos
func on_events(w: SimWorld, events: Array[Dictionary]) -> void:
	for ev in events:
		match ev["t"]:
			"shot":
				var a: SimEnt = w.by_id.get(ev["a"])
				var b: SimEnt = w.by_id.get(ev["b"])
				if a and b:
					_beam(a, b)
			"die":
				if ev["kind"] != "ore":
					var big: bool = ev["kind"] == "building"
					_explosion(Vector3(ev["x"] / 100.0, 1.0 if not big else 2.5, ev["y"] / 100.0), 3.2 if big else 1.4)


func _beam(a: SimEnt, b: SimEnt) -> void:
	var from := Vector3(a.x / 100.0, height_of(a) + (2.0 if a.type == "torre" else 0.4), a.y / 100.0)
	var to := Vector3(b.x / 100.0, height_of(b), b.y / 100.0)
	var length := from.distance_to(to)
	if length < 0.1:
		return
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var thick := 0.22 if a.type == "tanque" else 0.12
	bm.size = Vector3(thick, thick, length)
	m.mesh = bm
	m.material_override = _shot_mats[maxi(a.owner, 0)]
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.position = (from + to) / 2.0
	m.look_at_from_position(m.position, to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	_fx.append({"node": m, "life": 0.12, "max": 0.12, "kind": "beam"})
	_flash(to, 0.5)


func _flash(p: Vector3, r: float) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2
	sm.radial_segments = 8
	sm.rings = 4
	m.mesh = sm
	m.material_override = _fire_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.position = p
	_fx.append({"node": m, "life": 0.15, "max": 0.15, "kind": "flash"})


func _explosion(p: Vector3, r: float) -> void:
	_flash(p, r)
	_fx[-1]["life"] = 0.35
	_fx[-1]["max"] = 0.35
	for i in 4:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r * 0.6
		sm.height = r * 1.2
		sm.radial_segments = 8
		sm.rings = 4
		m.mesh = sm
		m.material_override = _smoke_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		var ang := i * TAU / 4.0 + p.x
		m.position = p + Vector3(cos(ang) * r * 0.6, r * 0.5 + i * 0.3, sin(ang) * r * 0.6)
		_fx.append({"node": m, "life": 1.1, "max": 1.1, "kind": "smoke"})


func marker(p: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.6
	tm.outer_radius = 2.0
	tm.rings = 24
	tm.ring_segments = 4
	m.mesh = tm
	m.material_override = _unshaded(color)
	m.position = p + Vector3(0, 0.15, 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	_fx.append({"node": m, "life": 0.6, "max": 0.6, "kind": "marker"})


func _update_fx(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for f in _fx:
		f["life"] -= delta
		var n: Node3D = f["node"]
		if f["life"] <= 0.0:
			n.queue_free()
			continue
		var k: float = f["life"] / f["max"]
		match f["kind"]:
			"flash":
				n.scale = Vector3.ONE * (0.4 + 0.8 * k)
			"smoke":
				n.scale = Vector3.ONE * (1.4 - 0.6 * k)
				n.position.y += delta * 1.5
			"marker":
				n.scale = Vector3.ONE * (0.5 + 0.5 * k)
		keep.append(f)
	_fx = keep


# ------------------------------------------------------------------ fantasma de construção
func show_ghost(type: String, pos: Vector3, ok: bool) -> void:
	if _ghost_type != type:
		hide_ghost()
		_ghost = _scene(Defs.BUILDINGS[type]["model"]).instantiate()
		add_child(_ghost)
		_ghost_type = type
		_ghost.rotation.y = -PI / 2
	_ghost.position = pos
	var mat := _ghost_ok_mat if ok else _ghost_bad_mat
	for mi: MeshInstance3D in _ghost.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func hide_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
	_ghost = null
	_ghost_type = ""
