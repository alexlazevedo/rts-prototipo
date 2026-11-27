extends Node
## Animações simples dos grupos com nome fixo nos .glb (sem esqueleto, sem keyframes):
##   Rotor_L / Rotor_R  giram rápido (VTOL)
##   Ring / Orbit / Shards  giram devagar (Energia)
##   Float  sobe e desce (nó de Núcleo)
## Unidades da facção Energia flutuam inteiras (balanço leve).
## Coloque como filho da instância do asset.

const SPIN := {"Rotor_L": 22.0, "Rotor_R": -22.0, "Ring": 0.7, "Orbit": 1.6, "Shards": 0.25}

var _parts: Dictionary = {}
var _float: Node3D
var _float_y := 0.0
var _hover: Node3D
var _hover_y := 0.0
var _t := 0.0


func _ready() -> void:
	var root := get_parent()
	_t = randf() * TAU
	for n: String in SPIN:
		var f := root.find_child(n, true, false) as Node3D
		if f:
			_parts[n] = f
	_float = root.find_child("Float", true, false) as Node3D
	if _float:
		_float_y = _float.position.y
	if root.name.begins_with("energia_") and root.get_meta("kind", "") == "unit" and root.get_child_count() > 0:
		_hover = root.get_child(0) as Node3D
		_hover_y = _hover.position.y


func _process(delta: float) -> void:
	_t += delta
	for n: String in _parts:
		(_parts[n] as Node3D).rotate_y(SPIN[n] * delta)
	if _float:
		_float.position.y = _float_y + sin(_t * 1.3) * 0.35
	if _hover:
		_hover.position.y = _hover_y + sin(_t * 1.8) * 0.15
