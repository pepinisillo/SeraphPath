class_name Silueta
extends Node2D
## Silueta de Mika que queda atrás durante el Impulso y se desvanece.

var _tiempo := 0.0


func _process(delta: float) -> void:
	_tiempo += delta
	if _tiempo >= Config.RASTRO_DURACION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alfa := 0.45 * (1.0 - _tiempo / Config.RASTRO_DURACION)
	var r := Mika.ANCHO_CAPSULA / 2.0
	var color := Color(Paleta.CALMA, alfa)
	draw_rect(Rect2(-r, -Mika.ALTO_CAPSULA + r, Mika.ANCHO_CAPSULA, Mika.ALTO_CAPSULA - 2.0 * r), color)
	draw_circle(Vector2(0, -Mika.ALTO_CAPSULA + r), r, color)
	draw_circle(Vector2(0, -r), r, color)
