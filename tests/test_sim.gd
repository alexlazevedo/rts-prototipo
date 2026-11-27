extends SceneTree
## Testes da simulação sem gráficos. Uso:
##   godot --headless --path . -s res://tests/test_sim.gd
## Verifica: determinismo, duração das partidas bot x bot, ciclo de contra-ataque.

var failures := 0


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	test_determinism()
	test_counters()
	test_matches()
	print("\nTEMPO TOTAL: %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("RESULTADO: %s" % ("OK" if failures == 0 else "%d FALHA(S)" % failures))
	quit(0 if failures == 0 else 1)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("  FALHOU: ", msg)


func run_match(seed: int, d0: String, d1: String, max_ticks := Defs.MATCH_TICKS + 10) -> SimWorld:
	var w := SimWorld.new(seed)
	var bots := [SimBot.new(w, 0, d0), SimBot.new(w, 1, d1)]
	while not w.over and w.tick < max_ticks:
		for b in bots:
			b.think()
		w.step()
	return w


func test_determinism() -> void:
	print("== Determinismo")
	var a := run_match(7, "normal", "dificil", 3000)
	var b := run_match(7, "normal", "dificil", 3000)
	var c := run_match(8, "normal", "dificil", 3000)
	print("  semente 7: %s / %s   semente 8: %s" % [a.state_hash().left(10), b.state_hash().left(10), c.state_hash().left(10)])
	check(a.state_hash() == b.state_hash(), "mesma semente deveria gerar a mesma partida")


func duel(ta: String, na: int, tb: String, nb: int) -> String:
	var w := SimWorld.new(1)
	var A: Array = []
	var B: Array = []
	for i in na:
		A.append(w._spawn_unit(0, ta, -1800, (i - na / 2) * 320).id)
	for i in nb:
		B.append(w._spawn_unit(1, tb, 1800, (i - nb / 2) * 320).id)
	w.issue(0, {"kind": "amove", "ids": A, "x": 1800, "y": 0})
	w.issue(1, {"kind": "amove", "ids": B, "x": -1800, "y": 0})
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
	return "A" if va > vb else ("B" if vb > va else "empate")


func test_counters() -> void:
	print("== Ciclo de contra-ataque (mesmo custo de cada lado)")
	# pares (vencedor esperado, perdedor) com quantidades de custo parecido
	var cases := [
		["buggy", 4, "antiaereo", 3, "leve > antiaéreo"],
		["antiaereo", 5, "vtol", 4, "antiaéreo > aérea"],
		["vtol", 6, "tanque", 5, "aérea > pesada"],
		["tanque", 2, "buggy", 4, "pesada > leve"],
	]
	for c in cases:
		var r1 := duel(c[0], c[1], c[2], c[3])
		print("  %-20s -> vence %s" % [c[4], c[0] if r1 == "A" else (c[2] if r1 == "B" else "empate")])
		check(r1 == "A", c[4])


func test_matches() -> void:
	print("== Partidas bot x bot")
	var cfgs := [["normal", "normal"], ["dificil", "facil"], ["facil", "dificil"], ["dificil", "normal"], ["dificil", "dificil"]]
	var durations: Array[int] = []
	for c in cfgs:
		for seed in [1, 2, 3]:
			var w := run_match(seed, c[0], c[1])
			var mins := w.tick / 600.0
			durations.append(w.tick)
			print("  %-8s x %-8s s%d: %5.1f min  vencedor=%s  (%s)  minério=%d/%d  abates=%d/%d" % [
				c[0], c[1], seed, mins, str(w.winner), w.end_reason,
				w.players[0]["mined"], w.players[1]["mined"], w.players[0]["killed"], w.players[1]["killed"]])
			check(w.over, "partida deveria terminar")
			check(w.tick <= Defs.MATCH_TICKS + 1, "partida passou de 10 min")
	durations.sort()
	print("  duração mediana: %.1f min" % (durations[durations.size() / 2] / 600.0))
