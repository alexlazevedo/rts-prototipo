class_name TeamColor
## Aplica a cor do time e a intensidade do brilho num asset importado (.glb).
## Os assets usam materiais com nomes fixos:
##   TeamColor -> recebe a cor do time
##   Glow, CoreGlow, Ore -> emissivos; ganham energia para o efeito de brilho (glow)
## Os materiais gerados são compartilhados por cor (cache), não duplicados por unidade.

const GLOW_ENERGY := {"Glow": 3.0, "CoreGlow": 3.0, "Ore": 1.6}

static var _cache: Dictionary = {}


static func apply(root: Node, color: Color) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as BaseMaterial3D
			if mat == null:
				continue
			var key := ""
			if mat.resource_name == "TeamColor":
				key = "team:%s:%d" % [color.to_html(false), mat.get_instance_id()]
			elif GLOW_ENERGY.has(mat.resource_name):
				key = "glow:%d" % mat.get_instance_id()
			else:
				continue
			if not _cache.has(key):
				var d := mat.duplicate() as BaseMaterial3D
				if mat.resource_name == "TeamColor":
					d.albedo_color = color
				else:
					d.emission_enabled = true
					d.emission_energy_multiplier = GLOW_ENERGY[mat.resource_name]
				_cache[key] = d
			mi.set_surface_override_material(i, _cache[key])
