extends Pantalla
## Galería de finales (desde el título): los que ya se vieron se pueden volver a ver.

const FINALES := ["La sangre de Yuu", "En el límite", "Vampiro completo"]

var dialogo: Dialogo


func construir() -> void:
	if dialogo != null and not dialogo.acabado:
		return
	titulo("Finales", Paleta.BLANCO_HUESO, 36)
	texto("Caídas: %d" % expedicion.caidas, Paleta.DETALLES, 16)
	espacio()
	for nombre in FINALES:
		if nombre in expedicion.finales_vistos:
			boton(nombre, _ver.bind(nombre), not Guion.final(nombre).is_empty())
		else:
			boton("???", func() -> void: pass, false)
	espacio()
	boton("Volver", expedicion.volver_al_titulo)


func _ver(nombre: String) -> void:
	if dialogo != null:
		dialogo.queue_free()
	dialogo = Dialogo.new()
	add_child(dialogo)
	dialogo.terminado.connect(rehacer)
	dialogo.bebio.connect(func() -> void: pass)
	dialogo.empezar(Guion.final(nombre))
	rehacer()
