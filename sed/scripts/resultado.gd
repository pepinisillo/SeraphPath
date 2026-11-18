class_name Resultado
extends CanvasLayer
## Pantalla de resultado de un mapa: si Mika salió o cayó, el objetivo opcional,
## lo que pasó por el camino y cómo queda Mika. Se muestra con el juego en pausa.

const COLOR_TENUE := Color("6c7a91")

var exito := false
var boton_repetir: Button
var boton_salir: Button


func mostrar(mapa: Mapa, p_exito: bool) -> void:
	exito = p_exito
	var e := mapa.estadisticas
	var mika := mapa.mika

	var fondo := ColorRect.new()
	fondo.color = Color(0.03, 0.035, 0.05, 0.88)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.05, 0.06, 0.09, 0.97)
	estilo.border_color = Paleta.TURQUESA if exito else Paleta.ROJO
	estilo.set_border_width_all(2)
	estilo.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	panel.add_child(caja)

	if mapa.prueba_de_la_sed:
		var textos := _textos_prueba(mapa.motivo)
		_etiqueta(caja, textos[0], 32, Paleta.TURQUESA if exito else Paleta.ROJO)
		_etiqueta(caja, textos[1], 16, Paleta.BLANCO_HUESO)
		if exito and EstadoExpedicion.en_curso():
			var n := EstadoExpedicion.actual().recuerdo_nuevo
			var texto := "Ya tenías todos los recuerdos."
			if n > 0:
				texto = "Recuerdo %d: %s" % [n, EstadoExpedicion.datos_recuerdos()[n - 1].titulo]
			_etiqueta(caja, texto, 18, Paleta.TURQUESA)
	else:
		_etiqueta(caja, "Mapa superado" if exito else "Mika ha caído", 32, Paleta.TURQUESA if exito else Paleta.ROJO)
		_etiqueta(caja, mapa.nombre, 18, COLOR_TENUE)

	if mapa.texto_objetivo() != "":
		var cumplido := mapa.objetivo_cumplido()
		var texto := "Objetivo opcional: %s · %s" % [mapa.texto_objetivo(), "conseguido" if cumplido else "no conseguido"]
		_etiqueta(caja, texto, 16, Paleta.TURQUESA if cumplido else COLOR_TENUE)

	var tabla := GridContainer.new()
	tabla.columns = 2
	tabla.add_theme_constant_override("h_separation", 40)
	tabla.add_theme_constant_override("v_separation", 6)
	var tiempo := "%d:%02d" % [int(e.tiempo) / 60, int(e.tiempo) % 60]
	var filas := [["Tiempo", tiempo]] if mapa.prueba_de_la_sed else [
		["Tiempo", tiempo],
		["Veces que sonó la alarma", str(e.alarmas)],
		["Derribados en silencio", str(e.derribados_en_silencio)],
		["Derribados con el Tajo", str(e.derribados_con_tajo)],
		["Cuerpos descubiertos", str(e.cuerpos_descubiertos)],
		["Sangre humana bebida", str(e.sangre_bebida)],
		["Viales recogidos", str(e.viales_recogidos)],
	]
	# Solo si pasaron: lo que depende de los vampiros, los Jinetes y los hechiceros.
	if not mapa.prueba_de_la_sed:
		for extra in [["Veces que te delató un vampiro", e.delaciones], ["Soldados cazados por un Jinete", e.cazados_por_jinetes], ["Talismanes pisados", e.talismanes_pisados]]:
			if extra[1] > 0:
				filas.append([extra[0], str(extra[1])])
	for fila in filas:
		_etiqueta(tabla, fila[0], 16, Paleta.DETALLES)
		_etiqueta(tabla, fila[1], 16, Paleta.BLANCO_HUESO).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caja.add_child(tabla)

	var estado := "Vida %d/%d · Sed %d · Humanidad %d/%d" % [mika.vida, mika.vida_max, mika.sed, mika.humanidad, Config.HUMANIDAD_INICIAL]
	_etiqueta(caja, estado, 16, Paleta.BLANCO_HUESO)
	if not mika.mejoras.is_empty():
		var nombres := PackedStringArray()
		for id in mika.mejoras:
			nombres.append(Mejoras.nombre(id))
		_etiqueta(caja, "Sangre: " + " · ".join(nombres), 16, Paleta.ROJO)
	if not mika.filos.is_empty():
		_etiqueta(caja, "Filos: " + " · ".join(mika.filos.map(func(f): return Filos.nombre(f))), 16, Paleta.BLANCO_HUESO)

	var logros := _logros(e)
	if exito and not mapa.prueba_de_la_sed and not logros.is_empty():
		_etiqueta(caja, " · ".join(logros), 18, Paleta.TURQUESA)

	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 16)
	if EstadoExpedicion.en_curso():
		# En una expedición no se repite: se sigue adelante, o se acaba si Mika cayó.
		var expedicion := EstadoExpedicion.actual()
		var sigue := exito or mapa.prueba_de_la_sed
		boton_repetir = _boton(botones, "Continuar" if sigue else "Fin de la expedición", expedicion.completar_parada if sigue else expedicion.caer)
		boton_salir = _boton(botones, "Abandonar la expedición", expedicion.volver_al_titulo)
	else:
		var repetir := "Jugar de nuevo" if exito else "Volver a intentarlo"
		if mapa.prueba_de_la_sed:
			repetir = "Repetir la prueba"
		boton_repetir = _boton(botones, repetir, _repetir)
		boton_salir = _boton(botones, "Salir del juego", _salir)
	caja.add_child(botones)
	boton_repetir.grab_focus()


## Título y explicación de cada final de la Prueba de la sed.
func _textos_prueba(motivo: String) -> Array:
	match motivo:
		"cedida":
			return ["Cediste a la sed", "Bebiste de un eco: sed a 0 y una mejora, a cambio de 1 de Humanidad."]
		"fallida":
			return ["La sed te venció", "Despiertas con la sed en %d. El siguiente mapa empezará en Alarma." % Config.PRUEBA_SED_FALLIDA]
	return ["Prueba superada", "Llegaste hasta Yuu sin beber. Ganas un recuerdo."]


## Menciones por jugar en sigilo y sin ceder a la sangre.
func _logros(e: Estadisticas) -> PackedStringArray:
	var logros := PackedStringArray()
	if e.alarmas == 0 and e.cuerpos_descubiertos == 0:
		logros.append("Sin dejar rastro")
	elif e.alarmas == 0:
		logros.append("Nadie dio la alarma")
	if e.sangre_bebida == 0:
		logros.append("Sin beber sangre humana")
	return logros


func _etiqueta(padre: Control, texto: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	padre.add_child(etiqueta)
	return etiqueta


func _boton(padre: Control, texto: String, accion: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(200, 44)
	boton.pressed.connect(accion)
	padre.add_child(boton)
	return boton


func _repetir() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _salir() -> void:
	get_tree().quit()
