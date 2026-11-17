extends Pantalla
## Final de una expedición: Mika cayó, o llegó al jefe de la zona 1 (donde termina, por ahora, el juego).


func construir() -> void:
	var e := expedicion
	if e.activa and e.parada_actual() == "jefe":
		titulo("Fin de la zona 1", Paleta.TURQUESA)
		texto("Ferid Bathory te espera al final de Sanguinem. El jefe y las zonas 2 y 3 todavía no existen: aquí termina, por ahora, la expedición.", Paleta.BLANCO_HUESO)
		espacio()
		estado_expedicion()
	else:
		titulo("Caído", Paleta.ROJO)
		texto("Mika cae antes de llegar. Krul lo recoge, y despierta en Sanguinem con los recuerdos ganados.", Paleta.BLANCO_HUESO)
		texto("«Yuu sigue ahí arriba.»", Paleta.TURQUESA, 22)
	espacio()
	texto("Recuerdos: %d/%d" % [e.recuerdos.size(), e.TOTAL_RECUERDOS], Paleta.TURQUESA, 16)
	boton("Volver al título", e.volver_al_titulo)
