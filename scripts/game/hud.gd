class_name GameHUD
extends CanvasLayer
## Interface do jogo, desenhada para celular deitado (base 1688 x 780, escala automática).
## Só desenha e emite sinais; quem decide o que fazer é o game.gd.

signal build_pressed(type: String)
signal place_confirmed
signal place_cancelled
signal train_pressed(type: String)
signal panel_closed
signal start_pressed(difficulty: String, watch: bool)
signal restart_pressed

const W := 1688.0
const H := 780.0
const SLOT := Vector2(70, 60)
const SLOT_GAP := 6.0
const MAP_RECT := Rect2(12, H - 12 - 150, 225, 150)
const BTN := Vector2(150, 130)

var game: Node
var slot_ids: Array[int] = []           # 10 posições, -1 = vazia
var slot_panels: Array[Panel] = []
var slot_labels: Array[Label] = []
var slot_bars: Array[ColorRect] = []
var info_label: Label
var toast: Label
var toast_time := 0.0
var help: Label
var build_btn: Button
var build_menu: HBoxContainer
var place_bar: HBoxContainer
var place_hint: Label
var prod_panel: VBoxContainer
var prod_title: Label
var prod_buttons: HBoxContainer
var menu_overlay: Control
var over_overlay: Control
var over_title: Label
var over_text: Label
var minimap: Control
var bars: Control
var mode := "idle"                       # idle, build_menu, placing, production
var bars_drawn := 0                      # diagnóstico (teste automático)
var bars_calls := 0
var prod_building := -1


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.size = Vector2(W, H)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font_size = 22
	root.theme = th
	add_child(root)

	bars = _Overlay.new()
	bars.hud = self
	bars.kind = "bars"
	bars.size = Vector2(W, H)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bars)

	for i in 10:
		slot_ids.append(-1)
		var p := Panel.new()
		p.position = Vector2(12 + i * (SLOT.x + SLOT_GAP), 10)
		p.size = SLOT
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(p)
		var l := Label.new()
		l.size = Vector2(SLOT.x, 40)
		l.position = Vector2(0, 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 20)
		p.add_child(l)
		var bar := ColorRect.new()
		bar.position = Vector2(6, SLOT.y - 12)
		bar.size = Vector2(SLOT.x - 12, 6)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(bar)
		slot_panels.append(p)
		slot_labels.append(l)
		slot_bars.append(bar)

	var info_bg := _panel(Rect2(W - 12 - 520, 10, 520, 60), 0.72)
	root.add_child(info_bg)
	info_label = Label.new()
	info_label.position = Vector2(14, 14)
	info_label.size = Vector2(500, 34)
	info_bg.add_child(info_label)

	minimap = _Overlay.new()
	minimap.hud = self
	minimap.kind = "map"
	minimap.position = MAP_RECT.position
	minimap.size = MAP_RECT.size
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap)

	toast = Label.new()
	toast.position = Vector2(W / 2 - 400, 86)
	toast.size = Vector2(800, 40)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_color", Color("ffd27a"))
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	toast.add_theme_constant_override("outline_size", 6)
	root.add_child(toast)

	help = Label.new()
	help.position = Vector2(260, H - 46)
	help.size = Vector2(W - 520, 36)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 18)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 5)
	help.text = "Barra: toque, arraste ou 2 toques  ·  Chão: toque = atacar/mover, segure = só mover  ·  Arraste = câmera"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(help)

	build_btn = _button("Construir", Vector2(150, 150))
	build_btn.position = Vector2(W - 12 - 150, H - 12 - 150)
	build_btn.pressed.connect(func() -> void: _set_mode("build_menu"))
	root.add_child(build_btn)

	build_menu = HBoxContainer.new()
	build_menu.add_theme_constant_override("separation", 8)
	for t in ["fabrica", "hangar", "torre"]:
		var b := _button("", BTN)
		b.name = t
		b.pressed.connect(func() -> void: build_pressed.emit(t))
		build_menu.add_child(b)
	var close1 := _button("Fechar", Vector2(110, BTN.y))
	close1.pressed.connect(func() -> void: _set_mode("idle"))
	build_menu.add_child(close1)
	build_menu.position = Vector2(W - 12 - (3 * BTN.x + 110 + 24), H - 12 - BTN.y)
	root.add_child(build_menu)

	place_bar = HBoxContainer.new()
	place_bar.add_theme_constant_override("separation", 8)
	var ok := _button("Confirmar", Vector2(170, 100))
	ok.pressed.connect(func() -> void: place_confirmed.emit())
	var cancel := _button("Cancelar", Vector2(170, 100))
	cancel.pressed.connect(func() -> void: place_cancelled.emit())
	place_bar.add_child(ok)
	place_bar.add_child(cancel)
	place_bar.position = Vector2(W - 12 - 348, H - 12 - 100)
	root.add_child(place_bar)
	place_hint = Label.new()
	place_hint.position = Vector2(W - 12 - 600, H - 12 - 150)
	place_hint.size = Vector2(600, 40)
	place_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	place_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	place_hint.add_theme_constant_override("outline_size", 6)
	root.add_child(place_hint)

	prod_panel = VBoxContainer.new()
	prod_panel.add_theme_constant_override("separation", 6)
	prod_title = Label.new()
	prod_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prod_title.add_theme_color_override("font_outline_color", Color.BLACK)
	prod_title.add_theme_constant_override("outline_size", 6)
	prod_panel.add_child(prod_title)
	prod_buttons = HBoxContainer.new()
	prod_buttons.add_theme_constant_override("separation", 8)
	prod_buttons.alignment = BoxContainer.ALIGNMENT_END
	prod_panel.add_child(prod_buttons)
	root.add_child(prod_panel)

	_build_menus(root)
	_set_mode("idle")


func _panel(r: Rect2, alpha: float) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.1, 0.13, alpha)
	sb.border_color = Color("56636f")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _button(text: String, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = sz
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(0.08, 0.12, 0.16, 0.85), "hover": Color(0.12, 0.18, 0.24, 0.9),
			"pressed": Color(0.18, 0.3, 0.42, 0.95), "disabled": Color(0.08, 0.1, 0.12, 0.6)}[st]
		sb.border_color = Color("a9bccd") if st != "disabled" else Color("4a5560")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_disabled_color", Color("6f7a84"))
	return b


func _build_menus(root: Control) -> void:
	menu_overlay = _overlay_box(root)
	var box: VBoxContainer = menu_overlay.get_child(1)
	var t := Label.new()
	t.text = "RTS — protótipo jogável"
	t.add_theme_font_size_override("font_size", 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var s := Label.new()
	s.text = "Você (azul) contra 1 bot (vermelho). Destrua a Base central inimiga.\nAos 8 min as Bases perdem a blindagem; aos 10 min vence quem tiver mais pontos."
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for pair in [["facil", "Fácil"], ["normal", "Normal"], ["dificil", "Difícil"]]:
		var b := _button(pair[1], Vector2(210, 110))
		b.add_theme_font_size_override("font_size", 30)
		b.pressed.connect(func() -> void: start_pressed.emit(pair[0], false))
		row.add_child(b)
	box.add_child(row)
	var watch := _button("Assistir bot x bot", Vector2(320, 70))
	watch.pressed.connect(func() -> void: start_pressed.emit("normal", true))
	var wrow := HBoxContainer.new()
	wrow.alignment = BoxContainer.ALIGNMENT_CENTER
	wrow.add_child(watch)
	box.add_child(wrow)

	over_overlay = _overlay_box(root)
	var ob: VBoxContainer = over_overlay.get_child(1)
	over_title = Label.new()
	over_title.add_theme_font_size_override("font_size", 56)
	over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ob.add_child(over_title)
	over_text = Label.new()
	over_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ob.add_child(over_text)
	var again := _button("Jogar de novo", Vector2(320, 90))
	again.pressed.connect(func() -> void: restart_pressed.emit())
	var arow := HBoxContainer.new()
	arow.alignment = BoxContainer.ALIGNMENT_CENTER
	arow.add_child(again)
	ob.add_child(arow)
	over_overlay.visible = false


func _overlay_box(root: Control) -> Control:
	var o := Control.new()
	o.size = Vector2(W, H)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.06, 0.72)
	dim.size = Vector2(W, H)
	o.add_child(dim)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.position = Vector2(W / 2 - 500, 150)
	box.size = Vector2(1000, 480)
	o.add_child(box)
	root.add_child(o)
	return o


# ------------------------------------------------------------------ estado
func _set_mode(m: String) -> void:
	mode = m
	build_btn.visible = m == "idle"
	build_menu.visible = m == "build_menu"
	place_bar.visible = m == "placing"
	place_hint.visible = m == "placing"
	prod_panel.visible = m == "production"
	if m != "production":
		prod_building = -1


func open_production(b: SimEnt) -> void:
	prod_building = b.id
	for c in prod_buttons.get_children():
		c.queue_free()
	for t: String in Defs.BUILDINGS[b.type]["produces"]:
		var btn := _button("", BTN)
		btn.name = t
		btn.pressed.connect(func() -> void: train_pressed.emit(t))
		prod_buttons.add_child(btn)
	var close := _button("Fechar", Vector2(110, BTN.y))
	close.pressed.connect(func() -> void:
		_set_mode("idle")
		panel_closed.emit())
	prod_buttons.add_child(close)
	_set_mode("production")


func start_placing(type: String) -> void:
	_set_mode("placing")
	place_hint.text = "Toque no mapa para posicionar: %s" % NAMES.get(type, type)


func close_panels() -> void:
	_set_mode("idle")


func show_toast(t: String) -> void:
	toast.text = t
	toast_time = 2.2


func show_menu(v: bool) -> void:
	menu_overlay.visible = v


func show_over(title: String, text: String) -> void:
	over_title.text = title
	over_text.text = text
	over_overlay.visible = true


func hide_over() -> void:
	over_overlay.visible = false


const NAMES := {"fabrica": "Fábrica", "hangar": "Hangar", "torre": "Torre", "base": "Base central",
	"buggy": "Buggy", "tanque": "Tanque", "antiaereo": "Antiaéreo", "vtol": "VTOL", "coletor": "Coletor"}


# ------------------------------------------------------------------ toque: o que está sob o dedo
func blocks(pos: Vector2) -> bool:
	if menu_overlay.visible or over_overlay.visible:
		return true
	if slot_at(pos) >= 0 or MAP_RECT.has_point(pos):
		return true
	for c: Control in [build_btn, build_menu, place_bar, prod_panel]:
		if c.visible and c.get_global_rect().grow(6).has_point(pos):
			return true
	return Rect2(W - 12 - 520, 10, 520, 60).has_point(pos)


func slot_at(pos: Vector2) -> int:
	for i in 10:
		if slot_panels[i].get_global_rect().grow(SLOT_GAP / 2).has_point(pos):
			return i
	return -1


# ------------------------------------------------------------------ atualização por quadro
func assign_slots(w: SimWorld, p: int) -> void:
	for i in 10:
		if slot_ids[i] >= 0 and not w.by_id.has(slot_ids[i]):
			slot_ids[i] = -1
	var present := {}
	for id in slot_ids:
		present[id] = true
	for u in w.army(p):
		if present.has(u.id):
			continue
		var free := slot_ids.find(-1)
		if free >= 0:
			slot_ids[free] = u.id
			present[u.id] = true


func refresh(w: SimWorld, p: int, selected: Dictionary, delta: float) -> void:
	assign_slots(w, p)
	for i in 10:
		var e: SimEnt = w.by_id.get(slot_ids[i])
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(5)
		if e:
			var sel := selected.has(e.id)
			sb.bg_color = Color(0.16, 0.24, 0.34, 0.9) if sel else Color(0.07, 0.1, 0.13, 0.8)
			sb.border_color = Color.WHITE if sel else Color("a9bccd")
			sb.set_border_width_all(3 if sel else 2)
			slot_labels[i].text = Defs.UNITS[e.type]["tag"]
			var r := float(e.hp) / e.max_hp
			slot_bars[i].visible = true
			slot_bars[i].size.x = (SLOT.x - 12) * r
			slot_bars[i].color = Color("4cd26b") if r > 0.6 else (Color("e8b52a") if r > 0.3 else Color("e0483a"))
		else:
			sb.bg_color = Color(0.07, 0.1, 0.13, 0.32)
			sb.border_color = Color("56636f")
			sb.set_border_width_all(2)
			slot_labels[i].text = ""
			slot_bars[i].visible = false
		slot_panels[i].add_theme_stylebox_override("panel", sb)

	var pl: Dictionary = w.players[p]
	var secs := w.tick / Defs.TICK_HZ
	var warn := "  · BASES SEM BLINDAGEM" if w.tick >= Defs.ARMOR_OFF_TICK else ""
	info_label.text = "Minério %d    Coletores %d/%d    Exército %d/%d    %02d:%02d%s" % [
		pl["ore"], w.queued_count(p, true), Defs.WORKER_CAP, w.queued_count(p, false), Defs.COMBAT_CAP,
		secs / 60, secs % 60, warn]

	if mode == "build_menu":
		for b: Button in build_menu.get_children():
			if Defs.BUILDINGS.has(String(b.name)):
				var t := String(b.name)
				var d: Dictionary = Defs.BUILDINGS[t]
				var req: String = d["req"]
				var lock := req != "" and not w.has_built(p, req)
				b.text = "%s\n%d%s" % [NAMES[t], d["cost"], "\n(precisa %s)" % NAMES[req] if lock else ""]
				b.disabled = lock or pl["ore"] < d["cost"]
	if mode == "production":
		var bld: SimEnt = w.by_id.get(prod_building)
		if bld == null or bld.owner != p:
			_set_mode("idle")
		else:
			var line: String = NAMES[bld.type]
			if not bld.built:
				line += " — em construção %d%%" % (100 * bld.progress / Defs.BUILDINGS[bld.type]["time"])
			elif not bld.queue.is_empty():
				line += " — produzindo %s %d%%  (fila %d)" % [NAMES[bld.queue[0]], 100 * bld.qprog / Defs.UNITS[bld.queue[0]]["time"], bld.queue.size()]
			prod_title.text = line
			for b in prod_buttons.get_children():
				if b is Button and Defs.UNITS.has(String(b.name)):
					var t := String(b.name)
					var q := bld.queue.count(t)
					(b as Button).text = "%s\n%d%s" % [NAMES[t], Defs.UNITS[t]["cost"], "  ×%d" % q if q > 0 else ""]
					(b as Button).disabled = w.can_train(p, bld, t) != ""
			prod_panel.position = Vector2(W - 12 - prod_panel.size.x, H - 12 - prod_panel.size.y)

	if toast_time > 0.0:
		toast_time -= delta
		toast.modulate.a = clampf(toast_time, 0.0, 1.0)
	if w.tick > 300:
		help.modulate.a = maxf(0.0, help.modulate.a - delta * 0.5)
	bars.queue_redraw()
	minimap.queue_redraw()


# ------------------------------------------------------------------ desenhos 2D
func _draw_bars(c: Control) -> void:
	bars_calls += 1
	if game == null or game.world == null:
		return
	var cam: Camera3D = game.cam_rig.cam
	var w: SimWorld = game.world
	var sel: Dictionary = game.view.selected
	for e in w.ents:
		if e.kind == "ore":
			continue
		var wants := e.hp < e.max_hp or sel.has(e.id) or (e.kind == "building" and not e.built)
		if not wants:
			continue
		var n: Node3D = game.view.nodes.get(e.id)
		if n == null:
			continue
		var top := n.position + Vector3(0, GameView.height_of(e) + (5.0 if e.kind == "building" else 2.6), 0)
		if cam.is_position_behind(top):
			continue
		var sp := cam.unproject_position(top) - Vector2(0, 14)
		var wdt := 104.0 if e.kind == "building" else 60.0
		var r := float(e.hp) / e.max_hp
		c.draw_rect(Rect2(sp.x - wdt / 2 - 2, sp.y - 2, wdt + 4, 13), Color(0.02, 0.03, 0.04, 0.85))
		var col := Color("4cd26b") if r > 0.6 else (Color("e8b52a") if r > 0.3 else Color("e0483a"))
		c.draw_rect(Rect2(sp.x - wdt / 2, sp.y, wdt * r, 9), col)
		c.draw_rect(Rect2(sp.x - wdt / 2 - 2, sp.y - 2, 4, 13), GameView.TEAM_COLORS[e.owner])
		bars_drawn += 1


func _draw_map(c: Control) -> void:
	var sz := c.size
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.24, 0.19, 0.12, 0.85))
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("a9bccd"), false, 2.0)
	if game == null or game.world == null:
		return
	var w: SimWorld = game.world
	var to_map := func(x: int, y: int) -> Vector2:
		return Vector2((x + Defs.HALF_W) * sz.x / (2.0 * Defs.HALF_W), (y + Defs.HALF_H) * sz.y / (2.0 * Defs.HALF_H))
	for e in w.ents:
		var p: Vector2 = to_map.call(e.x, e.y)
		if e.kind == "ore":
			c.draw_circle(p, 4, Color("d9761c"))
		elif e.kind == "building":
			var col: Color = GameView.TEAM_COLORS[e.owner]
			c.draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), col)
		else:
			c.draw_circle(p, 2.5, GameView.TEAM_COLORS[e.owner].lightened(0.3))
	var cp: Vector3 = game.cam_rig.position
	var cv: Vector2 = to_map.call(int(cp.x * 100), int(cp.z * 100))
	var half := Vector2(game.cam_rig.distance * 0.9, game.cam_rig.distance * 0.42) * sz.x / (2.0 * Defs.HALF_W / 100.0)
	c.draw_rect(Rect2(cv - half, half * 2), Color(1, 1, 1, 0.8), false, 1.5)


func map_to_world(pos: Vector2) -> Vector3:
	var local := (pos - MAP_RECT.position) / MAP_RECT.size
	return Vector3((local.x * 2.0 - 1.0) * Defs.HALF_W / 100.0, 0, (local.y * 2.0 - 1.0) * Defs.HALF_H / 100.0)


class _Overlay extends Control:
	var hud: GameHUD
	var kind := ""

	func _draw() -> void:
		if kind == "bars":
			hud._draw_bars(self)
		else:
			hud._draw_map(self)
