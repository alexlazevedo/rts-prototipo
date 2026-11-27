extends Node
## Captura rápida para conferência visual (rodar com: -- --quickshot)
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var g := get_parent()
	await get_tree().create_timer(0.3).timeout
	g._on_start("normal", false)
	var w: SimWorld = g.world
	for i in 4:
		var u := w._spawn_unit(0, ["buggy", "tanque", "antiaereo", "vtol"][i], -6500, -1200 + i * 800)
		u.hp = u.max_hp * (i + 1) / 5
		g.selected[u.id] = true
	g.cam_rig.call("focus", Vector3(-68, 0, 0))
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("AUTOTEST_SHOTS").path_join("quick.png"))
	print("bars_drawn=", g.hud.bars_drawn)
	get_tree().quit()
