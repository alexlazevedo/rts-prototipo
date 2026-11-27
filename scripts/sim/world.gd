class_name SimWorld
extends RefCounted
## Simulação determinística do RTS (Fase 2: 4 jogadores, 2 facções, terreno, névoa, Núcleo).
## Regras: só inteiros, ordem de processamento fixa (por id), nenhuma dependência de
## Nodes, tempo real ou aleatório global. Mesmos comandos + mesma semente = mesma partida.
## Jogador humano e bots só mudam o mundo via issue(); a tela só lê.

const CORNERS := [[-10000, 10000], [10000, -10000], [10000, 10000], [-10000, -10000]]
const EXPANSIONS := [[0, 11300], [0, -11300], [-11300, 0], [11300, 0]]
const DX8 := [1, -1, 0, 0, 1, 1, -1, -1]
const DY8 := [0, 0, 1, -1, 1, -1, 1, -1]

var tick := 0
var ents: Array[SimEnt] = []
var by_id: Dictionary = {}
var next_id := 1
var players: Array[Dictionary] = []
var pending: Array[Dictionary] = []
var events: Array[Dictionary] = []
var over := false
var winner := -1
var end_reason := ""
var seed_value := 1
var core_owner := -1             # quem controla o Núcleo agora (-1 = ninguém / disputado)

# terreno e navegação
var plateaus: Array[Dictionary] = []     # {cx, cy, half, dir}
var N := 0                               # células por lado da grade de navegação
var static_block := PackedByteArray()
var dyn_block := PackedInt32Array()
var _path_budget := 0

# névoa
var FN := 0
var vis: Array[PackedByteArray] = []
var explored: Array[PackedByteArray] = []
var _stamps: Dictionary = {}


func _init(p_seed := 1, factions: Array = ["militar", "militar"]) -> void:
	seed_value = p_seed
	for i in factions.size():
		players.append({"ore": Defs.START_ORE, "core": 0, "core_prog": 0, "alive": true, "mined": 0,
			"lost": 0, "killed": 0, "faction": factions[i], "techs": {}, "core_total": 0})
	N = 2 * Defs.HALF / Defs.CELL
	FN = 2 * Defs.HALF / Defs.FOG_CELL
	static_block.resize(N * N)
	dyn_block.resize(N * N)
	for p in players.size():
		var v := PackedByteArray()
		v.resize(FN * FN)
		vis.append(v)
		var ex := PackedByteArray()
		ex.resize(FN * FN)
		explored.append(ex)
	_setup_map()
	_update_fog()


# ------------------------------------------------------------------ mapa
func _setup_map() -> void:
	for p in players.size():
		var c: Array = CORNERS[p]
		var bx: int = c[0]
		var by: int = c[1]
		var d := 1 if bx < 0 else -1
		plateaus.append({"cx": bx, "cy": by, "half": Defs.PLATEAU_HALF, "dir": d})
	_build_static_grid()
	_spawn_core(0, 0)
	for e in EXPANSIONS:
		_spawn_ore(e[0], e[1], 2500)
	for p in players.size():
		var pl: Dictionary = plateaus[p]
		var bx: int = pl["cx"]
		var by: int = pl["cy"]
		var d: int = pl["dir"]
		var fac: String = players[p]["faction"]
		var b := _spawn_building(p, Defs.type_for(fac, "base"), bx, by, true)
		b.rally_x = bx + d * (Defs.PLATEAU_HALF + Defs.RAMP_LEN + 700)
		b.rally_y = by
		_spawn_ore(bx - d * 1900, by + 1900, 1800)
		_spawn_ore(bx - d * 1900, by - 1900, 1800)
		for i in Defs.START_WORKERS:
			var w := _spawn_unit(p, Defs.type_for(fac, "worker"), bx - d * 1150, by + (i - 1) * 320)
			w.order = "harvest"


func _build_static_grid() -> void:
	for gy in N:
		for gx in N:
			var x := cell_x(gx)
			var y := cell_x(gy)
			var blocked := 0
			for pl in plateaus:
				var cx: int = pl["cx"]
				var cy: int = pl["cy"]
				var half: int = pl["half"]
				var d: int = pl["dir"]
				var ax := absi(x - cx)
				var ay := absi(y - cy)
				var m := maxi(ax, ay)
				var on_ramp_side := (x - cx) * d > 0 and ax >= ay and ay <= Defs.RAMP_HALF_W - 100
				# anel de penhasco em volta do platô, aberto onde está a rampa
				if m >= half - Defs.CELL and m <= half + Defs.CELL and not on_ramp_side:
					blocked = 1
				# paredes laterais da rampa
				var rx := (x - cx) * d - half
				if rx > 0 and rx < Defs.RAMP_LEN and ay > Defs.RAMP_HALF_W - 100 and ay <= Defs.RAMP_HALF_W + Defs.CELL:
					blocked = 1
			static_block[gy * N + gx] = blocked


func height_at(x: int, y: int) -> int:
	for pl in plateaus:
		var cx: int = pl["cx"]
		var cy: int = pl["cy"]
		var half: int = pl["half"]
		var d: int = pl["dir"]
		if absi(x - cx) <= half and absi(y - cy) <= half:
			return Defs.PLATEAU_H
		var rx := (x - cx) * d - half
		if rx > 0 and rx < Defs.RAMP_LEN and absi(y - cy) <= Defs.RAMP_HALF_W:
			return Defs.PLATEAU_H * (Defs.RAMP_LEN - rx) / Defs.RAMP_LEN
	return 0


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
	e.max_shield = d.get("shield", 0)
	e.shield = e.max_shield
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
	e.max_shield = d.get("shield", 0)
	e.shield = e.max_shield if done else 0
	e.radius = d["radius"]
	e.built = done
	# ponto de encontro: em direção ao centro do mapa
	var dist := maxi(1, isqrt(x * x + y * y))
	var off: int = e.radius + 700
	e.rally_x = x - x * off / dist
	e.rally_y = y - y * off / dist
	_block(e, 1)
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
	_block(e, 1)
	return _add(e)


func _spawn_core(x: int, y: int) -> SimEnt:
	var e := SimEnt.new()
	e.kind = "core"
	e.type = "nucleo"
	e.x = x
	e.y = y
	e.radius = 450
	e.hp = 1
	e.max_hp = 1
	_block(e, 1)
	return _add(e)


func _block(e: SimEnt, delta: int) -> void:
	var r := e.radius - 60
	var g0x := cell_of_coord(e.x - r)
	var g1x := cell_of_coord(e.x + r)
	var g0y := cell_of_coord(e.y - r)
	var g1y := cell_of_coord(e.y + r)
	for gy in range(g0y, g1y + 1):
		for gx in range(g0x, g1x + 1):
			if dist2(cell_x(gx), cell_x(gy), e.x, e.y) <= r * r:
				dyn_block[gy * N + gx] += delta


# ------------------------------------------------------------------ grade
func cell_of_coord(v: int) -> int:
	return clampi((v + Defs.HALF) / Defs.CELL, 0, N - 1)


func cell_x(g: int) -> int:
	return -Defs.HALF + g * Defs.CELL + Defs.CELL / 2


func cell_idx(x: int, y: int) -> int:
	return cell_of_coord(y) * N + cell_of_coord(x)


func walkable_idx(i: int) -> bool:
	return static_block[i] == 0 and dyn_block[i] == 0


func walkable_at(x: int, y: int) -> bool:
	return walkable_idx(cell_idx(x, y))


func line_clear(ax: int, ay: int, bx: int, by: int) -> bool:
	var vx := bx - ax
	var vy := by - ay
	var dist := isqrt(vx * vx + vy * vy)
	var steps := dist / (Defs.CELL / 2) + 1
	var start := cell_idx(ax, ay)
	for i in range(1, steps + 1):
		var c := cell_idx(ax + vx * i / steps, ay + vy * i / steps)
		if c != start and not walkable_idx(c):
			return false
	return true


func _nearest_walkable(idx: int) -> int:
	if walkable_idx(idx):
		return idx
	var gx := idx % N
	var gy := idx / N
	for r in range(1, 12):
		var best := -1
		var bd := 0
		for oy in range(-r, r + 1):
			for ox in range(-r, r + 1):
				if maxi(absi(ox), absi(oy)) != r:
					continue
				var x := gx + ox
				var y := gy + oy
				if x < 0 or y < 0 or x >= N or y >= N:
					continue
				var i := y * N + x
				if walkable_idx(i):
					var dd := ox * ox + oy * oy
					if best < 0 or dd < bd:
						best = i
						bd = dd
		if best >= 0:
			return best
	return idx


## A* em grade de 8 direções (custos 10/14), sem cortar quinas; caminho suavizado por linha de visão.
func find_path(sx: int, sy: int, tx: int, ty: int) -> Array:
	var s := cell_idx(sx, sy)
	var t := _nearest_walkable(cell_idx(tx, ty))
	var goal_xy := [tx, ty] if walkable_idx(cell_idx(tx, ty)) else [cell_x(t % N), cell_x(t / N)]
	if s == t:
		return [goal_xy]
	var total := N * N
	var g := PackedInt32Array()
	g.resize(total)
	g.fill(1 << 30)
	var came := PackedInt32Array()
	came.resize(total)
	came.fill(-1)
	var closed := PackedByteArray()
	closed.resize(total)
	var heap: Array[int] = []
	var tgx := t % N
	var tgy := t / N
	g[s] = 0
	_heap_push(heap, _octile(s % N, s / N, tgx, tgy) * 32768 + s)
	var found := false
	var expanded := 0
	while not heap.is_empty() and expanded < 9000:
		var cur := _heap_pop(heap) % 32768
		if closed[cur] == 1:
			continue
		closed[cur] = 1
		expanded += 1
		if cur == t:
			found = true
			break
		var cx := cur % N
		var cy := cur / N
		for k in 8:
			var ox: int = DX8[k]
			var oy: int = DY8[k]
			var nx := cx + ox
			var ny := cy + oy
			if nx < 0 or ny < 0 or nx >= N or ny >= N:
				continue
			var ni := ny * N + nx
			if closed[ni] == 1 or (not walkable_idx(ni) and ni != t):
				continue
			if ox != 0 and oy != 0:
				if not walkable_idx(cy * N + nx) or not walkable_idx(ny * N + cx):
					continue
			var ng := g[cur] + (14 if ox != 0 and oy != 0 else 10)
			if ng < g[ni]:
				g[ni] = ng
				came[ni] = cur
				_heap_push(heap, (ng + _octile(nx, ny, tgx, tgy)) * 32768 + ni)
	if not found:
		return [goal_xy]
	var cells: Array[int] = []
	var c := t
	while c != s and c >= 0:
		cells.append(c)
		c = came[c]
	cells.reverse()
	# suaviza: pula waypoints enquanto houver linha de visão
	var out: Array = []
	var ax := sx
	var ay := sy
	var i := 0
	while i < cells.size():
		var j := cells.size() - 1
		while j > i:
			if line_clear(ax, ay, cell_x(cells[j] % N), cell_x(cells[j] / N)):
				break
			j -= 1
		ax = cell_x(cells[j] % N)
		ay = cell_x(cells[j] / N)
		out.append([ax, ay])
		i = j + 1
	out[out.size() - 1] = goal_xy
	return out


func _octile(ax: int, ay: int, bx: int, by: int) -> int:
	var dx := absi(ax - bx)
	var dy := absi(ay - by)
	return 10 * maxi(dx, dy) + 4 * mini(dx, dy)


func _heap_push(h: Array[int], v: int) -> void:
	h.append(v)
	var i := h.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if h[p] <= h[i]:
			break
		var tmp := h[p]
		h[p] = h[i]
		h[i] = tmp
		i = p


func _heap_pop(h: Array[int]) -> int:
	var top := h[0]
	var last: int = h.pop_back()
	if h.is_empty():
		return top
	h[0] = last
	var i := 0
	var n := h.size()
	while true:
		var l := 2 * i + 1
		var r := l + 1
		var m := i
		if l < n and h[l] < h[m]:
			m = l
		if r < n and h[r] < h[m]:
			m = r
		if m == i:
			break
		var tmp := h[m]
		h[m] = h[i]
		h[i] = tmp
		i = m
	return top


# ------------------------------------------------------------------ névoa
func fog_idx(x: int, y: int) -> int:
	return clampi((y + Defs.HALF) / Defs.FOG_CELL, 0, FN - 1) * FN + clampi((x + Defs.HALF) / Defs.FOG_CELL, 0, FN - 1)


func _stamp(radius: int) -> Array:
	if not _stamps.has(radius):
		var r := radius / Defs.FOG_CELL + 1
		var offs: Array = []
		for oy in range(-r, r + 1):
			for ox in range(-r, r + 1):
				if (ox * ox + oy * oy) * Defs.FOG_CELL * Defs.FOG_CELL <= radius * radius:
					offs.append(Vector2i(ox, oy))
		_stamps[radius] = offs
	return _stamps[radius]


func _update_fog() -> void:
	# arrays "packed" são cópia-na-escrita: monta cada grade localmente e grava de volta
	for p in players.size():
		var v := PackedByteArray()
		v.resize(FN * FN)
		var ex: PackedByteArray = explored[p]
		for e in ents:
			if e.owner != p or e.hp <= 0:
				continue
			var sight: int = Defs.def_of(e.type).get("sight", 1000)
			if e.kind == "building" and not e.built:
				sight = 600
			var gx := clampi((e.x + Defs.HALF) / Defs.FOG_CELL, 0, FN - 1)
			var gy := clampi((e.y + Defs.HALF) / Defs.FOG_CELL, 0, FN - 1)
			for o: Vector2i in _stamp(sight):
				var x := gx + o.x
				var y := gy + o.y
				if x >= 0 and y >= 0 and x < FN and y < FN:
					v[y * FN + x] = 1
					ex[y * FN + x] = 1
		vis[p] = v
		explored[p] = ex


func visible_to(p: int, e: SimEnt) -> bool:
	if e.owner == p or p < 0:
		return true
	return vis[p][fog_idx(e.x, e.y)] == 1


func known_to(p: int, e: SimEnt) -> bool:
	## Prédios e recursos já vistos continuam conhecidos (dá para mandar atacar).
	if visible_to(p, e):
		return true
	return e.kind != "unit" and explored[p][fog_idx(e.x, e.y)] == 1


# ------------------------------------------------------------------ comandos
## Comandos (Dictionary):
##   {"kind":"move"|"amove", "ids":[...], "x":cm, "y":cm}
##   {"kind":"attack", "ids":[...], "target":id}
##   {"kind":"train", "building":id, "type":"buggy"}
##   {"kind":"build", "type":"fabrica", "x":cm, "y":cm}
##   {"kind":"research", "building":id, "tech":"nivel2"}
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
				if t == null or not known_to(p, t):
					continue
				for id in c["ids"]:
					var e: SimEnt = by_id.get(int(id))
					if e and e.owner == p and e.is_combat():
						e.order = "attack"
						e.target = t.id
			"train":
				_cmd_train(p, int(c["building"]), String(c["type"]))
			"build":
				_cmd_build(p, String(c["type"]), int(c["x"]), int(c["y"]))
			"research":
				_cmd_research(p, int(c["building"]), String(c["tech"]))


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
		e.dx = clampi(x + ox, -Defs.HALF + 200, Defs.HALF - 200)
		e.dy = clampi(y + oy, -Defs.HALF + 200, Defs.HALF - 200)
		e.target = -1
		e.path = []
		e.path_goal = -1
		e.order = "move" if e.is_worker() else kind


func queued_count(p: int, worker: bool) -> int:
	var n := 0
	for e in ents:
		if e.owner != p:
			continue
		if e.kind == "unit" and e.is_worker() == worker:
			n += 1
		elif e.kind == "building":
			for t in e.queue:
				if Defs.UNITS[t].get("worker", false) == worker:
					n += 1
	return n


func has_tech(p: int, tech: String) -> bool:
	return tech == "" or players[p]["techs"].has(tech)


func can_train(p: int, b: SimEnt, type: String) -> String:
	## Retorna "" se pode; senão o motivo (para a tela mostrar).
	if b == null or b.owner != p or b.kind != "building" or not b.built:
		return "prédio indisponível"
	if not (type in Defs.BUILDINGS[b.type]["produces"]):
		return "não produz aqui"
	var d: Dictionary = Defs.UNITS[type]
	if not has_tech(p, d.get("tech", "")):
		return "precisa de %s (laboratório)" % Defs.TECHS[d["tech"]]["name"]
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


func can_research(p: int, b: SimEnt, tech: String) -> String:
	if b == null or b.owner != p or not b.built or Defs.BUILDINGS[b.type]["role"] != "lab":
		return "laboratório indisponível"
	if not Defs.TECHS.has(tech):
		return "pesquisa inválida"
	if has_tech(p, tech):
		return "já pesquisado"
	if b.research != "":
		return "laboratório ocupado"
	var t: Dictionary = Defs.TECHS[tech]
	if not has_tech(p, t.get("req", "")):
		return "precisa de %s" % Defs.TECHS[t["req"]]["name"]
	for e in ents:
		if e.owner == p and e.research == tech:
			return "já em andamento"
	if players[p]["ore"] < t["ore"]:
		return "minério insuficiente"
	if players[p]["core"] < t["core"]:
		return "Núcleo insuficiente (controle o centro)"
	return ""


func _cmd_research(p: int, bid: int, tech: String) -> void:
	var b: SimEnt = by_id.get(bid)
	if can_research(p, b, tech) != "":
		return
	players[p]["ore"] -= Defs.TECHS[tech]["ore"]
	players[p]["core"] -= Defs.TECHS[tech]["core"]
	b.research = tech
	b.rprog = 0


func has_built(p: int, role: String) -> bool:
	for e in ents:
		if e.owner == p and e.kind == "building" and e.built and Defs.BUILDINGS[e.type]["role"] == role:
			return true
	return false


func can_build(p: int, type: String, x: int, y: int) -> String:
	if not Defs.BUILDINGS.has(type) or Defs.BUILDINGS[type]["role"] == "base":
		return "tipo inválido"
	var d: Dictionary = Defs.BUILDINGS[type]
	if d["faction"] != players[p]["faction"]:
		return "outra facção"
	if players[p]["ore"] < d["cost"]:
		return "minério insuficiente"
	var req: String = d["req"]
	if req != "" and not has_built(p, req):
		return "precisa de %s" % req
	var r: int = d["radius"]
	if absi(x) > Defs.HALF - r or absi(y) > Defs.HALF - r:
		return "fora do mapa"
	# terreno plano e livre sob todo o prédio
	var h := height_at(x, y)
	for k in 9:
		var ox: int = [0, 1, -1, 0, 0, 1, 1, -1, -1][k] * r
		var oy: int = [0, 0, 0, 1, -1, 1, -1, 1, -1][k] * r * 7 / 10
		if k >= 5:
			ox = ox * 7 / 10
		if height_at(x + ox, y + oy) != h or static_block[cell_idx(x + ox, y + oy)] != 0:
			return "terreno irregular"
	# não pode fechar a saída da rampa (nem embaixo, nem em cima)
	for pl in plateaus:
		var top_x: int = pl["cx"] + pl["dir"] * pl["half"]
		for rx in [top_x - pl["dir"] * 400, top_x + pl["dir"] * (Defs.RAMP_LEN + 300)]:
			var lim := r + 1000
			if dist2(x, y, rx, pl["cy"]) < lim * lim:
				return "bloquearia a rampa"
	var near := false
	for e in ents:
		var min_d := r + e.radius + 150
		if e.kind != "unit" and dist2(x, y, e.x, e.y) < min_d * min_d:
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
	_path_budget = 14
	for e in ents:
		e.px = e.x
		e.py = e.y
	_apply_commands()
	var snapshot := ents.duplicate()
	for e: SimEnt in snapshot:
		if e.hp <= 0:
			continue
		if e.max_shield > 0 and e.shield < e.max_shield and tick - e.last_hit >= Defs.SHIELD_DELAY:
			e.shield = mini(e.max_shield, e.shield + maxi(1, e.max_shield / Defs.SHIELD_REGEN_DIV))
		if e.kind == "building":
			_update_building(e)
		elif e.kind == "unit":
			if e.is_worker():
				_update_worker(e)
			else:
				_update_combat(e, Defs.UNITS[e.type], true)
	_separate()
	_resolve_deaths()
	_update_core()
	if tick % 2 == 0:
		_update_fog()
	tick += 1
	_check_end()


# ------------------------------------------------------------------ Núcleo
func _update_core() -> void:
	var present := {}
	for e in ents:
		if e.is_combat() and dist2(e.x, e.y, 0, 0) <= Defs.CORE_RADIUS * Defs.CORE_RADIUS:
			present[e.owner] = true
	var prev := core_owner
	core_owner = present.keys()[0] if present.size() == 1 else -1
	if core_owner != prev:
		events.append({"t": "core", "owner": core_owner})
	if core_owner >= 0:
		var pl: Dictionary = players[core_owner]
		pl["core_prog"] += 1
		if pl["core_prog"] >= Defs.CORE_TICKS:
			pl["core_prog"] = 0
			pl["core"] += 1
			pl["core_total"] += 1


# ------------------------------------------------------------------ prédios
func _update_building(e: SimEnt) -> void:
	var d: Dictionary = Defs.BUILDINGS[e.type]
	if not e.built:
		e.progress += 1
		var t: int = d["time"]
		e.hp = mini(e.max_hp, e.max_hp / 10 + e.max_hp * 9 / 10 * e.progress / t)
		if e.progress >= t:
			e.built = true
			e.shield = e.max_shield
			events.append({"t": "built", "id": e.id})
		return
	if d.has("dmg"):
		e.cd = maxi(0, e.cd - 1)
		_update_combat(e, d, false)
	if e.research != "":
		e.rprog += 1
		if e.rprog >= Defs.TECHS[e.research]["time"]:
			players[e.owner]["techs"][e.research] = true
			events.append({"t": "research", "player": e.owner, "tech": e.research})
			e.research = ""
			e.rprog = 0
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
	var sx := e.x + vx * off / dist
	var sy := e.y + vy * off / dist
	if not ud["air"] and not walkable_at(sx, sy):
		var c := _nearest_walkable(cell_idx(sx, sy))
		sx = cell_x(c % N)
		sy = cell_x(c / N)
	var u := _spawn_unit(e.owner, type, sx, sy)
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
		if e.owner == p and e.kind == "unit" and e.is_worker() == worker:
			n += 1
	return n


# ------------------------------------------------------------------ combate
func _can_hit(d: Dictionary, t: SimEnt) -> bool:
	if t.air:
		return d.get("hits_air", false)
	return d.get("hits_ground", false)


func _valid_enemy(e: SimEnt, d: Dictionary, t: SimEnt, need_visible: bool) -> bool:
	if t == null or t.hp <= 0 or t.owner < 0 or t.owner == e.owner or not (t.kind == "unit" or t.kind == "building"):
		return false
	if not _can_hit(d, t):
		return false
	if need_visible and not visible_to(e.owner, t):
		return false
	return true


func _acquire(e: SimEnt, d: Dictionary, reach: int) -> SimEnt:
	var best: SimEnt = null
	var best_pri := 9
	var best_d := 0
	for t in ents:
		if not _valid_enemy(e, d, t, true):
			continue
		var r := reach + t.radius
		var dd := dist2(e.x, e.y, t.x, t.y)
		if dd > r * r:
			continue
		var pri := 2
		if t.kind == "unit":
			pri = 1 if t.is_worker() else 0
		elif Defs.BUILDINGS[t.type]["role"] == "torre":
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
	# alvo explícito: precisa estar visível, ou ser prédio já conhecido (anda até ele)
	if t == null or not _valid_enemy(e, d, t, false) or not known_to(e.owner, t):
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
		if dist2(e.x, e.y, t.x, t.y) <= reach * reach and visible_to(e.owner, t):
			if e.cd == 0:
				_shoot(e, d, t)
				e.cd = d["cd"]
			return
		if mobile and e.order != "move":
			_nav(e, t.x, t.y, d["speed"])
			return
	if mobile and (e.order == "move" or e.order == "amove"):
		if _nav(e, e.dx, e.dy, d["speed"]):
			e.order = "idle"


func _shoot(e: SimEnt, d: Dictionary, t: SimEnt) -> void:
	var dmg: int = d["dmg"] * Defs.bonus(d.get("class", ""), t.cls()) / 100
	if e.owner >= 0 and has_tech(e.owner, "armas"):
		dmg = dmg * 120 / 100
	if t.kind == "building" and Defs.BUILDINGS[t.type]["role"] == "base" and tick >= Defs.ARMOR_OFF_TICK:
		dmg *= 2
	t.last_hit = tick
	if t.shield > 0:
		var absorbed := mini(t.shield, dmg)
		t.shield -= absorbed
		dmg -= absorbed
	t.hp -= dmg
	events.append({"t": "shot", "a": e.id, "b": t.id, "air": e.air})
	if t.hp <= 0:
		players[e.owner]["killed"] += 1


# ------------------------------------------------------------------ coletor
func _update_worker(e: SimEnt) -> void:
	var sp: int = Defs.UNITS[e.type]["speed"]
	match e.order:
		"move":
			if _nav(e, e.dx, e.dy, sp):
				e.order = "harvest" if e.carry == 0 else "return"
		"harvest":
			var f: SimEnt = by_id.get(e.ore_target)
			if f == null or f.kind != "ore" or f.amount <= 0:
				f = _nearest_ore(e)
				e.ore_target = f.id if f else -1
				e.path = []
			if f == null:
				e.order = "idle"
				return
			var reach := f.radius + e.radius + 140
			if dist2(e.x, e.y, f.x, f.y) <= reach * reach:
				e.work += 1
				if e.work >= Defs.HARVEST_TICKS:
					var take := mini(Defs.CARRY, f.amount)
					f.amount -= take
					e.carry = take
					e.work = 0
					e.order = "return"
					e.path = []
			else:
				_nav(e, f.x, f.y, sp)
		"return":
			var b := _nearest_base(e)
			if b == null:
				e.order = "idle"
				return
			var reach := b.radius + e.radius + 160
			if dist2(e.x, e.y, b.x, b.y) <= reach * reach:
				players[e.owner]["ore"] += e.carry
				players[e.owner]["mined"] += e.carry
				e.carry = 0
				e.order = "harvest"
				e.path = []
			else:
				_nav(e, b.x, b.y, sp)
		_:
			e.order = "harvest" if e.carry == 0 else "return"


func _nearest_ore(e: SimEnt) -> SimEnt:
	## Campo mais perto da base mais próxima (evita coletores atravessarem o mapa à toa).
	var best: SimEnt = null
	var bd := 0
	var base := _nearest_base(e)
	var ox := base.x if base else e.x
	var oy := base.y if base else e.y
	for t in ents:
		if t.kind != "ore" or t.amount <= 0:
			continue
		var dd := dist2(ox, oy, t.x, t.y)
		if best == null or dd < bd:
			best = t
			bd = dd
	return best


func _nearest_base(e: SimEnt) -> SimEnt:
	var best: SimEnt = null
	var bd := 0
	for t in ents:
		if t.owner == e.owner and t.kind == "building" and t.built and Defs.BUILDINGS[t.type]["role"] == "base":
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


## Move com navegação (terreno, prédios). Aéreas vão em linha reta. Retorna true ao chegar.
func _nav(e: SimEnt, tx: int, ty: int, speed: int) -> bool:
	if e.air:
		return _move_toward(e, tx, ty, speed)
	var goal := cell_idx(tx, ty)
	if e.path.is_empty() or e.path_goal != goal:
		if line_clear(e.x, e.y, tx, ty):
			e.path = [[tx, ty]]
		elif _path_budget > 0:
			_path_budget -= 1
			e.path = find_path(e.x, e.y, tx, ty)
		else:
			return false
		e.path_goal = goal
	elif e.path.size() == 1:
		e.path[0] = [tx, ty]
	var wp: Array = e.path[0]
	if _move_toward(e, wp[0], wp[1], speed):
		e.path.pop_front()
		if e.path.is_empty():
			return dist2(e.x, e.y, tx, ty) <= speed * speed * 4
	return false


func _separate() -> void:
	var units: Array[SimEnt] = []
	var solids: Array[SimEnt] = []
	for e in ents:
		if e.kind == "unit":
			if e.hp > 0:
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
			if absi(vx) >= min_d or absi(vy) >= min_d:
				continue
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
			if absi(vx) >= min_d or absi(vy) >= min_d:
				continue
			var dd := vx * vx + vy * vy
			if dd >= min_d * min_d:
				continue
			var dist := maxi(1, isqrt(dd))
			var push := min_d - dist + 1
			var side := 1 if (u.id % 2 == 0) else -1
			u.x += vx * push / dist - side * vy * push / (dist * 2)
			u.y += vy * push / dist + side * vx * push / (dist * 2)
	for u in units:
		u.x = clampi(u.x, -Defs.HALF + 100, Defs.HALF - 100)
		u.y = clampi(u.y, -Defs.HALF + 100, Defs.HALF - 100)
		# nunca termina o tick dentro de penhasco
		if not u.air and static_block[cell_idx(u.x, u.y)] != 0 and static_block[cell_idx(u.px, u.py)] == 0:
			u.x = u.px
			u.y = u.py


# ------------------------------------------------------------------ mortes e fim
func _resolve_deaths() -> void:
	var keep: Array[SimEnt] = []
	for e in ents:
		var dead := (e.kind == "unit" or e.kind == "building") and e.hp <= 0
		dead = dead or (e.kind == "ore" and e.amount <= 0)
		if dead:
			by_id.erase(e.id)
			if e.kind != "unit":
				_block(e, -1)
			events.append({"t": "die", "id": e.id, "x": e.x, "y": e.y, "type": e.type, "kind": e.kind, "owner": e.owner})
			if e.owner >= 0:
				players[e.owner]["lost"] += 1
		else:
			keep.append(e)
	ents = keep


func _check_end() -> void:
	var alive: Array[int] = []
	for p in players.size():
		if not players[p]["alive"]:
			continue
		var has_base := false
		for e in ents:
			if e.owner == p and e.kind == "building" and Defs.BUILDINGS[e.type]["role"] == "base":
				has_base = true
				break
		if not has_base:
			players[p]["alive"] = false
			events.append({"t": "eliminated", "player": p})
			# o que sobrou do jogador eliminado é destruído
			for e in ents:
				if e.owner == p:
					e.hp = 0
			_resolve_deaths()
		else:
			alive.append(p)
	if alive.size() <= 1:
		over = true
		winner = alive[0] if alive.size() == 1 else -1
		end_reason = "último jogador de pé"
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
	if not players[p]["alive"]:
		return 0
	var s: int = players[p]["mined"] / 2 + players[p]["core_total"] * 5
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
		parts.append("%d,%d,%d,%d,%d,%d,%s,%d,%d,%d" % [e.id, e.owner, e.x, e.y, e.hp, e.shield, e.order, e.target, e.carry, e.amount])
	return "|".join(parts).md5_text()


func army(p: int) -> Array[SimEnt]:
	var out: Array[SimEnt] = []
	for e in ents:
		if e.owner == p and e.is_combat():
			out.append(e)
	return out


func base_of(p: int) -> SimEnt:
	for e in ents:
		if e.owner == p and e.kind == "building" and Defs.BUILDINGS[e.type]["role"] == "base":
			return e
	return null
