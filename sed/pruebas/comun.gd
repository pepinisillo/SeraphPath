extends SceneTree
## Utilidades compartidas por las pruebas: mapa con el tiempo detenido, paso fijo y comprobaciones.

const DT := 1.0 / 60.0
var ok := true


## Carga el puesto de control sin que avance solo: las pruebas lo hacen avanzar con paso().
## Solo deja a los soldados nombrados (por defecto S1, con el que se escribieron las pruebas
## de los pasos 2 a 6); con `todos` deja a los cuatro.
func nuevo_mapa(todos := false) -> Mapa:
	var mapa: Mapa = load("res://escenas/mapa_puesto_control.tscn").instantiate()
	if not todos:
		for nombre in ["S2", "S3", "S4"]:
			mapa.get_node(nombre).free()
	root.add_child(mapa)
	mapa.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	mapa.get_node("HUD").process_mode = Node.PROCESS_MODE_DISABLED
	return mapa


## Carga la Prueba de la sed sin que avance sola.
func nueva_prueba_de_la_sed() -> Mapa:
	var mapa: Mapa = load("res://escenas/mapa_prueba_sed.tscn").instantiate()
	root.add_child(mapa)
	mapa.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	mapa.get_node("HUD").process_mode = Node.PROCESS_MODE_DISABLED
	return mapa


func paso(m: Mapa, segundos: float = DT) -> void:
	for i in roundi(segundos / DT):
		if m.terminado:
			return
		m._physics_process(DT)
		if m.alerta:
			m.alerta._physics_process(DT)
		m.mika._physics_process(DT)
		for s in m.soldados():
			s._physics_process(DT)
			if m.es_muro(Vector2i(floori(s.pos.x), floori(s.pos.y))):
				ok = false
				print("FALLO: ", s.name, " dentro de muro en ", s.pos)
		for h in m.get_children():
			if h is Vial or h is Eco:
				h._physics_process(DT)


func soldado_extra(m: Mapa, nombre: String, celda: Vector2i, mirada: Vector2) -> Soldado:
	var s: Soldado = load("res://escenas/soldado.tscn").instantiate()
	s.name = nombre
	s.ruta.assign([celda])
	m.add_child(s)
	s.iniciar(m)
	s.mirada = mirada
	return s


func comprobar(nombre: String, valor, esperado, tolerancia := 0.01) -> void:
	var bien: bool
	if valor is Vector2:
		bien = valor.distance_to(esperado) <= tolerancia
	elif valor is float:
		bien = absf(valor - esperado) <= tolerancia
	else:
		bien = valor == esperado
	if not bien:
		ok = false
	print(("  ok  " if bien else "FALLO "), nombre, ": ", valor, " (esperado ", esperado, ")")


func terminar() -> void:
	print("RESULTADO: ", "OK" if ok else "FALLO")
	quit()
