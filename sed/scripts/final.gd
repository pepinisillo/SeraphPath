extends Pantalla
## Final de una expedición. Si Mika supera al jefe de la última zona, el final que corresponde
## según cómo llega (ver EstadoExpedicion.final_alcanzado): «La sangre de Yuu», «En el límite» o
## «Vampiro completo», con su escena del guion. Si cayó por el camino, el final «Caído».
## En «La sangre de Yuu» el jugador tiene que mantener Beber, como toda la partida evitó hacer;
## esta vez no cuesta Humanidad.

var dialogo: Dialogo
var final := "" # nombre del final que se ve
var _escena_vista := false
var _texto_final := ""


func construir() -> void:
	var e := expedicion
	var completo := e.activa and e.zona_terminada()
	if not _escena_vista:
		_escena_vista = true
		var golpes: Array[Dictionary] = []
		if completo:
			final = e.final_alcanzado()
			golpes = Guion.final(final)
			e.marcar_final(final)
		else:
			final = "Caído"
			golpes = e.escena_caido()
		for g in golpes:
			if g.tipo == "final":
				_texto_final = g.texto
		if not golpes.is_empty():
			dialogo = Dialogo.new()
			add_child(dialogo)
			dialogo.terminado.connect(rehacer)
			dialogo.empezar(Guion.segun_humanidad(golpes, e.humanidad))
			return
	if dialogo != null and not dialogo.acabado:
		return
	if completo:
		titulo(final, Paleta.TURQUESA)
		texto("Mika llegó hasta Yuu.", Paleta.BLANCO_HUESO)
		espacio()
		estado_expedicion()
	else:
		titulo("Caído", Paleta.ROJO)
		texto("Mika cae antes de llegar. Krul lo recoge, y despierta en Sanguinem con los recuerdos ganados.", Paleta.BLANCO_HUESO)
	if _texto_final != "":
		espacio()
		texto(_texto_final, Paleta.TURQUESA, 22)
	espacio()
	texto("Recuerdos: %d/%d · Finales vistos: %d/3" % [e.recuerdos.size(), e.TOTAL_RECUERDOS, e.finales_vistos.size()], Paleta.TURQUESA, 16)
	boton("Volver al título", e.volver_al_titulo)
