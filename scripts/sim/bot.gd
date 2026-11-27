class_name SimBot
extends RefCounted
## Bot: joga pelas mesmas regras do humano — só lê o mundo e emite comandos via issue().
## Não recebe recursos extras. (No protótipo ele enxerga o mapa todo: ainda não há névoa.)
## A dificuldade muda a qualidade das decisões, não as regras.

const LEVELS := {
	"facil":   {"interval": 30, "workers": 4, "wave": 7, "counter": false, "towers": 0, "factories": 1, "retreat": 0, "focus": false},
	"normal":  {"interval": 10, "workers": 6, "wave": 6, "counter": true,  "towers": 1, "factories": 1, "retreat": 2, "focus": false},
	"dificil": {"interval": 4,  "workers": 6, "wave": 6, "counter": true,  "towers": 1, "factories": 1, "retreat": 0, "focus": true},
}

var w: SimWorld
var p := 1
var level := "normal"
var cfg: Dictionary
var attacking := false
var _rng := 1


func _init(world: SimWorld, player: int, difficulty := "normal") -> void:
	w = world
	p = player
	level = difficulty
	cfg = LEVELS[difficulty]
	_rng = (world.seed_value * 7919 + player * 104729) % 2147483647
	if _rng <= 0:
		_rng = 1


func _rand(n: int) -> int:
	_rng = (_rng * 48271) % 2147483647
	return _rng % n


func think() -> void:
	if w.over or not w.players[p]["alive"]:
		return
	if (w.tick + p * 3) % cfg["interval"] != 0:
		return
	var base: SimEnt = null
	var buildings := {}
	var workers := 0
	for e in w.ents:
		if e.owner != p:
			continue
		if e.kind == "building":
			if e.type == "base":
				base = e
			if not buildings.has(e.type):
				buildings[e.type] = []
			buildings[e.type].append(e)
		elif e.kind == "unit" and Defs.UNITS[e.type].get("worker", false):
			workers += 1
	if base == null:
		return
	_economy(base)
	_build_order(base, buildings)
	_production(buildings)
	_army(base)


# ------------------------------------------------------------------ economia
func _economy(base: SimEnt) -> void:
	if base.queue.is_empty() and w.queued_count(p, true) < cfg["workers"]:
		w.issue(p, {"kind": "train", "building": base.id, "type": "coletor"})


func _count(buildings: Dictionary, type: String) -> int:
	return buildings.get(type, []).size()


func _build_order(base: SimEnt, b: Dictionary) -> void:
	var ore: int = w.players[p]["ore"]
	var army_n := w.army(p).size()
	if _count(b, "fabrica") == 0:
		if ore >= 150:
			_place(base, "fabrica", 0)
		return
	if not w.has_built(p, "fabrica"):
		return
	if _count(b, "hangar") == 0 and ore >= 175 and (army_n >= 2 or w.tick > 1500):
		_place(base, "hangar", 1)
		return
	if _count(b, "torre") < cfg["towers"] and ore >= 100 and w.tick > 1200:
		_place(base, "torre", 2)
		return
	if _count(b, "fabrica") < cfg["factories"] and ore >= 300:
		_place(base, "fabrica", 3)


func _place(base: SimEnt, type: String, salt: int) -> void:
	## Procura um lugar válido perto da base, voltado para o centro do mapa.
	var toward := -1 if base.x > 0 else 1
	# direções em milésimos (cos, sen) de 0, ±35, ±70, ±110, ±150 graus — tabela fixa, sem trigonometria
	var dirs := [[1000, 0], [819, 574], [819, -574], [342, 940], [342, -940],
		[-342, 940], [-342, -940], [-866, 500], [-866, -500]]
	var dists := [1900, 2500, 3100]
	if type == "torre":
		dists = [2600, 3200]
	for di: int in dists:
		for k in dirs.size():
			var dv: Array = dirs[(k + salt) % dirs.size()]
			var x: int = base.x + toward * int(dv[0]) * di / 1000
			var y: int = base.y + int(dv[1]) * di / 1000
			if w.can_build(p, type, x, y) == "":
				w.issue(p, {"kind": "build", "type": type, "x": x, "y": y})
				return


# ------------------------------------------------------------------ produção
func _production(b: Dictionary) -> void:
	var enemy := {"light": 0, "heavy": 0, "aa": 0, "air": 0}
	var mine := {"light": 0, "heavy": 0, "aa": 0, "air": 0}
	for e in w.ents:
		if e.kind != "unit" or Defs.UNITS[e.type].get("worker", false):
			continue
		var c := e.cls()
		if e.owner == p:
			mine[c] += 1
		elif e.owner >= 0:
			enemy[c] += 1
	for type in ["fabrica", "hangar"]:
		for bld: SimEnt in b.get(type, []):
			if not bld.built or bld.queue.size() >= 1:
				continue
			var choice := _choose(bld.type, enemy, mine)
			if choice != "" and w.can_train(p, bld, choice) == "":
				w.issue(p, {"kind": "train", "building": bld.id, "type": choice})
				mine[Defs.UNITS[choice]["class"]] += 1


func _choose(btype: String, enemy: Dictionary, mine: Dictionary) -> String:
	var options: Array = Defs.BUILDINGS[btype]["produces"]
	if not cfg["counter"]:
		return options[_rand(options.size())]
	# necessidade de cada classe = o que derrota o que o inimigo tem, menos o que já tenho
	var need := {
		"heavy": 10 + enemy["light"] * 10,
		"air": 10 + enemy["heavy"] * 10,
		"light": 10 + enemy["aa"] * 10,
		"aa": 4 + enemy["air"] * 12,
	}
	var best := ""
	var best_v := -999
	for t: String in options:
		var c: String = Defs.UNITS[t]["class"]
		var v: int = need[c] - mine[c] * 6 + _rand(5)
		if v > best_v:
			best_v = v
			best = t
	return best


# ------------------------------------------------------------------ exército
func _army(base: SimEnt) -> void:
	var army := w.army(p)
	if army.is_empty():
		attacking = false
		return
	var ids: Array = []
	for u in army:
		ids.append(u.id)
	# defesa: inimigo perto dos meus prédios
	var threat: SimEnt = null
	var td := 0
	for e in w.ents:
		if e.owner < 0 or e.owner == p or e.kind != "unit":
			continue
		var dd := SimWorld.dist2(e.x, e.y, base.x, base.y)
		if dd < 5000 * 5000 and (threat == null or dd < td):
			threat = e
			td = dd
	if cfg["focus"]:
		_focus_fire(army)
	if threat:
		var free: Array = []
		for u in army:
			if u.order != "attack":
				free.append(u.id)
		if not free.is_empty():
			w.issue(p, {"kind": "amove", "ids": free, "x": threat.x, "y": threat.y})
		attacking = false
		return
	var enemy_base := _enemy_base()
	if enemy_base == null:
		return
	if not attacking and army.size() >= cfg["wave"]:
		attacking = true
	if attacking and army.size() <= cfg["retreat"]:
		attacking = false
		w.issue(p, {"kind": "move", "ids": ids, "x": base.rally_x, "y": base.rally_y})
		return
	if attacking:
		# reforços e grupo seguem para a base inimiga atacando no caminho
		var idle: Array = []
		for u in army:
			if u.order == "idle" or u.order == "amove":
				idle.append(u.id)
		if not idle.is_empty() and w.tick % 50 < cfg["interval"]:
			w.issue(p, {"kind": "amove", "ids": idle, "x": enemy_base.x, "y": enemy_base.y})


func _enemy_base() -> SimEnt:
	var best: SimEnt = null
	for e in w.ents:
		if e.kind == "building" and e.type == "base" and e.owner >= 0 and e.owner != p:
			if best == null or e.id < best.id:
				best = e
	return best


## Foco de fogo (difícil): cada unidade em combate ataca o inimigo ao alcance com menos
## vida, preferindo alvos contra os quais tem vantagem no ciclo de contra-ataque.
func _focus_fire(army: Array[SimEnt]) -> void:
	var orders := {}
	for u in army:
		if u.aim < 0:
			continue
		var d: Dictionary = Defs.UNITS[u.type]
		var reach: int = d["range"] + 300
		var best: SimEnt = null
		var best_v := 0
		for e in w.ents:
			if e.owner < 0 or e.owner == p or e.kind == "ore" or e.hp <= 0:
				continue
			if e.air and not d.get("hits_air", false):
				continue
			if not e.air and not d.get("hits_ground", false):
				continue
			var r := reach + e.radius
			if SimWorld.dist2(u.x, u.y, e.x, e.y) > r * r:
				continue
			var v := e.hp * 100 / Defs.bonus(d["class"], e.cls())
			if e.kind == "building":
				v += 5000
			if best == null or v < best_v:
				best = e
				best_v = v
		if best and best.id != u.target:
			if not orders.has(best.id):
				orders[best.id] = []
			orders[best.id].append(u.id)
	for tid in orders:
		w.issue(p, {"kind": "attack", "ids": orders[tid], "target": tid})
