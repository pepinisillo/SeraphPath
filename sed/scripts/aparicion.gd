class_name Aparicion
extends Node2D
## Grupo de soldados que no está en el mapa hasta que Mika entra en una de sus zonas.
## Sus soldados se ponen como hijos en la escena del mapa; al empezar se apartan y, cuando
## Mika pisa la zona, se marca en el suelo dónde van a salir (APARICION_AVISO s) y aparecen
## en el primer punto de su ruta. Recién aparecidos no pueden verlo durante APARICION_GRACIA s.
## Con `probabilidad` < 1, en algunas partidas el grupo no sale nunca y su zona queda vacía.

enum Estado { ESPERANDO, AVISANDO, APARECIDO, DESCARTADO }

const COLOR_AVISO := Paleta.CALMA

## Zonas que lo activan, en casillas.
@export var zonas: Array[Rect2i] = []
## Probabilidad de que el grupo exista en esta partida.
@export_range(0.0, 1.0) var probabilidad := 1.0

## Las pruebas lo encienden: todos los grupos existen, sin sorteo.
static var forzar := false

var mapa: Mapa
var estado := Estado.ESPERANDO
var pendientes: Array[Soldado] = []
var _aviso := 0.0


func iniciar(p_mapa: Mapa) -> void:
	mapa = p_mapa
	z_index = -1 # sobre el suelo, debajo de los personajes
	for hijo in get_children():
		if hijo is Soldado:
			remove_child(hijo)
			pendientes.append(hijo)
	if not forzar and Soldado.generador(name).randf() >= probabilidad:
		estado = Estado.DESCARTADO


func _physics_process(delta: float) -> void:
	if mapa == null or mapa.terminado:
		return
	match estado:
		Estado.ESPERANDO:
			if mapa.mika != null and _en_zona(mapa.mika.pos):
				estado = Estado.AVISANDO
				_aviso = Config.APARICION_AVISO
		Estado.AVISANDO:
			_aviso -= delta
			queue_redraw()
			if _aviso <= 0.0001: # sin depender del redondeo de los fotogramas
				aparecer()


func _en_zona(pos: Vector2) -> bool:
	var celda := Vector2i(floori(pos.x), floori(pos.y))
	for zona in zonas:
		if zona.has_point(celda):
			return true
	return false


## Pone a los soldados en el mapa. Las pruebas lo llaman directamente.
func aparecer() -> void:
	if estado == Estado.APARECIDO:
		return
	estado = Estado.APARECIDO
	for s in pendientes:
		s.aparecido = true
		mapa.add_child(s)
		s.iniciar(mapa)
	pendientes.clear()
	queue_redraw()


## Mientras avisa, un rombo que late en cada casilla donde va a salir un soldado.
func _draw() -> void:
	if estado != Estado.AVISANDO:
		return
	var f := 1.0 - _aviso / Config.APARICION_AVISO
	var latido := 0.5 + 0.5 * sin(f * TAU * 3.0)
	for s in pendientes:
		if s.ruta.is_empty():
			continue
		var centro := Iso.a_pantalla(Vector2(s.ruta[0]) + Vector2(0.5, 0.5))
		var escala := 0.4 + 0.5 * f
		var puntos := PackedVector2Array([
			centro + Vector2(0, -Config.ALTO_CASILLA / 2.0) * escala,
			centro + Vector2(Config.ANCHO_CASILLA / 2.0, 0) * escala,
			centro + Vector2(0, Config.ALTO_CASILLA / 2.0) * escala,
			centro + Vector2(-Config.ANCHO_CASILLA / 2.0, 0) * escala,
		])
		var color := COLOR_AVISO
		color.a = 0.25 + 0.5 * latido
		draw_colored_polygon(puntos, Color(color, color.a * 0.4))
		puntos.append(puntos[0])
		draw_polyline(puntos, color, 3.0)
