extends Node3D
## Demo de assets: monta um trecho de partida (duas bases em platôs, recursos,
## exércitos no centro) com os modelos gerados por código. Não há regras de jogo aqui —
## serve para ver os assets no aparelho, na câmera e na luz do jogo.

const MODELS := "res://assets/models/"
const TEAM := {
	"blue": Color("2f7de1"), "red": Color("d8402f"),
	"yellow": Color("e8b52a"), "green": Color("3fbf6a"),
}
const PLATEAU_Y := 4.0
const R := PI / 2.0

var _scenes: Dictionary = {}


func _ready() -> void:
	_setup_world()
	_build_terrain()
	_build_base("militar", "blue", 1)
	_build_base("energia", "red", -1)
	_build_center()
	var rig := Node3D.new()
	rig.set_script(load("res://scripts/rts_camera.gd"))
	rig.position = Vector3(-6, 0, 0)
	add_child(rig)
	_build_hud()


# ------------------------------------------------------------------ mundo
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
	env.fog_enabled = true
	env.fog_light_color = Color("b89566")
	env.fog_density = 0.002
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffeccc")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	sun.transform = Transform3D(Basis(), Vector3(-40, 70, -30)).looking_at(Vector3.ZERO, Vector3.UP)
	add_child(sun)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(700, 700)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("c4a06a")
	gm.roughness = 0.97
	ground.material_override = gm
	add_child(ground)


func place(asset: String, pos: Vector3, rot_y := 0.0, team := "") -> Node3D:
	if not _scenes.has(asset):
		_scenes[asset] = load(MODELS + asset + ".glb")
	var n: Node3D = (_scenes[asset] as PackedScene).instantiate()
	n.name = asset
	n.position = pos
	n.rotation.y = rot_y
	n.set_meta("kind", "unit" if _is_unit(asset) else "other")
	add_child(n, true)
	TeamColor.apply(n, TEAM.get(team, TEAM["blue"]))
	var anim := Node.new()
	anim.set_script(load("res://scripts/asset_animator.gd"))
	n.add_child(anim)
	return n


func _is_unit(asset: String) -> bool:
	for k in ["coletor", "buggy", "tanque", "vtol", "antiaereo", "drone", "sentinela", "obelisco", "lamina", "prisma"]:
		if asset.contains(k):
			return true
	return false


# ------------------------------------------------------------------ mapa
func _build_terrain() -> void:
	for pair in [[-50.0, 1], [50.0, -1]]:
		var cx: float = pair[0]
		var side: int = pair[1]
		for i in range(-1, 2):
			for j in range(-1, 2):
				place("terreno_plato", Vector3(cx + i * 16, 0, j * 16))
		place("terreno_rampa", Vector3(cx + side * 28.5, 0, 0), -R if side > 0 else R)


func _build_base(f: String, t: String, k: int) -> void:
	var ry := -R if k > 0 else R
	place(f + "_base", Vector3(-56 * k, PLATEAU_Y, 8 * k), ry, t)
	place(f + "_fabrica", Vector3(-38 * k, PLATEAU_Y, 12 * k), ry, t)
	place(f + "_hangar", Vector3(-42 * k, PLATEAU_Y, -13 * k), ry, t)
	place(f + "_laboratorio", Vector3(-58 * k, PLATEAU_Y, -16 * k), ry, t)
	place(f + "_torre", Vector3(-29 * k, PLATEAU_Y, -7 * k), ry, t)
	place("recurso_minerio", Vector3(-67 * k, PLATEAU_Y, -5 * k), 0.3)
	place("recurso_minerio", Vector3(-69 * k, PLATEAU_Y, 18 * k), 1.2)
	var col := "militar_coletor" if f == "militar" else "energia_drone_extrator"
	place(col, Vector3(-61 * k, PLATEAU_Y, -1 * k), 0.4 + (0.0 if k > 0 else PI), t)
	place(col, Vector3(-63 * k, PLATEAU_Y, 14 * k), 2.6 + (0.0 if k > 0 else PI), t)


func _build_center() -> void:
	place("recurso_nucleo", Vector3(2, 0, -24))
	var mil := [["militar_tanque_cerco", -13, 3, -R + 0.15], ["militar_buggy", -5, -7, -R - 0.3],
		["militar_buggy", -3, 8, -R + 0.2], ["militar_antiaereo", -16, -6, -R],
		["militar_vtol", -9, -1, -R + 0.2], ["militar_vtol", -14, 11, -R]]
	var ene := [["energia_sentinela", 6, -6, R + 0.3], ["energia_sentinela", 5, 6, R - 0.2],
		["energia_obelisco", 14, 2, R], ["energia_prisma", 16, -8, R],
		["energia_lamina", 9, -12, R + 0.4], ["energia_lamina", 11, 11, R - 0.3]]
	for u in mil:
		place(u[0], Vector3(u[1], 0, u[2]), u[3], "blue")
	for u in ene:
		place(u[0], Vector3(u[1], 0, u[2]), u[3], "red")


# ------------------------------------------------------------------ HUD (só leiaute)
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bar := HBoxContainer.new()
	bar.position = Vector2(12, 10)
	bar.add_theme_constant_override("separation", 6)
	layer.add_child(bar)
	for i in 10:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(64, 56)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.1, 0.13, 0.78 if i < 6 else 0.3)
		sb.border_color = Color("a9bccd") if i < 6 else Color("56636f")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(5)
		slot.add_theme_stylebox_override("panel", sb)
		bar.add_child(slot)
