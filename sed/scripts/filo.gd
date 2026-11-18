extends Pantalla
## Elegir un filo de la espada entre dos (tras una emboscada, en el refugio o en «El filo
## exigente»). Si Mika ya lleva FILOS_MAX, al elegir uno hay que decir cuál deja.

var elegido := "" # el nuevo, cuando ya lleva el máximo y falta decir cuál deja


func construir() -> void:
	var e := expedicion
	titulo("La espada", Paleta.BLANCO_HUESO, 30)
	if e.filos.is_empty():
		texto("Aún no lleva ningún filo.", Paleta.DETALLES, 16)
	else:
		texto("Lleva: " + ", ".join(e.filos.map(func(f): return Filos.nombre(f))), Paleta.DETALLES, 16)
	espacio()
	if elegido == "":
		for id in e.filos_ofrecidos:
			boton("%s — %s" % [Filos.nombre(id), Filos.descripcion(id)], _elegir.bind(id))
		boton("No coger ninguno", e.elegir_filo.bind(""))
		return
	texto("Ya lleva %d filos. ¿Cuál deja por %s?" % [Config.FILOS_MAX, Filos.nombre(elegido)], Paleta.BLANCO_HUESO)
	for viejo in e.filos:
		boton("Dejar %s" % Filos.nombre(viejo), e.elegir_filo.bind(elegido, viejo))
	boton("Mejor no", _cancelar)


func _elegir(id: String) -> void:
	if expedicion.filos.size() < Config.FILOS_MAX:
		expedicion.elegir_filo(id)
	else:
		elegido = id
		rehacer()


func _cancelar() -> void:
	elegido = ""
	rehacer()
