@tool
class_name Mapa
extends Node2D
## Mapa construido a partir de un plano de texto. Cada carácter es una casilla:
## `#` muro · `.` suelo · `s` sombra · `M` inicio de Mika · `E` salida · `V` vial de Krul.
## La lógica consulta la cuadrícula (es_muro, es_sombra); los TileMapLayer solo dibujan.

const ATLAS_SUELO := Vector2i(0, 0)
const ATLAS_SOMBRA := Vector2i(1, 0)
const ATLAS_MURO := Vector2i(2, 0)
const ATLAS_SALIDA := Vector2i(3, 0)

@export_multiline var plano: String = "":
	set(valor):
		plano = valor
		if is_node_ready():
			_construir()

## Casilla por la que llegan los refuerzos durante la alarma.
@export var entrada_refuerzos := Vector2i(9, 0)

var filas: PackedStringArray = []
var ancho := 0
var alto := 0
var inicio_mika := Vector2i.ZERO
var mika: Mika

var _rejilla := AStarGrid2D.new()

@onready var suelo: TileMapLayer = $Suelo
@onready var muros: TileMapLayer = $Muros
@onready var alerta: Alerta = get_node_or_null("Alerta")


func _ready() -> void:
	_construir()
	if Engine.is_editor_hint():
		return
	mika = get_node_or_null("Mika")
	if mika:
		mika.iniciar(self, Vector2(inicio_mika) + Vector2(0.5, 0.5))
	for soldado in soldados():
		soldado.iniciar(self)


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
	for f in alto:
		for c in ancho:
			var celda := Vector2i(c, f)
			match caracter(celda):
				"#":
					muros.set_cell(celda, 0, ATLAS_MURO)
				"s":
					suelo.set_cell(celda, 0, ATLAS_SOMBRA)
				"E":
					suelo.set_cell(celda, 0, ATLAS_SALIDA)
				"M":
					inicio_mika = celda
					suelo.set_cell(celda, 0, ATLAS_SUELO)
				_:
					suelo.set_cell(celda, 0, ATLAS_SUELO)

	_rejilla.region = Rect2i(0, 0, ancho, alto)
	_rejilla.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_rejilla.update()
	for f in alto:
		for c in ancho:
			_rejilla.set_point_solid(Vector2i(c, f), es_muro(Vector2i(c, f)))


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


func es_sombra(celda: Vector2i) -> bool:
	return caracter(celda) == "s"


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


## Un ruido en `origen`: los soldados a menos de RUIDO_RADIO casillas lo oyen, haya muros o no.
func hacer_ruido(origen: Vector2) -> void:
	for soldado in soldados():
		if soldado.pos.distance_to(origen) <= Config.RUIDO_RADIO:
			soldado.oir(origen)
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
