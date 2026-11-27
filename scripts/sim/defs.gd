class_name Defs
## Regras e números do jogo (protótipo). Tudo em inteiros:
##   distância em centímetros, tempo em ticks (10 por segundo), velocidade em cm/tick.
## Ajuste de balanceamento = mudar números aqui e rodar os testes (tests/test_sim.gd).

const TICK_HZ := 10
const MATCH_TICKS := 6000        # 10 min: fim garantido por pontos
const ARMOR_OFF_TICK := 4800     # 8 min: Bases perdem blindagem (dano em dobro)
const HALF_W := 12000            # mapa 240 m x 160 m
const HALF_H := 8000
const COMBAT_CAP := 10
const WORKER_CAP := 6
const START_ORE := 200
const START_WORKERS := 3
const BUILD_RANGE := 3600        # novo prédio a até 36 m de um prédio seu

const CARRY := 8                 # minério por viagem
const HARVEST_TICKS := 20

const UNITS := {
	"coletor": {"cost": 50, "time": 100, "hp": 60, "speed": 45, "radius": 110, "air": false,
		"worker": true, "class": "worker", "tag": "COL", "from": "base", "model": "militar_coletor"},
	"buggy": {"cost": 75, "time": 140, "hp": 110, "speed": 75, "radius": 110, "air": false,
		"range": 650, "dmg": 9, "cd": 6, "hits_ground": true, "hits_air": false,
		"class": "light", "tag": "BGY", "from": "fabrica", "model": "militar_buggy"},
	"tanque": {"cost": 150, "time": 220, "hp": 300, "speed": 38, "radius": 160, "air": false,
		"range": 1300, "dmg": 34, "cd": 22, "hits_ground": true, "hits_air": false,
		"class": "heavy", "tag": "TNQ", "from": "fabrica", "model": "militar_tanque_cerco"},
	"antiaereo": {"cost": 100, "time": 170, "hp": 170, "speed": 48, "radius": 130, "air": false,
		"range": 1200, "dmg": 22, "cd": 10, "hits_ground": false, "hits_air": true,
		"class": "aa", "tag": "AA", "from": "fabrica", "model": "militar_antiaereo"},
	"vtol": {"cost": 125, "time": 200, "hp": 150, "speed": 65, "radius": 150, "air": true,
		"range": 750, "dmg": 15, "cd": 8, "hits_ground": true, "hits_air": false,
		"class": "air", "tag": "VTL", "from": "hangar", "model": "militar_vtol"},
}

const BUILDINGS := {
	"base": {"cost": 0, "time": 0, "hp": 1600, "radius": 850, "produces": ["coletor"],
		"req": "", "model": "militar_base", "value": 400},
	"fabrica": {"cost": 150, "time": 250, "hp": 800, "radius": 700, "produces": ["buggy", "tanque", "antiaereo"],
		"req": "", "model": "militar_fabrica", "value": 150},
	"hangar": {"cost": 175, "time": 300, "hp": 650, "radius": 750, "produces": ["vtol"],
		"req": "fabrica", "model": "militar_hangar", "value": 175},
	"torre": {"cost": 100, "time": 200, "hp": 550, "radius": 320, "produces": [],
		"req": "", "model": "militar_torre", "value": 100,
		"range": 1250, "dmg": 14, "cd": 8, "hits_ground": true, "hits_air": true, "class": "building"},
}

const ORE_RADIUS := 420

## Ciclo de contra-ataque (%): leve > antiaéreo > aérea > pesada > leve
const BONUS := {
	"light>aa": 150,
	"heavy>light": 200,
	"air>heavy": 175,
	"heavy>building": 150,
}


static func bonus(attacker: String, target: String) -> int:
	return BONUS.get(attacker + ">" + target, 100)


static func def_of(type: String) -> Dictionary:
	if UNITS.has(type):
		return UNITS[type]
	return BUILDINGS.get(type, {})
