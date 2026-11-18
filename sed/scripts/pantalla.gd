class_name Pantalla
extends Control
## Base de las pantallas fuera de los mapas (título, ruta, evento, refugio, recuerdo, final):
## fondo, una columna centrada y ayudas para títulos, textos y botones con la paleta del juego.
## Cada pantalla rellena la columna en construir(); para cambiar de contenido, llama a rehacer().

const ANCHO_COLUMNA := 680.0
const COLOR_FONDO := Color(0.03, 0.035, 0.05)

var columna: VBoxContainer
## La expedición en curso (el autoload).
var expedicion: EstadoExpedicion:
	get:
		return EstadoExpedicion.actual()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var fondo := ColorRect.new()
	fondo.color = COLOR_FONDO
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var desplazable := ScrollContainer.new()
	desplazable.set_anchors_preset(Control.PRESET_FULL_RECT)
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(desplazable)
	var centro := CenterContainer.new()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazable.add_child(centro)
	columna = VBoxContainer.new()
	columna.custom_minimum_size = Vector2(ANCHO_COLUMNA, 0)
	columna.add_theme_constant_override("separation", 12)
	centro.add_child(columna)
	rehacer()


## Vacía la columna, la vuelve a construir y da el foco al primer botón activo.
func rehacer() -> void:
	for hijo in columna.get_children():
		columna.remove_child(hijo)
		hijo.queue_free()
	construir()
	for hijo in columna.find_children("*", "Button", true, false):
		if not hijo.disabled:
			hijo.call_deferred("grab_focus")
			break


func construir() -> void:
	pass


func titulo(texto_titulo: String, color := Paleta.BLANCO_HUESO, tamano := 36) -> Label:
	return texto(texto_titulo, color, tamano)


func texto(contenido: String, color := Paleta.DETALLES, tamano := 18) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = contenido
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.custom_minimum_size = Vector2(ANCHO_COLUMNA, 0)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	columna.add_child(etiqueta)
	return etiqueta


func boton(contenido: String, accion: Callable, activo := true) -> Button:
	var b := Button.new()
	b.text = contenido
	b.disabled = not activo
	b.custom_minimum_size = Vector2(ANCHO_COLUMNA, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(accion)
	columna.add_child(b)
	return b


func espacio(alto := 12.0) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, alto)
	columna.add_child(c)


## Una línea con lo que Mika lleva encima en la expedición.
func estado_expedicion() -> void:
	var e := expedicion
	texto("Vida %d/%d · Sed %d · Humanidad %d/%d · Viales %d" % [e.vida, e.vida_max, e.sed, e.humanidad, Config.HUMANIDAD_INICIAL, e.viales], Paleta.BLANCO_HUESO, 16)
	if not e.mejoras.is_empty():
		var nombres := PackedStringArray()
		for id in e.mejoras:
			nombres.append(Mejoras.nombre(id))
		texto("Sangre: " + " · ".join(nombres), Paleta.ROJO, 16)
	if not e.filos.is_empty():
		var de_filos := PackedStringArray()
		for id in e.filos:
			de_filos.append(Filos.nombre(id))
		texto("Filos: " + " · ".join(de_filos), Paleta.BLANCO_HUESO, 16)
