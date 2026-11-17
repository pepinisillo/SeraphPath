class_name Hud
extends CanvasLayer
## Interfaz: vida, sed con sus tramos, Humanidad, viales, mejoras de sangre y estado de alerta.
## También muestra la elección de mejora (con el juego en pausa), el Frenesí y la caída de Mika.

const COLOR_TEXTO := Paleta.BLANCO_HUESO
const COLOR_TENUE := Color("6c7a91")
const COLOR_FONDO := Color(0.04, 0.05, 0.08, 0.75)
const COLOR_VIDA := Paleta.CALMA
const COLOR_SED := Paleta.ROJO
const COLOR_SOSPECHA := Paleta.AMBAR
const COLOR_ALARMA := Paleta.ROJO
const ANCHO_BARRA := 220.0
const ALTO_BARRA := 14.0
const MARGEN := 24.0

var mapa: Mapa
var mika: Mika
var _tiempo := 0.0
var _caida := -1.0 # s desde que cayó Mika; < 0 si sigue en pie
var _eleccion: Control = null

@onready var lienzo: Control = $Lienzo


func iniciar(p_mapa: Mapa) -> void:
	mapa = p_mapa
	mika = mapa.mika
	mika.mejora_pendiente.connect(_mostrar_eleccion)
	mika.derrotada.connect(func() -> void: _caida = 0.0)
	lienzo.draw.connect(_dibujar)


func _process(delta: float) -> void:
	_tiempo += delta
	if _caida >= 0.0:
		_caida += delta
	lienzo.queue_redraw()


# --- Elección de mejora de sangre ---

func _mostrar_eleccion(opciones: Array[String]) -> void:
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.05, 0.06, 0.09, 0.95)
	estilo.border_color = COLOR_SED
	estilo.set_border_width_all(2)
	estilo.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", estilo)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	var titulo := Label.new()
	titulo.text = "Bebiste sangre humana. Elige una mejora:"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	for id in opciones:
		var boton := Button.new()
		boton.text = "%s\n%s" % [Mejoras.nombre(id), Mejoras.descripcion(id)]
		boton.custom_minimum_size = Vector2(240, 80)
		boton.pressed.connect(_elegir.bind(id))
		fila.add_child(boton)
	caja.add_child(fila)
	panel.add_child(caja)
	centro.add_child(panel)
	add_child(centro)
	_eleccion = centro
	get_tree().paused = true
	fila.get_child(0).grab_focus()


func _elegir(id: String) -> void:
	mika.elegir_mejora(id)
	_eleccion.queue_free()
	_eleccion = null
	get_tree().paused = false


# --- Dibujo ---

func _dibujar() -> void:
	if mika == null:
		return
	var fuente := ThemeDB.fallback_font
	var tam := lienzo.size

	if mika.sin_control():
		_dibujar_frenesi(fuente, tam)

	# Panel de estado, arriba a la izquierda.
	lienzo.draw_rect(Rect2(MARGEN - 12, MARGEN - 12, ANCHO_BARRA + 24, 150), COLOR_FONDO)
	var y := MARGEN
	_texto(fuente, Vector2(MARGEN, y + 12), "Vida %d/%d" % [mika.vida, mika.vida_max], COLOR_TEXTO)
	y += 18
	_barra(Vector2(MARGEN, y), float(mika.vida) / mika.vida_max, COLOR_VIDA, [])
	y += ALTO_BARRA + 12
	_texto(fuente, Vector2(MARGEN, y + 12), "Sed %d · %s" % [mika.sed, _tramo_sed()], COLOR_TEXTO)
	y += 18
	var marcas := [Config.SED_TRAMO_REGENERA + 1, Config.SED_TRAMO_LENTO, Config.SED_TRAMO_FRENESI]
	_barra(Vector2(MARGEN, y), float(mika.sed) / Config.SED_MAX, COLOR_SED, marcas)
	y += ALTO_BARRA + 12
	_texto(fuente, Vector2(MARGEN, y + 14), "Humanidad", COLOR_TEXTO)
	for i in Config.HUMANIDAD_INICIAL:
		_rombo(Vector2(MARGEN + 118 + i * 24, y + 9), i < mika.humanidad)
	y += 26
	_texto(fuente, Vector2(MARGEN, y + 14), "Viales de Krul: %d" % mika.viales, COLOR_TEXTO)

	# Mejoras de sangre, abajo a la izquierda.
	if not mika.mejoras.is_empty():
		var nombres := PackedStringArray()
		for id in mika.mejoras:
			nombres.append(Mejoras.nombre(id))
		_texto(fuente, Vector2(MARGEN, tam.y - MARGEN), "Sangre: " + " · ".join(nombres), COLOR_SED)

	# Estado de alerta, arriba a la derecha.
	var estado := _estado_alerta()
	lienzo.draw_string(fuente, Vector2(tam.x - MARGEN - 300, MARGEN + 20), estado[0], HORIZONTAL_ALIGNMENT_RIGHT, 300, 24, estado[1])
	if mapa.alerta.activa:
		lienzo.draw_string(fuente, Vector2(tam.x - MARGEN - 300, MARGEN + 44), "Refuerzos %d/%d" % [mapa.alerta.refuerzos, Config.ALARMA_REFUERZOS_MAX], HORIZONTAL_ALIGNMENT_RIGHT, 300, 16, COLOR_TENUE)

	if _caida >= 0.0:
		lienzo.draw_rect(Rect2(Vector2.ZERO, tam), Color(0, 0, 0, minf(0.7, _caida * 0.6)))
		lienzo.draw_string(fuente, Vector2(0, tam.y / 2.0), "Mika ha caído", HORIZONTAL_ALIGNMENT_CENTER, tam.x, 36, COLOR_TEXTO)


func _dibujar_frenesi(fuente: Font, tam: Vector2) -> void:
	var pulso := 0.35 + 0.2 * sin(_tiempo * 8.0)
	lienzo.draw_rect(Rect2(Vector2.ZERO, tam), Color(COLOR_SED, pulso), false, 24.0)
	lienzo.draw_string(fuente, Vector2(0, MARGEN + 30), "FRENESÍ", HORIZONTAL_ALIGNMENT_CENTER, tam.x, 30, COLOR_SED)


func _tramo_sed() -> String:
	if mika.sed >= Config.SED_TRAMO_FRENESI:
		return "Frenesí"
	if mika.sed >= Config.SED_TRAMO_LENTO:
		return "Sediento"
	if mika.sed > Config.SED_TRAMO_REGENERA:
		return "Estable"
	return "Saciado"


## Peor estado entre los soldados en pie: [texto, color].
func _estado_alerta() -> Array:
	if mapa.alerta.activa:
		return ["ALARMA", COLOR_ALARMA]
	for soldado in mapa.soldados():
		if not soldado.derribado and soldado.estado == Soldado.Estado.SOSPECHA:
			return ["SOSPECHA", COLOR_SOSPECHA]
	return ["OCULTO", COLOR_TENUE]


func _texto(fuente: Font, posicion: Vector2, texto: String, color: Color) -> void:
	lienzo.draw_string(fuente, posicion, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)


func _barra(esquina: Vector2, fraccion: float, color: Color, marcas: Array) -> void:
	lienzo.draw_rect(Rect2(esquina, Vector2(ANCHO_BARRA, ALTO_BARRA)), Color(0, 0, 0, 0.6))
	lienzo.draw_rect(Rect2(esquina, Vector2(ANCHO_BARRA * clampf(fraccion, 0.0, 1.0), ALTO_BARRA)), color)
	for marca in marcas:
		var x: float = esquina.x + ANCHO_BARRA * float(marca) / Config.SED_MAX
		lienzo.draw_line(Vector2(x, esquina.y - 2), Vector2(x, esquina.y + ALTO_BARRA + 2), Color(COLOR_TEXTO, 0.6), 1.0)
	lienzo.draw_rect(Rect2(esquina, Vector2(ANCHO_BARRA, ALTO_BARRA)), Color(COLOR_TEXTO, 0.4), false, 1.0)


func _rombo(centro: Vector2, lleno: bool) -> void:
	var puntos := PackedVector2Array([centro + Vector2(0, -8), centro + Vector2(8, 0), centro + Vector2(0, 8), centro + Vector2(-8, 0)])
	if lleno:
		lienzo.draw_colored_polygon(puntos, COLOR_TEXTO)
	puntos.append(puntos[0])
	lienzo.draw_polyline(puntos, COLOR_TEXTO, 2.0)
