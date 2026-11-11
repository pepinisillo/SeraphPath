class_name Soldado
extends Node2D
## Soldado humano. Patrulla su ruta y reacciona a Mika en tres estados: Oculto, Sospecha y Alarma.
## Puede quedar derribado (por Tajo o Golpe silencioso); otro soldado puede descubrir su cuerpo.
## Su posición real vive en coordenadas de casilla.

enum Estado { OCULTO, SOSPECHA, ALARMA }

const COLOR_CUERPO := Color("4a5a6e")
const COLOR_CONTORNO := Color("8d9db3")
const COLOR_MIRADA := Color("c9d6e8")
const COLOR_CALMA := Color("9eccff")
const COLOR_SOSPECHA := Color("f2b13c")
const COLOR_ALARMA := Color("e0384a")
const COLOR_MARCA_SILENCIOSO := Color("e8f1ff")
const COLOR_FONDO_MEDIDOR := Color(0.04, 0.05, 0.08, 0.85)
const ALTO_CAPSULA := 104.0
const ANCHO_CAPSULA := 42.0
const ANCHO_MEDIDOR := 54.0
const ALTO_MEDIDOR := 8.0
const LLEGADA := 0.05 # casillas: a esta distancia del destino ya ha llegado

## Casillas que recorre, en orden. Con una sola casilla, hace guardia en ella.
@export var ruta: Array[Vector2i] = []
## True: vuelve del último punto al primero. False: va y viene (vaivén).
@export var en_bucle := true

var mapa: Mapa
var pos := Vector2.ZERO # casillas
var mirada := Vector2(1, 0) # dirección en casillas, normalizada
var direccion := 0 # una de 8 direcciones de pantalla
var estado := Estado.OCULTO
var medidor := 0.0 # detección, de 0 a 1
var vida := Config.SOLDADO_VIDA
var derribado := false
var descubierto := false # otro soldado ya encontró su cuerpo

var _indice := 0 # punto de la ruta hacia el que camina
var _sentido := 1 # para el vaivén
var _pausa := 0.0
var _volviendo := false # regresa a su ruta después de investigar
var _punto_investigado := Vector2.ZERO
var _buscando := false # ya llegó al punto y mira alrededor
var _busqueda := 0.0 # s que lleva buscando
var _camino := PackedVector2Array()
var _celda_destino := Vector2i(-1, -1)

@onready var cono: ConoVision = $Cono


func iniciar(p_mapa: Mapa) -> void:
	mapa = p_mapa
	if ruta.is_empty():
		push_warning("%s no tiene ruta" % name)
		return
	pos = _centro(ruta[0])
	_indice = 1 % ruta.size()
	if ruta.size() > 1:
		mirada = (_centro(ruta[_indice]) - pos).normalized()
	position = Iso.a_pantalla(pos)


func _physics_process(delta: float) -> void:
	if mapa == null or ruta.is_empty() or derribado:
		return
	var ve := _ve_a_mika()
	if estado != Estado.ALARMA:
		_buscar_cuerpos()
	_actualizar_medidor(ve, delta)
	if mapa.alerta.activa and estado != Estado.ALARMA:
		_entrar_en_alarma()

	match estado:
		Estado.OCULTO:
			_oculto(ve, delta)
		Estado.SOSPECHA:
			_sospecha(ve, delta)
		Estado.ALARMA:
			_alarma(ve, delta)

	direccion = Formas.direccion_8(mirada)
	position = Iso.a_pantalla(pos)
	cono.actualizar(mapa, pos, mirada, _color_estado())
	queue_redraw()


# --- Acciones de Mika sobre él ---

func recibir_dano(cantidad: int) -> void:
	if derribado:
		return
	vida -= cantidad
	if vida <= 0:
		derribar()
	else:
		mapa.alerta.dar_alarma(mapa.mika.pos)


func derribar() -> void:
	derribado = true
	vida = 0
	medidor = 0.0
	estado = Estado.OCULTO
	cono.visible = false
	queue_redraw()


## Por la espalda o fuera del cono, y sin alarma activa.
func admite_golpe_silencioso() -> bool:
	return not derribado and not mapa.alerta.activa and not _ve_a_mika()


## Oye un ruido: va a investigar el origen. En Alarma ya persigue y no le cambia nada.
func oir(origen: Vector2) -> void:
	if derribado or estado == Estado.ALARMA:
		return
	_investigar(origen)


# --- Percepción ---

func _ve_a_mika() -> bool:
	return mapa.mika != null and _puede_ver(mapa.mika.pos)


## El punto está dentro del cono, al alcance (menor si está en sombra) y sin muros de por medio.
func _puede_ver(punto: Vector2) -> bool:
	var hacia := punto - pos
	var distancia := hacia.length()
	var en_sombra := mapa.es_sombra(Vector2i(floori(punto.x), floori(punto.y)))
	var alcance := Config.VISION_ALCANCE_SOMBRA if en_sombra else Config.VISION_ALCANCE
	if distancia > alcance:
		return false
	if distancia > 0.001 and absf(angle_difference(mirada.angle(), hacia.angle())) > deg_to_rad(Config.VISION_ANGULO) / 2.0:
		return false
	return mapa.hay_linea_de_vision(pos, punto)


## Si ve un cuerpo que nadie había encontrado, va a investigarlo.
func _buscar_cuerpos() -> void:
	for otro in mapa.soldados():
		if otro.derribado and not otro.descubierto and _puede_ver(otro.pos):
			otro.descubierto = true
			_investigar(otro.pos)


func _actualizar_medidor(ve: bool, delta: float) -> void:
	if estado == Estado.ALARMA:
		medidor = 1.0
		return
	if not ve:
		medidor = maxf(0.0, medidor - delta / Config.DETECCION_VACIADO)
		return
	var cerca := pos.distance_to(mapa.mika.pos) < Config.DETECCION_DISTANCIA_CERCA
	var tiempo := Config.DETECCION_CERCA if cerca else Config.DETECCION_LEJOS
	medidor = minf(1.0, medidor + delta / tiempo)
	if medidor >= 1.0:
		mapa.alerta.dar_alarma(mapa.mika.pos)
	elif medidor >= Config.DETECCION_SOSPECHA and estado == Estado.OCULTO:
		_investigar(mapa.mika.pos)


# --- Estados ---

func _oculto(ve: bool, delta: float) -> void:
	if ve and medidor > 0.0:
		# Algo le llamó la atención: se detiene a mirar mientras el medidor sube.
		_girar_hacia(mapa.mika.pos - pos, delta)
		return
	if _volviendo:
		if _ir_hacia(_centro(ruta[_indice]), Config.SOLDADO_VELOCIDAD_PATRULLA, delta):
			_volviendo = false
		return
	_patrullar(delta)


func _sospecha(ve: bool, delta: float) -> void:
	if ve:
		_punto_investigado = mapa.mika.pos
		_buscando = false
	if not _buscando:
		if _ir_hacia(_punto_investigado, Config.SOLDADO_VELOCIDAD_PATRULLA, delta):
			_buscando = true
			_busqueda = 0.0
		return
	_busqueda += delta
	_mirar_alrededor(delta)
	if _busqueda >= Config.SOSPECHA_DURACION:
		estado = Estado.OCULTO
		_volviendo = true
		_buscando = false


func _alarma(ve: bool, delta: float) -> void:
	if not mapa.alerta.activa:
		# La alarma se apagó: queda la duda, va a revisar el último sitio donde la vieron.
		medidor = Config.DETECCION_SOSPECHA
		_investigar(mapa.alerta.ultima_posicion)
		return
	if ve:
		mapa.alerta.vista(mapa.mika.pos)
	var objetivo := mapa.alerta.ultima_posicion
	if ve and pos.distance_to(objetivo) <= Config.SOLDADO_DISTANCIA_GOLPE:
		_girar_hacia(objetivo - pos, delta)
		return
	if _ir_hacia(objetivo, Config.SOLDADO_VELOCIDAD_ALARMA, delta):
		_mirar_alrededor(delta)


func _investigar(punto: Vector2) -> void:
	estado = Estado.SOSPECHA
	_punto_investigado = punto
	_buscando = false
	_volviendo = false


func _entrar_en_alarma() -> void:
	estado = Estado.ALARMA
	medidor = 1.0
	_buscando = false
	_volviendo = false


# --- Movimiento ---

func _patrullar(delta: float) -> void:
	if ruta.size() == 1:
		_ir_hacia(_centro(ruta[0]), Config.SOLDADO_VELOCIDAD_PATRULLA, delta)
		return
	var destino := _centro(ruta[_indice])
	var hacia := destino - pos
	_girar_hacia(hacia, delta)

	if _pausa > 0.0:
		_pausa -= delta
		return

	var avance := Config.SOLDADO_VELOCIDAD_PATRULLA * delta
	if hacia.length() <= avance:
		pos = destino
		_pausa = Config.SOLDADO_PAUSA_RUTA
		_siguiente_punto()
	else:
		pos += hacia.normalized() * avance


func _siguiente_punto() -> void:
	if en_bucle:
		_indice = (_indice + 1) % ruta.size()
		return
	if _indice + _sentido < 0 or _indice + _sentido >= ruta.size():
		_sentido = -_sentido
	_indice += _sentido


## Camina hacia `destino` rodeando muros. Devuelve true cuando ya está allí.
func _ir_hacia(destino: Vector2, velocidad: float, delta: float) -> bool:
	if pos.distance_to(destino) <= LLEGADA:
		_camino.clear()
		return true
	var celda_destino := Vector2i(floori(destino.x), floori(destino.y))
	if _camino.is_empty() or celda_destino != _celda_destino:
		_camino = mapa.camino(pos, destino)
		_celda_destino = celda_destino
		if _camino.is_empty():
			return true # inalcanzable: se queda donde está
	else:
		_camino[-1] = destino # el destino puede moverse dentro de la misma casilla

	_girar_hacia(_camino[0] - pos, delta)
	var avance := velocidad * delta
	while avance > 0.0 and not _camino.is_empty():
		var hacia := _camino[0] - pos
		var distancia := hacia.length()
		if distancia <= avance:
			pos = _camino[0]
			avance -= distancia
			_camino.remove_at(0)
		else:
			pos += hacia / distancia * avance
			avance = 0.0
	return _camino.is_empty()


## Gira la mirada poco a poco, para que el cono barra el suelo en vez de saltar.
func _girar_hacia(hacia: Vector2, delta: float) -> void:
	if hacia.length() < 0.001:
		return
	var actual := mirada.angle()
	var giro := clampf(angle_difference(actual, hacia.angle()), -Config.SOLDADO_GIRO * delta, Config.SOLDADO_GIRO * delta)
	mirada = Vector2.from_angle(actual + giro)


func _mirar_alrededor(delta: float) -> void:
	mirada = mirada.rotated(Config.SOLDADO_GIRO_BUSQUEDA * delta)


func _centro(celda: Vector2i) -> Vector2:
	return Vector2(celda) + Vector2(0.5, 0.5)


# --- Dibujo ---

func _color_estado() -> Color:
	match estado:
		Estado.SOSPECHA:
			return COLOR_SOSPECHA
		Estado.ALARMA:
			return COLOR_ALARMA
	return COLOR_CALMA


func _draw() -> void:
	if derribado:
		Formas.caido(self, ALTO_CAPSULA * 0.8, ANCHO_CAPSULA * 0.8, COLOR_CUERPO.darkened(0.25), COLOR_CONTORNO.darkened(0.3))
		return
	Formas.mirada(self, mirada, COLOR_MIRADA)
	Formas.capsula(self, ALTO_CAPSULA, ANCHO_CAPSULA, COLOR_CUERPO, COLOR_CONTORNO)

	# Rombo sobre la cabeza: Mika puede derribarlo ahora con un Golpe silencioso.
	if mapa and mapa.mika and mapa.mika.objetivo_silencioso == self:
		var c := Vector2(0, -ALTO_CAPSULA - 46.0)
		var rombo := PackedVector2Array([c + Vector2(0, -9), c + Vector2(9, 0), c + Vector2(0, 9), c + Vector2(-9, 0), c + Vector2(0, -9)])
		draw_polyline(rombo, COLOR_MARCA_SILENCIOSO, 2.0, true)

	if medidor <= 0.0 and estado == Estado.OCULTO:
		return

	# Medidor de detección sobre la cabeza; la marca central es el umbral de Sospecha.
	var color := COLOR_ALARMA if estado == Estado.ALARMA else COLOR_SOSPECHA
	var esquina := Vector2(-ANCHO_MEDIDOR / 2.0, -ALTO_CAPSULA - 22.0)
	draw_rect(Rect2(esquina, Vector2(ANCHO_MEDIDOR, ALTO_MEDIDOR)), COLOR_FONDO_MEDIDOR)
	draw_rect(Rect2(esquina, Vector2(ANCHO_MEDIDOR * medidor, ALTO_MEDIDOR)), color)
	var marca := esquina.x + ANCHO_MEDIDOR * Config.DETECCION_SOSPECHA
	draw_line(Vector2(marca, esquina.y), Vector2(marca, esquina.y + ALTO_MEDIDOR), Color(1, 1, 1, 0.5), 1.0)

	if estado != Estado.OCULTO:
		var signo := "!" if estado == Estado.ALARMA else "?"
		draw_string(ThemeDB.fallback_font, Vector2(-20.0, esquina.y - 6.0), signo, HORIZONTAL_ALIGNMENT_CENTER, 40.0, 28, color)
