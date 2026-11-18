@tool
class_name Mapa
extends Node2D
## Mapa construido a partir de un plano de texto. Cada carácter es una casilla:
## `#` muro · `.` suelo · `s` sombra · `M` inicio de Mika · `E` salida · `V` vial de Krul
## · `e` eco (solo en la Prueba de la sed, donde la salida es Yuu)
## · `x` zona prohibida (suelo; un vampiro que vea a Mika ahí lo delata).
## La lógica consulta la cuadrícula (es_muro, es_sombra); los TileMapLayer solo dibujan.

const ATLAS_SUELO := Vector2i(0, 0)
const ATLAS_SOMBRA := Vector2i(1, 0)
const ATLAS_MURO := Vector2i(2, 0)
const ATLAS_SALIDA := Vector2i(3, 0)
const COLOR_PROHIBIDA := Paleta.VAMPIROS

@export_multiline var plano: String = "":
	set(valor):
		plano = valor
		if is_node_ready():
			_construir()

## Mapa dentro de la mente de Mika: sin ataques, con ecos, y la salida es Yuu.
@export var prueba_de_la_sed := false
## Lo que dicen los ecos, uno por eco y en orden. Si faltan, se repiten.
## Nombre que aparece en la pantalla de resultado.
@export var nombre := "Puesto de control"
## Casilla por la que llegan los refuerzos durante la alarma.
@export var entrada_refuerzos := Vector2i(9, 0)
## Prueba de la sed: dónde empieza Mika con el evento «El escuadrón de Yuu» (más cerca de la salida).
@export var inicio_cerca := Vector2i(-1, -1)
## Ruta del vampiro de más que trae el evento «La doncella de Krul» (vacía: no cabe en este mapa).
@export var ruta_vampiro_extra: Array[Vector2i] = []
## Ruta del Jinete que suelta el evento «El Jinete dormido» (vacía: no cabe en este mapa).
@export var ruta_jinete_suelto: Array[Vector2i] = []

@export_group("Jefe")
## Nombre del jefe en el guion («Ferid Bathory»); vacío si el mapa no es de jefe.
@export var jefe := ""
## Casilla donde empieza el jefe.
@export var inicio_jefe := Vector2i(-1, -1)
## Puntos de control, de izquierda a derecha: al atraparlo, Mika vuelve al último que pasó.
@export var puntos_de_control: Array[Vector2i] = []
## Desde qué punto de control empieza la segunda fase del jefe.
@export var fase2_desde := 2

## Las pruebas lo apagan: sin escena del guion antes del jefe.
static var escenas_de_jefe := true

var punto_de_control := 0 # el último que pasó Mika
var vampiros_callados := false # evento «Lacus y René»: los vampiros de este mapa no lo delatan
var celdas_prohibidas: Array[Vector2i] = []
var ferid: Ferid
var sonido: Sonido
var jefe_combate: Crowley # Crowley o Guren: el jefe con el que se pelea

var filas: PackedStringArray = []
var ancho := 0
var alto := 0
var inicio_mika := Vector2i.ZERO
var celdas_vial: Array[Vector2i] = []
var celdas_eco: Array[Vector2i] = []
var celda_salida := Vector2i(-1, -1)
var mika: Mika
var estadisticas := Estadisticas.new()
var efectos: Efectos
## Evento «La copa de Ferid»: se ven todas las patrullas a través de los muros.
var patrullas_visibles := false
var terminado := false
## Cómo terminó: "" (superado o caída), "cedida" o "fallida" (Prueba de la sed).
var motivo := ""

var _rejilla := AStarGrid2D.new()
var _frases_ecos := {} # Humanidad -> frases

@onready var suelo: TileMapLayer = $Suelo
@onready var muros: Muros = $Muros
@onready var alerta: Alerta = get_node_or_null("Alerta")


func _ready() -> void:
	_construir()
	if Engine.is_editor_hint():
		return
	mika = get_node_or_null("Mika")
	efectos = Efectos.new()
	efectos.name = "Efectos"
	add_child(efectos)
	efectos.iniciar(self)
	if mika:
		mika.iniciar(self, Vector2(inicio_mika) + Vector2(0.5, 0.5))
	Soldado.preparar_azar()
	for soldado in soldados():
		soldado.iniciar(self)
	for vampiro in vampiros():
		vampiro.iniciar(self)
	for jinete in jinetes():
		jinete.iniciar(self)
	for aparicion in apariciones():
		aparicion.iniciar(self)
	for i in celdas_eco.size():
		var eco: Eco = load("res://escenas/eco.tscn").instantiate()
		add_child(eco)
		eco.iniciar(self, celdas_eco[i], i)
	if prueba_de_la_sed and celda_salida.x >= 0:
		var yuu: Yuu = load("res://escenas/yuu.tscn").instantiate()
		add_child(yuu)
		yuu.iniciar(celda_salida)
	for celda in celdas_vial:
		var vial: Vial = load("res://escenas/vial.tscn").instantiate()
		add_child(vial)
		vial.iniciar(self, celda)
	if jefe == "Ferid Bathory" and inicio_jefe.x >= 0:
		ferid = load("res://escenas/ferid.tscn").instantiate()
		add_child(ferid)
		ferid.iniciar(self, inicio_jefe)
	elif jefe in ["Crowley Eusford", "Guren Ichinose"] and inicio_jefe.x >= 0:
		var escena := "res://escenas/crowley.tscn" if jefe == "Crowley Eusford" else "res://escenas/guren.tscn"
		jefe_combate = load(escena).instantiate()
		add_child(jefe_combate)
		jefe_combate.iniciar(self, inicio_jefe)
	var hud := get_node_or_null("HUD")
	if hud:
		hud.iniciar(self)
	sonido = Sonido.new()
	sonido.name = "Sonido"
	add_child(sonido)
	sonido.iniciar(self)
	var menu := MenuPausa.new()
	menu.name = "MenuPausa"
	add_child(menu)
	menu.iniciar(self)
	if ControlesTactiles.hacen_falta():
		var tactiles := ControlesTactiles.new()
		tactiles.name = "ControlesTactiles"
		add_child(tactiles)
	if mika:
		mika.derrotada.connect(_al_caer_mika)
		if EstadoExpedicion.en_curso():
			EstadoExpedicion.actual().aplicar_a_mapa(self)
	if jefe != "" and escenas_de_jefe:
		_escena_antes_del_jefe()


## La escena «antes» del guion, sobre el propio mapa, con el juego en pausa.
func _escena_antes_del_jefe() -> void:
	var humanidad := mika.humanidad if mika else Config.HUMANIDAD_INICIAL
	var golpes := Guion.segun_humanidad(Guion.jefe_antes(jefe), humanidad)
	if golpes.is_empty():
		return
	var dialogo := Dialogo.new()
	dialogo.sobre_mapa = true
	dialogo.name = "DialogoJefe"
	add_child(dialogo)
	dialogo.terminado.connect(func() -> void: get_tree().paused = false)
	get_tree().paused = true
	dialogo.empezar(golpes)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or terminado:
		return
	estadisticas.tiempo += delta
	if mika and not puntos_de_control.is_empty():
		for i in range(punto_de_control + 1, puntos_de_control.size()):
			if mika.pos.x >= puntos_de_control[i].x:
				punto_de_control = i
	if mika:
		muros.actualizar_transparencia(mika.pos, Mika.ALTO_CAPSULA, Mika.ANCHO_CAPSULA)


func _construir() -> void:
	filas = []
	for linea in plano.strip_edges().split("\n"):
		filas.append(linea.strip_edges())
	alto = filas.size()
	ancho = 0
	for fila in filas:
		ancho = max(ancho, fila.length())

	suelo.clear()
	muros.clear()
	celdas_vial.clear()
	celdas_eco.clear()
	celdas_prohibidas.clear()
	for f in alto:
		for c in ancho:
			var celda := Vector2i(c, f)
			match caracter(celda):
				"#":
					muros.set_cell(celda, 0, ATLAS_MURO)
				"s":
					suelo.set_cell(celda, 0, ATLAS_SOMBRA)
				"E":
					celda_salida = celda
					suelo.set_cell(celda, 0, ATLAS_SALIDA)
				"e":
					celdas_eco.append(celda)
					suelo.set_cell(celda, 0, ATLAS_SUELO)
				"M":
					inicio_mika = celda
					suelo.set_cell(celda, 0, ATLAS_SUELO)
				"V":
					celdas_vial.append(celda)
					suelo.set_cell(celda, 0, ATLAS_SUELO)
				"x":
					celdas_prohibidas.append(celda)
					suelo.set_cell(celda, 0, ATLAS_SUELO)
				_:
					suelo.set_cell(celda, 0, ATLAS_SUELO)

	_rejilla.region = Rect2i(0, 0, ancho, alto)
	_rejilla.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_rejilla.update()
	for f in alto:
		for c in ancho:
			_rejilla.set_point_solid(Vector2i(c, f), es_muro(Vector2i(c, f)))
	queue_redraw()


func caracter(celda: Vector2i) -> String:
	if celda.y < 0 or celda.y >= filas.size():
		return "#"
	var fila := filas[celda.y]
	if celda.x < 0 or celda.x >= fila.length():
		return "#"
	return fila[celda.x]


## Fuera del mapa cuenta como muro, para que nadie se salga.
func es_muro(celda: Vector2i) -> bool:
	return caracter(celda) == "#"


## Casillas con un talismán que aún revela a Mika (su hechicero sigue en pie).
func talismanes_activos() -> Array[Vector2i]:
	var lista: Array[Vector2i] = []
	for soldado in soldados():
		if soldado is Hechicero:
			lista.append_array(soldado.talismanes_activos())
	return lista


## Suena un efecto (ver Sonido.efecto).
func sonar(nombre: String) -> void:
	if sonido:
		sonido.efecto(nombre)


func es_prohibida(celda: Vector2i) -> bool:
	return caracter(celda) == "x"


## Las zonas prohibidas: un rombo violeta tenue sobre el suelo de cada casilla.
func _draw() -> void:
	for celda in celdas_prohibidas:
		var c := Iso.a_pantalla(Vector2(celda) + Vector2(0.5, 0.5))
		var m := Vector2(Config.ANCHO_CASILLA / 2.0, Config.ALTO_CASILLA / 2.0) * 0.86
		var rombo := PackedVector2Array([c + Vector2(0, -m.y), c + Vector2(m.x, 0), c + Vector2(0, m.y), c + Vector2(-m.x, 0)])
		draw_colored_polygon(rombo, Color(COLOR_PROHIBIDA, 0.22))
		rombo.append(rombo[0])
		draw_polyline(rombo, Color(COLOR_PROHIBIDA, 0.6), 2.0)


func es_sombra(celda: Vector2i) -> bool:
	return caracter(celda) == "s"


func es_salida(celda: Vector2i) -> bool:
	return caracter(celda) == "E"


# --- Final del mapa ---

## Texto del objetivo opcional, o "" si el mapa no tiene.
func texto_objetivo() -> String:
	if celdas_vial.is_empty():
		return ""
	return "Recoger el vial de Krul" if celdas_vial.size() == 1 else "Recoger los viales de Krul"


func objetivo_cumplido() -> bool:
	return not celdas_vial.is_empty() and estadisticas.viales_recogidos >= celdas_vial.size()


## Termina el mapa (al llegar a la salida o al caer Mika) y muestra el resultado con el juego en pausa.
func terminar(exito: bool, p_motivo := "") -> void:
	if terminado:
		return
	terminado = true
	motivo = p_motivo
	if motivo == "fallida":
		mika.sed = Config.PRUEBA_SED_FALLIDA # despierta con esta sed
	if EstadoExpedicion.en_curso():
		EstadoExpedicion.actual().al_terminar_mapa(self, exito, motivo)
	var resultado: Resultado = load("res://escenas/resultado.tscn").instantiate()
	add_child(resultado)
	resultado.mostrar(self, exito)
	get_tree().paused = true


## Mika bebió de un eco: la prueba queda cedida en cuanto elija su mejora.
func ceder() -> void:
	if mika.mejora_en_espera:
		await mika.mejora_elegida
	terminar(false, "cedida")


func _al_caer_mika() -> void:
	get_tree().create_timer(Config.RESULTADO_ESPERA_CAIDA, true).timeout.connect(terminar.bind(false))


## Puntos (en casillas) para ir de `desde` a `hasta` esquivando muros: centros de casilla
## y, al final, el punto exacto. Vacío si no hay camino.
func camino(desde: Vector2, hasta: Vector2) -> PackedVector2Array:
	var inicio := Vector2i(floori(desde.x), floori(desde.y))
	var fin := Vector2i(floori(hasta.x), floori(hasta.y))
	var puntos := PackedVector2Array()
	if not _rejilla.is_in_boundsv(inicio) or not _rejilla.is_in_boundsv(fin):
		return puntos
	var celdas := _rejilla.get_id_path(inicio, fin, true)
	for i in range(1, celdas.size()):
		puntos.append(Vector2(celdas[i]) + Vector2(0.5, 0.5))
	if not celdas.is_empty() and celdas[-1] == fin:
		if puntos.is_empty():
			puntos.append(hasta)
		else:
			puntos[-1] = hasta
	return puntos


func soldados() -> Array[Soldado]:
	var lista: Array[Soldado] = []
	for hijo in get_children():
		if hijo is Soldado:
			lista.append(hijo)
	return lista


## Lo que dicen los ecos, del guion, según la Humanidad de Mika (con 0 no hay voz).
func frases_ecos() -> PackedStringArray:
	var humanidad := mika.humanidad if mika else Config.HUMANIDAD_INICIAL
	if not _frases_ecos.has(humanidad):
		_frases_ecos[humanidad] = Guion.frases_ecos(humanidad)
	return _frases_ecos[humanidad]


## Devuelve a Mika al último punto de control que pasó (lo atrapó el jefe).
func volver_al_punto_de_control() -> void:
	if puntos_de_control.is_empty():
		return
	mika.pos = Vector2(puntos_de_control[punto_de_control]) + Vector2(0.5, 0.5)
	mika.position = Iso.a_pantalla(mika.pos)


## El centro de la casilla sin muro más cercana a `p`, dentro del mapa.
func casilla_libre_cerca(p: Vector2) -> Vector2:
	var objetivo := Vector2i(clampi(floori(p.x), 0, ancho - 1), clampi(floori(p.y), 0, alto - 1))
	var mejor := Vector2i(-1, -1)
	var mejor_distancia := INF
	for f in alto:
		for c in ancho:
			var celda := Vector2i(c, f)
			if es_muro(celda):
				continue
			var d := Vector2(celda - objetivo).length()
			if d < mejor_distancia:
				mejor_distancia = d
				mejor = celda
	return Vector2(mejor) + Vector2(0.5, 0.5)


## Grupos de soldados que aparecen cuando Mika entra en su zona.
func apariciones() -> Array[Aparicion]:
	var lista: Array[Aparicion] = []
	for hijo in get_children():
		if hijo is Aparicion:
			lista.append(hijo)
	return lista


func jinetes() -> Array[Jinete]:
	var lista: Array[Jinete] = []
	for hijo in get_children():
		if hijo is Jinete:
			lista.append(hijo)
	return lista


## Evento «El Jinete dormido» (atraerlo): 2 soldados menos y un Jinete suelto, si el mapa tiene sitio.
func soltar_jinete() -> void:
	var quitados := 0
	for soldado in soldados():
		if quitados >= 2:
			break
		soldado.queue_free()
		remove_child(soldado)
		quitados += 1
	if ruta_jinete_suelto.is_empty():
		return
	var jinete: Jinete = load("res://escenas/jinete.tscn").instantiate()
	jinete.name = "JineteSuelto"
	jinete.ruta = ruta_jinete_suelto
	add_child(jinete)
	jinete.iniciar(self)


func vampiros() -> Array[Vampiro]:
	var lista: Array[Vampiro] = []
	for hijo in get_children():
		if hijo is Vampiro:
			lista.append(hijo)
	return lista


## Lo que Mika puede atacar: soldados, vampiros y el jefe con el que se pelea (Crowley, Guren).
func atacables() -> Array:
	var lista: Array = [] # sin tipo: soldados y vampiros juntos
	lista.append_array(soldados())
	lista.append_array(vampiros())
	if jefe_combate:
		lista.append(jefe_combate)
	return lista


## Mika acaba de hacer algo prohibido ("ataque", "vial"): lo delata todo vampiro que lo vea.
func acto_prohibido(motivo: String) -> void:
	if mika == null:
		return
	for vampiro in vampiros():
		if vampiro.puede_ver(mika.pos):
			vampiro.presenciar(motivo)


## Evento «La doncella de Krul»: un vampiro de más en este mapa, si tiene sitio para él.
func poner_vampiro_extra() -> void:
	if ruta_vampiro_extra.is_empty():
		return
	var vampiro: Vampiro = load("res://escenas/vampiro.tscn").instantiate()
	vampiro.name = "VampiroExtra"
	vampiro.ruta = ruta_vampiro_extra
	vampiro.en_bucle = false
	add_child(vampiro)
	vampiro.iniciar(self)


func ecos() -> Array[Eco]:
	var lista: Array[Eco] = []
	for hijo in get_children():
		if hijo is Eco:
			lista.append(hijo)
	return lista


## Un ruido en `origen`: los soldados a menos de RUIDO_RADIO casillas lo oyen, haya muros o no.
func hacer_ruido(origen: Vector2) -> void:
	for soldado in soldados():
		if soldado.pos.distance_to(origen) <= Config.RUIDO_RADIO:
			soldado.oir(origen)
	for jinete in jinetes():
		if jinete.pos.distance_to(origen) <= Config.JINETE_OIDO:
			jinete.oir(origen)
	var onda := OndaRuido.new()
	onda.position = Iso.a_pantalla(origen)
	add_child(onda)


## Llama a un soldado de refuerzo, que aparece en la entrada de refuerzos.
func crear_refuerzo(numero: int) -> void:
	var soldado: Soldado = load("res://escenas/soldado.tscn").instantiate()
	soldado.name = "Refuerzo%d" % numero
	soldado.ruta.assign([entrada_refuerzos])
	add_child(soldado)
	soldado.iniciar(self)


## Distancia en casillas desde `origen` en `direccion` hasta el primer muro, como máximo `maximo`.
## Recorre la cuadrícula casilla a casilla (DDA), así que no se salta esquinas.
func distancia_hasta_muro(origen: Vector2, direccion: Vector2, maximo: float) -> float:
	var dir := direccion.normalized()
	var celda := Vector2i(floori(origen.x), floori(origen.y))
	if es_muro(celda):
		return 0.0
	var paso := Vector2i(int(signf(dir.x)), int(signf(dir.y)))
	var t_max := Vector2(INF, INF)
	var t_delta := Vector2(INF, INF)
	if dir.x != 0.0:
		t_delta.x = absf(1.0 / dir.x)
		t_max.x = (celda.x + (1 if paso.x > 0 else 0) - origen.x) / dir.x
	if dir.y != 0.0:
		t_delta.y = absf(1.0 / dir.y)
		t_max.y = (celda.y + (1 if paso.y > 0 else 0) - origen.y) / dir.y
	while true:
		var t: float
		if t_max.x < t_max.y:
			t = t_max.x
			t_max.x += t_delta.x
			celda.x += paso.x
		else:
			t = t_max.y
			t_max.y += t_delta.y
			celda.y += paso.y
		if t >= maximo:
			return maximo
		if es_muro(celda):
			return t
	return maximo


## True si ningún muro corta la recta entre a y b.
func hay_linea_de_vision(a: Vector2, b: Vector2) -> bool:
	var distancia := a.distance_to(b)
	return distancia_hasta_muro(a, b - a, distancia) >= distancia
