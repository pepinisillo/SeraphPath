class_name ConoVision
extends Node2D
## Dibuja en el suelo el cono de visión de un enemigo, recortado por los muros.
## La parte cercana, donde la detección es casi inmediata, se pinta más intensa.
## Solo dibuja: la detección se calcula aparte, en coordenadas de casilla.

var _lejos := PackedVector2Array() # puntos del borde exterior, en pantalla, relativos al dueño
var _cerca := PackedVector2Array() # puntos del borde de la zona cercana
var _color := Color.WHITE


func actualizar(mapa: Mapa, origen: Vector2, mirada: Vector2, color: Color) -> void:
	_lejos = PackedVector2Array()
	_cerca = PackedVector2Array()
	_color = color
	var origen_pantalla := Iso.a_pantalla(origen)
	var medio := deg_to_rad(Config.VISION_ANGULO) / 2.0
	var base := mirada.angle()
	for i in Config.VISION_RAYOS + 1:
		var angulo := base - medio + 2.0 * medio * i / Config.VISION_RAYOS
		var dir := Vector2.from_angle(angulo)
		var largo := mapa.distancia_hasta_muro(origen, dir, Config.VISION_ALCANCE)
		var corto := minf(largo, Config.DETECCION_DISTANCIA_CERCA)
		_lejos.append(Iso.a_pantalla(origen + dir * largo) - origen_pantalla)
		_cerca.append(Iso.a_pantalla(origen + dir * corto) - origen_pantalla)
	queue_redraw()


func _draw() -> void:
	if _lejos.size() < 2:
		return
	_abanico(_lejos, Color(_color, 0.20))
	_abanico(_cerca, Color(_color, 0.16))
	var borde := PackedVector2Array([Vector2.ZERO])
	borde.append_array(_lejos)
	borde.append(Vector2.ZERO)
	draw_polyline(borde, Color(_color, 0.75), 2.0, true)


func _abanico(puntos: PackedVector2Array, color: Color) -> void:
	for i in puntos.size() - 1:
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, puntos[i], puntos[i + 1]]), color)
