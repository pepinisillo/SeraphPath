class_name Yuu
extends Node2D
## Yuu al fondo de la Prueba de la sed: es la salida. Llegar hasta él sin beber supera la prueba.

const ALTO_CAPSULA := 106.0
const ANCHO_CAPSULA := 40.0

var _tiempo := 0.0


func iniciar(celda: Vector2i) -> void:
	position = Iso.a_pantalla(Vector2(celda) + Vector2(0.5, 0.5))


func _process(delta: float) -> void:
	_tiempo += delta
	queue_redraw()


func _draw() -> void:
	var brillo := 0.5 + 0.2 * sin(_tiempo * 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 46.0, Color(Paleta.TURQUESA, brillo * 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Formas.capsula(self, ALTO_CAPSULA, ANCHO_CAPSULA, Color(Paleta.BLANCO_HUESO, 0.9), Paleta.TURQUESA)
	draw_string(ThemeDB.fallback_font, Vector2(-40, -ALTO_CAPSULA - 14), "Yuu", HORIZONTAL_ALIGNMENT_CENTER, 80, 18, Paleta.TURQUESA)
