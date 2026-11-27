class_name SimWorld
extends RefCounted
## Simulação determinística do RTS.
## Regras: só inteiros, ordem de processamento fixa (por id), nenhuma dependência de
## Nodes, tempo real ou aleatório global. Mesmos comandos + mesma semente = mesma partida.
## Jogador humano e bots só mudam o mundo via issue(); a tela só lê.

var tick := 0
var ents: Array[SimEnt] = []
var by_id: Dictionary = {}
var next_id := 1
var players: Array[Dictionary] = []
var pending: Array[Dictionary] = []
var events: Array[Dictionary] = []       # eventos do último tick (tiros, mortes...) para a tela
var over := false
var winner := -1
var end_reason := ""
var seed_value := 1


func _init(p_seed := 1, n_players := 2) -> void:
	seed_value = p_seed
	for i in n_players:
		players.append({"ore": Defs.START_ORE, "alive": true, "mined": 0, "lost": 0, "killed": 0})
	_setup_map()


# ------------------------------------------------------------------ mapa
func _setup_map() -> void:
	for p in players.size():
		var s := -1 if p == 0 else 1
		var bx := s * 9000
		var b := _spawn_building(p, "base", bx, 0, true)
		b.rally_x = bx - s * 1600
		b.rally_y = 0
		_spawn_ore(bx + s * 1500, 3300, 1800)
		_spawn_ore(bx + s * 1500, -3300, 1800)
		for i in Defs.START_WORKERS:
			var w := _spawn_unit(p, "coletor", bx - s * 1100, (i - 1) * 300)
			w.order = "harvest"
	_spawn_ore(0, 5600, 3000)
	_spawn_ore(0, -5600, 3000)


func _add(e: SimEnt) -> SimEnt:
	e.id = next_id
	next_id += 1
	e.px = e.x
	e.py = e.y
	ents.append(e)
	by_id[e.id] = e
	return e


func _spawn_unit(owner: int, type: String, x: int, y: int) -> SimEnt:
	var d: Dictionary = Defs.UNITS[type]
	var e := SimEnt.new()
	e.owner = owner
	e.kind = "unit"
	e.type = type
	e.x = x
	e.y = y
	e.hp = d["hp"]
	e.max_hp = d["hp"]
	e.radius = d["radius"]
	e.air = d["air"]
	return _add(e)


func _spawn_building(owner: int, type: String, x: int, y: int, done: bool) -> SimEnt:
	var d: Dictionary = Defs.BUILDINGS[type]
	var e := SimEnt.new()
	e.owner = owner
	e.kind = "building"
	e.type = type
	e.x = x
	e.y = y
	e.max_hp = d["hp"]
	e.hp = d["hp"] if done else maxi(1, d["hp"] / 10)
	e.radius = d["radius"]
	e.built = done
	# ponto de encontro: em direção ao centro do mapa
	var dist := maxi(1, isqrt(x * x + y * y))
	var off: int = e.radius + 700
	e.rally_x = x - x * off / dist
	e.rally_y = y - y * off / dist
	return _add(e)


func _spawn_ore(x: int, y: int, amount: int) -> SimEnt:
	var e := SimEnt.new()
	e.kind = "ore"
	e.type = "minerio"
	e.x = x
	e.y = y
	e.radius = Defs.ORE_RADIUS
	e.amount = amount
	e.hp = 1
	e.max_hp = amount
	return _add(e)


# ------------------------------------------------------------------ comandos
## Comandos (Dictionary):
##   {"kind":"move"|"amove", "ids":[...], "x":cm, "y":cm}
##   {"kind":"attack", "ids":[...], "target":id}
##   {"kind":"train", "building":id, "type":"buggy"}
##   {"kind":"build", "type":"fabrica", "x":cm, "y":cm}
func issue(player: int, cmd: Dictionary) -> void:
	var c := cmd.duplicate()
	c["player"] = player
	pending.append(c)


func _apply_commands() -> void:
	var cmds := pending
	pending = []
	for c in cmds:
		var p: int = c["player"]
		if p < 0 or p >= players.size() or not players[p]["alive"]:
			continue
		match c.get("kind", ""):
			"move", "amove":
				_cmd_move(p, c["ids"], int(c["x"]), int(c["y"]), c["kind"])
			"attack":
				var t: SimEnt = by_id.get(int(c["target"]))
				if t == null:
					continue
				for id in c["ids"]:
					var e: SimEnt = by_id.get(int(id))
					if e and e.owner == p and e.kind == "unit" and not Defs.UNITS[e.type].get("worker", false):
						e.order = "attack"
						e.target = t.id
			"train":
				_cmd_train(p, int(c["building"]), String(c["type"]))
			"build":
				_cmd_build(p, String(c["type"]), int(c["x"]), int(c["y"]))


func _cmd_move(p: int, ids: Array, x: int, y: int, kind: String) -> void:
	var units: Array[SimEnt] = []
	for id in ids:
		var e: SimEnt = by_id.get(int(id))
		if e and e.owner == p and e.kind == "unit":
			units.append(e)
	units.sort_custom(func(a: SimEnt, b: SimEnt) -> bool: return a.id < b.id)
	var n := units.size()
	if n == 0:
		return
	var cols := maxi(1, isqrt(n - 1) + 1)
	var rows := (n + cols - 1) / cols
	var gap := 380
	for i in n:
		var e := units[i]
		var ox := (i % cols) * gap - (cols - 1) * gap / 2
		var oy := (i / cols) * gap - (rows - 1) * gap / 2
		e.dx = clampi(x + ox, -Defs.HALF_W, Defs.HALF_W)
		e.dy = clampi(y + oy, -Defs.HALF_H, Defs.HALF_H)
		e.target = -1
		if Defs.UNITS[e.type].get("worker", false):
			e.order = "move"
		else:
			e.order = kind


func queued_count(p: int, worker: bool) -> int:
	var n := 0
	for e in ents:
		if e.owner != p:
			continue
		if e.kind == "unit" and Defs.UNITS[e.type].get("worker", false) == worker:
			n += 1
		elif e.kind == "building":
			for t in e.queue:
				if Defs.UNITS[t].get("worker", false) == worker:
					n += 1
	return n


func can_train(p: int, b: SimEnt, type: String) -> String:
	## Retorna "" se pode; senão o motivo (para a tela mostrar).
	if b == null or b.owner != p or b.kind != "building" or not b.built:
		return "prédio indisponível"
	if not (type in Defs.BUILDINGS[b.type]["produces"]):
		return "não produz aqui"
	var d: Dictionary = Defs.UNITS[type]
	if players[p]["ore"] < d["cost"]:
		return "minério insuficiente"
	if b.queue.size() >= 5:
		return "fila cheia"
	var worker: bool = d.get("worker", false)
	var cap := Defs.WORKER_CAP if worker else Defs.COMBAT_CAP
	if queued_count(p, worker) >= cap:
		return "limite de %d" % cap
	return ""


func _cmd_train(p: int, bid: int, type: String) -> void:
	var b: SimEnt = by_id.get(bid)
	if can_train(p, b, type) != "":
		return
	players[p]["ore"] -= Defs.UNITS[type]["cost"]
	b.queue.append(type)


func has_built(p: int, type: String) -> bool:
	for e in ents:
		if e.owner == p and e.kind == "building" and e.type == type and e.built:
			return true
	return false


func can_build(p: int, type: String, x: int, y: int) -> String:
	if not Defs.BUILDINGS.has(type) or type == "base":
		return "tipo inválido"
	var d: Dictionary = Defs.BUILDINGS[type]
	if players[p]["ore"] < d["cost"]:
		return "minério insuficiente"
	var req: String = d["req"]
	if req != "" and not has_built(p, req):
		return "precisa de %s" % req
	var r: int = d["radius"]
	if absi(x) > Defs.HALF_W - r or absi(y) > Defs.HALF_H - r:
		return "fora do mapa"
	var near := false
	for e in ents:
		var min_d := r + e.radius + 150
		if dist2(x, y, e.x, e.y) < min_d * min_d and e.kind != "unit":
			return "local ocupado"
		if e.owner == p and e.kind == "building" and dist2(x, y, e.x, e.y) <= Defs.BUILD_RANGE * Defs.BUILD_RANGE:
			near = true
	if not near:
		return "longe demais da base"
	return ""


func _cmd_build(p: int, type: String, x: int, y: int) -> void:
	if can_build(p, type, x, y) != "":
		return
	players[p]["ore"] -= Defs.BUILDINGS[type]["cost"]
	_spawn_building(p, type, x, y, false)


# ------------------------------------------------------------------ passo
func step() -> void:
	if over:
		return
	events.clear()
	for e in ents:
		e.px = e.x
		e.py = e.y
	_apply_commands()
	var snapshot := ents.duplicate()
	for e: SimEnt in snapshot:
		if e.hp <= 0:
			continue
		if e.kind == "building":
			_update_building(e)
		elif e.kind == "unit":
			if Defs.UNITS[e.type].get("worker", false):
				_update_worker(e)
			else:
				_update_combat(e, Defs.UNITS[e.type], true)
	_separate()
	_resolve_deaths()
	tick += 1
	_check_end()


# ------------------------------------------------------------------ prédios
func _update_building(e: SimEnt) -> void:
	var d: Dictionary = Defs.BUILDINGS[e.type]
	if not e.built:
		e.progress += 1
		var t: int = d["time"]
		e.hp = mini(e.max_hp, e.max_hp / 10 + e.max_hp * 9 / 10 * e.progress / t)
		if e.progress >= t:
			e.built = true
			events.append({"t": "built", "id": e.id})
		return
	if d.has("dmg"):
		e.cd = maxi(0, e.cd - 1)
		_update_combat(e, d, false)
	if e.queue.is_empty():
		return
	var type: String = e.queue[0]
	var ud: Dictionary = Defs.UNITS[type]
	var worker: bool = ud.get("worker", false)
	var cap := Defs.WORKER_CAP if worker else Defs.COMBAT_CAP
	if _alive_count(e.owner, worker) >= cap:
		return
	e.qprog += 1
	if e.qprog < ud["time"]:
		return
	e.queue.pop_front()
	e.qprog = 0
	var vx := e.rally_x - e.x
	var vy := e.rally_y - e.y
	var dist := maxi(1, isqrt(vx * vx + vy * vy))
	var off: int = e.radius + ud["radius"] + 60
	var u := _spawn_unit(e.owner, type, e.x + vx * off / dist, e.y + vy * off / dist)
	if worker:
		u.order = "harvest"
	else:
		u.order = "amove"
		u.dx = e.rally_x
		u.dy = e.rally_y
	events.append({"t": "spawn", "id": u.id})


func _alive_count(p: int, worker: bool) -> int:
	var n := 0
	for e in ents:
		if e.owner == p and e.kind == "unit" and Defs.UNITS[e.type].get("worker", false) == worker:
			n += 1
	return n


# ------------------------------------------------------------------ combate
func _can_hit(d: Dictionary, t: SimEnt) -> bool:
	if t.air:
		return d.get("hits_air", false)
	return d.get("hits_ground", false)


func _valid_enemy(e: SimEnt, d: Dictionary, t: SimEnt) -> bool:
	return t != null and t.hp > 0 and t.owner >= 0 and t.owner != e.owner and t.kind != "ore" and _can_hit(d, t)


func _acquire(e: SimEnt, d: Dictionary, reach: int) -> SimEnt:
	var best: SimEnt = null
	var best_pri := 9
	var best_d := 0
	for t in ents:
		if not _valid_enemy(e, d, t):
			continue
		var r := reach + t.radius
		var dd := dist2(e.x, e.y, t.x, t.y)
		if dd > r * r:
			continue
		var pri := 2
		if t.kind == "unit":
			pri = 1 if Defs.UNITS[t.type].get("worker", false) else 0
		elif t.type == "torre":
			pri = 1
		if best == null or pri < best_pri or (pri == best_pri and dd < best_d):
			best = t
			best_pri = pri
			best_d = dd
	return best


func _update_combat(e: SimEnt, d: Dictionary, mobile: bool) -> void:
	if mobile:
		e.cd = maxi(0, e.cd - 1)
	var rng: int = d["range"]
	var t: SimEnt = by_id.get(e.target)
	if not _valid_enemy(e, d, t):
		t = null
		e.target = -1
		if e.order == "attack":
			e.order = "idle"
	if t == null and e.order != "move":
		var extra := 450 if e.order == "idle" else 700
		if not mobile:
			extra = 0
		t = _acquire(e, d, rng + extra)
	e.aim = t.id if t else -1
	if t:
		var reach := rng + t.radius
		if dist2(e.x, e.y, t.x, t.y) <= reach * reach:
			if e.cd == 0:
				_shoot(e, d, t)
				e.cd = d["cd"]
			return
		if mobile and e.order != "move":
			_move_toward(e, t.x, t.y, d["speed"])
			return
	if mobile and (e.order == "move" or e.order == "amove"):
		if _move_toward(e, e.dx, e.dy, d["speed"]):
			e.order = "idle"


func _shoot(e: SimEnt, d: Dictionary, t: SimEnt) -> void:
	var dmg: int = d["dmg"] * Defs.bonus(d.get("class", ""), t.cls()) / 100
	if t.type == "base" and tick >= Defs.ARMOR_OFF_TICK:
		dmg *= 2
	t.hp -= dmg
	events.append({"t": "shot", "a": e.id, "b": t.id, "air": e.air})
	if t.hp <= 0:
		players[e.owner]["killed"] += 1


# ------------------------------------------------------------------ coletor
func _update_worker(e: SimEnt) -> void:
	var sp: int = Defs.UNITS["coletor"]["speed"]
	match e.order:
		"move":
			if _move_toward(e, e.dx, e.dy, sp):
				e.order = "harvest" if e.carry == 0 else "return"
		"harvest":
			var f: SimEnt = by_id.get(e.ore_target)
			if f == null or f.kind != "ore" or f.amount <= 0:
				f = _nearest(e, "ore", -1)
				e.ore_target = f.id if f else -1
			if f == null:
				e.order = "idle"
				return
			var reach := f.radius + e.radius + 60
			if dist2(e.x, e.y, f.x, f.y) <= reach * reach:
				e.work += 1
				if e.work >= Defs.HARVEST_TICKS:
					var take := mini(Defs.CARRY, f.amount)
					f.amount -= take
					e.carry = take
					e.work = 0
					e.order = "return"
			else:
				_move_toward(e, f.x, f.y, sp)
		"return":
			var b := _nearest_base(e)
			if b == null:
				e.order = "idle"
				return
			var reach := b.radius + e.radius + 80
			if dist2(e.x, e.y, b.x, b.y) <= reach * reach:
				players[e.owner]["ore"] += e.carry
				players[e.owner]["mined"] += e.carry
				e.carry = 0
				e.order = "harvest"
			else:
				_move_toward(e, b.x, b.y, sp)
		_:
			e.order = "harvest" if e.carry == 0 else "return"


func _nearest(e: SimEnt, kind: String, owner: int) -> SimEnt:
	var best: SimEnt = null
	var bd := 0
	for t in ents:
		if t.kind != kind or t.hp <= 0 or (owner >= 0 and t.owner != owner):
			continue
		if kind == "ore" and t.amount <= 0:
			continue
		var dd := dist2(e.x, e.y, t.x, t.y)
		if best == null or dd < bd:
			best = t
			bd = dd
	return best


func _nearest_base(e: SimEnt) -> SimEnt:
	var best: SimEnt = null
	var bd := 0
	for t in ents:
		if t.owner == e.owner and t.kind == "building" and t.type == "base" and t.built:
			var dd := dist2(e.x, e.y, t.x, t.y)
			if best == null or dd < bd:
				best = t
				bd = dd
	return best


# ------------------------------------------------------------------ movimento
## Move em linha reta; retorna true ao chegar.
func _move_toward(e: SimEnt, tx: int, ty: int, speed: int) -> bool:
	var vx := tx - e.x
	var vy := ty - e.y
	var dist := isqrt(vx * vx + vy * vy)
	if dist <= speed:
		e.x = tx
		e.y = ty
		return true
	e.x += vx * speed / dist
	e.y += vy * speed / dist
	return false


func _separate() -> void:
	var units: Array[SimEnt] = []
	var solids: Array[SimEnt] = []
	for e in ents:
		if e.hp <= 0 and e.kind != "ore":
			continue
		if e.kind == "unit":
			units.append(e)
		else:
			solids.append(e)
	var n := units.size()
	for i in n:
		var a := units[i]
		for j in range(i + 1, n):
			var b := units[j]
			if a.air != b.air:
				continue
			var min_d := a.radius + b.radius
			var vx := b.x - a.x
			var vy := b.y - a.y
			var dd := vx * vx + vy * vy
			if dd >= min_d * min_d:
				continue
			var dist := isqrt(dd)
			if dist == 0:
				vx = 1 if (a.id + b.id) % 2 == 0 else -1
				vy = 0
				dist = 1
			var push := (min_d - dist) / 2 + 1
			a.x -= vx * push / dist
			a.y -= vy * push / dist
			b.x += vx * push / dist
			b.y += vy * push / dist
	for u in units:
		if u.air:
			continue
		for s in solids:
			var min_d := u.radius + s.radius
			var vx := u.x - s.x
			var vy := u.y - s.y
			var dd := vx * vx + vy * vy
			if dd >= min_d * min_d:
				continue
			var dist := maxi(1, isqrt(dd))
			var push := min_d - dist + 1
			# empurra para fora e um pouco para o lado, para contornar o obstáculo
			var side := 1 if (u.id % 2 == 0) else -1
			u.x += vx * push / dist - side * vy * push / (dist * 2)
			u.y += vy * push / dist + side * vx * push / (dist * 2)
	for u in units:
		u.x = clampi(u.x, -Defs.HALF_W, Defs.HALF_W)
		u.y = clampi(u.y, -Defs.HALF_H, Defs.HALF_H)


# ------------------------------------------------------------------ mortes e fim
func _resolve_deaths() -> void:
	var keep: Array[SimEnt] = []
	for e in ents:
		var dead := (e.kind != "ore" and e.hp <= 0) or (e.kind == "ore" and e.amount <= 0)
		if dead:
			by_id.erase(e.id)
			events.append({"t": "die", "id": e.id, "x": e.x, "y": e.y, "type": e.type, "kind": e.kind, "owner": e.owner})
			if e.owner >= 0:
				players[e.owner]["lost"] += 1
		else:
			keep.append(e)
	ents = keep


func _check_end() -> void:
	var alive: Array[int] = []
	for p in players.size():
		var has_base := false
		for e in ents:
			if e.owner == p and e.kind == "building" and e.type == "base":
				has_base = true
				break
		if not has_base and players[p]["alive"]:
			players[p]["alive"] = false
			events.append({"t": "eliminated", "player": p})
		if players[p]["alive"]:
			alive.append(p)
	if alive.size() <= 1:
		over = true
		winner = alive[0] if alive.size() == 1 else -1
		end_reason = "base destruída"
	elif tick >= Defs.MATCH_TICKS:
		over = true
		var best := -1
		var best_s := -1
		for p in alive:
			var s := score(p)
			if s > best_s:
				best_s = s
				best = p
			elif s == best_s:
				best = -1
		winner = best
		end_reason = "tempo esgotado — vitória por pontos"


func score(p: int) -> int:
	var s: int = players[p]["mined"] / 2
	for e in ents:
		if e.owner != p:
			continue
		if e.kind == "unit":
			s += Defs.UNITS[e.type]["cost"] * e.hp / e.max_hp
		elif e.kind == "building":
			s += Defs.BUILDINGS[e.type]["value"] * e.hp / e.max_hp
	return s


# ------------------------------------------------------------------ utilidades
static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var r := int(sqrt(float(n)))
	while r * r > n:
		r -= 1
	while (r + 1) * (r + 1) <= n:
		r += 1
	return r


static func dist2(ax: int, ay: int, bx: int, by: int) -> int:
	var vx := bx - ax
	var vy := by - ay
	return vx * vx + vy * vy


func state_hash() -> String:
	var parts := PackedStringArray()
	parts.append("%d|%s" % [tick, str(players)])
	for e in ents:
		parts.append("%d,%d,%d,%d,%d,%s,%d,%d,%d" % [e.id, e.owner, e.x, e.y, e.hp, e.order, e.target, e.carry, e.amount])
	return "|".join(parts).md5_text()


func army(p: int) -> Array[SimEnt]:
	var out: Array[SimEnt] = []
	for e in ents:
		if e.owner == p and e.kind == "unit" and not Defs.UNITS[e.type].get("worker", false):
			out.append(e)
	return out
