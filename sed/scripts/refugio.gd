extends Pantalla
## Refugio: una línea de Mika sobre Yuu, distinta según su Humanidad, y un descanso.
## Las líneas vienen de docs/historia.md («El romance durante la partida»).

const LINEAS := {
	3: "«Cuando te encuentre, voy a seguir siendo alguien a quien puedas mirar.»",
	2: "«Fue solo una vez. Tú lo entenderías. Creo.»",
	1: "«Ya no recuerdo a qué sabía la comida del orfanato. A ti sí te recuerdo.»",
	0: "«Te voy a encontrar. Lo que quede de mí te va a encontrar.»",
}

var descansado := false


func construir() -> void:
	titulo("Refugio")
	texto(LINEAS[expedicion.humanidad], Paleta.BLANCO_HUESO, 20)
	espacio()
	estado_expedicion()
	espacio()
	if descansado:
		texto("Descansaste. La vida vuelve a estar completa.", Paleta.TURQUESA)
		boton("Continuar", expedicion.completar_parada)
		return
	boton("Curar toda la vida", _curar)
	boton("Mejorar la espada (los filos aún no existen)", func() -> void: pass, false)


func _curar() -> void:
	expedicion.curar()
	descansado = true
	rehacer()
