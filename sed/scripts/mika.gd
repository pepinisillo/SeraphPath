class_name Mika
extends Node2D
## Mika. Su posición real vive en coordenadas de casilla (pos); `position` solo se deriva al dibujar.
## Acciones: Tajo (daño y ruido), Golpe silencioso (derriba sin ruido), Impulso (dash con ruido),
## beber sangre de un humano derribado y tomar un vial de Krul.
## La sed sube sola; en Frenesí Mika pierde el control y va a beber del humano más cercano.

signal mejora_pendiente(opciones: Array[String])
signal derrotada

const COLOR_CUERPO := Color("dfe8f5")
const COLOR_CONTORNO := Color("7f93b3")
const COLOR_FRENESI := Color("e0384a")
const COLOR_MIRADA := Color("9fd8ff")
const COLOR_TAJO := Color("eef5ff")
const COLOR_SANGRE := Color("b3263a")

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
## Cuerpo del que puede beber ahora (o null). Él dibuja el aviso.
var objetivo_beber: Soldado = null

# Estado vital
var vida := Config.VIDA_MIKA
var vida_max := Config.VIDA_MIKA
var sed := Config.SED_INICIAL
var humanidad := Config.HUMANIDAD_INICIAL
var viales := 0
var mejoras: Array[String] = []
var caida := false
var rng := RandomNumberGenerator.new()

var _impulso_restante := 0.0 # s que quedan de dash; > 0 mientras dura
var _impulso_dir := Vector2.ZERO
var _enfriamiento_impulso := 0.0
var _enfriamiento_tajo := 0.0
var _enfriamiento_golpe := 0.0
var _tajo_restante := 0.0
var _acumulado_sed := 0.0
var _acumulado_regeneracion := 0.0
var _bebiendo: Soldado = null
var _beber_forzado := false # bebe en Frenesí: no hace falta mantener el botón
var _bebido := 0.0 # s que lleva bebiendo
var _vial_restante := 0.0
var _frenesi_restante := 0.0
var _respiro := 0.0


func iniciar(p_mapa: Mapa, p_pos: Vector2) -> void:
	mapa = p_mapa
	pos = p_pos
	position = Iso.a_pantalla(pos)
	$Camara.reset_smoothing()


func celda() -> Vector2i:
	return Vector2i(floori(pos.x), floori(pos.y))


func esta_impulsando() -> bool:
	return _impulso_restante > 0.0


func esta_bebiendo() -> bool:
	return _bebiendo != null


func en_frenesi() -> bool:
	return _frenesi_restante > 0.0


## El jugador no la controla: Frenesí o el trago que lo cierra.
func sin_control() -> bool:
	return en_frenesi() or (esta_bebiendo() and _beber_forzado)


## Fracción completada de lo que está bebiendo (sangre o vial), o -1 si no bebe nada.
func progreso_bebida() -> float:
	if esta_bebiendo():
		return _bebido / Config.BEBER_DURACION
	if _vial_restante > 0.0:
		return 1.0 - _vial_restante / Config.VIAL_DURACION
	return -1.0


func tiene_mejora(id: String) -> bool:
	return id in mejoras


func velocidad() -> float:
	var base := Config.VELOCIDAD_MIKA_SEDIENTO if sed >= Config.SED_TRAMO_LENTO else Config.VELOCIDAD_MIKA
	return base + (Config.MEJORA_VELOCIDAD if tiene_mejora(Mejoras.VELOCIDAD) else 0.0)


func dano_tajo() -> int:
	return Config.TAJO_DANO + (Config.MEJORA_FUERZA if tiene_mejora(Mejoras.FUERZA) else 0)


func _physics_process(delta: float) -> void:
	if mapa == null or caida:
		return
	_enfriamiento_impulso -= delta
	_enfriamiento_tajo -= delta
	_enfriamiento_golpe -= delta
	_tajo_restante -= delta
	_respiro -= delta
	_actualizar_sed(delta)
	_actualizar_regeneracion(delta)
	if sed >= Config.SED_TRAMO_FRENESI and not en_frenesi() and not esta_bebiendo() and _respiro <= 0.0:
		_frenesi_restante = Config.FRENESI_DURACION

	objetivo_beber = _buscar_cuerpo()
	if esta_bebiendo():
		_seguir_bebiendo(delta)
	elif en_frenesi():
		_frenesi(delta)
	elif _vial_restante > 0.0:
		_seguir_con_vial(delta)
	elif esta_impulsando():
		_impulsar(delta)
	else:
		_control(delta)

	objetivo_silencioso = null if sin_control() else _buscar_objetivo_silencioso()
	direccion = Formas.direccion_8(mirada)
	position = Iso.a_pantalla(pos)
	queue_redraw()


func _control(delta: float) -> void:
	var entrada := Input.get_vector("mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo")
	if entrada != Vector2.ZERO:
		var dir := Iso.direccion_desde_pantalla(entrada)
		mover(dir * velocidad() * delta)
		mirada = dir.normalized()
	if Input.is_action_just_pressed("impulso"):
		impulso(entrada)
	elif Input.is_action_just_pressed("tajo"):
		tajo()
	elif Input.is_action_just_pressed("golpe_silencioso"):
		golpe_silencioso()
	elif Input.is_action_just_pressed("vial"):
		tomar_vial()
	elif Input.is_action_pressed("beber"):
		empezar_a_beber()


# --- Sed, vida y Humanidad ---

func sumar_sed(cantidad: int) -> void:
	sed = clampi(sed + cantidad, 0, Config.SED_MAX)


func _actualizar_sed(delta: float) -> void:
	_acumulado_sed += delta
	while _acumulado_sed >= Config.SED_INTERVALO:
		_acumulado_sed -= Config.SED_INTERVALO
		sumar_sed(1)


func _actualizar_regeneracion(delta: float) -> void:
	var regenera := sed <= Config.SED_TRAMO_REGENERA or tiene_mejora(Mejoras.REGENERACION)
	if not regenera or vida >= vida_max:
		_acumulado_regeneracion = 0.0
		return
	_acumulado_regeneracion += delta
	if _acumulado_regeneracion >= Config.REGENERACION_INTERVALO:
		_acumulado_regeneracion -= Config.REGENERACION_INTERVALO
		vida += 1


func recibir_golpe(dano: int) -> void:
	if caida:
		return
	vida -= dano
	sumar_sed(Config.SED_POR_GOLPE)
	if vida <= 0:
		vida = 0
		caida = true
		_bebiendo = null
		_frenesi_restante = 0.0
		queue_redraw()
		derrotada.emit()


func elegir_mejora(id: String) -> void:
	if tiene_mejora(id):
		return
	mejoras.append(id)
	if id == Mejoras.VIGOR:
		vida_max += Config.MEJORA_VIGOR
		vida += Config.MEJORA_VIGOR


# --- Beber ---

## Empieza a beber del cuerpo más cercano. Si no es forzado, hay que mantener el botón.
func empezar_a_beber(forzado := false) -> bool:
	if objetivo_beber == null or esta_bebiendo():
		return false
	_bebiendo = objetivo_beber
	_beber_forzado = forzado
	_bebido = 0.0
	if _bebiendo.pos.distance_to(pos) > 0.01:
		mirada = (_bebiendo.pos - pos).normalized()
	return true


func _seguir_bebiendo(delta: float) -> void:
	if not _beber_forzado and not Input.is_action_pressed("beber"):
		_bebiendo = null # soltó el botón: no bebe
		return
	_bebido += delta
	if _bebido >= Config.BEBER_DURACION:
		_terminar_de_beber()


func _terminar_de_beber() -> void:
	_bebiendo.bebido = true
	_bebiendo = null
	_beber_forzado = false
	_frenesi_restante = 0.0
	sed = 0
	_acumulado_sed = 0.0
	vida = vida_max
	humanidad = maxi(0, humanidad - 1)
	_ofrecer_mejora()


## Dos mejoras al azar entre las que aún no tiene. La interfaz muestra la elección.
func _ofrecer_mejora() -> void:
	var disponibles: Array[String] = []
	for id in Mejoras.TODAS:
		if not tiene_mejora(id):
			disponibles.append(id)
	if disponibles.is_empty():
		return
	for i in range(disponibles.size() - 1, 0, -1): # barajar con el generador propio
		var j := rng.randi_range(0, i)
		var tmp := disponibles[i]
		disponibles[i] = disponibles[j]
		disponibles[j] = tmp
	mejora_pendiente.emit(disponibles.slice(0, 2))


func _buscar_cuerpo() -> Soldado:
	var mejor: Soldado = null
	for soldado in mapa.soldados():
		if soldado.derribado and not soldado.bebido and pos.distance_to(soldado.pos) <= Config.BEBER_DISTANCIA:
			if mejor == null or pos.distance_to(soldado.pos) < pos.distance_to(mejor.pos):
				mejor = soldado
	return mejor


# --- Vial ---

func tomar_vial() -> bool:
	if viales <= 0 or _vial_restante > 0.0:
		return false
	_vial_restante = Config.VIAL_DURACION
	return true


func _seguir_con_vial(delta: float) -> void:
	_vial_restante -= delta
	if _vial_restante <= 0.0:
		_vial_restante = 0.0
		viales -= 1
		sumar_sed(Config.VIAL_SED)


# --- Frenesí ---

## Va por el humano más cercano: si está en pie lo derriba con el Tajo, y luego bebe.
func _frenesi(delta: float) -> void:
	_frenesi_restante -= delta
	if _frenesi_restante <= 0.0:
		_frenesi_restante = 0.0
		_respiro = Config.FRENESI_RESPIRO # no encontró a nadie: un respiro antes de volver a perderse
		return
	var presa := _humano_mas_cercano()
	if presa == null:
		return
	var hacia := presa.pos - pos
	if presa.derribado and hacia.length() <= Config.BEBER_DISTANCIA:
		objetivo_beber = presa
		empezar_a_beber(true)
		_frenesi_restante = 0.0
		return
	if not presa.derribado and hacia.length() <= Config.TAJO_ALCANCE * 0.9:
		mirada = hacia.normalized()
		tajo()
		return
	var camino := mapa.camino(pos, presa.pos)
	if camino.is_empty():
		return
	var paso := camino[0] - pos
	if paso.length() > 0.001:
		mirada = paso.normalized()
		mover(mirada * minf(velocidad() * delta, paso.length()))


func _humano_mas_cercano() -> Soldado:
	var mejor: Soldado = null
	for soldado in mapa.soldados():
		if soldado.bebido:
			continue
		if mejor == null or pos.distance_to(soldado.pos) < pos.distance_to(mejor.pos):
			mejor = soldado
	return mejor


# --- Acciones de combate ---

## Daña a todos los soldados al alcance delante de Mika. Hace ruido.
func tajo() -> bool:
	if _enfriamiento_tajo > 0.0 or esta_impulsando():
		return false
	_enfriamiento_tajo = Config.TAJO_ENFRIAMIENTO
	_tajo_restante = TAJO_VISIBLE
	for soldado in mapa.soldados():
		if _al_alcance(soldado, Config.TAJO_ALCANCE):
			soldado.recibir_dano(dano_tajo())
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


## Dash hacia donde apunta la entrada (o hacia donde mira, si no hay entrada). Sube la sed
## y hace ruido donde empieza.
func impulso(entrada: Vector2) -> bool:
	if _enfriamiento_impulso > 0.0 or esta_impulsando():
		return false
	_impulso_dir = Iso.direccion_desde_pantalla(entrada).normalized() if entrada != Vector2.ZERO else mirada
	mirada = _impulso_dir
	_impulso_restante = Config.IMPULSO_DURACION
	_enfriamiento_impulso = Config.IMPULSO_ENFRIAMIENTO
	sumar_sed(Config.IMPULSO_SED)
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
	if caida:
		Formas.caido(self, ALTO_CAPSULA * 0.8, ANCHO_CAPSULA * 0.8, COLOR_CUERPO.darkened(0.3), COLOR_CONTORNO)
		return
	if _tajo_restante > 0.0:
		_dibujar_tajo()
	Formas.mirada(self, mirada, COLOR_MIRADA)
	var cuerpo := COLOR_CUERPO
	if esta_impulsando():
		cuerpo.a = 0.6
	var contorno := COLOR_FRENESI if sin_control() else COLOR_CONTORNO
	Formas.capsula(self, ALTO_CAPSULA, ANCHO_CAPSULA, cuerpo, contorno)

	var progreso := progreso_bebida()
	if progreso >= 0.0:
		var centro := Vector2(0, -ALTO_CAPSULA - 24.0)
		draw_arc(centro, 12.0, 0.0, TAU, 24, Color(0, 0, 0, 0.6), 5.0)
		draw_arc(centro, 12.0, -PI / 2.0, -PI / 2.0 + TAU * progreso, 24, COLOR_SANGRE, 5.0)


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
