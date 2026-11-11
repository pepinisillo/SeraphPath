class_name Soldado
extends Node2D
## Soldado humano que patrulla una ruta fija. Su posición real vive en coordenadas de casilla.

const COLOR_CUERPO := Color("4a5a6e")
const COLOR_CONTORNO := Color("8d9db3")
const COLOR_MIRADA := Color("c9d6e8")
const ALTO_CAPSULA := 104.0
const ANCHO_CAPSULA := 42.0

## Casillas que recorre, en orden.
@export var ruta: Array[Vector2i] = []
## True: vuelve del último punto al primero. False: va y viene (vaivén).
@export var en_bucle := true

var mapa: Mapa
var pos := Vector2.ZERO # casillas
var mirada := Vector2(1, 0) # dirección en casillas, normalizada
var direccion := 0 # una de 8 direcciones de pantalla

var _indice := 0 # punto de la ruta hacia el que camina
var _sentido := 1 # para el vaivén
var _pausa := 0.0

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
	if mapa == null or ruta.size() < 2:
		return
	_patrullar(delta)
	direccion = Formas.direccion_8(mirada)
	position = Iso.a_pantalla(pos)
	cono.actualizar(mapa, pos, mirada)
	queue_redraw()


func _patrullar(delta: float) -> void:
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


## Gira la mirada poco a poco, para que el cono barra el suelo en vez de saltar.
func _girar_hacia(hacia: Vector2, delta: float) -> void:
	if hacia.length() < 0.001:
		return
	var actual := mirada.angle()
	var objetivo := hacia.angle()
	var giro := clampf(angle_difference(actual, objetivo), -Config.SOLDADO_GIRO * delta, Config.SOLDADO_GIRO * delta)
	mirada = Vector2.from_angle(actual + giro)


func _centro(celda: Vector2i) -> Vector2:
	return Vector2(celda) + Vector2(0.5, 0.5)


func _draw() -> void:
	Formas.mirada(self, mirada, COLOR_MIRADA)
	Formas.capsula(self, ALTO_CAPSULA, ANCHO_CAPSULA, COLOR_CUERPO, COLOR_CONTORNO)
