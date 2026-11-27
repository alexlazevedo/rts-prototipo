extends SceneTree
## Testes da simulação sem gráficos. Uso:
##   godot --headless --path . -s res://tests/test_sim.gd
## Verifica: determinismo, ciclo de contra-ataque nas duas facções, equilíbrio entre facções,
## caminho até o platô pela rampa, névoa de guerra, partidas de 4 bots.

var failures := 0


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var quick := "--quick" in OS.get_cmdline_user_args()
	test_determinism()
	test_counters()
	test_faction_parity()
	test_path()
	test_fog()
	test_core_and_tech()
	test_matches(quick)
	print("\nTEMPO TOTAL: %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("RESULTADO: %s" % ("OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(0 if failures == 0 else 1)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("  FALHOU: ", msg)


func run_match(seed: int, diffs: Array, factions: Array, max_ticks := Defs.MATCH_TICKS + 10) -> SimWorld:
	var w := SimWorld.new(seed, factions)
	var bots: Array = []
	for i in diffs.size():
		bots.append(SimBot.new(w, i, diffs[i]))
	while not w.over and w.tick < max_ticks:
		for b in bots:
			b.think()
		w.step()
	return w


func test_determinism() -> void:
	print("== Determinismo (4 jogadores)")
	var f := ["militar", "energia", "energia", "militar"]
	var a := run_match(7, ["normal", "dificil", "normal", "facil"], f, 2000)
	var b := run_match(7, ["normal", "dificil", "normal", "facil"], f, 2000)
	print("  hash A %s  hash B %s" % [a.state_hash().left(10), b.state_hash().left(10)])
	check(a.state_hash() == b.state_hash(), "mesma semente deveria gerar a mesma partida")


## Duelo em campo aberto: retorna [vencedor ("A"/"B"/"empate"), valor restante A, valor restante B]
func duel(ta: String, na: int, tb: String, nb: int) -> Array:
	var w := SimWorld.new(1, [Defs.UNITS[ta]["faction"], Defs.UNITS[tb]["faction"]])
	w.players[0]["techs"]["nivel2"] = true
	w.players[1]["techs"]["nivel2"] = true
	var A: Array = []
	var B: Array = []
	for i in na:
		A.append(w._spawn_unit(0, ta, -1500, 6000 + (i - na / 2) * 330).id)
	for i in nb:
		B.append(w._spawn_unit(1, tb, 1500, 6000 + (i - nb / 2) * 330).id)
	w.issue(0, {"kind": "amove", "ids": A, "x": 1500, "y": 6000})
	w.issue(1, {"kind": "amove", "ids": B, "x": -1500, "y": 6000})
	for t in 900:
		w.step()
	var va := 0
	var vb := 0
	for id in A:
		var e: SimEnt = w.by_id.get(id)
		if e:
			va += Defs.UNITS[ta]["cost"] * e.hp / e.max_hp
	for id in B:
		var e: SimEnt = w.by_id.get(id)
		if e:
			vb += Defs.UNITS[tb]["cost"] * e.hp / e.max_hp
	return ["A" if va > vb else ("B" if vb > va else "empate"), va, vb]


func test_counters() -> void:
	print("== Ciclo de contra-ataque (mesmo custo de cada lado)")
	for fac in Defs.FACTIONS:
		var R: Dictionary = Defs.ROSTER[fac]
		var cases := [
			[R["light"], 4, R["aa"], 3, "leve > antiaéreo"],
			[R["aa"], 5, R["air"], 4, "antiaéreo > aérea"],
			[R["air"], 6, R["heavy"], 5, "aérea > pesada"],
			[R["heavy"], 2, R["light"], 4, "pesada > leve"],
		]
		for c in cases:
			var r: Array = duel(c[0], c[1], c[2], c[3])
			print("  %-8s %-20s -> vence %s" % [fac, c[4], c[0] if r[0] == "A" else (c[2] if r[0] == "B" else "empate")])
			check(r[0] == "A", "%s: %s" % [fac, c[4]])


func test_faction_parity() -> void:
	print("== Militar x Energia, mesmo papel e mesmo custo (valor que sobra de cada lado)")
	var M: Dictionary = Defs.ROSTER["militar"]
	var E: Dictionary = Defs.ROSTER["energia"]
	var lopsided := 0
	for role in ["light", "heavy", "aa", "air"]:
		var n := 4
		var r: Array = duel(M[role], n, E[role], n)
		if role == "aa" or role == "air":
			# antiaéreo só atira em aéreos e aéreos só em terrestres: medir contra o papel que eles combatem
			var opp := "air" if role == "aa" else "heavy"
			var r1: Array = duel(M[role], 4, E[opp], 3)
			var r2: Array = duel(E[role], 4, M[opp], 3)
			print("  %-6s  M.%s x E.%s sobra %d | E.%s x M.%s sobra %d" % [role, M[role], E[opp], r1[1], E[role], M[opp], r2[1]])
			if r1[1] * 3 < r2[1] or r2[1] * 3 < r1[1]:
				lopsided += 1
		else:
			print("  %-6s  %s x %s -> vence %s  (sobra %d x %d)" % [role, M[role], E[role], r[0], r[1], r[2]])
			if r[1] > 0 and r[2] == 0 and r[1] > Defs.UNITS[M[role]]["cost"] * n * 6 / 10:
				lopsided += 1
			if r[2] > 0 and r[1] == 0 and r[2] > Defs.UNITS[E[role]]["cost"] * n * 6 / 10:
				lopsided += 1
	check(lopsided == 0, "facções desequilibradas em %d papel(éis)" % lopsided)


func test_path() -> void:
	print("== Caminho: do chão até o topo do platô pela rampa")
	var w := SimWorld.new(1, ["militar", "militar"])
	var u := w._spawn_unit(0, "buggy", -3000, 6000)
	w.issue(0, {"kind": "move", "ids": [u.id], "x": -11500, "y": 11500})
	w.step()
	var ok_cells := true
	var t := 1
	while t < 900 and u.order == "move":
		w.step()
		if w.static_block[w.cell_idx(u.x, u.y)] != 0:
			ok_cells = false
		t += 1
	var h := w.height_at(u.x, u.y)
	print("  chegou em %.1f s, altura final %d cm, posição (%d, %d)" % [t / 10.0, h, u.x, u.y])
	check(u.order != "move" and h == Defs.PLATEAU_H, "unidade deveria chegar ao topo do platô")
	check(ok_cells, "unidade atravessou o penhasco")


func test_fog() -> void:
	print("== Névoa de guerra")
	var w := SimWorld.new(1, ["militar", "militar"])
	var a := w._spawn_unit(0, "buggy", 0, 6000)
	var b := w._spawn_unit(1, "buggy", 2600, 6000)
	for i in 6:
		w.step()
	print("  a 26 m: visível=%s, mira=%d" % [w.visible_to(0, b), a.aim])
	check(not w.visible_to(0, b) and a.aim < 0, "inimigo fora da visão não deveria ser visto nem atacado")
	b.x = 1100
	for i in 6:
		w.step()
	print("  a 11 m: visível=%s, mira=%d" % [w.visible_to(0, b), a.aim])
	check(w.visible_to(0, b) and a.aim == b.id, "inimigo dentro da visão deveria ser atacado")


func test_core_and_tech() -> void:
	print("== Núcleo e laboratório")
	var w := SimWorld.new(1, ["militar", "energia"])
	var u := w._spawn_unit(0, "buggy", 300, 0)
	for i in 300:
		w.step()
	print("  30 s sozinho no centro: Núcleo = %d" % w.players[0]["core"])
	check(w.players[0]["core"] >= 25, "controlar o centro deveria render Núcleo")
	w._spawn_unit(1, "sentinela", -300, 300)
	var c0: int = w.players[0]["core"]
	for i in 3:
		w.step()
	check(w.core_owner == -1, "centro disputado não deveria ter dono")
	w.players[0]["ore"] = 1000
	var base := w.base_of(0)
	var fab := w._spawn_building(0, "fabrica", base.x - 1900, base.y + 2400, true)
	var lab := w._spawn_building(0, "laboratorio", base.x - 1900, base.y - 2400, true)
	check(w.can_train(0, fab, "tanque") != "", "tanque deveria exigir Nível 2")
	w.issue(0, {"kind": "research", "building": lab.id, "tech": "nivel2"})
	for i in 260:
		w.step()
	check(w.has_tech(0, "nivel2") and w.can_train(0, fab, "tanque") == "", "Nível 2 deveria liberar o tanque")
	print("  Nível 2 pesquisado: %s; tanque liberado: %s" % [w.has_tech(0, "nivel2"), w.can_train(0, fab, "tanque") == ""])


func test_matches(quick: bool) -> void:
	print("== Partidas de 4 bots (todos contra todos)")
	var cfgs := [
		[["normal", "normal", "normal", "normal"], ["militar", "energia", "militar", "energia"]],
		[["normal", "normal", "normal", "normal"], ["energia", "militar", "energia", "militar"]],
		[["dificil", "facil", "facil", "facil"], ["militar", "energia", "energia", "militar"]],
		[["dificil", "dificil", "normal", "normal"], ["energia", "militar", "militar", "energia"]],
	]
	var seeds := [1] if quick else [1, 2]
	var durations: Array[int] = []
	var fac_wins := {"militar": 0, "energia": 0, "ninguém": 0}
	for c in cfgs:
		for seed in seeds:
			var t0 := Time.get_ticks_msec()
			var w := run_match(seed, c[0], c[1])
			durations.append(w.tick)
			var wf: String = w.players[w.winner]["faction"] if w.winner >= 0 else "ninguém"
			fac_wins[wf] += 1
			var cores := []
			for pl in w.players:
				cores.append(pl["core_total"])
			print("  %s %s s%d: %4.1f min  vence %s (%s, %s)  Núcleo %s  [%.1fs]" % [
				",".join(c[0]), ",".join(c[1]).replace("militar", "M").replace("energia", "E"), seed,
				w.tick / 600.0, str(w.winner), wf, w.end_reason, str(cores), (Time.get_ticks_msec() - t0) / 1000.0])
			check(w.over and w.tick <= Defs.MATCH_TICKS + 1, "partida deveria terminar em até 10 min")
	durations.sort()
	print("  duração mediana: %.1f min · vitórias por facção: %s" % [durations[durations.size() / 2] / 600.0, str(fac_wins)])
