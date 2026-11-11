class_name OndaRuido
extends Node2D
## Onda que se dibuja en el suelo al hacer ruido: crece hasta el radio en que se oye y se desvanece.

const COLOR := Color(0.85, 0.92, 1.0)

var _tiempo := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = -1


func _process(delta: float) -> void:
	_tiempo += delta
	if _tiempo >= Config.RUIDO_ONDA_DURACION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var avance := _tiempo / Config.RUIDO_ONDA_DURACION
	# Un círculo de radio r casillas se ve en pantalla como una elipse 2:1 de semieje r·ancho/√2.
	var radio := Config.RUIDO_RADIO * avance * Config.ANCHO_CASILLA / sqrt(2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, radio, 0.0, TAU, 64, Color(COLOR, 0.6 * (1.0 - avance)), 4.0, true)
