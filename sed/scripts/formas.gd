class_name Formas
## Formas provisionales compartidas mientras no haya arte (paso 9).


## Dibuja una cápsula de pie con su sombra en el suelo. El origen es el punto de los pies.
static func capsula(lienzo: CanvasItem, alto: float, ancho: float, relleno: Color, contorno: Color) -> void:
	lienzo.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	lienzo.draw_circle(Vector2.ZERO, ancho * 0.75, Color(0, 0, 0, 0.35))
	lienzo.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var r := ancho / 2.0
	var arriba := Vector2(0, -alto + r)
	var abajo := Vector2(0, -r)
	lienzo.draw_rect(Rect2(-r, arriba.y, ancho, abajo.y - arriba.y), relleno)
	lienzo.draw_circle(arriba, r, relleno)
	lienzo.draw_circle(abajo, r, relleno)
	lienzo.draw_arc(arriba, r, PI, TAU, 16, contorno, 2.0)
	lienzo.draw_arc(abajo, r, 0.0, PI, 16, contorno, 2.0)
	lienzo.draw_line(Vector2(-r, arriba.y), Vector2(-r, abajo.y), contorno, 2.0)
	lienzo.draw_line(Vector2(r, arriba.y), Vector2(r, abajo.y), contorno, 2.0)


## Flecha sobre el suelo que indica hacia dónde mira (dirección en casillas).
static func mirada(lienzo: CanvasItem, direccion: Vector2, color: Color) -> void:
	var frente := Iso.a_pantalla(direccion) - Iso.a_pantalla(Vector2.ZERO)
	frente = frente.normalized() * 34.0 * Vector2(1.0, 0.75)
	lienzo.draw_line(Vector2.ZERO, frente, color, 3.0)
	lienzo.draw_circle(frente, 5.0, color)


## Índice de 8 direcciones de pantalla (0 = derecha, en sentido horario) para una dirección en casillas.
static func direccion_8(direccion: Vector2) -> int:
	var pantalla := Iso.a_pantalla(direccion) - Iso.a_pantalla(Vector2.ZERO)
	return posmod(roundi(pantalla.angle() / (PI / 4.0)), 8)
