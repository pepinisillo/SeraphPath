extends Pantalla
## Pantalla de título: empezar una expedición, releer los recuerdos ganados o salir.


func construir() -> void:
	titulo("Sed", Paleta.ROJO, 64)
	texto("Fan juego de Owari no Seraph · La ruta de Mika", Paleta.BLANCO_HUESO, 20)
	texto("Gratuito y sin fines de lucro. Arte y música propios.", Paleta.DETALLES, 14)
	espacio(24)
	boton("Nueva expedición", _empezar)
	var n := expedicion.recuerdos.size()
	boton("Recuerdos (%d/%d)" % [n, EstadoExpedicion.TOTAL_RECUERDOS], _recuerdos, n > 0)
	boton("Salir", get_tree().quit)


func _empezar() -> void:
	expedicion.empezar()


func _recuerdos() -> void:
	get_tree().change_scene_to_file(EstadoExpedicion.ESCENA_RECUERDO)
