class_name Jinete
extends Node2D
## Jinete del Apocalipsis: un monstruo que caza humanos e ignora a los vampiros, y a Mika con
## ellos (salvo que Mika lo ataque: entonces va a por él un rato; con vida JINETE_VIDA, cae). Mika no puede con él, pero puede usarlo: un ruido lo atrae (lo oye desde más lejos que
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
var presa: Node2D = null # un soldado o, si Mika lo atacó, Mika
var derribados := 0 # soldados que ha cazado en este mapa
var vida := Config.JINETE_VIDA
var derribado := false
var furia := 0.0 # s que le quedan yendo a por Mika porque lo atacó

var _indice := 0
var _sentido := 1
var _pausa := 0.0
var _destino := Vector2.ZERO # adónde acude (un ruido)
var _volviendo := false # tras acudir, vuelve a su ruta
var _hasta_golpe := 0.0

@onready var cono: ConoVision = $Cono
var _silueta: Node2D # con Sentidos, se le ve tras las paredes


var animador: Animador # el arte en 8 direcciones, cuando exista (ver animador.gd)


func iniciar(p_mapa: Mapa) -> void:
	mapa = p_mapa
	if animador == null:
		animador = Animador.crear(self, "jinete")
	_silueta = Node2D.new()
	_silueta.z_index = 50
	_silueta.z_as_relative = false
	_silueta.visible = false
	_silueta.draw.connect(func() -> void: Formas.capsula(_silueta, ALTO_CAPSULA, ANCHO_CAPSULA, Color(Paleta.ROJO, 0.08), Color(Paleta.ROJO, 0.5)))
	add_child(_silueta)
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
	if derribado:
		cono.visible = false
		queue_redraw()
		return
	_hasta_golpe -= delta
	furia -= delta
	if estado == Estado.CAZA and presa == mapa.mika and furia <= 0.0:
		presa = null # se le pasó la furia
		estado = Estado.VAGA
		_volviendo = true
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
	var sentidos := mapa.mika != null and mapa.mika.revelando()
	_silueta.visible = sentidos
	cono.z_index = 49 if sentidos and mapa.mika.tiene_filo(Filos.CAZADOR) else -1
	cono.actualizar(mapa, pos, mirada, COLOR_CAZA if estado == Estado.CAZA else COLOR_CONO, Config.JINETE_ANGULO, Config.JINETE_VISION)
	queue_redraw()


## Mika lo ataca: le quita vida y, si sigue en pie, se gira contra Mika (furia).
func recibir_dano(cantidad: int) -> void:
	if derribado:
		return
	vida -= cantidad
	if vida <= 0:
		vida = 0
		derribado = true
		cono.visible = false
		return
	presa = mapa.mika
	estado = Estado.CAZA
	furia = Config.JINETE_FURIA


## Es un monstruo: no se le derriba por la espalda.
func admite_golpe_silencioso() -> bool:
	return false


func recibir_golpe_silencioso() -> void:
	pass


## Oye un ruido: si no está cazando, va al origen.
func oir(origen: Vector2) -> void:
	if estado == Estado.CAZA:
		return
	_destino = origen
	estado = Estado.ACUDE


func _cazar(delta: float) -> void:
	var caida: bool = presa != null and is_instance_valid(presa) and (presa.caida if presa == mapa.mika else presa.derribado)
	if presa == null or not is_instance_valid(presa) or caida:
		presa = null
		estado = Estado.VAGA
		_volviendo = true
		return
	_ir_hacia(presa.pos, Config.JINETE_VELOCIDAD_CAZA, delta)
	if pos.distance_to(presa.pos) <= Config.JINETE_ALCANCE and _hasta_golpe <= 0.0:
		_hasta_golpe = Config.JINETE_GOLPE_INTERVALO
		if presa == mapa.mika:
			mapa.mika.recibir_golpe(Config.JINETE_DANO)
			return
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
	if derribado:
		draw_set_transform(Vector2.ZERO, PI / 2.0, Vector2(0.6, 1.0))
		Formas.capsula(self, ALTO_CAPSULA * 0.5, ANCHO_CAPSULA, Color(COLOR_CUERPO, 0.6), COLOR_CONTORNO)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if animador:
		animador.poner(estado_animacion(animador.se_mueve()), Formas.direccion_8(mirada))
	if not (animador and animador.activo):
		Formas.capsula(self, ALTO_CAPSULA, ANCHO_CAPSULA, COLOR_CUERPO, COLOR_CONTORNO)
	if estado == Estado.ACUDE:
		var fuente := ThemeDB.fallback_font
		draw_string(fuente, Vector2(-10, -ALTO_CAPSULA - 14), "?", HORIZONTAL_ALIGNMENT_CENTER, 20, 28, Paleta.DETALLES)


## Estado para el arte: cazar, andar o quieto.
func estado_animacion(se_mueve: bool) -> String:
	if derribado:
		return "derribado"
	if estado == Estado.CAZA:
		return "cazar"
	return "andar" if se_mueve else "quieto"
