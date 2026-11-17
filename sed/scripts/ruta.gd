extends Pantalla
## Mapa de paradas de la zona: qué se ha hecho, dónde está Mika, la bifurcación y lo que viene.

const DESCRIPCIONES := {
	"infiltracion": "Cruza el puesto de control hasta la salida.",
	"emboscada": "El mismo puesto, pero empieza en Alarma. (Su recompensa, un filo, llegará cuando existan los filos.)",
	"evento": "Una decisión, sin mapa.",
	"refugio": "Un lugar seguro para recuperarse.",
	"prueba": "Dentro de tu mente. Llega hasta Yuu sin beber.",
	"jefe": "No se le vence: se le escapa. (Aún no existe: aquí termina, por ahora, la expedición.)",
}


func construir() -> void:
	var e := expedicion
	titulo("Zona %d · Sanguinem" % e.zona)
	estado_expedicion()
	texto("Recuerdos: %d/%d" % [e.recuerdos.size(), e.TOTAL_RECUERDOS], Paleta.TURQUESA, 16)
	espacio()

	var lista := e.paradas()
	for i in lista.size():
		if i == 1 and e.ruta == "":
			texto("    ├ Ruta segura: %s" % _contenido("segura"), Paleta.BLANCO_HUESO)
			texto("    └ Ruta arriesgada: %s" % _contenido("arriesgada"), Paleta.BLANCO_HUESO)
			continue
		if lista[i] == "?":
			continue
		var marca := "✓" if i < e.indice else ("▶" if i == e.indice else "·")
		var color := Paleta.DETALLES if i < e.indice else (Paleta.TURQUESA if i == e.indice else Paleta.BLANCO_HUESO)
		texto("%s  %s" % [marca, e.NOMBRES[lista[i]]], color, 20)

	espacio()
	for aviso in _avisos():
		texto(aviso, Paleta.AMBAR, 16)
	if e.toca_elegir_ruta():
		boton("Ruta segura: %s" % _contenido("segura"), _elegir.bind("segura"))
		boton("Ruta arriesgada: %s" % _contenido("arriesgada"), _elegir.bind("arriesgada"))
	else:
		var actual := e.parada_actual()
		texto(DESCRIPCIONES[actual], Paleta.DETALLES, 16)
		boton("Entrar: %s" % e.NOMBRES[actual], e.entrar)
	espacio()
	boton("Abandonar la expedición", e.volver_al_titulo)


## Las dos paradas de una ruta. Sin el recuerdo 3, «El mapa», no se sabe qué hay en ellas.
func _contenido(ruta: String) -> String:
	if not expedicion.tiene_recuerdo(3):
		return "? → ?"
	var nombres := PackedStringArray()
	for parada in EstadoExpedicion.RUTAS[ruta]:
		nombres.append(EstadoExpedicion.NOMBRES[parada])
	return " → ".join(nombres)


func _avisos() -> PackedStringArray:
	var e := expedicion
	var avisos := PackedStringArray()
	if e.siguiente_empieza == "sospecha":
		avisos.append("El siguiente mapa empieza en Sospecha.")
	elif e.siguiente_empieza == "alarma":
		avisos.append("El siguiente mapa empieza en Alarma.")
	if e.sed_congelada:
		avisos.append("La sed no subirá durante el siguiente mapa.")
	if e.patrullas_visibles:
		avisos.append("Ves todas las patrullas de la zona.")
	return avisos


func _elegir(ruta: String) -> void:
	expedicion.elegir_ruta(ruta)
	rehacer()
