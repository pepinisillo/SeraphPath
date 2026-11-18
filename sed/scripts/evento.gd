extends Pantalla
## Evento: la escena del guion, la decisión (con sus efectos) y lo que pasa después, sin mapa.
## Los efectos de cada opción viven en eventos.gd; el texto, en el guion.

var evento: Dictionary
var texto_evento: Dictionary # del guion: {intro, opciones}
var elegida := -1
var mejoras_ofrecidas: Array[String] = []
var dialogo: Dialogo


func _init() -> void:
	evento = Eventos.por_id(expedicion.evento_actual)
	texto_evento = Guion.evento(evento.titulo)


func _ready() -> void:
	super()
	_contar(texto_evento.intro)


func construir() -> void:
	if dialogo != null and not dialogo.acabado:
		return
	titulo(evento.titulo)
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
	elif opcion.efectos.get("filo", false):
		boton("Elegir el filo", expedicion.ofrecer_filo.bind(expedicion.completar_parada))
	else:
		boton("Continuar", expedicion.completar_parada)


func elegir(i: int) -> void:
	elegida = i
	mejoras_ofrecidas = expedicion.aplicar_efectos(evento.opciones[i].efectos)
	var resultado: Array = texto_evento.opciones.get(evento.opciones[i].texto, [])
	_contar(resultado)
	rehacer()


## Enseña un tramo del guion como escena con diálogo; al terminar, vuelve a la pantalla.
func _contar(golpes: Array) -> void:
	var visibles: Array[Dictionary] = []
	visibles.assign(Guion.segun_humanidad(_tipadas(golpes), expedicion.humanidad))
	if visibles.is_empty():
		return
	if dialogo != null:
		dialogo.queue_free()
	dialogo = Dialogo.new()
	add_child(dialogo)
	dialogo.terminado.connect(rehacer)
	dialogo.empezar(visibles)


func _tipadas(golpes: Array) -> Array[Dictionary]:
	var t: Array[Dictionary] = []
	t.assign(golpes)
	return t


func _elegir_mejora(id: String) -> void:
	expedicion.elegir_mejora(id)
	mejoras_ofrecidas = []
	rehacer()
