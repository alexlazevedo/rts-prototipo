extends Node
## Teste de ponta a ponta com toques simulados (rodar com: -- --autotest).
## Faz o caminho de um jogador real: menu -> construir fábrica -> produzir -> selecionar pela
## barra (toque, arraste, dois toques) -> mover atacando -> segurar para só mover -> pinça.
## Salva capturas de tela em user://autotest_*.png e imprime PASSOU/FALHOU.

var g: Node
var results: Array[String] = []
var fails := 0
var shot_dir := ""


func _ready() -> void:
	g = get_parent()
	shot_dir = OS.get_environment("AUTOTEST_SHOTS")
	if shot_dir == "":
		shot_dir = "user://"
	_run.call_deferred()


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	e.relative = rel
	Input.parse_input_event(e)


func tap(pos: Vector2, hold := 0.06) -> void:
	touch(0, pos, true)
	await wait(hold)
	touch(0, pos, false)
	await wait(0.12)


func check(ok: bool, name: String) -> void:
	results.append(("PASSOU  " if ok else "FALHOU  ") + name)
	if not ok:
		fails += 1


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_dir.path_join("autotest_%s.png" % name))


func button(text: String) -> Button:
	for b: Button in g.hud.find_children("*", "Button", true, false):
		if b.visible and b.is_visible_in_tree() and b.text.begins_with(text):
			return b
	return null


func center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func screen_of(p: Vector3) -> Vector2:
	return (g.cam_rig.get("cam") as Camera3D).unproject_position(p)


func _run() -> void:
	await wait(0.6)
	await shot("01_menu")
	await tap(center(button("Normal")))
	await wait(0.3)
	check(g.state == "playing", "menu: tocar em Normal inicia a partida")
	g.speed = 6.0

	await tap(center(g.hud.build_btn))
	check(g.hud.mode == "build_menu", "botão Construir abre o menu de prédios")
	await tap(center(g.hud.build_menu.get_node("fabrica")))
	check(g.placing == "fabrica", "escolher Fábrica entra no modo de posicionar")
	await tap(screen_of(Vector3(-74, 0, 12)))
	var err: String = g._place_error()
	check(err == "", "tocar no mapa posiciona o prédio em lugar válido (%s)" % (err if err != "" else "ok"))
	await shot("02_posicionando")
	await tap(center(button("Confirmar")))
	await wait(0.3)
	var fab: SimEnt = null
	for e in g.world.ents:
		if e.owner == 0 and e.type == "fabrica":
			fab = e
	check(fab != null, "Confirmar cria a fábrica em construção")
	if fab == null:
		_finish()
		return

	var t0: float = g._clock
	while not fab.built and g._clock - t0 < 15.0:
		await wait(0.2)
	check(fab.built, "fábrica termina de construir")
	await tap(screen_of(Vector3(fab.x / 100.0, 3, fab.y / 100.0)))
	check(g.hud.mode == "production" and g.hud.prod_building == fab.id, "tocar na fábrica abre o painel de produção")
	var made := 0
	t0 = g._clock
	while made < 3 and g._clock - t0 < 25.0:
		var t := "buggy" if made < 2 else "antiaereo"
		if g.world.can_train(0, fab, t) == "":
			await tap(center(g.hud.prod_buttons.get_node(t)))
			made += 1
		await wait(0.2)
	check(made == 3, "botões de produção colocam 3 unidades na fila")
	await shot("03_producao")
	t0 = g._clock
	while g.world.army(0).size() < 3 and g._clock - t0 < 30.0:
		await wait(0.2)
	check(g.world.army(0).size() >= 3, "3 unidades de combate saem da fábrica")
	await wait(0.2)

	var s0: Vector2 = center(g.hud.slot_panels[0])
	var s1: Vector2 = center(g.hud.slot_panels[1])
	var s2: Vector2 = center(g.hud.slot_panels[2])
	touch(0, s0, true)
	await wait(0.05)
	drag(0, s1, s1 - s0)
	await wait(0.05)
	drag(0, s2, s2 - s1)
	await wait(0.05)
	touch(0, s2, false)
	await wait(0.1)
	check(g.selected.size() == 3, "arrastar na barra seleciona o grupo (%d)" % g.selected.size())

	await wait(0.5)
	await tap(s1)
	check(g.selected.size() == 1, "um toque na barra seleciona 1 unidade")
	await wait(0.5)
	await tap(s0, 0.04)
	await tap(s0, 0.04)
	check(g.selected.size() == 3, "dois toques na barra selecionam todas (%d)" % g.selected.size())

	g.cam_rig.call("focus", Vector3(-55, 0, 0))
	await wait(0.1)
	await tap(screen_of(Vector3(-40, 0, 4)))
	await wait(0.3)
	var ok := true
	var dbg := ""
	for id in g.selected:
		var u: SimEnt = g.world.by_id.get(id)
		dbg += " %s:%s:%d" % [u.type if u else "?", u.order if u else "-", u.dx if u else 0]
		if u == null or not (u.order == "amove" or u.order == "idle") or absi(u.dx + 4000) > 900:
			ok = false
	check(ok, "toque no chão manda o grupo mover atacando (%s, sel=%d)" % [dbg, g.selected.size()])
	await shot("04_ordem")

	touch(0, screen_of(Vector3(-60, 0, -10)), true)
	await wait(0.7)
	touch(0, screen_of(Vector3(-60, 0, -10)), false)
	await wait(0.3)
	ok = true
	for id in g.selected:
		var u: SimEnt = g.world.by_id.get(id)
		if u == null or u.order != "move":
			ok = false
	check(ok, "segurar no chão manda só mover (recuar)")

	var d0: float = g.cam_rig.get("distance")
	var c := Vector2(844, 400)
	touch(0, c - Vector2(60, 0), true)
	touch(1, c + Vector2(60, 0), true)
	await wait(0.05)
	drag(0, c - Vector2(160, 0), Vector2(-100, 0))
	drag(1, c + Vector2(160, 0), Vector2(100, 0))
	await wait(0.05)
	touch(0, c - Vector2(160, 0), false)
	touch(1, c + Vector2(160, 0), false)
	await wait(0.1)
	check(float(g.cam_rig.get("distance")) < d0 * 0.8, "pinça aproxima a câmera")

	var p0: Vector3 = g.cam_rig.position
	touch(0, Vector2(900, 450), true)
	for i in 6:
		drag(0, Vector2(900 - i * 30, 450), Vector2(-30, 0))
		await wait(0.02)
	touch(0, Vector2(750, 450), false)
	await wait(0.1)
	check(g.cam_rig.position.x > p0.x + 2.0, "arrastar no mapa move a câmera")
	g.cam_rig.set("distance", 70.0)
	g.cam_rig.call("zoom_by", 1.0)

	await tap(center(g.hud.minimap) + Vector2(60, 0))
	check(g.cam_rig.position.x > 20.0, "tocar no minimapa leva a câmera até o ponto")
	g.cam_rig.call("focus", Vector3(-45, 0, 0))

	# deixa a partida correr para capturar combate
	g.speed = 10.0
	t0 = g._clock
	var fought := false
	while g._clock - t0 < 40.0 and g.state == "playing":
		await wait(0.25)
		for ev in g.world.events:
			if ev["t"] == "shot":
				fought = true
		if fought:
			var a: SimEnt = null
			for e in g.world.ents:
				if e.kind == "unit" and e.aim >= 0:
					a = e
					break
			if a:
				g.cam_rig.call("focus", Vector3(a.x / 100.0, 0, a.y / 100.0))
				g.speed = 1.0
				await wait(0.4)
				await shot("05_combate")
				break
	check(fought, "a partida segue e há combate")
	_finish()


func _finish() -> void:
	print("\n==== TESTE DE TOQUE ====")
	print("barras de vida desenhadas: %d (chamadas de desenho: %d)" % [g.hud.bars_drawn, g.hud.bars_calls])
	var cam: Camera3D = g.cam_rig.get("cam")
	for e in g.world.army(0):
		var n: Node3D = g.view.nodes.get(e.id)
		if n:
			print("unidade %d pos=%s tela=%s atras=%s vp=%s bars_rect=%s vis=%s" % [e.id, n.position, cam.unproject_position(n.position + Vector3(0, 2.5, 0)), cam.is_position_behind(n.position), get_viewport().get_visible_rect().size, g.hud.bars.get_global_rect(), g.hud.bars.is_visible_in_tree()])
	for r in results:
		print(r)
	print("RESULTADO: %s" % ("OK" if fails == 0 else "%d FALHA(S)" % fails))
	get_tree().quit(0 if fails == 0 else 1)
