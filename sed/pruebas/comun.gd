extends SceneTree
## Utilidades compartidas por las pruebas: mapa con el tiempo detenido, paso fijo y comprobaciones.

const DT := 1.0 / 60.0
const PASO_PLAN := 0.1 # s entre muestras de la línea temporal de la búsqueda de rutas
const HORIZONTE := 120.0 # s que se planifican
const FUERA := Vector2(-100, -100) # Mika aparcado fuera del mapa mientras se graba a los soldados
var ok := true
var linea := [] # [muestra] -> [[pos, mirada], ...] por soldado
var _visible_cache := {}
var _con_margen := false # solo la búsqueda con grupos planifica con margen


## Las pruebas de los pasos se escribieron con patrullas fijas; las que prueban el azar lo encienden.
## Los grupos que aparecen existen siempre (sin sorteo); aparecer_todos() los saca de golpe.
func _init() -> void:
	Soldado.patrullas_al_azar = false
	Aparicion.forzar = true


## Saca a todos los grupos del mapa a la vez, como si Mika hubiera pisado sus zonas.
## La búsqueda de ruta los necesita en el mapa desde el principio: es el caso más difícil.
func aparecer_todos(m: Mapa) -> void:
	for a in m.apariciones():
		a.aparecer()


## Carga el puesto de control sin que avance solo: las pruebas lo hacen avanzar con paso().
## Solo deja a los soldados nombrados (por defecto S1, con el que se escribieron las pruebas
## de los pasos 2 a 6); con `todos` deja a los cuatro.
func nuevo_mapa(todos := false) -> Mapa:
	var mapa: Mapa = load("res://escenas/mapa_puesto_control.tscn").instantiate()
	if not todos:
		for nombre in ["S2", "S3", "S4"]:
			mapa.get_node(nombre).free()
	root.add_child(mapa)
	mapa.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	mapa.get_node("HUD").process_mode = Node.PROCESS_MODE_DISABLED
	mapa.efectos.permitir_paradas = false
	return mapa


## Carga cualquier mapa, con todos sus soldados, sin que avance solo.
func cargar_mapa(escena: String) -> Mapa:
	var mapa: Mapa = load(escena).instantiate()
	root.add_child(mapa)
	mapa.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	mapa.get_node("HUD").process_mode = Node.PROCESS_MODE_DISABLED
	mapa.efectos.permitir_paradas = false
	return mapa


## Carga la Prueba de la sed sin que avance sola.
func nueva_prueba_de_la_sed() -> Mapa:
	var mapa: Mapa = load("res://escenas/mapa_prueba_sed.tscn").instantiate()
	root.add_child(mapa)
	mapa.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	mapa.get_node("HUD").process_mode = Node.PROCESS_MODE_DISABLED
	mapa.efectos.permitir_paradas = false
	return mapa


func paso(m: Mapa, segundos: float = DT) -> void:
	for i in roundi(segundos / DT):
		if m.terminado:
			return
		m._physics_process(DT)
		if m.alerta:
			m.alerta._physics_process(DT)
		m.mika._physics_process(DT)
		for s in m.soldados():
			s._physics_process(DT)
			if m.es_muro(Vector2i(floori(s.pos.x), floori(s.pos.y))):
				ok = false
				print("FALLO: ", s.name, " dentro de muro en ", s.pos)
		for h in m.get_children():
			if h is Vial or h is Eco or h is Aparicion:
				h._physics_process(DT)


func soldado_extra(m: Mapa, nombre: String, celda: Vector2i, mirada: Vector2) -> Soldado:
	var s: Soldado = load("res://escenas/soldado.tscn").instantiate()
	s.name = nombre
	s.ruta.assign([celda])
	m.add_child(s)
	s.iniciar(m)
	s.mirada = mirada
	return s


func comprobar(nombre: String, valor, esperado, tolerancia := 0.01) -> void:
	var bien: bool
	if valor is Vector2:
		bien = valor.distance_to(esperado) <= tolerancia
	elif valor is float:
		bien = absf(valor - esperado) <= tolerancia
	else:
		bien = valor == esperado
	if not bien:
		ok = false
	print(("  ok  " if bien else "FALLO "), nombre, ": ", valor, " (esperado ", esperado, ")")


# --- Búsqueda de una ruta sin ser visto ---
# Mientras nadie ve a Mika, los soldados son deterministas: se graba dónde está y adónde mira
# cada uno, y se busca una ruta casilla a casilla (esperar o moverse) en la que nadie lo vea nunca.

## Avanza el mapa con Mika fuera y guarda dónde está y adónde mira cada soldado en cada muestra.
## Cada foto guarda el propio soldado junto a su posición y su mirada.
func grabar_linea(m: Mapa) -> void:
	linea = []
	_visible_cache = {}
	m.mika.pos = FUERA
	var por_muestra := roundi(PASO_PLAN / DT)
	for k in roundi(HORIZONTE / PASO_PLAN) + 1:
		var foto := []
		for s in m.soldados():
			foto.append([s, s.pos, s.mirada])
		linea.append(foto)
		paso(m, por_muestra * DT)
		m.mika.sed = 0


## Ruta sin ser visto en un mapa con grupos que aparecen, que salen cuando Mika pisa su zona
## (más el aviso), como en el juego. Se graba una vez a los soldados fijos y, aparte, a cada
## grupo fotograma a fotograma desde que aparece. La búsqueda en anchura lleva en cada estado
## cuándo salió cada grupo en su propio camino: al pasar de una casilla a otra mira, fotograma a
## fotograma, si Mika pisa una zona, y desde ahí coloca a ese grupo según su grabación.
## Devuelve [[casilla, segundo], ...] o [].
func buscar_ruta_con_apariciones(escena: String, inicio: Vector2i, meta: Vector2i) -> Array:
	var por_muestra := roundi(PASO_PLAN / DT)
	var fotogramas := roundi(HORIZONTE / DT) + por_muestra
	var aviso := roundi(Config.APARICION_AVISO / DT) + 1 # como en paso(): sale al final del último fotograma del aviso
	_con_margen = true
	var m: Mapa = await cargar_mapa(escena)
	grabar_linea(m) # Mika está fuera: no sale ningún grupo, solo los fijos
	var grupos := [] # {zonas, soldados, fotos: [fotograma] -> [[pos, mirada], ...]}
	for idx in m.apariciones().size():
		var mg: Mapa = await cargar_mapa(escena)
		for s in mg.soldados():
			s.free() # solo hace falta el grupo
		var a: Aparicion = mg.apariciones()[idx]
		var soldados: Array = a.pendientes.duplicate()
		a.aparecer()
		mg.mika.pos = FUERA
		var fotos := []
		for f in fotogramas:
			var foto := []
			for s in soldados:
				foto.append([s.pos, s.mirada])
			fotos.append(foto)
			paso(mg)
			mg.mika.sed = 0
		grupos.append({"zonas": a.zonas, "soldados": soldados, "fotos": fotos, "mapa": mg})

	var ultima := linea.size() - 1
	var centro := func(c: Vector2i) -> Vector2: return Vector2(c) + Vector2(0.5, 0.5)
	var en_zona := func(g: Dictionary, p: Vector2) -> bool:
		var celda := Vector2i(floori(p.x), floori(p.y))
		for z in g.zonas:
			if z.has_point(celda):
				return true
		return false
	# ¿Algún soldado (fijo o de un grupo ya salido) ve el punto en la muestra k o en sus vecinas?
	var visto := func(punto: Vector2, k: int, salidas: Dictionary) -> bool:
		for j in [k - 1, k, k + 1]:
			if j < 0 or j > ultima:
				continue
			if _visible_en(m, punto, j):
				return true
			for idx in salidas:
				var f: int = j * por_muestra - salidas[idx]
				if f < 0:
					continue
				var g: Dictionary = grupos[idx]
				var foto: Array = g.fotos[mini(f, g.fotos.size() - 1)]
				for n in g.soldados.size():
					var s: Soldado = g.soldados[n]
					s.pos = foto[n][0]
					s.mirada = foto[n][1]
					if _ve_con_margen(m, s, punto):
						return true
		return false

	var salidas_inicio := {}
	for idx in grupos.size():
		if en_zona.call(grupos[idx], centro.call(inicio)):
			salidas_inicio[idx] = aviso
	var previo := {[inicio, 0]: null}
	var salidas_de := {[inicio, 0]: salidas_inicio}
	var cola := [[inicio, 0]]
	var vecinos := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var ruta := []
	while not cola.is_empty():
		var actual: Array = cola.pop_front()
		var celda: Vector2i = actual[0]
		var k: int = actual[1]
		if celda == meta:
			var nodo = actual
			while nodo != null:
				ruta.push_front([nodo[0], nodo[1] * PASO_PLAN])
				nodo = previo[nodo]
			break
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
			var a: Vector2 = centro.call(celda)
			var b: Vector2 = centro.call(destino)
			# Grupos que salen en este tramo: el primer fotograma en que Mika pisa su zona.
			var salidas: Dictionary = salidas_de[actual].duplicate()
			for idx in grupos.size():
				if salidas.has(idx):
					continue
				for f in range(k * por_muestra, k2 * por_muestra + 1):
					var t := float(f - k * por_muestra) / ((k2 - k) * por_muestra)
					if en_zona.call(grupos[idx], a.lerp(b, t)):
						salidas[idx] = f + aviso
						break
			var seguro := true
			for j in range(k, k2 + 1):
				if visto.call(a.lerp(b, float(j - k) / (k2 - k)), j, salidas):
					seguro = false
					break
			if seguro:
				previo[[destino, k2]] = actual
				salidas_de[[destino, k2]] = salidas
				cola.push_back([destino, k2])
	m.queue_free()
	for g in grupos:
		g.mapa.queue_free()
	_con_margen = false
	return ruta


## El camino más corto de inicio a meta, sin esperar, como ruta para reproducir().
func ruta_directa(m: Mapa, inicio: Vector2i, meta: Vector2i) -> Array:
	var celdas := m._rejilla.get_id_path(inicio, meta)
	var ruta := [[celdas[0], 0.0]]
	for i in range(1, celdas.size()):
		var t: float = ruta[-1][1] + ceili(Vector2(celdas[i] - celdas[i - 1]).length() / Config.VELOCIDAD_MIKA / PASO_PLAN) * PASO_PLAN
		ruta.append([celdas[i], t])
	return ruta


## Prudente: el punto cuenta como visto si algún soldado lo ve en la muestra k o en sus vecinas.
## Basta un vistazo para que un soldado se pare a mirar y deje de seguir su línea grabada.
func _visible(m: Mapa, punto: Vector2, k: int) -> bool:
	for j in [k - 1, k, k + 1]:
		if j >= 0 and j < linea.size() and _visible_en(m, punto, j):
			return true
	return false


func _visible_en(m: Mapa, punto: Vector2, k: int) -> bool:
	var clave := [punto, k]
	if _visible_cache.has(clave):
		return _visible_cache[clave]
	var resultado := false
	for foto in linea[k]:
		var s: Soldado = foto[0]
		var antes := [s.pos, s.mirada]
		s.pos = foto[1]
		s.mirada = foto[2]
		resultado = _ve_con_margen(m, s, punto) if _con_margen else s._puede_ver(punto)
		s.pos = antes[0]
		s.mirada = antes[1]
		if resultado:
			break
	_visible_cache[clave] = resultado
	return resultado


## Como Soldado._puede_ver, con margen: la planificación mira cada PASO_PLAN s y un cono que
## gira deprisa (o un soldado que pasa al lado) puede barrer a Mika entre dos muestras.
const MARGEN_ANGULO := 15.0 # grados de más a cada lado
const MARGEN_ALCANCE := 0.5 # casillas de más
const MARGEN_CERCA := 1.2 # casillas: a esta distancia cuenta como visto, mire adonde mire


func _ve_con_margen(m: Mapa, s: Soldado, punto: Vector2) -> bool:
	var hacia := punto - s.pos
	var distancia := hacia.length()
	if distancia < MARGEN_CERCA:
		return m.hay_linea_de_vision(s.pos, punto)
	var en_sombra := m.es_sombra(Vector2i(floori(punto.x), floori(punto.y)))
	var alcance := (Config.VISION_ALCANCE_SOMBRA if en_sombra else Config.VISION_ALCANCE) + MARGEN_ALCANCE
	if distancia > alcance:
		return false
	if absf(angle_difference(s.mirada.angle(), hacia.angle())) > deg_to_rad(Config.VISION_ANGULO / 2.0 + MARGEN_ANGULO):
		return false
	return m.hay_linea_de_vision(s.pos, punto)


## Búsqueda en anchura sobre (casilla, muestra): cada paso es esperar una muestra o moverse a
## una casilla vecina a la velocidad de Mika. Devuelve [[casilla, segundo], ...] o [].
func buscar_ruta(m: Mapa, inicio: Vector2i, meta: Vector2i) -> Array:
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


## Mueve a Mika por la ruta en el juego real, fotograma a fotograma. Devuelve si llega a la
## salida sin que nadie llegue a Sospecha; con `informar`, cuenta como fallo si alguien llega.
func reproducir(m: Mapa, ruta: Array, informar := true) -> bool:
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
				if informar:
					ok = false
					print("FALLO: %s llegó a Sospecha en t=%.2f con Mika en %s" % [s.name, t, m.mika.pos])
				return false
	return m.terminado


## Lo que tarda Mika en ir de inicio a meta por el camino más corto, sin esperar a nadie,
## con los mismos pasos que usa buscar_ruta. Sirve para ver si una ruta sin ser visto es
## solo «correr» o exige esperar y esconderse.
func tiempo_directo(m: Mapa, inicio: Vector2i, meta: Vector2i) -> float:
	var celdas := m._rejilla.get_id_path(inicio, meta)
	var t := 0.0
	for i in range(1, celdas.size()):
		t += ceili(Vector2(celdas[i] - celdas[i - 1]).length() / Config.VELOCIDAD_MIKA / PASO_PLAN) * PASO_PLAN
	return t


func terminar() -> void:
	print("RESULTADO: ", "OK" if ok else "FALLO")
	quit()
