class_name ConoVision
extends Node2D
## Dibuja en el suelo el cono de visión de un enemigo, recortado por los muros.
## Solo dibuja: la detección se calcula aparte, en coordenadas de casilla.

const COLOR_RELLENO := Color(0.62, 0.80, 1.0, 0.30)
const COLOR_BORDE := Color(0.62, 0.80, 1.0, 0.75)

var _puntos := PackedVector2Array() # en pantalla, relativos al dueño


func actualizar(mapa: Mapa, origen: Vector2, mirada: Vector2) -> void:
	_puntos = PackedVector2Array()
	var origen_pantalla := Iso.a_pantalla(origen)
	var medio := deg_to_rad(Config.VISION_ANGULO) / 2.0
	var base := mirada.angle()
	for i in Config.VISION_RAYOS + 1:
		var angulo := base - medio + 2.0 * medio * i / Config.VISION_RAYOS
		var dir := Vector2.from_angle(angulo)
		var largo := mapa.distancia_hasta_muro(origen, dir, Config.VISION_ALCANCE)
		_puntos.append(Iso.a_pantalla(origen + dir * largo) - origen_pantalla)
	queue_redraw()


func _draw() -> void:
	if _puntos.size() < 2:
		return
	for i in _puntos.size() - 1:
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, _puntos[i], _puntos[i + 1]]), COLOR_RELLENO)
	var borde := PackedVector2Array([Vector2.ZERO])
	borde.append_array(_puntos)
	borde.append(Vector2.ZERO)
	draw_polyline(borde, COLOR_BORDE, 2.0, true)
