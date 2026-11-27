class_name SimEnt
extends RefCounted
## Uma entidade da simulação: unidade, prédio, campo de minério ou o Núcleo. Só dados.

var id := 0
var owner := -1                 # 0..3 ; -1 = neutro (minério, Núcleo)
var kind := ""                  # "unit", "building", "ore", "core"
var type := ""
var x := 0                      # cm
var y := 0                      # cm (vira Z no Godot)
var px := 0                     # posição no tick anterior (interpolação na tela)
var py := 0
var hp := 0
var max_hp := 0
var shield := 0                 # Energia: absorve dano antes da vida e se regenera
var max_shield := 0
var last_hit := -1000
var radius := 0
var air := false

# ordens
var order := "idle"             # idle, move, amove, attack, harvest, return
var dx := 0
var dy := 0
var target := -1                # alvo explícito (ordem de ataque)
var aim := -1                   # alvo atual (explícito ou automático) — para a tela
var cd := 0

# navegação
var path: Array = []            # waypoints [[x, y], ...]
var path_goal := -1             # célula do destino para o qual o caminho foi calculado

# coletor
var carry := 0
var ore_target := -1
var work := 0

# prédio
var built := true
var progress := 0
var queue: Array[String] = []
var qprog := 0
var rally_x := 0
var rally_y := 0
var research := ""              # laboratório: pesquisa em andamento
var rprog := 0

# minério
var amount := 0


func cls() -> String:
	if kind == "building":
		return "building"
	return Defs.def_of(type).get("class", "")


func is_worker() -> bool:
	return kind == "unit" and Defs.UNITS[type].get("worker", false)


func is_combat() -> bool:
	return kind == "unit" and not Defs.UNITS[type].get("worker", false)
