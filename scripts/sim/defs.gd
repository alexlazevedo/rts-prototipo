class_name Defs
## Regras e números do jogo. Tudo em inteiros:
##   distância em centímetros, tempo em ticks (10 por segundo), velocidade em cm/tick.
## Ajuste de balanceamento = mudar números aqui e rodar os testes (tests/test_sim.gd).

const TICK_HZ := 10
const MATCH_TICKS := 6000        # 10 min: fim garantido por pontos
const ARMOR_OFF_TICK := 4800     # 8 min: Bases perdem blindagem (dano em dobro)
const HALF := 14000              # mapa 280 m x 280 m (de -HALF a +HALF nos dois eixos)
const COMBAT_CAP := 10
const WORKER_CAP := 6
const START_ORE := 250
const START_WORKERS := 3
const BUILD_RANGE := 3600        # novo prédio a até 36 m de um prédio seu

const CARRY := 10                # minério por viagem
const HARVEST_TICKS := 16
const ORE_RADIUS := 420

# Núcleo: controlar a zona central (só você com unidades de combate lá) rende 1 Núcleo/s
const CORE_RADIUS := 1600
const CORE_TICKS := 10

# terreno (ver SimWorld): platô de 64 m nas bases, 4 m de altura, rampa de 8 m
const PLATEAU_HALF := 3200
const PLATEAU_H := 400
const RAMP_LEN := 900
const RAMP_HALF_W := 400
const CELL := 200                # grade de navegação: 2 m
const FOG_CELL := 400            # grade de visão: 4 m

const FACTIONS := ["militar", "energia"]

## Papéis (iguais nas duas facções) -> tipo concreto de cada facção
const ROSTER := {
	"militar": {"worker": "coletor", "light": "buggy", "heavy": "tanque", "aa": "antiaereo", "air": "vtol",
		"base": "base", "fabrica": "fabrica", "hangar": "hangar", "torre": "torre", "lab": "laboratorio"},
	"energia": {"worker": "drone", "light": "sentinela", "heavy": "obelisco", "aa": "prisma", "air": "lamina",
		"base": "e_base", "fabrica": "e_fabrica", "hangar": "e_hangar", "torre": "e_torre", "lab": "e_laboratorio"},
}

## Militar: mais vida, mais lenta, prédios mais fortes.
## Energia: menos vida + escudo que se regenera (5 s sem levar dano), mais rápida.
const UNITS := {
	# ---- Militar
	"coletor": {"faction": "militar", "cost": 50, "time": 100, "hp": 70, "speed": 45, "radius": 110, "air": false,
		"worker": true, "class": "worker", "tag": "COL", "from": "base", "sight": 1000, "model": "militar_coletor"},
	"buggy": {"faction": "militar", "cost": 75, "time": 140, "hp": 120, "speed": 70, "radius": 110, "air": false,
		"range": 650, "dmg": 9, "cd": 6, "hits_ground": true, "hits_air": false, "sight": 1500,
		"class": "light", "tag": "BGY", "from": "fabrica", "model": "militar_buggy"},
	"tanque": {"faction": "militar", "cost": 150, "time": 220, "hp": 330, "speed": 34, "radius": 160, "air": false,
		"range": 1300, "dmg": 34, "cd": 22, "hits_ground": true, "hits_air": false, "sight": 1500, "tech": "nivel2",
		"class": "heavy", "tag": "TNQ", "from": "fabrica", "model": "militar_tanque_cerco"},
	"antiaereo": {"faction": "militar", "cost": 100, "time": 170, "hp": 185, "speed": 45, "radius": 130, "air": false,
		"range": 1200, "dmg": 22, "cd": 10, "hits_ground": false, "hits_air": true, "sight": 1500,
		"class": "aa", "tag": "AA", "from": "fabrica", "model": "militar_antiaereo"},
	"vtol": {"faction": "militar", "cost": 125, "time": 200, "hp": 165, "speed": 60, "radius": 150, "air": true,
		"range": 750, "dmg": 15, "cd": 8, "hits_ground": true, "hits_air": false, "sight": 1700,
		"class": "air", "tag": "VTL", "from": "hangar", "model": "militar_vtol"},
	# ---- Energia
	"drone": {"faction": "energia", "cost": 50, "time": 100, "hp": 45, "shield": 25, "speed": 52, "radius": 110, "air": false,
		"worker": true, "class": "worker", "tag": "DRN", "from": "base", "sight": 1000, "model": "energia_drone_extrator"},
	"sentinela": {"faction": "energia", "cost": 75, "time": 140, "hp": 75, "shield": 40, "speed": 84, "radius": 110, "air": false,
		"range": 650, "dmg": 9, "cd": 6, "hits_ground": true, "hits_air": false, "sight": 1600,
		"class": "light", "tag": "SEN", "from": "fabrica", "model": "energia_sentinela"},
	"obelisco": {"faction": "energia", "cost": 150, "time": 220, "hp": 200, "shield": 100, "speed": 38, "radius": 160, "air": false,
		"range": 1400, "dmg": 34, "cd": 22, "hits_ground": true, "hits_air": false, "sight": 1600, "tech": "nivel2",
		"class": "heavy", "tag": "OBE", "from": "fabrica", "model": "energia_obelisco"},
	"prisma": {"faction": "energia", "cost": 100, "time": 170, "hp": 115, "shield": 60, "speed": 52, "radius": 130, "air": false,
		"range": 1250, "dmg": 22, "cd": 10, "hits_ground": false, "hits_air": true, "sight": 1600,
		"class": "aa", "tag": "PRI", "from": "fabrica", "model": "energia_prisma"},
	"lamina": {"faction": "energia", "cost": 125, "time": 200, "hp": 100, "shield": 55, "speed": 72, "radius": 150, "air": true,
		"range": 750, "dmg": 15, "cd": 8, "hits_ground": true, "hits_air": false, "sight": 1800,
		"class": "air", "tag": "LAM", "from": "hangar", "model": "energia_lamina"},
}

const BUILDINGS := {
	# ---- Militar
	"base": {"faction": "militar", "role": "base", "cost": 0, "time": 0, "hp": 1800, "radius": 850,
		"produces": ["coletor"], "req": "", "model": "militar_base", "value": 400, "sight": 1400},
	"fabrica": {"faction": "militar", "role": "fabrica", "cost": 150, "time": 250, "hp": 850, "radius": 700,
		"produces": ["buggy", "tanque", "antiaereo"], "req": "", "model": "militar_fabrica", "value": 150, "sight": 1000},
	"hangar": {"faction": "militar", "role": "hangar", "cost": 175, "time": 300, "hp": 700, "radius": 750,
		"produces": ["vtol"], "req": "fabrica", "model": "militar_hangar", "value": 175, "sight": 1000},
	"torre": {"faction": "militar", "role": "torre", "cost": 100, "time": 200, "hp": 600, "radius": 320,
		"produces": [], "req": "", "model": "militar_torre", "value": 100, "sight": 1500,
		"range": 1250, "dmg": 15, "cd": 8, "hits_ground": true, "hits_air": true, "class": "building"},
	"laboratorio": {"faction": "militar", "role": "lab", "cost": 150, "time": 250, "hp": 650, "radius": 650,
		"produces": [], "research": ["nivel2", "armas"], "req": "fabrica", "model": "militar_laboratorio", "value": 150, "sight": 1000},
	# ---- Energia
	"e_base": {"faction": "energia", "role": "base", "cost": 0, "time": 0, "hp": 1400, "shield": 500, "radius": 850,
		"produces": ["drone"], "req": "", "model": "energia_base", "value": 400, "sight": 1400},
	"e_fabrica": {"faction": "energia", "role": "fabrica", "cost": 150, "time": 250, "hp": 650, "shield": 220, "radius": 700,
		"produces": ["sentinela", "obelisco", "prisma"], "req": "", "model": "energia_fabrica", "value": 150, "sight": 1000},
	"e_hangar": {"faction": "energia", "role": "hangar", "cost": 175, "time": 300, "hp": 550, "shield": 180, "radius": 750,
		"produces": ["lamina"], "req": "fabrica", "model": "energia_hangar", "value": 175, "sight": 1000},
	"e_torre": {"faction": "energia", "role": "torre", "cost": 100, "time": 200, "hp": 430, "shield": 170, "radius": 320,
		"produces": [], "req": "", "model": "energia_torre", "value": 100, "sight": 1600,
		"range": 1300, "dmg": 15, "cd": 8, "hits_ground": true, "hits_air": true, "class": "building"},
	"e_laboratorio": {"faction": "energia", "role": "lab", "cost": 150, "time": 250, "hp": 500, "shield": 160, "radius": 650,
		"produces": [], "research": ["nivel2", "armas"], "req": "fabrica", "model": "energia_laboratorio", "value": 150, "sight": 1000},
}

## Pesquisas do laboratório (custam minério + Núcleo)
const TECHS := {
	"nivel2": {"name": "Nível 2", "ore": 100, "core": 25, "time": 250},
	"armas": {"name": "Armas +20%", "ore": 100, "core": 40, "time": 300, "req": "nivel2"},
}

## Ciclo de contra-ataque (%): leve > antiaéreo > aérea > pesada > leve
const BONUS := {
	"light>aa": 150,
	"heavy>light": 200,
	"air>heavy": 175,
	"heavy>building": 150,
}

const SHIELD_DELAY := 50         # ticks sem dano antes do escudo voltar
const SHIELD_REGEN_DIV := 40     # escudo volta em ~4 s


static func bonus(attacker: String, target: String) -> int:
	return BONUS.get(attacker + ">" + target, 100)


static func def_of(type: String) -> Dictionary:
	if UNITS.has(type):
		return UNITS[type]
	return BUILDINGS.get(type, {})


static func role_of(type: String) -> String:
	if BUILDINGS.has(type):
		return BUILDINGS[type]["role"]
	if UNITS.has(type):
		return UNITS[type]["class"]
	return ""


static func type_for(faction: String, role: String) -> String:
	return ROSTER[faction][role]
