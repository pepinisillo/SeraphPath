extends Pantalla
## Pantalla de opciones (desde el título): volumen y pantalla completa.


func construir() -> void:
	titulo("Opciones", Paleta.BLANCO_HUESO, 36)
	espacio()
	texto("Volumen: %d %%" % Opciones.volumen, Paleta.BLANCO_HUESO, 20)
	boton("Más volumen", _volumen.bind(Opciones.PASO_VOLUMEN), Opciones.volumen < 100)
	boton("Menos volumen", _volumen.bind(-Opciones.PASO_VOLUMEN), Opciones.volumen > 0)
	espacio()
	boton("Pantalla completa: %s" % ("sí" if Opciones.pantalla_completa else "no"), _pantalla)
	espacio()
	boton("Volver", expedicion.volver_al_titulo)


func _volumen(cuanto: int) -> void:
	Opciones.cambiar_volumen(cuanto)
	rehacer()


func _pantalla() -> void:
	Opciones.cambiar_pantalla_completa()
	rehacer()
