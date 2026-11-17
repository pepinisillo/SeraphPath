extends Pantalla
## Evento: una situación y una decisión en texto, sin mapa.

var evento: Dictionary
var elegida := -1
var mejoras_ofrecidas: Array[String] = []


func _init() -> void:
	evento = Eventos.por_id(expedicion.evento_actual)


func construir() -> void:
	titulo(evento.titulo)
	texto(evento.situacion, Paleta.BLANCO_HUESO, 20)
	espacio()
	if elegida < 0:
		for i in evento.opciones.size():
			var opcion: Dictionary = evento.opciones[i]
			boton("%s — %s" % [opcion.texto, Eventos.describir(opcion.efectos)], elegir.bind(i))
		espacio()
		estado_expedicion()
		return

	var opcion: Dictionary = evento.opciones[elegida]
	texto("Elegiste: " + opcion.texto, Paleta.TURQUESA)
	texto(Eventos.describir(opcion.efectos))
	estado_expedicion()
	espacio()
	if not mejoras_ofrecidas.is_empty():
		texto("Bebiste sangre humana. Elige una mejora:", Paleta.ROJO)
		for id in mejoras_ofrecidas:
			boton("%s — %s" % [Mejoras.nombre(id), Mejoras.descripcion(id)], _elegir_mejora.bind(id))
	else:
		boton("Continuar", expedicion.completar_parada)


func elegir(i: int) -> void:
	elegida = i
	mejoras_ofrecidas = expedicion.aplicar_efectos(evento.opciones[i].efectos)
	rehacer()


func _elegir_mejora(id: String) -> void:
	expedicion.elegir_mejora(id)
	mejoras_ofrecidas = []
	rehacer()
