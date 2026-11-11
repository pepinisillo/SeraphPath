class_name Mika
extends Node2D
## Mika. Su posición real vive en coordenadas de casilla (pos); `position` solo se deriva al dibujar.

const COLOR_CUERPO := Color("dfe8f5")
const COLOR_CONTORNO := Color("7f93b3")
const COLOR_SOMBRA := Color(0, 0, 0, 0.35)
const COLOR_MIRADA := Color("9fd8ff")

const ALTO_CAPSULA := 110.0 # px
const ANCHO_CAPSULA := 40.0 # px
const PASO_MAXIMO := 0.1 # casillas por subpaso, para no atravesar muros a gran velocidad

var mapa: Mapa
var pos := Vector2.ZERO # casillas
var mirada := Vector2(1, 1).normalized() # dirección en casillas
var direccion := 0 # una de 8 direcciones de pantalla, 0 = derecha, en sentido horario


func iniciar(p_mapa: Mapa, p_pos: Vector2) -> void:
	mapa = p_mapa
	pos = p_pos
	position = Iso.a_pantalla(pos)
	$Camara.reset_smoothing()


func _physics_process(delta: float) -> void:
	if mapa == null:
		return
	var entrada := Input.get_vector("mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo")
	if entrada != Vector2.ZERO:
		var dir := Iso.direccion_desde_pantalla(entrada)
		mover(dir * Config.VELOCIDAD_MIKA * delta)
		mirada = dir.normalized()
		direccion = _direccion_8(entrada)
	position = Iso.a_pantalla(pos)
	queue_redraw()


## Mueve en coordenadas de casilla, deslizando contra los muros.
func mover(desplazamiento: Vector2) -> void:
	var pasos := maxi(1, ceili(desplazamiento.length() / PASO_MAXIMO))
	var paso := desplazamiento / pasos
	for i in pasos:
		pos += paso
		_salir_de_muros()


## Empuja el círculo de Mika fuera de cualquier casilla de muro que toque.
func _salir_de_muros() -> void:
	var r := Config.RADIO_MIKA
	var base := Vector2i(floori(pos.x), floori(pos.y))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var celda := base + Vector2i(dx, dy)
			if not mapa.es_muro(celda):
				continue
			var cercano := Vector2(
				clampf(pos.x, celda.x, celda.x + 1.0),
				clampf(pos.y, celda.y, celda.y + 1.0))
			var dif := pos - cercano
			var dist := dif.length()
			if dist < r:
				if dist > 0.0001:
					pos += dif / dist * (r - dist)
				else:
					# El centro quedó dentro del muro: salir por el lado más cercano.
					pos = Vector2(celda) + Vector2(0.5, 0.5) + (pos - Vector2(celda) - Vector2(0.5, 0.5)).normalized() * (0.5 + r)


func _direccion_8(entrada: Vector2) -> int:
	return posmod(roundi(entrada.angle() / (PI / 4.0)), 8)


func _draw() -> void:
	# Sombra en el suelo (el origen del nodo está en los pies, que es lo que usa el Y-sort).
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 30.0, COLOR_SOMBRA)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Indicador de mirada sobre el suelo.
	var frente := Iso.a_pantalla(mirada) - Iso.a_pantalla(Vector2.ZERO)
	frente = frente.normalized() * 34.0 * Vector2(1.0, 0.75)
	draw_line(Vector2.ZERO, frente, COLOR_MIRADA, 3.0)
	draw_circle(frente, 5.0, COLOR_MIRADA)

	# Cápsula.
	var r := ANCHO_CAPSULA / 2.0
	var arriba := Vector2(0, -ALTO_CAPSULA + r)
	var abajo := Vector2(0, -r)
	draw_rect(Rect2(-r, arriba.y, ANCHO_CAPSULA, abajo.y - arriba.y), COLOR_CUERPO)
	draw_circle(arriba, r, COLOR_CUERPO)
	draw_circle(abajo, r, COLOR_CUERPO)
	draw_arc(arriba, r, PI, TAU, 16, COLOR_CONTORNO, 2.0)
	draw_arc(abajo, r, 0.0, PI, 16, COLOR_CONTORNO, 2.0)
	draw_line(Vector2(-r, arriba.y), Vector2(-r, abajo.y), COLOR_CONTORNO, 2.0)
	draw_line(Vector2(r, arriba.y), Vector2(r, abajo.y), COLOR_CONTORNO, 2.0)
