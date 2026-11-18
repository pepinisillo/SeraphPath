class_name Dialogo
extends CanvasLayer
## Escena con diálogo al estilo de Hades (novela visual): un fondo (un paisaje o, si se juega
## encima de un mapa, el propio mapa oscurecido), los retratos de los personajes delante y abajo
## un cuadro con el nombre de quien habla y el texto, que aparece poco a poco.
##
## Avanzar (Intro, Espacio, clic o A): si el texto aún está apareciendo, lo completa; si no,
## pasa al siguiente. Saltar (Esc o B): termina la escena.
## Termina al avanzar tras la última línea (o al saltar): emite `terminado` y se oculta.
##
## Quién habla lo dice cada golpe (`habla`, ver Guion.asignar_hablantes). Arte provisional: los
## retratos son siluetas de color con el nombre; el arte final solo cambia _dibujar_retrato.

signal terminado
## El jugador mantuvo Beber en un golpe «beber» (si no era obligatorio, podía no hacerlo).
signal bebio

const ALTO_CUADRO := 190.0
const MARGEN := 32.0
const ANCHO_RETRATO := 220.0
const ALTO_RETRATO := 420.0
const COLOR_CUADRO := Color(0.03, 0.04, 0.07, 0.92)
const COLOR_FONDO_ARRIBA := Color("1a2233")
const COLOR_FONDO_ABAJO := Color("07090e")
const OPACIDAD_CALLADO := 0.35

## Colores provisionales de cada personaje (los del retrato y su nombre).
const COLORES := {
	"Mika": Paleta.BLANCO_HUESO, "Mika, ahora": Paleta.TURQUESA, "Yuu": Paleta.CALMA,
	"El otro Yuu": Paleta.ROJO, "Krul": Paleta.VAMPIROS, "Ferid": Paleta.VAMPIROS,
	"Crowley": Paleta.VAMPIROS, "Lacus": Paleta.VAMPIROS, "René": Paleta.VAMPIROS,
	"La doncella": Paleta.VAMPIROS, "Akane": Paleta.CALMA, "Guren": Paleta.SOLDADOS,
	"Shinoa": Paleta.SOLDADOS, "Mahiru": Paleta.AMBAR,
}

## Sobre un mapa: el fondo es el propio mapa, oscurecido.
var sobre_mapa := false

var golpes: Array[Dictionary] = []
var indice := -1 # golpe que se está enseñando
var acabado := false
var _etiqueta: Label # texto del golpe actual
var _nombre: Label
var _letras := 0.0
var _esperando := false # negro o silencio en curso: no se avanza a mano
var _negro: ColorRect
var _tween: Tween
var _pista: Label
var _retratos := {} # nombre -> Control
var _raiz: Control
var _gris: ColorRect # quita color a la escena (sin_color / color)
var esperando_beber := false
var beber_obligatorio := false
var bebido := 0.0 # s que lleva mantenido Beber


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS # también con el juego en pausa (escenas sobre un mapa)
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_poner_fondo()
	var cuadro := Panel.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COLOR_CUADRO
	estilo.border_color = Paleta.DETALLES
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(6)
	cuadro.add_theme_stylebox_override("panel", estilo)
	cuadro.anchor_left = 0.0
	cuadro.anchor_right = 1.0
	cuadro.anchor_top = 1.0
	cuadro.anchor_bottom = 1.0
	cuadro.offset_left = MARGEN
	cuadro.offset_right = -MARGEN
	cuadro.offset_top = -ALTO_CUADRO - MARGEN
	cuadro.offset_bottom = -MARGEN
	_raiz.add_child(cuadro)
	_nombre = Label.new()
	_nombre.position = Vector2(24, -18)
	_nombre.add_theme_font_size_override("font_size", 22)
	cuadro.add_child(_nombre)
	_etiqueta = Label.new()
	_etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etiqueta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_etiqueta.offset_left = 28
	_etiqueta.offset_right = -28
	_etiqueta.offset_top = 26
	_etiqueta.offset_bottom = -20
	cuadro.add_child(_etiqueta)
	_pista = Label.new()
	_pista.text = "Intro / clic: avanzar · Esc: saltar"
	_pista.add_theme_font_size_override("font_size", 13)
	_pista.add_theme_color_override("font_color", Paleta.DETALLES)
	_pista.anchor_left = 1.0
	_pista.anchor_right = 1.0
	_pista.anchor_top = 1.0
	_pista.anchor_bottom = 1.0
	_pista.offset_left = -300
	_pista.offset_top = -26
	_pista.offset_right = -16
	_pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cuadro.add_child(_pista)
	_gris = ColorRect.new()
	_gris.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://recursos/gris.gdshader")
	material.set_shader_parameter("gris", 0.0)
	_gris.material = material
	_gris.visible = false
	_raiz.add_child(_gris)
	_negro = ColorRect.new()
	_negro.color = Color.BLACK
	_negro.modulate.a = 0.0
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(_negro)


func _poner_fondo() -> void:
	if sobre_mapa:
		var velo := ColorRect.new()
		velo.color = Color(0.0, 0.0, 0.02, 0.55)
		velo.set_anchors_preset(Control.PRESET_FULL_RECT)
		velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_raiz.add_child(velo)
		return
	# Paisaje provisional: un degradado frío de arriba abajo.
	var degradado := Gradient.new()
	degradado.set_color(0, COLOR_FONDO_ARRIBA)
	degradado.set_color(1, COLOR_FONDO_ABAJO)
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.fill_from = Vector2(0, 0)
	textura.fill_to = Vector2(0, 1)
	var fondo := TextureRect.new()
	fondo.texture = textura
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fondo)


## Empieza la escena. Si no hay golpes, termina enseguida.
func empezar(p_golpes: Array[Dictionary]) -> void:
	golpes = Guion.asignar_hablantes(p_golpes.filter(func(g): return g.tipo in Guion.TIPOS_VISIBLES))
	indice = -1
	acabado = false
	_crear_retratos()
	_siguiente()


func _process(delta: float) -> void:
	if esperando_beber:
		bebido = bebido + delta if Input.is_action_pressed("beber") else maxf(0.0, bebido - delta)
		var tecla := Opciones.nombre_tecla("beber")
		var hecho := roundi(100.0 * bebido / Config.BEBER_DURACION)
		_pista.text = ("Mantén %s (B) para beber  %d%%" % [tecla, hecho]) if beber_obligatorio else ("Mantén %s (B) para beber · Intro: seguir  %d%%" % [tecla, hecho])
		if bebido >= Config.BEBER_DURACION:
			beber_ya()
		return
	if acabado or _esperando or _etiqueta.visible_ratio >= 1.0:
		return
	_letras += delta * Config.DIALOGO_LETRAS_POR_S
	_etiqueta.visible_characters = int(_letras)


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
	if esperando_beber:
		if not beber_obligatorio:
			esperando_beber = false # sigue sin beber
			_pista.text = "Intro / clic: avanzar · Esc: saltar"
			_siguiente()
		return
	if _etiqueta.visible_ratio < 1.0:
		_etiqueta.visible_ratio = 1.0
	else:
		_siguiente()


## Termina la escena de golpe. Si está esperando a que beba y es obligatorio, no se salta.
func saltar() -> void:
	if acabado or (esperando_beber and beber_obligatorio):
		return
	if _tween:
		_tween.kill()
	_negro.modulate.a = 0.0
	_esperando = false
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
			_etiqueta.text = ""
			_nombre.text = ""
			_destacar("")
			_esperar(Config.DIALOGO_SILENCIO, false)
		"beber":
			esperando_beber = true
			beber_obligatorio = g.get("obligatorio", false)
			bebido = 0.0
		"sin_color":
			_gris.visible = true
			_gris.material.set_shader_parameter("gris", Config.DIALOGO_GRIS)
			_siguiente()
		"color":
			_esperando = true
			_tween = create_tween()
			_tween.tween_method(func(v: float) -> void: _gris.material.set_shader_parameter("gris", v), Config.DIALOGO_GRIS, 0.0, Config.DIALOGO_COLOR_VUELVE)
			_tween.tween_callback(func() -> void:
				_esperando = false
				_siguiente())
		_:
			_mostrar(g)


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


## Para la escena sin avisar (quien la puso va a enseñar otra cosa).
func detener() -> void:
	acabado = true
	esperando_beber = false
	if _tween:
		_tween.kill()
	set_process(false)
	visible = false


## Completa el trago (lo llama el botón mantenido; las pruebas, directamente).
func beber_ya() -> void:
	if not esperando_beber:
		return
	esperando_beber = false
	_pista.text = "Intro / clic: avanzar · Esc: saltar"
	bebio.emit()
	if not acabado:
		_siguiente()


func _mostrar(g: Dictionary) -> void:
	var habla: String = g.get("habla", "")
	var color: Color = COLORES.get(habla, Paleta.BLANCO_HUESO)
	_nombre.text = habla
	_nombre.add_theme_color_override("font_color", color)
	_etiqueta.text = g.texto
	var tamano := 21
	match g.tipo:
		"narracion":
			_etiqueta.add_theme_color_override("font_color", Paleta.DETALLES)
			tamano = 19
		"ahora":
			_etiqueta.add_theme_color_override("font_color", Paleta.TURQUESA)
		"otro_yuu":
			_etiqueta.add_theme_color_override("font_color", Paleta.ROJO)
		"final":
			_etiqueta.add_theme_color_override("font_color", Paleta.TURQUESA)
			tamano = 24
		_:
			_etiqueta.add_theme_color_override("font_color", Paleta.BLANCO_HUESO)
	_etiqueta.add_theme_font_size_override("font_size", tamano)
	_letras = 0.0
	_etiqueta.visible_characters = 0
	_destacar(habla)


func _terminar() -> void:
	if acabado:
		return
	acabado = true
	_etiqueta.visible_ratio = 1.0
	set_process(false)
	visible = false
	terminado.emit()


# --- Retratos ---

## Un retrato por personaje que habla en la escena: Mika a la izquierda, los demás a la derecha.
func _crear_retratos() -> void:
	for r in _retratos.values():
		r.queue_free()
	_retratos.clear()
	var nombres: Array[String] = []
	for g in golpes:
		var n: String = g.get("habla", "")
		if n == "Mika, ahora":
			n = "Mika"
		if n != "" and not n in nombres:
			nombres.append(n)
	var derecha := 0
	for n in nombres:
		var r := Control.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.size = Vector2(ANCHO_RETRATO, ALTO_RETRATO)
		var a_la_izquierda := n == "Mika"
		r.anchor_left = 0.0 if a_la_izquierda else 1.0
		r.anchor_right = r.anchor_left
		r.anchor_top = 1.0
		r.anchor_bottom = 1.0
		var x := MARGEN + 40.0 if a_la_izquierda else -MARGEN - 40.0 - ANCHO_RETRATO * (derecha + 1) - 30.0 * derecha
		if not a_la_izquierda:
			derecha += 1
		r.offset_left = x
		r.offset_right = x + ANCHO_RETRATO
		r.offset_top = -ALTO_CUADRO - MARGEN - ALTO_RETRATO + 40.0
		r.offset_bottom = -ALTO_CUADRO - MARGEN + 40.0
		r.draw.connect(_dibujar_retrato.bind(r, n))
		_raiz.add_child(r)
		_raiz.move_child(r, 1) # delante del fondo, detrás del cuadro
		_retratos[n] = r


## Quien habla, a plena luz y un poco más arriba; los demás, apagados.
func _destacar(habla: String) -> void:
	if habla == "Mika, ahora":
		habla = "Mika"
	for n in _retratos:
		var r: Control = _retratos[n]
		var activo: bool = n == habla
		r.modulate.a = 1.0 if activo else OPACIDAD_CALLADO
		r.offset_top = -ALTO_CUADRO - MARGEN - ALTO_RETRATO + (20.0 if activo else 40.0)
		r.offset_bottom = r.offset_top + ALTO_RETRATO


## Arte provisional: una cápsula de color con el nombre encima.
func _dibujar_retrato(r: Control, nombre: String) -> void:
	var color: Color = COLORES.get(nombre, Paleta.DETALLES)
	var ancho := ANCHO_RETRATO * 0.62
	var x := (ANCHO_RETRATO - ancho) / 2.0
	var cabeza := ancho * 0.5
	r.draw_circle(Vector2(ANCHO_RETRATO / 2.0, cabeza + 10.0), cabeza * 0.75, Color(color, 0.9))
	var cuerpo := Rect2(x, cabeza * 2.0 + 10.0, ancho, ALTO_RETRATO - cabeza * 2.0 - 10.0)
	r.draw_rect(cuerpo, Color(color, 0.75))
	r.draw_rect(cuerpo, Paleta.DETALLES, false, 2.0)
