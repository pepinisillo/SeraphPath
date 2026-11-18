class_name Generador
## Genera mapas de infiltración al azar: salas (algunas en L) unidas por pasillos de dos casillas,
## a veces con un atajo que se salta una sala (dos caminos que elegir), cobertura
## (pilares y cajas), sombras junto a las paredes, patrullas que van y vienen dentro de las
## salas y algún enemigo propio de la zona (un vampiro con su zona prohibida en Sanguinem, un
## Jinete en Shinjuku, un portador de arma maldita en Shibuya).
##
## No decide si el mapa es bueno: eso lo hace la herramienta `pruebas/generar_mapas.gd`, que
## valida cada candidato como a los mapas hechos a mano (inicio seguro, ruta sin ser visto, que
## no baste con correr) y guarda solo los que pasan en `escenas/generados/`.
##
## generar() devuelve un diccionario con: plano, inicio, salida, entidades
## ([{tipo, nombre, ruta, bucle, grupo?, talismanes?}]), grupos ([{nombre, zonas, probabilidad}]),
## ruta_vampiro_extra, ruta_jinete_suelto y entrada_refuerzos.
## Además de las patrullas, la sala final tiene un grupo que aparece al entrar Mika en la
## anterior (la mitad de las veces), y en Shibuya un hechicero deja dos talismanes en los
## pasillos (siempre en una sola de sus dos casillas de ancho, para que quede paso).

const ANCHO := 30
const ALTO := 18


static func generar(semilla: int, zona: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var g := []
	for f in ALTO:
		var fila := []
		fila.resize(ANCHO)
		fila.fill("#")
		g.append(fila)
	var salas := _salas(rng)
	for s in salas:
		_rellenar(g, s, ".")
	# Salas en L: a algunas se les pega un anexo (no a la de inicio ni a la de la salida).
	for s in salas.slice(1, salas.size() - 1):
		if rng.randf() < 0.5:
			var anexo := Rect2i(s.position.x + rng.randi_range(0, maxi(0, s.size.x - 3)), s.end.y if s.end.y + 3 <= ALTO else s.position.y - 3, 3, 3)
			if anexo.position.y >= 0 and anexo.end.y <= ALTO and anexo.end.x <= ANCHO:
				_rellenar(g, anexo, ".")
	# Pasillos: cada sala con la siguiente (ordenadas de izquierda a derecha), en L, de dos de ancho.
	for i in range(1, salas.size()):
		_pasillo(g, _centro(salas[i - 1]), _centro(salas[i]), rng)
	# Atajo: a veces un pasillo más, saltándose una sala, para que haya caminos que elegir.
	var atajo := salas.size() >= 4 and rng.randf() < 0.5
	if atajo:
		var i := rng.randi_range(0, salas.size() - 3)
		_pasillo(g, _centro(salas[i]), _centro(salas[i + 2]), rng)
	var inicial: Rect2i = salas[0]
	var final: Rect2i = salas[-1]
	var inicio := Vector2i(inicial.position.x, inicial.end.y - 1)
	var salida := Vector2i(final.end.x - 1, final.position.y)
	# Cobertura dentro de las salas (no en la de inicio ni junto a la salida) y sombras.
	for s in salas.slice(1):
		for k in rng.randi_range(1, 3):
			var c := Vector2i(rng.randi_range(s.position.x + 1, s.end.x - 2), rng.randi_range(s.position.y + 1, s.end.y - 2))
			if c.distance_to(salida) > 2.5:
				g[c.y][c.x] = "#"
	_sombras(g, rng)
	g[inicio.y][inicio.x] = "M"
	g[salida.y][salida.x] = "E"
	if not _conectado(g, inicio, salida):
		return {}

	# Patrullas: en las salas del medio y la final, a lo largo de su lado más largo.
	var entidades := []
	var n := 0
	for s in salas.slice(1):
		var ruta := _ruta_en_sala(g, s, rng)
		if ruta.is_empty():
			continue
		n += 1
		entidades.append({"tipo": "soldado", "nombre": "G%d" % n, "ruta": ruta, "bucle": false})
	# Un enemigo propio de la zona en una sala del medio.
	var sala_zona: Rect2i = salas[rng.randi_range(1, maxi(1, salas.size() - 2))]
	var ruta_zona := _ruta_en_sala(g, sala_zona, rng, true)
	if not ruta_zona.is_empty():
		match zona:
			1:
				entidades.append({"tipo": "vampiro", "nombre": "V1", "ruta": ruta_zona, "bucle": false})
				# Su rincón prohibido, con un vial: robarlo a su vista lo delata.
				var rincon := Vector2i(sala_zona.end.x - 1, sala_zona.end.y - 1)
				for d in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
					var c: Vector2i = rincon + d
					if g[c.y][c.x] == "." or g[c.y][c.x] == "s":
						g[c.y][c.x] = "x"
				if g[rincon.y][rincon.x] == "x":
					g[rincon.y][rincon.x] = "V"
			2:
				entidades.append({"tipo": "jinete", "nombre": "J1", "ruta": ruta_zona, "bucle": false})
			3:
				entidades.append({"tipo": "portador", "nombre": "P1", "ruta": ruta_zona, "bucle": false})
	# Grupo que aparece en la sala final, al entrar Mika en la anterior.
	var grupos := []
	if salas.size() >= 3 and rng.randf() < 0.5:
		var ruta_grupo := _ruta_en_sala(g, final, rng)
		if not ruta_grupo.is_empty():
			grupos.append({"nombre": "GrupoFinal", "zonas": [salas[-2]], "probabilidad": 0.5 + 0.5 * float(rng.randf() < 0.5)})
			entidades.append({"tipo": "soldado", "nombre": "GF1", "ruta": ruta_grupo, "bucle": false, "grupo": "GrupoFinal"})
	# Shibuya: un hechicero con dos talismanes en los pasillos.
	if zona == 3:
		var sala_h: Rect2i = salas[1]
		var ruta_h := _ruta_en_sala(g, sala_h, rng, true)
		var talismanes := _casillas_de_pasillo(g, salas, rng, 2)
		if not ruta_h.is_empty() and not talismanes.is_empty():
			entidades.append({"tipo": "hechicero", "nombre": "H1", "ruta": ruta_h, "bucle": false, "talismanes": talismanes})
	var plano := PackedStringArray()
	for fila in g:
		plano.append("".join(fila))
	var sala_media: Rect2i = salas[salas.size() / 2]
	var datos := {
		"plano": "\n".join(plano), "inicio": inicio, "salida": salida, "entidades": entidades, "grupos": grupos, "atajo": atajo,
		"ruta_vampiro_extra": _ruta_en_sala(g, sala_media, rng, true),
		"ruta_jinete_suelto": _ruta_en_sala(g, sala_media, rng, true),
		"entrada_refuerzos": salida,
	}
	# Para que no vayan todos de abajo a la izquierda a arriba a la derecha: a veces volteado.
	return voltear(datos, rng.randf() < 0.5, rng.randf() < 0.5)


## El mismo mapa volteado en horizontal y/o en vertical (plano, puntos, rutas y zonas).
static func voltear(datos: Dictionary, en_x: bool, en_y: bool) -> Dictionary:
	if not en_x and not en_y:
		datos.volteado = [false, false]
		return datos
	var punto := func(p: Vector2i) -> Vector2i:
		return Vector2i(ANCHO - 1 - p.x if en_x else p.x, ALTO - 1 - p.y if en_y else p.y)
	var filas: PackedStringArray = datos.plano.split("\n")
	var nuevas := PackedStringArray()
	for y in ALTO:
		var fila: String = filas[ALTO - 1 - y if en_y else y]
		nuevas.append(fila.reverse() if en_x else fila)
	var resultado := datos.duplicate(true)
	resultado.plano = "\n".join(nuevas)
	resultado.inicio = punto.call(datos.inicio)
	resultado.salida = punto.call(datos.salida)
	resultado.entrada_refuerzos = punto.call(datos.entrada_refuerzos)
	resultado.ruta_vampiro_extra = datos.ruta_vampiro_extra.map(func(p): return punto.call(p))
	resultado.ruta_jinete_suelto = datos.ruta_jinete_suelto.map(func(p): return punto.call(p))
	for e in resultado.entidades:
		e.ruta = e.ruta.map(func(p): return punto.call(p))
		if e.has("talismanes"):
			e.talismanes = e.talismanes.map(func(p): return punto.call(p))
	for grupo in resultado.grupos:
		grupo.zonas = grupo.zonas.map(func(z: Rect2i) -> Rect2i:
			var a: Vector2i = punto.call(z.position)
			var b: Vector2i = punto.call(z.end - Vector2i.ONE)
			return Rect2i(Vector2i(mini(a.x, b.x), mini(a.y, b.y)), z.size))
	resultado.volteado = [en_x, en_y]
	return resultado


## Entre 4 y 6 salas sin solaparse, repartidas de izquierda a derecha.
static func _salas(rng: RandomNumberGenerator) -> Array:
	var salas := []
	var columnas := rng.randi_range(4, 5)
	var ancho_franja := ANCHO / columnas
	for i in columnas:
		var w := rng.randi_range(4, maxi(4, ancho_franja - 1))
		var h := rng.randi_range(4, 7)
		var x := i * ancho_franja + rng.randi_range(0, maxi(0, ancho_franja - w - 1))
		var y := rng.randi_range(0, ALTO - h)
		if i == 0:
			y = ALTO - h # la de inicio, abajo
		elif i == columnas - 1:
			y = 0 # la de la salida, arriba
		salas.append(Rect2i(x, y, w, h))
	return salas


static func _rellenar(g: Array, r: Rect2i, c: String) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			g[y][x] = c


static func _centro(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2


## Pasillo en L de dos casillas de ancho entre dos puntos.
static func _pasillo(g: Array, a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	var codo := Vector2i(b.x, a.y) if rng.randf() < 0.5 else Vector2i(a.x, b.y)
	for tramo in [[a, codo], [codo, b]]:
		var desde: Vector2i = tramo[0]
		var hasta: Vector2i = tramo[1]
		for x in range(mini(desde.x, hasta.x), maxi(desde.x, hasta.x) + 1):
			for y in range(mini(desde.y, hasta.y), maxi(desde.y, hasta.y) + 1):
				for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var c: Vector2i = Vector2i(x, y) + d
					if c.x < ANCHO and c.y < ALTO:
						g[c.y][c.x] = "."


## Sombra en algunas casillas de suelo pegadas a un muro.
static func _sombras(g: Array, rng: RandomNumberGenerator) -> void:
	for y in ALTO:
		for x in ANCHO:
			if g[y][x] != ".":
				continue
			var junto_a_muro := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var c: Vector2i = Vector2i(x, y) + d
				if c.x < 0 or c.y < 0 or c.x >= ANCHO or c.y >= ALTO or g[c.y][c.x] == "#":
					junto_a_muro = true
			if junto_a_muro and rng.randf() < 0.18:
				g[y][x] = "s"


## Una ruta de ida y vuelta en línea recta dentro de la sala, por casillas libres. Con
## `corta`, de la mitad de largo (para el enemigo de la zona y los extras de los eventos).
static func _ruta_en_sala(g: Array, s: Rect2i, rng: RandomNumberGenerator, corta := false) -> Array:
	for intento in 8:
		var horizontal := s.size.x >= s.size.y
		var a: Vector2i
		var b: Vector2i
		if horizontal:
			var y := rng.randi_range(s.position.y, s.end.y - 1)
			a = Vector2i(s.position.x, y)
			b = Vector2i(s.end.x - 1, y)
		else:
			var x := rng.randi_range(s.position.x, s.end.x - 1)
			a = Vector2i(x, s.position.y)
			b = Vector2i(x, s.end.y - 1)
		if corta:
			b = a + (b - a) / 2
		if rng.randf() < 0.5:
			var t := a
			a = b
			b = t
		if a == b:
			continue
		var libre := true
		var paso := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var c := a
		while true:
			if not g[c.y][c.x] in [".", "s"]:
				libre = false
				break
			if c == b:
				break
			c += paso
		if libre:
			return [a, b]
	return []


## Casillas de pasillo (suelo fuera de las salas) cuya vecina de al lado también es suelo: un
## talismán en una deja paso por la otra.
static func _casillas_de_pasillo(g: Array, salas: Array, rng: RandomNumberGenerator, cuantas: int) -> Array:
	var posibles := []
	for y in ALTO:
		for x in ANCHO:
			var c := Vector2i(x, y)
			if g[y][x] != "." or salas.any(func(s): return s.has_point(c)):
				continue
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var o: Vector2i = c + d
				if o.x < ANCHO and o.y < ALTO and g[o.y][o.x] in [".", "s"]:
					posibles.append(c)
					break
	var elegidas := []
	while elegidas.size() < cuantas and not posibles.is_empty():
		var c: Vector2i = posibles.pop_at(rng.randi_range(0, posibles.size() - 1))
		if elegidas.all(func(e): return Vector2(e).distance_to(Vector2(c)) > 3.0):
			elegidas.append(c)
	return elegidas


static func _conectado(g: Array, desde: Vector2i, hasta: Vector2i) -> bool:
	var vistos := {desde: true}
	var cola := [desde]
	while not cola.is_empty():
		var c: Vector2i = cola.pop_front()
		if c == hasta:
			return true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var o: Vector2i = c + d
			if o.x < 0 or o.y < 0 or o.x >= ANCHO or o.y >= ALTO or vistos.has(o) or g[o.y][o.x] == "#":
				continue
			vistos[o] = true
			cola.append(o)
	return false


## El texto de la escena (.tscn) del mapa generado.
static func escena(datos: Dictionary, nombre_nodo: String, nombre: String) -> String:
	var v := func(p: Vector2i) -> String: return "Vector2i(%d, %d)" % [p.x, p.y]
	var ruta := func(r: Array) -> String: return "Array[Vector2i]([%s])" % ", ".join(r.map(func(p): return v.call(p)))
	var t := PackedStringArray([
		"[gd_scene format=3]", "",
		'[ext_resource type="Script" path="res://scripts/mapa.gd" id="1_mapa"]',
		'[ext_resource type="TileSet" path="res://recursos/casillas.tres" id="2_casillas"]',
		'[ext_resource type="PackedScene" path="res://escenas/mika.tscn" id="3_mika"]',
		'[ext_resource type="PackedScene" path="res://escenas/soldado.tscn" id="4_soldado"]',
		'[ext_resource type="Script" path="res://scripts/alerta.gd" id="5_alerta"]',
		'[ext_resource type="PackedScene" path="res://escenas/hud.tscn" id="6_hud"]',
		'[ext_resource type="Script" path="res://scripts/muros.gd" id="7_muros"]',
		'[ext_resource type="PackedScene" path="res://escenas/vampiro.tscn" id="9_vampiro"]',
		'[ext_resource type="PackedScene" path="res://escenas/jinete.tscn" id="10_jinete"]',
		'[ext_resource type="PackedScene" path="res://escenas/portador.tscn" id="11_portador"]',
		'[ext_resource type="PackedScene" path="res://escenas/hechicero.tscn" id="12_hechicero"]',
		'[ext_resource type="Script" path="res://scripts/aparicion.gd" id="8_aparicion"]', "",
		'[node name="%s" type="Node2D"]' % nombre_nodo, "y_sort_enabled = true", 'script = ExtResource("1_mapa")',
		'plano = "%s"' % datos.plano, 'nombre = "%s"' % nombre,
		"entrada_refuerzos = %s" % v.call(datos.entrada_refuerzos),
	])
	if not datos.ruta_vampiro_extra.is_empty():
		t.append("ruta_vampiro_extra = %s" % ruta.call(datos.ruta_vampiro_extra))
	if not datos.ruta_jinete_suelto.is_empty():
		t.append("ruta_jinete_suelto = %s" % ruta.call(datos.ruta_jinete_suelto))
	t.append_array(["", '[node name="Alerta" type="Node" parent="."]', 'script = ExtResource("5_alerta")', "",
		'[node name="Suelo" type="TileMapLayer" parent="."]', "z_index = -2", 'tile_set = ExtResource("2_casillas")', "",
		'[node name="Muros" type="TileMapLayer" parent="."]', "y_sort_enabled = true", 'tile_set = ExtResource("2_casillas")', 'script = ExtResource("7_muros")', "",
		'[node name="Mika" parent="." instance=ExtResource("3_mika")]', ""])
	var rect := func(r: Rect2i) -> String: return "Rect2i(%d, %d, %d, %d)" % [r.position.x, r.position.y, r.size.x, r.size.y]
	for grupo in datos.get("grupos", []):
		t.append('[node name="%s" type="Node2D" parent="."]' % grupo.nombre)
		t.append('script = ExtResource("8_aparicion")')
		t.append("zonas = Array[Rect2i]([%s])" % ", ".join(grupo.zonas.map(func(z): return rect.call(z))))
		t.append("probabilidad = %s" % grupo.probabilidad)
		t.append("")
	var ids := {"soldado": "4_soldado", "vampiro": "9_vampiro", "jinete": "10_jinete", "portador": "11_portador", "hechicero": "12_hechicero"}
	for e in datos.entidades:
		t.append('[node name="%s" parent="%s" instance=ExtResource("%s")]' % [e.nombre, e.get("grupo", "."), ids[e.tipo]])
		t.append("ruta = %s" % ruta.call(e.ruta))
		if not e.bucle:
			t.append("en_bucle = false")
		if e.has("talismanes"):
			t.append("talismanes = %s" % ruta.call(e.talismanes))
		t.append("")
	t.append('[node name="HUD" parent="." instance=ExtResource("6_hud")]')
	return "\n".join(t) + "\n"
