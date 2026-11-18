class_name MenuPausa
extends CanvasLayer
## Menú de pausa de los mapas (Esc o Start): seguir, ver los controles o abandonar. En una
## expedición, abandonar en mitad de una parada cuenta como caída (como cerrar el juego).
## No se abre si el juego ya está en pausa por otra cosa (resultado, mejora, una escena).

const CONTROLES := [
	["Moverse", "WASD o flechas", "Stick izquierdo"],
	["Tajo", "J o clic izquierdo", "X"],
	["Golpe silencioso", "K o clic derecho", "Y"],
	["Impulso", "Espacio", "A"],
	["Beber (mantener)", "E", "B"],
	["Vial de Krul", "Q", "LB"],
	["Sentidos", "R", "RB"],
	["Espada, bebe mi sangre", "F", "Gatillo derecho"],
	["Pausa", "Esc", "Start"],
]

var mapa: Mapa
var abierto := false
var _caja: VBoxContainer
var _fondo: ColorRect


func iniciar(p_mapa: Mapa) -> void:
	mapa = p_mapa
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fondo = ColorRect.new()
	_fondo.color = Color(0.02, 0.03, 0.05, 0.8)
	_fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fondo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fondo.add_child(centro)
	_caja = VBoxContainer.new()
	_caja.custom_minimum_size = Vector2(520, 0)
	_caja.add_theme_constant_override("separation", 10)
	centro.add_child(_caja)
	visible = false


func _unhandled_input(evento: InputEvent) -> void:
	if not evento.is_action_pressed("pausa"):
		return
	if abierto:
		cerrar()
	elif not get_tree().paused and mapa and not mapa.terminado:
		abrir()
	get_viewport().set_input_as_handled()


func abrir(con_controles := false) -> void:
	abierto = true
	visible = true
	get_tree().paused = true
	for hijo in _caja.get_children():
		hijo.queue_free()
	_etiqueta("Pausa", 34, Paleta.BLANCO_HUESO)
	if con_controles:
		for fila in CONTROLES:
			_etiqueta("%s: %s · %s" % fila, 16, Paleta.DETALLES)
	_boton("Seguir", cerrar)
	if not con_controles:
		_boton("Controles", abrir.bind(true))
	if EstadoExpedicion.en_curso():
		_boton("Abandonar la expedición (Mika cae)", _abandonar)
	else:
		_boton("Volver al título", _al_titulo)
	for hijo in _caja.get_children():
		if hijo is Button:
			hijo.call_deferred("grab_focus")
			break


func cerrar() -> void:
	abierto = false
	visible = false
	get_tree().paused = false


func _abandonar() -> void:
	cerrar()
	EstadoExpedicion.actual().caer()


func _al_titulo() -> void:
	cerrar()
	get_tree().change_scene_to_file(EstadoExpedicion.ESCENA_TITULO)


func _etiqueta(texto: String, tamano: int, color: Color) -> void:
	var e := Label.new()
	e.text = texto
	e.add_theme_font_size_override("font_size", tamano)
	e.add_theme_color_override("font_color", color)
	_caja.add_child(e)


func _boton(texto: String, accion: Callable) -> void:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(520, 44)
	b.pressed.connect(accion)
	_caja.add_child(b)
