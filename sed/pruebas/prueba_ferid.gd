extends "res://pruebas/comun.gd"
## Ferid Bathory, jefe de la zona 1: persigue, avisa y embiste (doble en la segunda fase),
## atrapa a Mika y lo devuelve al punto de control. Y que sea justo: corriendo sin esquivar
## te atrapa; apartándose de la línea marcada se llega vivo a la rampa.

const ESCENA := "res://escenas/mapa_hangar.tscn"
const RAMPA := Vector2(39.5, 5.5)


func _initialize():
	await process_frame
	print("A) Estructura")
	var m: Mapa = await cargar_mapa(ESCENA)
	comprobar("jefe y puntos de control", [m.jefe, m.puntos_de_control, m.fase2_desde], ["Ferid Bathory", [Vector2i(0, 6), Vector2i(15, 6), Vector2i(27, 6)], 1])
	comprobar("Ferid está, y no es un soldado", [m.ferid != null, m.soldados().size()], [true, 0])
	comprobar("la rampa es la salida", [m.es_salida(Vector2i(39, 5)), m.es_salida(Vector2i(39, 6))], [true, true])
	comprobar("hay camino a la rampa", m.camino(m.mika.pos, RAMPA).is_empty(), false)
	m.queue_free()

	print("B) Espera, persigue y avisa")
	m = await cargar_mapa(ESCENA)
	var f: Ferid = m.ferid
	m.mika.pos = Vector2(6.5, 6.5)
	paso(m, Config.FERID_ESPERA_INICIAL - 0.1)
	comprobar("al principio espera", f.estado, Ferid.Estado.ESPERA)
	var antes := f.pos.distance_to(m.mika.pos)
	paso(m, 0.15)
	comprobar("luego persigue y se acerca", [f.estado != Ferid.Estado.ESPERA, f.pos.distance_to(m.mika.pos) < antes], [true, true])
	var avisa := false
	for i in roundi(3.0 / DT):
		paso(m)
		m.mika.sed = 0
		if f.estado == Ferid.Estado.AVISA:
			avisa = true
			break
	comprobar("cerca y viéndolo, avisa la embestida", avisa, true)
	var linea := f.linea_de_embestida()
	comprobar("la línea marcada va hacia Mika", (linea[1] - linea[0]).normalized().dot((m.mika.pos - linea[0]).normalized()) > 0.99, true)
	# Mika se aparta de la línea: la embestida no lo alcanza.
	var lado := Vector2(-(linea[1] - linea[0]).y, (linea[1] - linea[0]).x).normalized()
	var vida := m.mika.vida
	m.mika.pos += lado * 1.6 if not m.es_muro(Vector2i((m.mika.pos + lado * 1.6).floor())) else -lado * 1.6
	paso(m, Config.FERID_EMBESTIDA_AVISO + Config.FERID_EMBESTIDA_DURACION + 0.05)
	comprobar("apartándose, la embestida falla", [m.mika.vida, f.atrapadas], [vida, 0])
	comprobar("Ferid acaba al final de la línea y se recupera", [f.pos.distance_to(linea[1]) < 0.1, f.estado], [true, Ferid.Estado.RECUPERA])
	m.queue_free()

	print("C) Atrapa: vida, punto de control y espera")
	m = await cargar_mapa(ESCENA)
	f = m.ferid
	m.mika.pos = Vector2(16.5, 4.5) # pasado el segundo punto de control
	paso(m)
	comprobar("pasa el punto de control 1 (segunda fase)", [m.punto_de_control, f.fase], [1, 2])
	f.pos = m.mika.pos + Vector2(0.3, 0)
	f.estado = Ferid.Estado.PERSIGUE
	vida = m.mika.vida
	paso(m)
	comprobar("lo atrapa: pierde vida", [f.atrapadas, m.mika.vida], [1, vida - Config.FERID_DANO])
	comprobar("vuelve al punto de control", m.mika.pos, Vector2(15.5, 6.5))
	comprobar("Ferid queda lejos y espera", [f.estado, f.pos.distance_to(m.mika.pos) >= 4.0], [Ferid.Estado.ESPERA, true])
	m.queue_free()

	print("D) Segunda fase: dos embestidas seguidas")
	m = await cargar_mapa(ESCENA)
	f = m.ferid
	m.punto_de_control = 1
	m.mika.pos = Vector2(15.5, 3.5)
	f.pos = Vector2(11.5, 3.5)
	f.estado = Ferid.Estado.PERSIGUE
	var embestidas := 0
	var estado_antes := f.estado
	for i in roundi(2.5 / DT):
		paso(m)
		m.mika.sed = 0
		if f.estado == Ferid.Estado.EMBISTE and estado_antes != Ferid.Estado.EMBISTE:
			embestidas += 1
			m.mika.pos = Vector2(15.5, 0.5) if m.mika.pos.y > 2.0 else Vector2(15.5, 4.5) # se aparta
		estado_antes = f.estado
		if f.estado == Ferid.Estado.RECUPERA:
			break
	comprobar("embiste dos veces antes de recuperarse", embestidas, 2)
	m.queue_free()

	print("E) Justo: corriendo sin esquivar te atrapa; esquivando llegas")
	var sin_esquivar := await _jugar(false)
	print("    sin esquivar: llega=%s, atrapado %d veces, vida %d, %.1f s" % sin_esquivar)
	comprobar("sin esquivar, te atrapa alguna vez", sin_esquivar[1] >= 1, true)
	var esquivando := await _jugar(true)
	print("    esquivando: llega=%s, atrapado %d veces, vida %d, %.1f s" % esquivando)
	comprobar("esquivando, llega vivo a la rampa", [esquivando[0], esquivando[2] > 0], [true, true])
	terminar()


## Un jugador automático: corre hacia la rampa por el camino más corto; con `esquivar`, cuando
## Ferid marca una embestida que lo va a alcanzar, se aparta de la línea. Devuelve
## [llegó, veces atrapado, vida, segundos].
func _jugar(esquivar: bool) -> Array:
	var m: Mapa = await cargar_mapa(ESCENA)
	var f: Ferid = m.ferid
	var t := 0.0
	while t < 60.0 and not m.terminado and not m.mika.caida:
		var mika := m.mika
		var paso_mika := Vector2.ZERO
		var linea := f.linea_de_embestida()
		if esquivar and not linea.is_empty():
			var cerca := Geometry2D.get_closest_point_to_segment(mika.pos, linea[0], linea[1])
			if mika.pos.distance_to(cerca) < 1.3:
				var fuera := mika.pos - cerca
				if fuera.length() < 0.01:
					fuera = Vector2(-(linea[1] - linea[0]).y, (linea[1] - linea[0]).x)
				paso_mika = fuera.normalized()
				if m.es_muro(Vector2i((mika.pos + paso_mika * 0.6).floor())):
					paso_mika = -paso_mika
		if paso_mika == Vector2.ZERO:
			var camino := m.camino(mika.pos, RAMPA)
			if not camino.is_empty():
				paso_mika = (camino[0] - mika.pos).normalized()
		var nueva := mika.pos + paso_mika * Config.VELOCIDAD_MIKA * DT
		if not m.es_muro(Vector2i(nueva.floor())):
			mika.pos = nueva
		mika.sed = 0
		paso(m)
		t += DT
	var resultado := [m.terminado and not m.mika.caida, f.atrapadas, m.mika.vida, t]
	m.queue_free()
	paused = false
	return resultado
