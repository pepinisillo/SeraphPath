extends Pantalla
## Escena del guion entre paradas (entrada de la Prueba de la sed, escena del fondo, salidas,
## eventos…). La pide la expedición con mostrar_escena(); al terminar, sigue adonde ella diga.
## Si en la escena aparece el botón Beber (el fondo de la zona 3) y Mika bebe, la prueba queda
## cedida y se ve el texto de cedida en lugar del resto.

var dialogo: Dialogo


func construir() -> void:
	titulo(expedicion.escena_titulo, Paleta.BLANCO_HUESO, 30)
	dialogo = Dialogo.new()
	add_child(dialogo)
	dialogo.terminado.connect(expedicion.terminar_escena)
	dialogo.bebio.connect(_al_beber)
	dialogo.empezar(Guion.segun_humanidad(expedicion.escena_golpes, expedicion.humanidad))


func _al_beber() -> void:
	dialogo.terminado.disconnect(expedicion.terminar_escena)
	dialogo.detener()
	dialogo.queue_free()
	expedicion.ceder_en_fondo()
	expedicion.escena_golpes = Guion.prueba_salida(expedicion.zona, "cedida")
	rehacer()
