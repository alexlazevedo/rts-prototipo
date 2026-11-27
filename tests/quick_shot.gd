extends Node
## Captura rápida para conferência visual (rodar com: -- --quickshot)
## Joga 3 min de bots acelerados e fotografa a base e o centro do mapa.
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var g := get_parent()
	var dir := OS.get_environment("AUTOTEST_SHOTS")
	await get_tree().create_timer(0.3).timeout
	g.hud._choose_faction("energia")
	g._on_start("normal", false)
	g.bots.append(SimBot.new(g.world, 0, "normal"))   # o "jogador" também é bot, para a cena andar
	g.speed = 12.0
	while g.world.tick < 1900:
		await get_tree().create_timer(0.2).timeout
	g.speed = 1.0
	var b: SimEnt = g.world.base_of(0)
	g.cam_rig.call("focus", Vector3(b.x / 100.0 + 15, 0, b.y / 100.0 - 8))
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("quick_base.png"))
	g.view.fog_player = -1
	g.view.update_fog()
	g.cam_rig.set("distance", 120.0)
	g.cam_rig.call("zoom_by", 1.0)
	g.cam_rig.call("focus", Vector3(0, 0, 0))
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("quick_mapa.png"))
	get_tree().quit()
