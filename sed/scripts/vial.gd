class_name Vial
extends Node2D
## Vial de sangre de Krul tirado en el suelo. Mika lo recoge al pasar por encima.

const COLOR_VIDRIO := Color("c9d6e8")
const COLOR_SANGRE := Color("b3263a")

var mapa: Mapa
var pos := Vector2.ZERO # casillas
var _tiempo := 0.0


func iniciar(p_mapa: Mapa, celda: Vector2i) -> void:
	mapa = p_mapa
	pos = Vector2(celda) + Vector2(0.5, 0.5)
	position = Iso.a_pantalla(pos)


func _physics_process(delta: float) -> void:
	_tiempo += delta
	queue_redraw()
	if mapa == null or mapa.mika == null:
		return
	if mapa.mika.pos.distance_to(pos) <= Config.VIAL_RADIO_RECOGER:
		mapa.mika.viales += 1
		queue_free()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var y := -34.0 + sin(_tiempo * 3.0) * 3.0 # flota un poco para que se vea
	draw_rect(Rect2(-7.0, y, 14.0, 24.0), Color(COLOR_VIDRIO, 0.35))
	draw_rect(Rect2(-7.0, y + 9.0, 14.0, 15.0), COLOR_SANGRE)
	draw_rect(Rect2(-7.0, y, 14.0, 24.0), COLOR_VIDRIO, false, 2.0)
	draw_rect(Rect2(-4.0, y - 5.0, 8.0, 5.0), COLOR_VIDRIO)
