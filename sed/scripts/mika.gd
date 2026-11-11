class_name Mika
extends Node2D
## Mika. Su posición real vive en coordenadas de casilla (pos); `position` solo se deriva al dibujar.
## Acciones: Tajo (daño y ruido), Golpe silencioso (derriba sin ruido) e Impulso (dash con ruido).

const COLOR_CUERPO := Color("dfe8f5")
const COLOR_CONTORNO := Color("7f93b3")
const COLOR_MIRADA := Color("9fd8ff")
const COLOR_TAJO := Color("eef5ff")

const ALTO_CAPSULA := 110.0 # px
const ANCHO_CAPSULA := 40.0 # px
const PASO_MAXIMO := 0.1 # casillas por subpaso, para no atravesar muros a gran velocidad
const TAJO_VISIBLE := 0.12 # s que se ve el arco del Tajo

var mapa: Mapa
var pos := Vector2.ZERO # casillas
var mirada := Vector2(1, 1).normalized() # dirección en casillas
var direccion := 0 # una de 8 direcciones de pantalla, 0 = derecha, en sentido horario
## Soldado al que derribaría ahora un Golpe silencioso (o null). Él dibuja la marca.
var objetivo_silencioso: Soldado = null

var _impulso_restante := 0.0 # s que quedan de dash; > 0 mientras dura
var _impulso_dir := Vector2.ZERO
var _enfriamiento_impulso := 0.0
var _enfriamiento_tajo := 0.0
var _enfriamiento_golpe := 0.0
var _tajo_restante := 0.0


func iniciar(p_mapa: Mapa, p_pos: Vector2) -> void:
	mapa = p_mapa
	pos = p_pos
	position = Iso.a_pantalla(pos)
	$Camara.reset_smoothing()


func celda() -> Vector2i:
	return Vector2i(floori(pos.x), floori(pos.y))


func esta_impulsando() -> bool:
	return _impulso_restante > 0.0


func _physics_process(delta: float) -> void:
	if mapa == null:
		return
	_enfriamiento_impulso -= delta
	_enfriamiento_tajo -= delta
	_enfriamiento_golpe -= delta
	_tajo_restante -= delta

	if esta_impulsando():
		_impulsar(delta)
	else:
		var entrada := Input.get_vector("mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo")
		if entrada != Vector2.ZERO:
			var dir := Iso.direccion_desde_pantalla(entrada)
			mover(dir * Config.VELOCIDAD_MIKA * delta)
			mirada = dir.normalized()
		if Input.is_action_just_pressed("impulso"):
			impulso(entrada)
		elif Input.is_action_just_pressed("tajo"):
			tajo()
		elif Input.is_action_just_pressed("golpe_silencioso"):
			golpe_silencioso()

	objetivo_silencioso = _buscar_objetivo_silencioso()
	direccion = Formas.direccion_8(mirada)
	position = Iso.a_pantalla(pos)
	queue_redraw()


# --- Acciones ---

## Daña a todos los soldados al alcance delante de Mika. Hace ruido.
func tajo() -> bool:
	if _enfriamiento_tajo > 0.0 or esta_impulsando():
		return false
	_enfriamiento_tajo = Config.TAJO_ENFRIAMIENTO
	_tajo_restante = TAJO_VISIBLE
	for soldado in mapa.soldados():
		if _al_alcance(soldado, Config.TAJO_ALCANCE):
			soldado.recibir_dano(Config.TAJO_DANO)
	mapa.hacer_ruido(pos)
	return true


## Derriba sin ruido al soldado marcado. Sin objetivo válido no hace nada.
func golpe_silencioso() -> bool:
	if _enfriamiento_golpe > 0.0 or esta_impulsando():
		return false
	var objetivo := _buscar_objetivo_silencioso()
	if objetivo == null:
		return false
	_enfriamiento_golpe = Config.GOLPE_SILENCIOSO_ENFRIAMIENTO
	objetivo.derribar()
	return true


## Dash hacia donde apunta la entrada (o hacia donde mira, si no hay entrada). Hace ruido donde empieza.
func impulso(entrada: Vector2) -> bool:
	if _enfriamiento_impulso > 0.0 or esta_impulsando():
		return false
	_impulso_dir = Iso.direccion_desde_pantalla(entrada).normalized() if entrada != Vector2.ZERO else mirada
	mirada = _impulso_dir
	_impulso_restante = Config.IMPULSO_DURACION
	_enfriamiento_impulso = Config.IMPULSO_ENFRIAMIENTO
	mapa.hacer_ruido(pos)
	return true


func _impulsar(delta: float) -> void:
	var tramo := minf(delta, _impulso_restante)
	mover(_impulso_dir * (Config.IMPULSO_DISTANCIA / Config.IMPULSO_DURACION) * tramo)
	_impulso_restante -= tramo
	if _impulso_restante < 0.0001:
		_impulso_restante = 0.0 # evita un fotograma extra por redondeo


## Soldado en pie, a menos de `alcance` casillas y dentro del arco de ataque delante de Mika.
func _al_alcance(soldado: Soldado, alcance: float) -> bool:
	if soldado.derribado:
		return false
	var hacia := soldado.pos - pos
	if hacia.length() > alcance:
		return false
	if hacia.length() < 0.3:
		return true # encima de él: no importa hacia dónde mire
	return absf(angle_difference(mirada.angle(), hacia.angle())) <= deg_to_rad(Config.ATAQUE_ANGULO) / 2.0


func _buscar_objetivo_silencioso() -> Soldado:
	var mejor: Soldado = null
	for soldado in mapa.soldados():
		if _al_alcance(soldado, Config.GOLPE_SILENCIOSO_ALCANCE) and soldado.admite_golpe_silencioso():
			if mejor == null or pos.distance_to(soldado.pos) < pos.distance_to(mejor.pos):
				mejor = soldado
	return mejor


# --- Movimiento ---

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
	var base := celda()
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := base + Vector2i(dx, dy)
			if not mapa.es_muro(c):
				continue
			var cercano := Vector2(
				clampf(pos.x, c.x, c.x + 1.0),
				clampf(pos.y, c.y, c.y + 1.0))
			var dif := pos - cercano
			var dist := dif.length()
			if dist < r:
				if dist > 0.0001:
					pos += dif / dist * (r - dist)
				else:
					# El centro quedó dentro del muro: salir por el lado más cercano.
					pos = Vector2(c) + Vector2(0.5, 0.5) + (pos - Vector2(c) - Vector2(0.5, 0.5)).normalized() * (0.5 + r)


# --- Dibujo ---

func _draw() -> void:
	if _tajo_restante > 0.0:
		_dibujar_tajo()
	Formas.mirada(self, mirada, COLOR_MIRADA)
	var cuerpo := COLOR_CUERPO
	if esta_impulsando():
		cuerpo.a = 0.6
	Formas.capsula(self, ALTO_CAPSULA, ANCHO_CAPSULA, cuerpo, COLOR_CONTORNO)


## Arco en el suelo con el alcance y el ángulo reales del Tajo.
func _dibujar_tajo() -> void:
	var medio := deg_to_rad(Config.ATAQUE_ANGULO) / 2.0
	var puntos := PackedVector2Array()
	for i in 13:
		var angulo := mirada.angle() - medio + 2.0 * medio * i / 12.0
		var punto := Vector2.from_angle(angulo) * Config.TAJO_ALCANCE
		puntos.append(Iso.a_pantalla(punto) - Iso.a_pantalla(Vector2.ZERO))
	var alfa := _tajo_restante / TAJO_VISIBLE
	draw_polyline(puntos, Color(COLOR_TAJO, alfa), 6.0, true)
