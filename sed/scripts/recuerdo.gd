extends Pantalla
## Recuerdo: el que se acaba de ganar en la expedición o, desde el título, la galería
## de los ganados para releerlos. El texto viene del guion (ver `guion.gd`) y se enseña como
## escena con diálogo; el comentario del otro Yuu depende de la Humanidad.

var mostrando := 0 # número del recuerdo que se lee (0 = galería)
var dialogo: Dialogo


func _init() -> void:
	if expedicion.activa and expedicion.recuerdo_nuevo > 0:
		mostrando = expedicion.recuerdo_nuevo


func construir() -> void:
	var datos := EstadoExpedicion.datos_recuerdos()
	if dialogo != null:
		dialogo.queue_free()
		dialogo = null
	if mostrando == 0:
		titulo("Recuerdos")
		for n in range(1, EstadoExpedicion.TOTAL_RECUERDOS + 1):
			if expedicion.tiene_recuerdo(n):
				boton("%d. %s" % [n, _titulo(n, datos)], _leer.bind(n))
			else:
				boton("%d. ???" % n, func() -> void: pass, false)
		espacio()
		boton("Volver", expedicion.volver_al_titulo)
		return

	var r: Dictionary = datos[mostrando - 1]
	titulo("Recuerdo %d · %s" % [mostrando, _titulo(mostrando, datos)], Paleta.TURQUESA)
	texto(r.cuando, Paleta.DETALLES, 16)
	espacio()
	# Fuera de una expedición (galería) se lee como con Humanidad completa.
	var humanidad: int = expedicion.humanidad if expedicion.activa else Config.HUMANIDAD_INICIAL
	dialogo = Dialogo.new()
	add_child(dialogo)
	dialogo.terminado.connect(_al_terminar.bind(r))
	dialogo.empezar(Guion.segun_humanidad(Guion.recuerdo(mostrando), humanidad))


func _al_terminar(r: Dictionary) -> void:
	espacio()
	texto("Para siempre: " + r.mejora, Paleta.TURQUESA, 16)
	espacio()
	var b: Button
	if expedicion.activa:
		b = boton("Continuar", _seguir)
	else:
		b = boton("Volver a los recuerdos", _leer.bind(0))
	b.call_deferred("grab_focus")


## El título del guion si existe; si no, el de recuerdos.json.
func _titulo(n: int, datos: Array) -> String:
	var t := Guion.titulo_recuerdo(n)
	return t if t != "" else datos[n - 1].titulo


func _leer(n: int) -> void:
	mostrando = n
	rehacer()


func _seguir() -> void:
	expedicion.recuerdo_nuevo = 0
	expedicion.ir_a_ruta()
