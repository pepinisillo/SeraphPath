extends "res://pruebas/comun.gd"
## Sonido provisional: cada efecto se genera y suena; las capas de música suben y bajan con el
## estado (sospecha, alarma, sed).


func _initialize():
	await process_frame
	Sonido.silencio = false
	var m: Mapa = await nuevo_mapa(true)
	var son: Sonido = m.sonido
	comprobar("cuatro capas", son.capas.keys(), ["fondo", "tension", "alarma", "sed"])
	for nombre in ["tajo", "silencioso", "impulso", "golpe", "alarma", "sospecha", "beber", "vial", "talisman"]:
		var flujo := son._efecto(nombre)
		if flujo == null or flujo.data.size() < 1000:
			ok = false
			print("FALLO: el efecto %s no se generó" % nombre)
	son._process(0.1)
	comprobar("en calma: solo el fondo", [son._objetivo.fondo > 0.0, son._objetivo.tension, son._objetivo.alarma], [true, 0.0, 0.0])
	m.get_node("S1").oir(m.get_node("S1").pos)
	son._process(0.1)
	comprobar("alguien sospecha: tensión", son._objetivo.tension > 0.0, true)
	m.alerta.dar_alarma(m.mika.pos)
	son._process(0.1)
	comprobar("Alarma: la capa de alarma, sin la de tensión", [son._objetivo.alarma > 0.0, son._objetivo.tension], [true, 0.0])
	m.mika.sed = 90
	son._process(0.1)
	comprobar("con mucha sed, el latido", son._objetivo.sed > 0.5, true)
	for i in 30:
		son._process(0.1)
	comprobar("las capas suben poco a poco hasta su volumen", db_to_linear(son.capas.alarma.volume_db) > 0.5, true)
	m.queue_free()
	Sonido.silencio = true
	terminar()
