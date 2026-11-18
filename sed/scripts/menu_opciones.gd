extends Pantalla
## Pantalla de opciones (desde el título): volumen, pantalla completa y teclas.
## Para cambiar una tecla: pulsar su botón y luego la tecla nueva (Esc cancela).

var esperando := "" # acción a la que se le está poniendo tecla


func construir() -> void:
	titulo("Opciones", Paleta.BLANCO_HUESO, 36)
	espacio()
	texto("Volumen: %d %%" % Opciones.volumen, Paleta.BLANCO_HUESO, 20)
	boton("Más volumen", _volumen.bind(Opciones.PASO_VOLUMEN), Opciones.volumen < 100)
	boton("Menos volumen", _volumen.bind(-Opciones.PASO_VOLUMEN), Opciones.volumen > 0)
	espacio()
	boton("Pantalla completa: %s" % ("sí" if Opciones.pantalla_completa else "no"), _pantalla)
	espacio()
	texto("Teclas (las flechas y el mando no cambian)", Paleta.BLANCO_HUESO, 20)
	if esperando != "":
		texto("Pulsa la tecla nueva para «%s». Esc cancela." % _nombre(esperando), Paleta.AMBAR, 16)
	for par in Opciones.ACCIONES:
		boton("%s: %s" % [par[1], Opciones.nombre_tecla(par[0])], _esperar.bind(par[0]), esperando == "")
	boton("Volver a las teclas de siempre", _restaurar, esperando == "")
	espacio()
	boton("Volver", expedicion.volver_al_titulo, esperando == "")


func _input(evento: InputEvent) -> void:
	if esperando == "" or not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	get_viewport().set_input_as_handled()
	var codigo: int = evento.physical_keycode if evento.physical_keycode != 0 else evento.keycode
	if codigo == KEY_ESCAPE and esperando != "pausa":
		esperando = ""
	else:
		Opciones.cambiar_tecla(esperando, codigo)
		esperando = ""
	rehacer()


func _esperar(accion: String) -> void:
	esperando = accion
	rehacer()


func _nombre(accion: String) -> String:
	for par in Opciones.ACCIONES:
		if par[0] == accion:
			return par[1]
	return accion


func _volumen(cuanto: int) -> void:
	Opciones.cambiar_volumen(cuanto)
	rehacer()


func _pantalla() -> void:
	Opciones.cambiar_pantalla_completa()
	rehacer()


func _restaurar() -> void:
	Opciones.restaurar_teclas()
	rehacer()
