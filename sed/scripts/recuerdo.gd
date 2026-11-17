extends Pantalla
## Recuerdo: el que se acaba de ganar en la expedición o, desde el título, la galería
## de los ganados para releerlos. Los guiones vienen de docs/historia.md (copiados a datos/recuerdos.json).

var mostrando := 0 # número del recuerdo que se lee (0 = galería)


func _init() -> void:
	if expedicion.activa and expedicion.recuerdo_nuevo > 0:
		mostrando = expedicion.recuerdo_nuevo


func construir() -> void:
	var datos := EstadoExpedicion.datos_recuerdos()
	if mostrando == 0:
		titulo("Recuerdos")
		for n in range(1, EstadoExpedicion.TOTAL_RECUERDOS + 1):
			var r: Dictionary = datos[n - 1]
			if expedicion.tiene_recuerdo(n):
				boton("%d. %s" % [n, r.titulo], _leer.bind(n))
			else:
				boton("%d. ???" % n, func() -> void: pass, false)
		espacio()
		boton("Volver", expedicion.volver_al_titulo)
		return

	var r: Dictionary = datos[mostrando - 1]
	titulo("Recuerdo %d · %s" % [mostrando, r.titulo], Paleta.TURQUESA)
	texto(r.cuando, Paleta.DETALLES, 16)
	espacio()
	for linea in r.lineas:
		_linea(linea)
	espacio()
	texto("Para siempre: " + r.mejora, Paleta.TURQUESA, 16)
	espacio()
	if expedicion.activa:
		boton("Continuar", _seguir)
	else:
		boton("Volver a los recuerdos", _leer.bind(0))


## Acotaciones en gris, diálogo en blanco hueso y la línea de «Mika, ahora» en turquesa.
func _linea(linea: String) -> void:
	if linea.begins_with("*") and linea.ends_with("*") and not linea.begins_with("**"):
		texto(linea.trim_prefix("*").trim_suffix("*"), Paleta.DETALLES, 17)
	elif linea.begins_with("**Mika, ahora:**"):
		texto("Mika, ahora: " + linea.trim_prefix("**Mika, ahora:**").strip_edges(), Paleta.TURQUESA, 19)
	else:
		texto(linea.replace("**", ""), Paleta.BLANCO_HUESO, 18)


func _leer(n: int) -> void:
	mostrando = n
	rehacer()


func _seguir() -> void:
	expedicion.recuerdo_nuevo = 0
	expedicion.ir_a_ruta()
