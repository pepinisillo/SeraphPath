extends "res://pruebas/comun.gd"
## El arte en 8 direcciones: sin arte, los personajes siguen como cápsulas; con un SpriteFrames
## en arte/personajes/<nombre>.tres, se elige la animación «<estado>_<dirección>» (o la más
## parecida que exista).

const CARPETA := "user://arte_prueba"


func _initialize():
	await process_frame
	print("A) Sin arte")
	var m: Mapa = await nuevo_mapa()
	comprobar("Mika y los soldados, sin arte: cápsulas", [m.mika.animador.activo, m.get_node("S1").animador.activo], [false, false])
	m.queue_free()

	print("B) Con un arte de muestra para Mika")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
	var frames := SpriteFrames.new()
	var imagen := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var textura := ImageTexture.create_from_image(imagen)
	for animacion in ["quieto_e", "quieto_n", "correr_se", "tajo", "derribado"]:
		frames.add_animation(animacion)
		frames.add_frame(animacion, textura)
	ResourceSaver.save(frames, CARPETA.path_join("mika.tres"))
	Animador.carpeta = CARPETA
	m = await nuevo_mapa()
	var a: Animador = m.mika.animador
	comprobar("con arte, se activa", a.activo, true)
	comprobar("estado y dirección exactos", a.nombre_animacion("correr", 1), "correr_se")
	comprobar("sin esa dirección, el estado a secas", a.nombre_animacion("tajo", 6), "tajo")
	comprobar("sin ese estado, quieto en esa dirección", a.nombre_animacion("beber", 6), "quieto_n")
	comprobar("los soldados siguen sin arte", m.get_node("S1").animador.activo, false)
	m.mika.mirada = Vector2(1, 1).normalized()
	m.mika.queue_redraw()
	await process_frame
	comprobar("Mika quieto: la animación de quieto", a.animation.begins_with("quieto"), true)
	m.mika.recibir_golpe(100)
	m.mika.queue_redraw()
	await process_frame
	comprobar("caído: derribado", a.animation, "derribado")
	m.queue_free()
	Animador.carpeta = Animador.CARPETA
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CARPETA.path_join("mika.tres")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CARPETA))
	terminar()
