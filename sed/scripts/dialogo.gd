class_name Dialogo
extends VBoxContainer
## Escena con diálogo: enseña los golpes del guion uno a uno, con el texto apareciendo poco a
## poco. Los párrafos ya leídos quedan arriba, más apagados, como en un libro.
##
## Avanzar (Intro, Espacio, clic o A): si el texto aún está apareciendo, lo completa; si no,
## pasa al siguiente. Saltar (Esc o B): enseña todo lo que falta de golpe.
## Al enseñar el último golpe completo emite `terminado`, y la pantalla pone sus botones.
## Retratos: pendientes del arte final.

signal terminado

const OPACIDAD_LEIDO := 0.6

var golpes: Array[Dictionary] = []
var indice := -1 # golpe que se está enseñando
var acabado := false
var _etiqueta: Label # la del golpe actual
var _letras := 0.0
var _esperando := false # negro o silencio en curso: no se avanza a mano
var _negro: ColorRect
var _tween: Tween
var _pista: Label


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Pantalla en negro por encima de todo.
	var capa := CanvasLayer.new()
	capa.layer = 10
	add_child(capa)
	_negro = ColorRect.new()
	_negro.color = Color.BLACK
	_negro.modulate.a = 0.0
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(_negro)
	_pista = Label.new()
	_pista.text = "Intro / clic: avanzar · Esc: saltar"
	_pista.add_theme_font_size_override("font_size", 13)
	_pista.add_theme_color_override("font_color", Paleta.DETALLES)
	_pista.modulate.a = 0.6
	add_child(_pista)


## Empieza la escena. Si no hay golpes, termina enseguida.
func empezar(p_golpes: Array[Dictionary]) -> void:
	golpes = p_golpes
	indice = -1
	acabado = false
	_siguiente()


func _process(delta: float) -> void:
	if _etiqueta == null or _etiqueta.visible_ratio >= 1.0:
		return
	_letras += delta * Config.DIALOGO_LETRAS_POR_S
	_etiqueta.visible_characters = int(_letras)
	if _etiqueta.visible_ratio >= 1.0:
		_texto_completo()


func _input(evento: InputEvent) -> void:
	if acabado:
		return
	var clic: bool = evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT
	if evento.is_action_pressed("ui_cancel"):
		saltar()
	elif clic or evento.is_action_pressed("ui_accept"):
		avanzar()
	else:
		return
	get_viewport().set_input_as_handled()


func avanzar() -> void:
	if acabado or _esperando:
		return
	if _etiqueta != null and _etiqueta.visible_ratio < 1.0:
		_etiqueta.visible_ratio = 1.0
		_texto_completo()
	else:
		_siguiente()


## Enseña de golpe todo lo que falta (sin negros ni silencios) y termina.
func saltar() -> void:
	if acabado:
		return
	if _tween:
		_tween.kill()
	_negro.modulate.a = 0.0
	_esperando = false
	if _etiqueta != null:
		_etiqueta.visible_ratio = 1.0
	for i in range(indice + 1, golpes.size()):
		var e := _poner(golpes[i])
		if e:
			e.visible_ratio = 1.0
	indice = golpes.size() - 1
	_terminar()


func _siguiente() -> void:
	indice += 1
	if indice >= golpes.size():
		_terminar()
		return
	var g: Dictionary = golpes[indice]
	match g.tipo:
		"negro":
			_esperar(Config.DIALOGO_NEGRO, true)
		"silencio":
			_esperar(Config.DIALOGO_SILENCIO, false)
		_:
			_etiqueta = _poner(g)
			_letras = 0.0
			_etiqueta.visible_characters = 0
			_bajar()


## Pausa que avanza sola. Con `negro`, la pantalla se funde a negro y vuelve.
func _esperar(segundos: float, negro: bool) -> void:
	_esperando = true
	_tween = create_tween()
	if negro:
		_tween.tween_property(_negro, "modulate:a", 1.0, Config.DIALOGO_FUNDIDO)
	_tween.tween_interval(segundos)
	if negro:
		_tween.tween_property(_negro, "modulate:a", 0.0, Config.DIALOGO_FUNDIDO)
	_tween.tween_callback(func() -> void:
		_esperando = false
		_siguiente())


## Añade la etiqueta de un golpe con su color y apaga las anteriores.
func _poner(g: Dictionary) -> Label:
	if not g.tipo in ["narracion", "dialogo", "ahora", "otro_yuu"]:
		return null
	if _etiqueta != null:
		_etiqueta.modulate.a = OPACIDAD_LEIDO
	var e := Label.new()
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.custom_minimum_size = Vector2(Pantalla.ANCHO_COLUMNA, 0)
	match g.tipo:
		"narracion":
			e.text = g.texto
			_estilo(e, Paleta.DETALLES, 18)
		"dialogo":
			e.text = g.texto
			_estilo(e, Paleta.BLANCO_HUESO, 19)
		"ahora":
			e.text = "Mika, ahora: " + g.texto
			_estilo(e, Paleta.TURQUESA, 19)
		"otro_yuu":
			e.text = "El otro Yuu: " + g.texto
			_estilo(e, Paleta.ROJO, 19)
	add_child(e)
	move_child(_pista, -1)
	_etiqueta = e
	return e


func _estilo(e: Label, color: Color, tamano: int) -> void:
	e.add_theme_color_override("font_color", color)
	e.add_theme_font_size_override("font_size", tamano)


func _texto_completo() -> void:
	if indice >= golpes.size() - 1:
		_terminar()


func _terminar() -> void:
	if acabado:
		return
	acabado = true
	_pista.visible = false
	set_process(false)
	terminado.emit()


## Lleva el desplazamiento de la pantalla hasta abajo, para que se vea el párrafo nuevo.
func _bajar() -> void:
	var desplazable := _desplazable()
	if desplazable == null:
		return
	await get_tree().process_frame
	if is_instance_valid(desplazable):
		desplazable.scroll_vertical = int(desplazable.get_v_scroll_bar().max_value)


func _desplazable() -> ScrollContainer:
	var nodo := get_parent()
	while nodo != null and not nodo is ScrollContainer:
		nodo = nodo.get_parent()
	return nodo
