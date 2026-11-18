extends Pantalla
## Escena del guion entre paradas (entrada de la Prueba de la sed, escena del fondo, salidas,
## eventos…). La pide la expedición con mostrar_escena(); al terminar, sigue adonde ella diga.

var dialogo: Dialogo


func construir() -> void:
	titulo(expedicion.escena_titulo, Paleta.BLANCO_HUESO, 30)
	dialogo = Dialogo.new()
	add_child(dialogo)
	dialogo.terminado.connect(expedicion.terminar_escena)
	dialogo.empezar(Guion.segun_humanidad(expedicion.escena_golpes, expedicion.humanidad))
