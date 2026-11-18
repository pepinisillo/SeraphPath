class_name ControlesTactiles
extends CanvasLayer
## Controles en pantalla para móviles: un joystick a la izquierda y los botones de acción a la
## derecha. Pulsan las mismas acciones que el teclado y el mando (Input.action_press), así que el
## juego no distingue de dónde vienen. Solo aparecen si la pantalla es táctil (o si las pruebas
## los fuerzan). Beber se mantiene pulsado, como en el teclado.

const RADIO_JOYSTICK := 90.0
const RADIO_BOTON := 46.0
const MARGEN := 40.0
const COLOR_BASE := Color(Paleta.BLANCO_HUESO, 0.18)
const COLOR_PULSADO := Color(Paleta.BLANCO_HUESO, 0.4)
const COLOR_TEXTO := Paleta.BLANCO_HUESO

## Botones: acción, etiqueta y posición relativa a la esquina inferior derecha (en radios).
const BOTONES := [
	["tajo", "Tajo", Vector2(-1.2, -1.2)],
	["golpe_silencioso", "Golpe", Vector2(-3.4, -1.2)],
	["impulso", "Impulso", Vector2(-1.2, -3.4)],
	["beber", "Beber", Vector2(-3.4, -3.4)],
	["vial", "Vial", Vector2(-5.6, -1.2)],
	["sentidos", "Sentidos", Vector2(-1.2, -5.6)],
	["espada", "Espada", Vector2(-3.4, -5.6)],
	["pausa", "Pausa", Vector2(-1.2, -7.8)],
]

static var forzar := false # las pruebas lo encienden

var lienzo: Control
var _dedo_joystick := -1 # índice del dedo que mueve el joystick
var _centro_joystick := Vector2.ZERO
var _punta := Vector2.ZERO # desplazamiento del joystick
var _dedos_en_boton := {} # dedo -> acción


## ¿Hay que mostrarlos aquí?
static func hacen_falta() -> bool:
	return forzar or DisplayServer.is_touchscreen_available()


func _ready() -> void:
	layer = 15
	lienzo = Control.new()
	lienzo.set_anchors_preset(Control.PRESET_FULL_RECT)
	lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lienzo.draw.connect(_dibujar)
	add_child(lienzo)


func _input(evento: InputEvent) -> void:
	if evento is InputEventScreenTouch:
		if evento.pressed:
			_tocar(evento.index, evento.position)
		else:
			_soltar(evento.index)
	elif evento is InputEventScreenDrag and evento.index == _dedo_joystick:
		_mover_joystick(evento.position)


func _tocar(dedo: int, punto: Vector2) -> void:
	var tam := lienzo.size
	for b in BOTONES:
		if punto.distance_to(posicion_boton(b[2], tam)) <= RADIO_BOTON:
			_dedos_en_boton[dedo] = b[0]
			Input.action_press(b[0])
			lienzo.queue_redraw()
			return
	if punto.x < tam.x * 0.45 and _dedo_joystick < 0:
		_dedo_joystick = dedo
		_centro_joystick = punto
		_mover_joystick(punto)


func _soltar(dedo: int) -> void:
	if _dedos_en_boton.has(dedo):
		Input.action_release(_dedos_en_boton[dedo])
		_dedos_en_boton.erase(dedo)
	if dedo == _dedo_joystick:
		_dedo_joystick = -1
		_punta = Vector2.ZERO
		for accion in ["mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo"]:
			Input.action_release(accion)
	lienzo.queue_redraw()


## El joystick hace de stick: cada eje pulsa su acción con la fuerza del desplazamiento.
func _mover_joystick(punto: Vector2) -> void:
	_punta = (punto - _centro_joystick).limit_length(RADIO_JOYSTICK)
	var v := _punta / RADIO_JOYSTICK
	_eje("mover_derecha", "mover_izquierda", v.x)
	_eje("mover_abajo", "mover_arriba", v.y)
	lienzo.queue_redraw()


func _eje(positiva: String, negativa: String, valor: float) -> void:
	if valor > 0.2:
		Input.action_press(positiva, valor)
		Input.action_release(negativa)
	elif valor < -0.2:
		Input.action_press(negativa, -valor)
		Input.action_release(positiva)
	else:
		Input.action_release(positiva)
		Input.action_release(negativa)


func posicion_boton(relativa: Vector2, tam: Vector2) -> Vector2:
	return tam - Vector2(MARGEN, MARGEN) + relativa * RADIO_BOTON


func _dibujar() -> void:
	var tam := lienzo.size
	var fuente := ThemeDB.fallback_font
	var centro := _centro_joystick if _dedo_joystick >= 0 else Vector2(MARGEN + RADIO_JOYSTICK, tam.y - MARGEN - RADIO_JOYSTICK)
	lienzo.draw_circle(centro, RADIO_JOYSTICK, COLOR_BASE)
	lienzo.draw_circle(centro + _punta, RADIO_JOYSTICK * 0.4, COLOR_PULSADO)
	for b in BOTONES:
		var p := posicion_boton(b[2], tam)
		var pulsado: bool = b[0] in _dedos_en_boton.values()
		lienzo.draw_circle(p, RADIO_BOTON, COLOR_PULSADO if pulsado else COLOR_BASE)
		lienzo.draw_string(fuente, p + Vector2(-RADIO_BOTON, 6), b[1], HORIZONTAL_ALIGNMENT_CENTER, RADIO_BOTON * 2, 15, COLOR_TEXTO)
