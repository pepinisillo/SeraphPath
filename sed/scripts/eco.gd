class_name Eco
extends Node2D
## Eco del recuerdo en la Prueba de la sed. Sigue a Mika rodeando muros, le corta el paso
## y le ofrece sangre con la voz de Yuu. Cerca de él, la sed sube más rápido.

const COLOR_CUERPO := Color(Paleta.BLANCO_HUESO, 0.35)
const COLOR_CONTORNO := Paleta.ROJO
const ALTO_CAPSULA := 104.0
const ANCHO_CAPSULA := 40.0

var mapa: Mapa
var pos := Vector2.ZERO # casillas
var numero := 0 # cada eco empieza por una frase distinta
## Lo que dice ahora: las frases del guion según la Humanidad de Mika, que van cambiando.
var frase: String:
	get:
		var frases := mapa.frases_ecos() if mapa else PackedStringArray()
		if frases.is_empty():
			return ""
		return frases[(numero + int(_tiempo / Config.ECO_CAMBIO_FRASE)) % frases.size()]
var bebido := false
var _tiempo := 0.0

@onready var voz: Node2D = $Voz


var animador: Animador # el arte en 8 direcciones, cuando exista (ver animador.gd)


func _ready() -> void:
	animador = Animador.crear(self, "eco")
	voz.draw.connect(_dibujar_voz)


func iniciar(p_mapa: Mapa, celda: Vector2i, p_numero: int) -> void:
	mapa = p_mapa
	pos = Vector2(celda) + Vector2(0.5, 0.5)
	numero = p_numero
	position = Iso.a_pantalla(pos)


func _physics_process(delta: float) -> void:
	_tiempo += delta
	if mapa == null or mapa.mika == null or bebido:
		return
	_seguir_a_mika(delta)
	position = Iso.a_pantalla(pos)
	queue_redraw()
	voz.queue_redraw()


## Camina hacia Mika a su velocidad, rodeando muros, hasta tocarlo.
func _seguir_a_mika(delta: float) -> void:
	var contacto := Config.RADIO_MIKA + Config.PRUEBA_ECO_RADIO
	if pos.distance_to(mapa.mika.pos) <= contacto + 0.02:
		return
	var camino := mapa.camino(pos, mapa.mika.pos)
	var avance := Config.PRUEBA_ECO_VELOCIDAD * delta
	for punto in camino:
		var hacia := punto - pos
		var distancia := hacia.length()
		if punto == camino[-1]:
			distancia -= contacto # el último tramo termina al tocarlo, no encima de él
		if distancia <= 0.0:
			break
		if distancia > avance:
			pos += hacia.normalized() * avance
			break
		pos += hacia.normalized() * distancia
		avance -= distancia


## Solo habla el eco más cercano a Mika, si está a distancia de oírse: así las frases no se pisan.
func habla() -> bool:
	var mika := mapa.mika
	if bebido or pos.distance_to(mika.pos) > Config.PRUEBA_ECO_VOZ:
		return false
	for otro in mapa.ecos():
		if otro != self and not otro.bebido and otro.pos.distance_to(mika.pos) < pos.distance_to(mika.pos):
			return false
	return true


func beber() -> void:
	bebido = true
	visible = false


func _draw() -> void:
	if animador:
		animador.poner(estado_animacion(animador.se_mueve()), Formas.direccion_8(Vector2(1, 1)))
	var flotar := sin(_tiempo * 2.0) * 3.0
	draw_set_transform(Vector2(0, flotar), 0.0, Vector2.ONE)
	if not (animador and animador.activo):
		Formas.capsula(self, ALTO_CAPSULA, ANCHO_CAPSULA, COLOR_CUERPO, COLOR_CONTORNO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Frase y aviso de «Beber», en una capa por encima de muros y personajes.
func _dibujar_voz() -> void:
	if mapa == null or mapa.mika == null or bebido:
		return
	var fuente := ThemeDB.fallback_font
	if habla() and frase != "":
		var ancho := fuente.get_string_size(frase, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 20
		var caja := Rect2(-ancho / 2.0, -ALTO_CAPSULA - 58, ancho, 26)
		voz.draw_rect(caja, Color(0.04, 0.05, 0.08, 0.85))
		voz.draw_string(fuente, Vector2(-ancho / 2.0, -ALTO_CAPSULA - 40), frase, HORIZONTAL_ALIGNMENT_CENTER, ancho, 16, Paleta.BLANCO_HUESO)
	var mika := mapa.mika
	if mika.objetivo_eco == self and not mika.esta_bebiendo():
		voz.draw_string(fuente, Vector2(-60, -ALTO_CAPSULA - 12), "Beber (E)", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Paleta.ROJO)


## Estado para el arte: flotar (o bebido, si ya bebió de él).
func estado_animacion(_se_mueve: bool) -> String:
	return "bebido" if bebido else "flotar"
