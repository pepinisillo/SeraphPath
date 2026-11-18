extends "res://pruebas/comun.gd"
## Paso 10: eventos de texto y encadenado de paradas. Efectos de cada evento, modificadores de
## los recuerdos, paso del estado de Mika entre paradas y una expedición completa navegando
## por las escenas reales.

const ARCHIVO := "user://prueba_recuerdos.cfg"

var expe: EstadoExpedicion


func escena() -> Node:
	for i in 3:
		await process_frame
	return current_scene


## Si hay guion en disco salen escenas con diálogo: las salta (y las pantallas de escena sueltas).
func saltar_dialogos(s: Node) -> Node:
	for i in 20:
		if not is_instance_valid(s):
			s = await escena()
			continue
		var d = s.get("dialogo")
		if d != null and is_instance_valid(d) and not d.acabado:
			d.saltar()
			s = await escena()
			continue
		if s.name == "Escena":
			s = await escena()
			continue
		return s
	return s


func botones(nodo: Node) -> Array:
	return nodo.find_children("*", "Button", true, false).filter(func(b): return not b.disabled)


func pulsar(nodo: Node, empieza_por: String) -> bool:
	for b in botones(nodo):
		if b.text.begins_with(empieza_por):
			b.pressed.emit()
			return true
	print("FALLO: no hay botón «%s» en %s; hay %s" % [empieza_por, nodo.name, botones(nodo).map(func(b): return b.text)])
	ok = false
	return false


func mapa_en_expedicion(prueba := false) -> Mapa:
	var m: Mapa = load(expe.ESCENA_PRUEBA if prueba else expe.ESCENA_INFILTRACION).instantiate()
	root.add_child(m)
	m.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	m.get_node("HUD").process_mode = Node.PROCESS_MODE_DISABLED
	m.efectos.permitir_paradas = false
	return m


func _initialize():
	await process_frame
	expe = EstadoExpedicion.actual()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVO))
	expe.archivo_recuerdos = ARCHIVO
	expe.cargar_recuerdos()

	print("A) Estructura de la zona")
	expe.nueva()
	comprobar("paradas antes de elegir", expe.paradas(), ["infiltracion", "?", "?", "prueba", "jefe"])
	expe.indice = 1
	comprobar("toca elegir ruta", expe.toca_elegir_ruta(), true)
	expe.elegir_ruta("arriesgada")
	comprobar("ruta arriesgada", expe.paradas(), ["infiltracion", "emboscada", "infiltracion", "prueba", "jefe"])
	var ids := Eventos.de_zona(1).map(func(e): return e.id)
	comprobar("eventos de la zona 1 (sin los que dependen de sistemas que faltan)", ids, ["doncella", "lacus_rene", "copa_ferid", "carta"])
	var salidos := []
	for i in 4: salidos.append(expe.elegir_evento())
	salidos.sort()
	comprobar("no se repiten hasta agotarlos", salidos, ["carta", "copa_ferid", "doncella", "lacus_rene"])

	print("B) Efectos de los eventos")
	expe.nueva()
	expe.aplicar_efectos(Eventos.por_id("doncella").opciones[0].efectos)
	comprobar("doncella: +1 vial", expe.viales, Config.VIALES_INICIALES + 1)
	expe.sed = 50
	expe.aplicar_efectos(Eventos.por_id("copa_ferid").opciones[0].efectos)
	comprobar("copa: sed a 0", expe.sed, 0)
	comprobar("copa: −1 Humanidad", expe.humanidad, 2)
	comprobar("copa: patrullas visibles", expe.patrullas_visibles, true)
	expe.vida = 5
	expe.aplicar_efectos(Eventos.por_id("carta").opciones[1].efectos)
	comprobar("carta, descansar: +3 de vida", expe.vida, 8)
	expe.aplicar_efectos(Eventos.por_id("carta").opciones[0].efectos)
	expe.aplicar_efectos(Eventos.por_id("lacus_rene").opciones[1].efectos)
	var m: Mapa = await mapa_en_expedicion()
	comprobar("el mapa recibe el estado (viales)", m.mika.viales, Config.VIALES_INICIALES + 1)
	comprobar("y la Humanidad", m.mika.humanidad, 2)
	comprobar("Lacus y René, negarse: empieza en Sospecha", m.soldados().all(func(s): return s.estado == Soldado.Estado.SOSPECHA), true)
	paso(m, 0.1)
	comprobar("copa: siluetas de todas las patrullas", m.get_node("S1").silueta.visible, true)
	m.mika.pos = Vector2(0.5, 0.5)
	var sed := m.mika.sed
	paso(m, 10.0)
	comprobar("carta, escribir: la sed no sube en este mapa", m.mika.sed, sed)
	comprobar("y se consumió", expe.sed_congelada, false)
	m.queue_free()
	await process_frame
	var mejoras := expe.aplicar_efectos(Eventos.por_id("soldado_atrapado").opciones[0].efectos)
	comprobar("beber en un evento ofrece 2 mejoras", mejoras.size(), 2)
	expe.elegir_mejora(Mejoras.VIGOR)
	comprobar("Vigor desde un evento", expe.vida_max, 16)

	print("C) Emboscada y estado entre paradas")
	expe.nueva()
	expe.siguiente_empieza = "alarma"
	m = await mapa_en_expedicion()
	comprobar("la emboscada empieza en Alarma", m.alerta.activa, true)
	m.mika.sed = 61; m.mika.viales = 2; m.mika.mejoras.assign([Mejoras.FUERZA])
	m.terminar(true)
	comprobar("el estado vuelve a la expedición", [expe.sed, expe.viales, expe.mejoras], [61, 2, [Mejoras.FUERZA]])
	paused = false
	m.queue_free()

	print("D) Prueba de la sed y recuerdos")
	expe.nueva()
	m = await mapa_en_expedicion(true)
	m.terminar(false, "fallida")
	comprobar("fallida: el siguiente mapa empieza en Alarma", expe.siguiente_empieza, "alarma")
	comprobar("fallida: sed 90", expe.sed, 90)
	paused = false
	m.queue_free()
	m = await mapa_en_expedicion(true)
	m.terminar(true)
	comprobar("superada: gana el recuerdo 1", expe.recuerdo_nuevo, 1)
	paused = false
	m.queue_free()
	expe.recuerdos = []
	expe.cargar_recuerdos()
	comprobar("el recuerdo queda guardado en disco", expe.recuerdos, [1])
	for n in [2, 3, 4, 5, 6]: expe.ganar_recuerdo()
	expe.nueva()
	comprobar("recuerdo 1: empieza con 4 viales", expe.viales, 4)
	m = await mapa_en_expedicion()
	var mika := m.mika
	comprobar("recuerdo 2: sed 2 por golpe", mika.sed_por_golpe, 2)
	comprobar("recuerdo 5: Sediento desde 70", mika.velocidad(), Config.VELOCIDAD_MIKA)
	mika.sed = 70
	comprobar("    (con 70 ya va lenta)", mika.velocidad(), Config.VELOCIDAD_MIKA_SEDIENTO)
	comprobar("recuerdo 6: Impulso cuesta 5", mika.sed_impulso, 5)
	mika.recibir_golpe(100)
	comprobar("recuerdo 4: sobrevive con 1 de vida", [mika.vida, mika.caida], [1, false])
	mika.recibir_golpe(100)
	comprobar("    solo una vez", mika.caida, true)
	m.queue_free()
	await process_frame
	paused = false

	print("E) Expedición completa por las escenas reales")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVO))
	expe.cargar_recuerdos()
	change_scene_to_file(expe.ESCENA_TITULO)
	var s := await escena()
	comprobar("título", s.name, "Titulo")
	pulsar(s, "Nueva expedición")
	s = await escena()
	if s.name == "Inicio": # solo si hay guion en disco
		s = await saltar_dialogos(s)
		pulsar(s, "Empezar la expedición")
		s = await escena()
		comprobar("el inicio queda visto", expe.inicio_visto, true)
	comprobar("mapa de paradas", s.name, "Ruta")
	pulsar(s, "Entrar: Infiltración")
	s = await escena()
	comprobar("infiltración", s.name, "MapaPuestoControl")
	s.mika.pos = Vector2(29.5, 0.6) # en la salida
	await physics_frame
	await physics_frame
	var res: Resultado = s.get_node_or_null("Resultado")
	comprobar("resultado al llegar a la salida", res != null, true)
	pulsar(res, "Continuar")
	s = await escena()
	comprobar("de vuelta en las paradas, toca elegir ruta", expe.toca_elegir_ruta(), true)
	pulsar(s, "Ruta segura")
	pulsar(s, "Entrar: Refugio")
	s = await escena()
	comprobar("refugio", s.name, "Refugio")
	s = await saltar_dialogos(s)
	pulsar(s, "Curar")
	pulsar(s, "Continuar")
	s = await escena()
	pulsar(s, "Entrar: Evento")
	s = await escena()
	comprobar("evento", s.name, "Evento")
	s = await saltar_dialogos(s)
	s.elegir(0)
	s = await saltar_dialogos(s)
	if not s.mejoras_ofrecidas.is_empty():
		pulsar(s, Mejoras.nombre(s.mejoras_ofrecidas[0]))
	pulsar(s, "Continuar")
	s = await escena()
	pulsar(s, "Entrar: Prueba de la sed")
	s = await saltar_dialogos(await escena())
	comprobar("prueba de la sed", s.name, "MapaPruebaSed")
	s.mika.pos = Vector2(11.5, 0.6)
	await physics_frame
	await physics_frame
	res = s.get_node_or_null("Resultado")
	pulsar(res, "Continuar")
	s = await saltar_dialogos(await escena())
	comprobar("enseña el recuerdo ganado", [str(s.name), s.mostrando], ["Recuerdo", 1])
	s = await saltar_dialogos(s)
	pulsar(s, "Continuar")
	s = await escena()
	pulsar(s, "Entrar: Jefe")
	s = await escena()
	comprobar("el jefe: el hangar de Ferid", s.name, "MapaHangar")
	s.mika.pos = Vector2(39.5, 5.6) # en la rampa
	await physics_frame
	await physics_frame
	res = s.get_node_or_null("Resultado")
	comprobar("resultado al llegar a la rampa", res != null, true)
	pulsar(res, "Continuar")
	s = await saltar_dialogos(await escena())
	comprobar("escapar de Ferid da otro recuerdo", [str(s.name), s.mostrando], ["Recuerdo", 2])
	s = await saltar_dialogos(s)
	pulsar(s, "Continuar")
	s = await escena()
	comprobar("fin de la zona 1", [str(s.name), expe.zona_terminada()], ["Final", true])
	pulsar(s, "Volver al título")
	s = await escena()
	comprobar("vuelta al título", s.name, "Titulo")
	comprobar("con los recuerdos disponibles", expe.recuerdos, [1, 2])

	print("F) Caer termina la expedición")
	expe.nueva()
	expe.indice = 0
	expe.entrar()
	s = await escena()
	s.mika.recibir_golpe(100)
	await create_timer(Config.RESULTADO_ESPERA_CAIDA + 0.2, true).timeout
	res = s.get_node_or_null("Resultado")
	pulsar(res, "Fin de la expedición")
	s = await escena()
	comprobar("pantalla de caída", [str(s.name), expe.activa], ["Final", false])
	comprobar("la caída cuenta para el final «Caído»", expe.caidas, 1)
	comprobar("los recuerdos se conservan", expe.recuerdos, [1, 2])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVO))
	terminar()
