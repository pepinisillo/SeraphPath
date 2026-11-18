extends "res://pruebas/comun.gd"
## La zona 3 y los finales: qué final toca según la Humanidad y los recuerdos, los eventos de
## la zona 3 (saltar una parada, Prueba de la sed más cerca de la salida) y ceder en el fondo.

const ARCHIVO := "user://prueba_finales.cfg"


func _initialize():
	await process_frame
	var e := EstadoExpedicion.actual()
	e.archivo_recuerdos = ARCHIVO
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVO))
	e.cargar_recuerdos()

	print("A) Zona 3")
	e.nueva()
	e.pasar_de_zona()
	e.pasar_de_zona()
	comprobar("Shibuya", [e.zona, e.datos_zona().nombre, e.escena_infiltracion(), e.nombre_parada("jefe")],
		[3, "Shibuya", "res://escenas/mapa_shibuya.tscn", "Jefe: Guren Ichinose"])
	e.indice = 1
	e.elegir_ruta("arriesgada")
	e.indice = 2
	comprobar("la ruta arriesgada entra por el río", e.escena_infiltracion(), "res://escenas/mapa_rio.tscn")
	comprobar("el jefe pelea en el patio", e.datos_zona().mapa_jefe, "res://escenas/mapa_patio.tscn")
	comprobar("los eventos de la zona 3", Eventos.de_zona(3).map(func(ev): return ev.id), ["carta", "desertor", "escuadron_yuu"])
	e.indice = 5
	comprobar("tras Guren se acaba la expedición", [e.zona_terminada(), e.ZONAS.has(4)], [true, false])

	print("B) Qué final toca")
	e.humanidad = 3
	e.recuerdos = [1, 2, 3, 4, 5, 6, 7]
	comprobar("Humanidad 3 y los siete recuerdos: la sangre de Yuu", e.final_alcanzado(), "La sangre de Yuu")
	e.recuerdos = [1, 2, 3, 4, 5, 6]
	comprobar("sin los siete, en el límite", e.final_alcanzado(), "En el límite")
	e.humanidad = 1
	comprobar("Humanidad 1: en el límite", e.final_alcanzado(), "En el límite")
	e.humanidad = 0
	comprobar("Humanidad 0: vampiro completo", e.final_alcanzado(), "Vampiro completo")
	e.marcar_final("En el límite")
	e.marcar_final("En el límite")
	e.finales_vistos = []
	e.cargar_recuerdos()
	comprobar("los finales vistos se guardan, sin repetir", e.finales_vistos, ["En el límite"])

	print("C) El desertor: saltar la siguiente parada")
	e.nueva()
	e.elegir_ruta("segura")
	e.indice = 2 # el evento
	e.aplicar_efectos(Eventos.por_id("desertor").opciones[0].efectos)
	e.completar_parada()
	comprobar("del evento salta la prueba y va al jefe", e.parada_actual(), "jefe")

	print("D) El escuadrón de Yuu: la prueba empieza más cerca")
	e.nueva()
	e.aplicar_efectos(Eventos.por_id("escuadron_yuu").opciones[0].efectos)
	var m: Mapa = await cargar_mapa("res://escenas/mapa_prueba_sed.tscn")
	comprobar("Mika empieza en el punto cercano", m.mika.pos, Vector2(m.inicio_cerca) + Vector2(0.5, 0.5))
	m.queue_free()
	m = await cargar_mapa("res://escenas/mapa_prueba_sed.tscn")
	comprobar("solo la siguiente", m.mika.pos, Vector2(m.inicio_mika) + Vector2(0.5, 0.5))
	m.queue_free()

	print("E) Ceder en el fondo de la zona 3")
	e.nueva()
	e.recuerdos = [1, 2]
	e.recuerdo_nuevo = 2
	e.sed = 70
	e.ceder_en_fondo()
	comprobar("pierde el recuerdo recién ganado, 1 de Humanidad y la sed; gana una mejora",
		[e.recuerdos, e.recuerdo_nuevo, e.humanidad, e.sed, e.mejoras.size()], [[1], 0, 2, 0, 1])
	e.activa = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVO))
	terminar()
