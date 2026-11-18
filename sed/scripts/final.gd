extends Pantalla
## Final de una expedición: Mika cayó (final «Caído», con su escena del guion) o escapó de
## Sanguinem tras el jefe de la zona 1, donde termina, por ahora, el juego.

var dialogo: Dialogo
var _escena_vista := false


func construir() -> void:
	var e := expedicion
	if e.activa and e.zona_terminada():
		titulo("Fin de la zona %d" % e.zona, Paleta.TURQUESA)
		texto("Mika dejó atrás %s. Las zonas siguientes todavía no existen: aquí termina, por ahora, la expedición." % e.datos_zona().nombre, Paleta.BLANCO_HUESO)
		espacio()
		estado_expedicion()
	else:
		if not _escena_vista:
			_escena_vista = true
			var golpes := e.escena_caido()
			if not golpes.is_empty():
				dialogo = Dialogo.new()
				add_child(dialogo)
				dialogo.terminado.connect(rehacer)
				dialogo.empezar(golpes)
				return
		titulo("Caído", Paleta.ROJO)
		texto("Mika cae antes de llegar. Krul lo recoge, y despierta en Sanguinem con los recuerdos ganados.", Paleta.BLANCO_HUESO)
	espacio()
	texto("Recuerdos: %d/%d" % [e.recuerdos.size(), e.TOTAL_RECUERDOS], Paleta.TURQUESA, 16)
	boton("Volver al título", e.volver_al_titulo)
