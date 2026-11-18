class_name Jinete
extends Node2D
## Jinete del Apocalipsis: un monstruo que caza humanos e ignora a los vampiros, y a Mika con
## ellos. Mika no puede con él, pero puede usarlo: un ruido lo atrae (lo oye desde más lejos que
## un soldado) y, si al llegar ve a un soldado, lo persigue y lo derriba. El soldado queda en el
## suelo como cualquier otro derribado: otra patrulla puede descubrirlo y Mika puede beber de él.
## Su posición vive en casillas.

enum Estado { VAGA, ACUDE, CAZA }

const COLOR_CUERPO := Paleta.JINETES
const COLOR_CONTORNO := Paleta.BLANCO_HUESO
const COLOR_CONO := Paleta.DETALLES
const COLOR_CAZA := Paleta.ROJO
const ALTO_CAPSULA := 150.0
const ANCHO_CAPSULA := 70.0

## Casillas que recorre, en orden, vagando. Con una sola, se queda en ella.
@export var ruta: Array[Vector2i] = []
## True: vuelve del último punto al primero. False: va y viene.
@export var en_bucle := false

var mapa: Mapa
var pos := Vector2.ZERO # casillas
var mirada := Vector2(1, 0)
var estado := Estado.VAGA
var presa: Soldado = null
var derribados := 0 # soldados que ha cazado en este mapa

var _indice := 0
var _sentido := 1
var _pausa := 0.0
var _destino := Vector2.ZERO # adónde acude (un ruido)
var _volviendo := false # tras acudir, vuelve a su ruta
var _hasta_golpe := 0.0

@onready var cono: ConoVision = $Cono


func iniciar(p_mapa: Mapa) -> void:
	mapa = p_mapa
	if ruta.is_empty():
		push_warning("%s no tiene ruta" % name)
		return
	pos = Vector2(ruta[0]) + Vector2(0.5, 0.5)
	_indice = 1 % ruta.size()
	if ruta.size() > 1:
		mirada = (Vector2(ruta[_indice]) + Vector2(0.5, 0.5) - pos).normalized()
	position = Iso.a_pantalla(pos)


func _physics_process(delta: float) -> void:
	if mapa == null or ruta.is_empty():
		return
	_hasta_golpe -= delta
	if estado != Estado.CAZA:
		var vista := _soldado_a_la_vista()
		if vista != null:
			presa = vista
			estado = Estado.CAZA
	match estado:
		Estado.VAGA:
			_vagar(delta)
		Estado.ACUDE:
			if _ir_hacia(_destino, Config.JINETE_VELOCIDAD_ACUDE, delta):
				estado = Estado.VAGA
				_volviendo = true
		Estado.CAZA:
			_cazar(delta)
	position = Iso.a_pantalla(pos)
	cono.actualizar(mapa, pos, mirada, COLOR_CAZA if estado == Estado.CAZA else COLOR_CONO, Config.JINETE_ANGULO, Config.JINETE_VISION)
	queue_redraw()


## Oye un ruido: si no está cazando, va al origen.
func oir(origen: Vector2) -> void:
	if estado == Estado.CAZA:
		return
	_destino = origen
	estado = Estado.ACUDE


func _cazar(delta: float) -> void:
	if presa == null or not is_instance_valid(presa) or presa.derribado:
		presa = null
		estado = Estado.VAGA
		_volviendo = true
		return
	_ir_hacia(presa.pos, Config.JINETE_VELOCIDAD_CAZA, delta)
	if pos.distance_to(presa.pos) <= Config.JINETE_ALCANCE and _hasta_golpe <= 0.0:
		_hasta_golpe = Config.JINETE_GOLPE_INTERVALO
		# Su golpe (JINETE_DANO) siempre derriba a un soldado (SOLDADO_VIDA): sin alarma, solo un cuerpo.
		presa.derribar()
		derribados += 1
		mapa.estadisticas.cazados_por_jinetes += 1


## El soldado en pie más cercano que vea (los vampiros y Mika no le interesan).
func _soldado_a_la_vista() -> Soldado:
	var mejor: Soldado = null
	for soldado in mapa.soldados():
		if soldado.derribado or not puede_ver(soldado.pos):
			continue
		if mejor == null or pos.distance_to(soldado.pos) < pos.distance_to(mejor.pos):
			mejor = soldado
	return mejor


func puede_ver(punto: Vector2) -> bool:
	var hacia := punto - pos
	var distancia := hacia.length()
	if distancia > Config.JINETE_VISION:
		return false
	if distancia > 0.001 and absf(angle_difference(mirada.angle(), hacia.angle())) > deg_to_rad(Config.JINETE_ANGULO) / 2.0:
		return false
	return mapa.hay_linea_de_vision(pos, punto)


func _vagar(delta: float) -> void:
	if _volviendo:
		if _ir_hacia(Vector2(ruta[_indice]) + Vector2(0.5, 0.5), Config.JINETE_VELOCIDAD, delta):
			_volviendo = false
		return
	if ruta.size() == 1:
		return
	if _pausa > 0.0:
		_pausa -= delta
		return
	var destino := Vector2(ruta[_indice]) + Vector2(0.5, 0.5)
	if _ir_hacia(destino, Config.JINETE_VELOCIDAD, delta):
		_pausa = Config.JINETE_PAUSA
		if en_bucle:
			_indice = (_indice + 1) % ruta.size()
		else:
			if _indice + _sentido < 0 or _indice + _sentido >= ruta.size():
				_sentido = -_sentido
			_indice += _sentido


## Camina hacia `destino` rodeando muros. Devuelve true al llegar.
func _ir_hacia(destino: Vector2, velocidad: float, delta: float) -> bool:
	if pos.distance_to(destino) <= 0.05:
		return true
	var camino := mapa.camino(pos, destino)
	if camino.is_empty():
		return true
	var hacia := camino[0] - pos
	var avance := velocidad * delta
	if hacia.length() > 0.001:
		mirada = hacia.normalized()
	if hacia.length() <= avance:
		pos = camino[0]
	else:
		pos += hacia.normalized() * avance
	return pos.distance_to(destino) <= 0.05


func _draw() -> void:
	Formas.capsula(self, ALTO_CAPSULA, ANCHO_CAPSULA, COLOR_CUERPO, COLOR_CONTORNO)
	if estado == Estado.ACUDE:
		var fuente := ThemeDB.fallback_font
		draw_string(fuente, Vector2(-10, -ALTO_CAPSULA - 14), "?", HORIZONTAL_ALIGNMENT_CENTER, 20, 28, Paleta.DETALLES)
