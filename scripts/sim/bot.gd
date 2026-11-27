class_name SimBot
extends RefCounted
## Bot: joga pelas mesmas regras do humano — lê o mundo e emite comandos via issue().
## Não recebe recursos extras e só reage ao que suas unidades veem (névoa de guerra).
## Conhece as posições iniciais das bases (como qualquer jogador, o mapa é conhecido).
## Dificuldade = qualidade das decisões; estilo = personalidade.

const LEVELS := {
	"facil":   {"interval": 30, "workers": 4, "wave": 7, "counter": false, "towers": 0, "retreat": 0, "focus": false, "tech": false},
	"normal":  {"interval": 10, "workers": 6, "wave": 6, "counter": true,  "towers": 1, "retreat": 2, "focus": false, "tech": true},
	"dificil": {"interval": 4,  "workers": 6, "wave": 6, "counter": true,  "towers": 1, "retreat": 0, "focus": true,  "tech": true},
}
const STYLES := ["agressivo", "nucleo", "defensivo"]

var w: SimWorld
var p := 1
var level := "normal"
var style := "agressivo"
var cfg: Dictionary
var faction := "militar"
var attacking := false
var target_player := -1
var memory := {"light": 0, "heavy": 0, "aa": 0, "air": 0}
var enemy_army := {}             # jogador -> maior exército visto
var _rng := 1


func _init(world: SimWorld, player: int, difficulty := "normal", p_style := "") -> void:
	w = world
	p = player
	level = difficulty
	cfg = LEVELS[difficulty].duplicate()
	style = p_style if p_style != "" else STYLES[(player + 2) % 3]
	faction = w.players[p]["faction"]
	if style == "agressivo":
		cfg["wave"] = maxi(4, cfg["wave"] - 1)
	elif style == "defensivo":
		cfg["wave"] += 2
		cfg["towers"] += 1
	_rng = (world.seed_value * 7919 + player * 104729) % 2147483647
	if _rng <= 0:
		_rng = 1


func _rand(n: int) -> int:
	_rng = (_rng * 48271) % 2147483647
	return _rng % n


func T(role: String) -> String:
	return Defs.type_for(faction, role)


func think() -> void:
	if w.over or not w.players[p]["alive"]:
		return
	if (w.tick + p * 3) % cfg["interval"] != 0:
		return
	var base := w.base_of(p)
	if base == null:
		return
	var by_role := {}
	for e in w.ents:
		if e.owner == p and e.kind == "building":
			var r: String = Defs.BUILDINGS[e.type]["role"]
			if not by_role.has(r):
				by_role[r] = []
			by_role[r].append(e)
	_observe()
	_economy(base)
	_build_order(base, by_role)
	_research(by_role)
	_production(by_role)
	_army(base)


# ------------------------------------------------------------------ o que eu vejo
func _observe() -> void:
	var now := {"light": 0, "heavy": 0, "aa": 0, "air": 0}
	var per_player := {}
	for e in w.ents:
		if e.owner < 0 or e.owner == p or not e.is_combat() or not w.visible_to(p, e):
			continue
		now[e.cls()] += 1
		per_player[e.owner] = per_player.get(e.owner, 0) + 1
	for c in memory:
		memory[c] = maxi(now[c], memory[c] - (1 if w.tick % 300 < cfg["interval"] else 0))
	for q in per_player:
		enemy_army[q] = maxi(enemy_army.get(q, 0), per_player[q])


# ------------------------------------------------------------------ economia e construção
func _economy(base: SimEnt) -> void:
	if base.queue.is_empty() and w.queued_count(p, true) < cfg["workers"]:
		w.issue(p, {"kind": "train", "building": base.id, "type": T("worker")})


func _count(b: Dictionary, role: String) -> int:
	return b.get(role, []).size()


func _build_order(base: SimEnt, b: Dictionary) -> void:
	var ore: int = w.players[p]["ore"]
	var army_n := w.army(p).size()
	if _count(b, "fabrica") == 0:
		if ore >= 150:
			_place(base, T("fabrica"), 0)
		return
	if not w.has_built(p, "fabrica"):
		return
	if cfg["tech"] and _count(b, "lab") == 0 and ore >= 150 and (army_n >= 3 or w.tick > 1800):
		_place(base, T("lab"), 2)
		return
	if _count(b, "hangar") == 0 and ore >= 175 and (army_n >= 2 or w.tick > 1500):
		_place(base, T("hangar"), 1)
		return
	if _count(b, "torre") < cfg["towers"] and ore >= 100 and w.tick > 1200:
		_place(base, T("torre"), 3)


func _place(base: SimEnt, type: String, salt: int) -> void:
	## Procura um lugar válido no platô da base, longe da rampa.
	var away := -1 if base.x < 0 else 1       # rampa fica do lado do centro; prédios vão para o fundo
	var dirs := [[0, 1000], [0, -1000], [707, 707], [707, -707], [1000, 0], [-707, 707], [-707, -707], [-1000, 0], [383, 924], [383, -924]]
	var dists := [1900, 2400]
	if Defs.BUILDINGS[type]["role"] == "torre":
		dists = [2500, 2000]
	for di: int in dists:
		for k in dirs.size():
			var dv: Array = dirs[(k + salt) % dirs.size()]
			var x: int = base.x + away * int(dv[0]) * di / 1000
			var y: int = base.y + int(dv[1]) * di / 1000
			if Defs.BUILDINGS[type]["role"] == "torre":
				x = base.x - away * 2300
				y = base.y + (1 if k % 2 == 0 else -1) * (600 + 400 * (k / 2))
			if w.can_build(p, type, x, y) == "":
				w.issue(p, {"kind": "build", "type": type, "x": x, "y": y})
				return


func _research(b: Dictionary) -> void:
	if not cfg["tech"]:
		return
	for lab: SimEnt in b.get("lab", []):
		for tech in ["nivel2", "armas"]:
			if w.can_research(p, lab, tech) == "":
				w.issue(p, {"kind": "research", "building": lab.id, "tech": tech})
				return


# ------------------------------------------------------------------ produção
func _production(b: Dictionary) -> void:
	var mine := {"light": 0, "heavy": 0, "aa": 0, "air": 0}
	for u in w.army(p):
		mine[u.cls()] += 1
	for role in ["fabrica", "hangar"]:
		for bld: SimEnt in b.get(role, []):
			if not bld.built or bld.queue.size() >= 1:
				continue
			var choice := _choose(bld, mine)
			if choice != "":
				w.issue(p, {"kind": "train", "building": bld.id, "type": choice})
				mine[Defs.UNITS[choice]["class"]] += 1


func _choose(bld: SimEnt, mine: Dictionary) -> String:
	var options: Array = []
	for t: String in Defs.BUILDINGS[bld.type]["produces"]:
		if w.can_train(p, bld, t) == "":
			options.append(t)
	if options.is_empty():
		return ""
	if not cfg["counter"]:
		return options[_rand(options.size())]
	var e := memory
	var need := {
		"heavy": 10 + e["light"] * 10,
		"air": 10 + e["heavy"] * 10,
		"light": 10 + e["aa"] * 10,
		"aa": 4 + e["air"] * 12,
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
	if cfg["focus"]:
		_focus_fire(army)
	# defesa: inimigo visível perto da base
	var threat: SimEnt = null
	var td := 0
	for e in w.ents:
		if e.owner < 0 or e.owner == p or e.kind != "unit" or not w.visible_to(p, e):
			continue
		var dd := SimWorld.dist2(e.x, e.y, base.x, base.y)
		if dd < 5500 * 5500 and (threat == null or dd < td):
			threat = e
			td = dd
	if threat:
		_send(army, "amove", threat.x, threat.y, true)
		attacking = false
		return
	if not attacking and army.size() >= cfg["wave"]:
		attacking = true
		target_player = _pick_target(base)
	# ataque perdeu força: reagrupa na base em vez de mandar reforço um a um
	var regroup := maxi(cfg["retreat"], cfg["wave"] / 2 - 1)
	if attacking and (army.size() <= regroup or target_player < 0 or not w.players[target_player]["alive"]):
		attacking = false
		if army.size() <= regroup:
			_send(army, "move", base.rally_x, base.rally_y, false)
			return
	if attacking:
		var eb := w.base_of(target_player)
		if eb and w.tick % 50 < cfg["interval"]:
			_send(army, "amove", eb.x, eb.y, true)
		return
	# sem ataque: segurar o Núcleo (estilo Núcleo sempre; os outros quando têm tropa sobrando)
	var hold: bool = style == "nucleo" or (army.size() >= 4 and cfg["tech"])
	if hold and w.core_owner != p and w.tick % 40 < cfg["interval"]:
		_send(army, "amove", 0, 0, true)


func _send(army: Array[SimEnt], kind: String, x: int, y: int, only_free: bool) -> void:
	var ids: Array = []
	for u in army:
		if only_free and u.order == "attack":
			continue
		ids.append(u.id)
	if not ids.is_empty():
		w.issue(p, {"kind": kind, "ids": ids, "x": x, "y": y})


func _pick_target(base: SimEnt) -> int:
	var best := -1
	var best_v := 0
	for q in w.players.size():
		if q == p or not w.players[q]["alive"]:
			continue
		var eb := w.base_of(q)
		if eb == null:
			continue
		var dist := SimWorld.isqrt(SimWorld.dist2(base.x, base.y, eb.x, eb.y)) / 100
		var v := dist
		if style != "agressivo":
			v += enemy_army.get(q, 3) * 40     # prefere quem parece mais fraco
		if best < 0 or v < best_v:
			best = q
			best_v = v
	return best


## Foco de fogo (difícil): cada unidade em combate ataca o inimigo visível ao alcance com
## menos vida, preferindo alvos contra os quais tem vantagem no ciclo de contra-ataque.
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
			if e.owner < 0 or e.owner == p or not (e.kind == "unit" or e.kind == "building") or e.hp <= 0:
				continue
			if not w.visible_to(p, e):
				continue
			if e.air and not d.get("hits_air", false):
				continue
			if not e.air and not d.get("hits_ground", false):
				continue
			var r := reach + e.radius
			if SimWorld.dist2(u.x, u.y, e.x, e.y) > r * r:
				continue
			var v := (e.hp + e.shield) * 100 / Defs.bonus(d["class"], e.cls())
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
