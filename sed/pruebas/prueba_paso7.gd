extends "res://pruebas/comun.gd"
## Paso 7: el puesto de control completo con sus cuatro soldados.
## Además de comprobar rutas y muros transparentes, busca una ruta de la M a la E en la que
## ningún soldado vea a Mika nunca, y la reproduce en el juego real para confirmarla.

const PASO_PLAN := 0.1 # s entre muestras de la línea temporal
const HORIZONTE := 120.0 # s que se planifican
const FUERA := Vector2(-100, -100) # Mika aparcado fuera del mapa mientras se graba a los soldados

var linea := [] # [muestra] -> [[pos, mirada], ...] por soldado
var _visible_cache := {}


func _initialize():
	await process_frame
	print("A) Los cuatro soldados y sus rutas")
	var m: Mapa = await nuevo_mapa(true)
	var nombres := []
	for s in m.soldados():
		nombres.append(str(s.name))
	comprobar("soldados", nombres, ["S1", "S2", "S3", "S4"])
	comprobar("S2 en vaivén", m.get_node("S2").en_bucle, false)
	var extremos := {"S2": [Vector2(4.5, 3.5), Vector2(9.5, 3.5)], "S3": [Vector2(9.5, 4.5), Vector2(9.5, 8.5)], "S4": [Vector2(5.5, 0.5), Vector2(8.5, 0.5)]}
	var tocados := {}
	m.mika.pos = FUERA
	for i in roundi(30.0 / DT):
		paso(m)
		m.mika.sed = 0
		for nombre in extremos:
			for punto in extremos[nombre]:
				if m.get_node(nombre).pos.distance_to(punto) < 0.01:
					tocados[nombre + str(punto)] = true
	comprobar("cada vaivén llega a sus dos extremos", tocados.size(), 6)
	comprobar("nadie vio nada", m.estadisticas.alarmas == 0 and m.soldados().all(func(s): return s.estado == Soldado.Estado.OCULTO), true)
	m.queue_free()

	print("B) Muros semitransparentes")
	m = await nuevo_mapa(true)
	m.mika.pos = Vector2(2.5, 5.65) # justo detrás del muro (2,6)
	paso(m)
	comprobar("el muro de delante se vuelve transparente", m.muros.transparentes.has(Vector2i(2, 6)), true)
	comprobar("el de detrás no", m.muros.transparentes.has(Vector2i(2, 4)), false)
	m.mika.pos = Vector2(9.5, 5.5) # columna 9: ningún muro delante
	paso(m)
	comprobar("sin muros delante, ninguno transparente", m.muros.transparentes.is_empty(), true)
	m.queue_free()

	print("C) Ruta sin ser visto")
	m = await nuevo_mapa(true)
	_grabar_linea(m)
	var ruta := _buscar_ruta(m, Vector2i(0, 9), Vector2i(9, 0))
	comprobar("existe una ruta de la M a la E sin que nadie lo vea", ruta.is_empty(), false)
	m.queue_free()
	if not ruta.is_empty():
		print("    ruta (casilla, segundo): ", ruta.map(func(p): return "%s@%.1f" % [p[0], p[1]]))
		m = await nuevo_mapa(true)
		_reproducir(m, ruta)
		comprobar("al reproducirla llega a la salida", m.terminado, true)
		comprobar("sin alarmas", m.estadisticas.alarmas, 0)
		m.queue_free()
		paused = false
	terminar()


## Avanza el mapa con Mika fuera y guarda dónde está y adónde mira cada soldado en cada muestra.
func _grabar_linea(m: Mapa) -> void:
	m.mika.pos = FUERA
	var por_muestra := roundi(PASO_PLAN / DT)
	for k in roundi(HORIZONTE / PASO_PLAN) + 1:
		var foto := []
		for s in m.soldados():
			foto.append([s.pos, s.mirada])
		linea.append(foto)
		paso(m, por_muestra * DT)
		m.mika.sed = 0


func _visible(m: Mapa, punto: Vector2, k: int) -> bool:
	var clave := [punto, k]
	if _visible_cache.has(clave):
		return _visible_cache[clave]
	var resultado := false
	var soldados := m.soldados()
	for i in soldados.size():
		var s: Soldado = soldados[i]
		var antes := [s.pos, s.mirada]
		s.pos = linea[k][i][0]
		s.mirada = linea[k][i][1]
		resultado = s._puede_ver(punto)
		s.pos = antes[0]
		s.mirada = antes[1]
		if resultado:
			break
	_visible_cache[clave] = resultado
	return resultado


## Búsqueda en anchura sobre (casilla, muestra): cada paso es esperar una muestra o moverse a
## una casilla vecina a la velocidad de Mika. Devuelve [[casilla, segundo], ...] o [].
func _buscar_ruta(m: Mapa, inicio: Vector2i, meta: Vector2i) -> Array:
	var ultima := linea.size() - 1
	var previo := {[inicio, 0]: null}
	var cola := [[inicio, 0]]
	var vecinos := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var centro := func(c: Vector2i) -> Vector2: return Vector2(c) + Vector2(0.5, 0.5)
	while not cola.is_empty():
		var actual: Array = cola.pop_front()
		var celda: Vector2i = actual[0]
		var k: int = actual[1]
		if celda == meta:
			var ruta := []
			var nodo = actual
			while nodo != null:
				ruta.push_front([nodo[0], nodo[1] * PASO_PLAN])
				nodo = previo[nodo]
			return ruta
		var opciones := [[celda, 1]]
		for d in vecinos:
			var otra: Vector2i = celda + d
			if m.es_muro(otra):
				continue
			if d.x != 0 and d.y != 0 and (m.es_muro(celda + Vector2i(d.x, 0)) or m.es_muro(celda + Vector2i(0, d.y))):
				continue
			opciones.append([otra, ceili(Vector2(d).length() / Config.VELOCIDAD_MIKA / PASO_PLAN)])
		for opcion in opciones:
			var destino: Vector2i = opcion[0]
			var k2: int = k + opcion[1]
			if k2 > ultima or previo.has([destino, k2]):
				continue
			var seguro := true
			for j in range(k, k2 + 1): # posición interpolada en cada muestra del trayecto
				var f := float(j - k) / (k2 - k)
				if _visible(m, centro.call(celda).lerp(centro.call(destino), f), j):
					seguro = false
					break
			if seguro:
				previo[[destino, k2]] = actual
				cola.push_back([destino, k2])
	return []


## Mueve a Mika por la ruta en el juego real, fotograma a fotograma.
func _reproducir(m: Mapa, ruta: Array) -> void:
	var t := 0.0
	var i := 0
	while not m.terminado and t <= ruta[-1][1] + 1.0:
		while i < ruta.size() - 2 and t >= ruta[i + 1][1]:
			i += 1
		var a: Array = ruta[i]
		var b: Array = ruta[mini(i + 1, ruta.size() - 1)]
		var f := clampf((t - a[1]) / maxf(b[1] - a[1], 0.001), 0.0, 1.0)
		m.mika.pos = (Vector2(a[0]) + Vector2(0.5, 0.5)).lerp(Vector2(b[0]) + Vector2(0.5, 0.5), f)
		m.mika.sed = 0
		paso(m)
		t += DT
		for s in m.soldados():
			if s.medidor >= Config.DETECCION_SOSPECHA:
				ok = false
				print("FALLO: %s llegó a Sospecha en t=%.2f con Mika en %s" % [s.name, t, m.mika.pos])
				return
