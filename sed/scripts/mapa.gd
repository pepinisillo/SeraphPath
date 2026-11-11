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

var filas: PackedStringArray = []
var ancho := 0
var alto := 0
var inicio_mika := Vector2i.ZERO

@onready var suelo: TileMapLayer = $Suelo
@onready var muros: TileMapLayer = $Muros


func _ready() -> void:
	_construir()
	if Engine.is_editor_hint():
		return
	var mika := get_node_or_null("Mika")
	if mika:
		mika.iniciar(self, Vector2(inicio_mika) + Vector2(0.5, 0.5))


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
