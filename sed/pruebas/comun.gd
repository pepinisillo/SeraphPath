extends SceneTree
## Utilidades compartidas por las pruebas: mapa con el tiempo detenido, paso fijo y comprobaciones.

const DT := 1.0 / 60.0
const PASO_PLAN := 0.1 # s entre muestras de la línea temporal de la búsqueda de rutas
const HORIZONTE := 120.0 # s que se planifican
const FUERA := Vector2(-100, -100) # Mika aparcado fuera del mapa mientras se graba a los soldados
var ok := true
var linea := [] # [muestra] -> [[pos, mirada], ...] por soldado
var _visible_cache := {}


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
			if h is Vial or h is Eco:
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
func grabar_linea(m: Mapa) -> void:
	linea = []
	_visible_cache = {}
	m.mika.pos = FUERA
	var por_muestra := roundi(PASO_PLAN / DT)
	for k in roundi(HORIZONTE / PASO_PLAN) + 1:
		var foto := []
		for s in m.soldados():
			foto.append([s.pos, s.mirada])
		linea.append(foto)
		paso(m, por_muestra * DT)
		m.mika.sed = 0


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


## Mueve a Mika por la ruta en el juego real, fotograma a fotograma.
func reproducir(m: Mapa, ruta: Array) -> void:
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
