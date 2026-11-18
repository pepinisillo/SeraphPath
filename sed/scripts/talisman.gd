class_name Talisman
extends Node2D
## Talismán de un hechicero, pegado al suelo. Si Mika lo pisa mientras su hechicero sigue en
## pie, lo revela: da la alarma en ese punto y se quema. Si el hechicero cae, se apaga.

const COLOR_PAPEL := Paleta.BLANCO_HUESO
const COLOR_TINTA := Paleta.ROJO

var mapa: Mapa
var hechicero: Hechicero
var celda := Vector2i.ZERO
var activo := true
var _tiempo := 0.0


func iniciar(p_mapa: Mapa, p_hechicero: Hechicero, p_celda: Vector2i) -> void:
	mapa = p_mapa
	hechicero = p_hechicero
	celda = p_celda
	z_index = -1
	position = Iso.a_pantalla(Vector2(celda) + Vector2(0.5, 0.5))


func _physics_process(delta: float) -> void:
	_tiempo += delta
	if not activo or mapa == null or mapa.mika == null:
		return
	if hechicero == null or not is_instance_valid(hechicero) or hechicero.derribado:
		activo = false
		queue_redraw()
		return
	if mapa.mika.celda() == celda and not mapa.mika.caida:
		activo = false
		mapa.estadisticas.talismanes_pisados += 1
		mapa.alerta.dar_alarma(mapa.mika.pos)
		mapa.efectos.salpicar(Vector2(celda) + Vector2(0.5, 0.5), COLOR_TINTA, 14)
	queue_redraw()


func _draw() -> void:
	if not activo:
		return
	var brillo := 0.65 + 0.2 * sin(_tiempo * 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5)) # tumbado en el suelo
	draw_rect(Rect2(-12, -20, 24, 40), Color(COLOR_PAPEL, brillo))
	draw_line(Vector2(0, -14), Vector2(0, 14), Color(COLOR_TINTA, brillo), 3.0)
	draw_line(Vector2(-7, -4), Vector2(7, -4), Color(COLOR_TINTA, brillo), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
