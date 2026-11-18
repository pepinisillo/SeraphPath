extends "res://pruebas/comun.gd"
## Guardar a mitad de expedición: se guarda en el mapa de paradas y al terminar cada parada; al
## continuar se recupera todo; si se cerró dentro de una parada, cuenta como caída.

const ARCHIVO := "user://prueba_guardar.cfg"


func _initialize():
	await process_frame
	var e := EstadoExpedicion.actual()
	comprobar("desde una prueba no se tocan los archivos de verdad", [e.archivo_partida, e.archivo_recuerdos], ["user://prueba_expedicion.cfg", "user://prueba_recuerdos_auto.cfg"])
	e.archivo_partida = ARCHIVO
	e.borrar_partida()

	print("A) Guardar y continuar")
	e.nueva()
	e.zona = 2
	e.ruta = "segura"
	e.indice = 2
	e.vida = 7
	e.sed = 44
	e.humanidad = 2
	e.viales = 3
	e.mejoras.assign([Mejoras.FUERZA])
	e.filos.assign([Filos.MUDO, Filos.KRUL])
	e.eventos_vistos.assign(["carta"])
	e.siguiente_empieza = "sospecha"
	e.guardar_partida(false)
	comprobar("hay partida", e.hay_partida(), true)
	e.nueva() # se pierde todo en memoria
	comprobar("en memoria, una nueva", [e.zona, e.vida, e.filos], [1, Config.VIDA_MIKA, []])
	e.continuar_partida()
	await process_frame
	await process_frame
	comprobar("se recupera todo", [e.zona, e.ruta, e.indice, e.vida, e.sed, e.humanidad, e.viales, e.mejoras, e.filos, e.eventos_vistos, e.siguiente_empieza],
		[2, "segura", 2, 7, 44, 2, 3, [Mejoras.FUERZA], [Filos.MUDO, Filos.KRUL], ["carta"], "sospecha"])
	comprobar("y vuelve al mapa de paradas", current_scene.name if current_scene else "", "Ruta")

	print("B) Cerrar dentro de una parada cuenta como caída")
	e.entrar() # entra en la parada: se guarda «dentro»
	await process_frame
	await process_frame
	e.nueva()
	e.continuar_partida()
	await process_frame
	await process_frame
	comprobar("al continuar, cayó", [e.activa, e.hay_partida()], [false, false])
	comprobar("y se ve el final «Caído»", current_scene.name if current_scene else "", "Final")

	print("C) Abandonar borra la partida")
	e.nueva()
	e.guardar_partida(false)
	e.volver_al_titulo()
	comprobar("ya no hay partida", e.hay_partida(), false)
	e.borrar_partida()
	terminar()
