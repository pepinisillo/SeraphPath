class_name Vampiro
extends Node2D
## Vampiro común de Sanguinem. No ataca a Mika ni le importa verlo pasar: para él, Mika es uno
## de los suyos. Pero lo delata si lo ve hacer algo prohibido:
## - atacar a un vampiro (o ver a un vampiro derribado),
## - robar un vial,
## - entrar en una zona prohibida (las casillas `x` del plano) y quedarse en ella.
## Al verlo se detiene, lo mira y, si en VAMPIRO_AVISO s nadie lo calla (derribándolo), da la
## alarma: los soldados del mapa van a por Mika. Mientras está avisando, Mika puede derribarlo
## con un Tajo o un Golpe silencioso, pero si otro vampiro lo ve, ese también lo delata.
## Los vampiros no dan sangre. Su posición vive en casillas.

enum Estado { CALMA, TESTIGO, DELATO }

const COLOR_CUERPO := Paleta.VAMPIROS
const COLOR_CONTORNO := Paleta.DETALLES
const COLOR_CONO := Paleta.VAMPIROS
const COLOR_AVISO := Paleta.ROJO
const COLOR_MARCA_SILENCIOSO := Paleta.BLANCO_HUESO
const ALTO_CAPSULA := 106.0
const ANCHO_CAPSULA := 40.0
const LLEGADA := 0.05

## Casillas que recorre, en orden. Con una sola, hace guardia en ella.
@export var ruta: Array[Vector2i] = []
## True: vuelve del último punto al primero. False: va y viene (vaivén).
@export var en_bucle := true

var mapa: Mapa
var pos := Vector2.ZERO # casillas
var mirada := Vector2(1, 0)
var estado := Estado.CALMA
var vida := Config.VAMPIRO_VIDA
var derribado := false
var bebido := true # no da sangre: para Mika siempre cuenta como «ya bebido»
var motivo := "" # qué vio: "ataque", "vial", "prohibida", "cuerpo"
var aviso := 0.0 # de 0 a 1: cuánto le falta para delatar
var azar := RandomNumberGenerator.new()

var _indice := 0
var _sentido := 1
var _pausa := 0.0
var _en_prohibida := 0.0 # s que lleva viendo a Mika en una zona prohibida
var _cuerpos_vistos: Array = []
var _donde := Vector2.ZERO # dónde manda la alarma (Mika o, si vio un cuerpo, el cuerpo)

@onready var cono: ConoVision = $Cono


func iniciar(p_mapa: Mapa) -> void:
	mapa = p_mapa
	azar.seed = Soldado.generador(name).seed
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
	var mika := mapa.mika
	match estado:
		Estado.CALMA:
			_patrullar(delta)
			_vigilar(delta)
		Estado.TESTIGO:
			if mika:
				_girar_hacia(mika.pos - pos, delta)
			aviso += delta / Config.VAMPIRO_AVISO
			if aviso >= 1.0:
				_delatar()
		Estado.DELATO:
			# Ya dio la alarma: mientras dure, no hace falta que vuelva a delatar.
			_patrullar(delta)
			if not mapa.alerta.activa:
				estado = Estado.CALMA
	position = Iso.a_pantalla(pos)
	cono.actualizar(mapa, pos, mirada, COLOR_AVISO if estado == Estado.TESTIGO else COLOR_CONO)
	queue_redraw()


## Mira por si Mika está en una zona prohibida o hay un vampiro derribado a la vista.
func _vigilar(delta: float) -> void:
	if mapa.vampiros_callados:
		return
	var mika := mapa.mika
	if mika and not mika.caida and mapa.es_prohibida(mika.celda()) and puede_ver(mika.pos):
		_en_prohibida += delta
		if _en_prohibida >= Config.VAMPIRO_PROHIBIDA:
			presenciar("prohibida")
			return
	else:
		_en_prohibida = 0.0
	for otro in mapa.vampiros():
		if otro != self and otro.derribado and not otro in _cuerpos_vistos and puede_ver(otro.pos):
			_cuerpos_vistos.append(otro)
			presenciar("cuerpo", otro.pos)
			return


## Ha visto algo prohibido: se queda mirando a Mika y empieza a contar para delatarlo.
## Si ya delató y la alarma se apagó, puede volver a hacerlo.
func presenciar(que: String, donde := Vector2(-1, -1)) -> void:
	if derribado or estado == Estado.TESTIGO or mapa.vampiros_callados:
		return
	motivo = que
	_donde = donde
	aviso = 0.0
	estado = Estado.TESTIGO


func _delatar() -> void:
	estado = Estado.DELATO
	aviso = 0.0
	mapa.estadisticas.delaciones += 1
	if _donde.x >= 0:
		mapa.alerta.dar_alarma(_donde)
	elif mapa.mika:
		mapa.alerta.dar_alarma(mapa.mika.pos)


## Mika lo golpea: es un ataque a un vampiro (lo ven los demás) y le quita vida.
func recibir_dano(cantidad: int) -> void:
	if derribado:
		return
	vida -= cantidad
	if vida <= 0:
		derribar()
	else:
		presenciar("ataque") # el propio golpeado lo ha visto todo


func recibir_golpe_silencioso() -> void:
	derribar()


func derribar() -> void:
	derribado = true
	vida = 0
	estado = Estado.CALMA
	aviso = 0.0
	cono.visible = false


## Por la espalda o sin que mire a Mika (como a un soldado). Mientras avisa lo está mirando,
## pero aún así se le puede callar con el Tajo.
func admite_golpe_silencioso() -> bool:
	return not derribado and estado != Estado.TESTIGO and not (mapa.mika and puede_ver(mapa.mika.pos))


## El punto está dentro de su cono, al alcance (menor si está en sombra) y sin muros de por medio.
func puede_ver(punto: Vector2) -> bool:
	if derribado:
		return false
	var hacia := punto - pos
	var distancia := hacia.length()
	var en_sombra := mapa.es_sombra(Vector2i(floori(punto.x), floori(punto.y)))
	var alcance := Config.VISION_ALCANCE_SOMBRA if en_sombra else Config.VISION_ALCANCE
	if distancia > alcance:
		return false
	if distancia > 0.001 and absf(angle_difference(mirada.angle(), hacia.angle())) > deg_to_rad(Config.VISION_ANGULO) / 2.0:
		return false
	return mapa.hay_linea_de_vision(pos, punto)


# --- Movimiento ---

func _patrullar(delta: float) -> void:
	if ruta.size() == 1:
		return
	var destino := Vector2(ruta[_indice]) + Vector2(0.5, 0.5)
	var hacia := destino - pos
	_girar_hacia(hacia, delta)
	if _pausa > 0.0:
		_pausa -= delta
		return
	var avance := Config.VAMPIRO_VELOCIDAD * delta
	if hacia.length() <= avance:
		pos = destino
		_pausa = azar.randf_range(Config.SOLDADO_PAUSA_RUTA_MIN, Config.SOLDADO_PAUSA_RUTA_MAX) if Soldado.patrullas_al_azar else Config.SOLDADO_PAUSA_RUTA
		if en_bucle:
			_indice = (_indice + 1) % ruta.size()
		else:
			if _indice + _sentido < 0 or _indice + _sentido >= ruta.size():
				_sentido = -_sentido
			_indice += _sentido
	else:
		pos += hacia.normalized() * avance


func _girar_hacia(hacia: Vector2, delta: float) -> void:
	if hacia.length() < 0.001:
		return
	var objetivo := hacia.angle()
	var actual := mirada.angle()
	var giro := clampf(angle_difference(actual, objetivo), -Config.SOLDADO_GIRO * delta, Config.SOLDADO_GIRO * delta)
	mirada = Vector2.from_angle(actual + giro)


func _draw() -> void:
	if derribado:
		draw_set_transform(Vector2.ZERO, PI / 2.0, Vector2(0.6, 1.0))
		Formas.capsula(self, ALTO_CAPSULA * 0.5, ANCHO_CAPSULA, Color(COLOR_CUERPO, 0.6), COLOR_CONTORNO)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	Formas.capsula(self, ALTO_CAPSULA, ANCHO_CAPSULA, COLOR_CUERPO, COLOR_CONTORNO)
	if mapa and mapa.mika and mapa.mika.objetivo_silencioso == self:
		var c := Vector2(0, -ALTO_CAPSULA - 46.0)
		var rombo := PackedVector2Array([c + Vector2(0, -9), c + Vector2(9, 0), c + Vector2(0, 9), c + Vector2(-9, 0), c + Vector2(0, -9)])
		draw_polyline(rombo, COLOR_MARCA_SILENCIOSO, 2.0, true)
	if estado == Estado.TESTIGO:
		# «!» y la barra de lo que le falta para delatar.
		var fuente := ThemeDB.fallback_font
		draw_string(fuente, Vector2(-10, -ALTO_CAPSULA - 30), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 28, COLOR_AVISO)
		var esquina := Vector2(-27, -ALTO_CAPSULA - 22.0)
		draw_rect(Rect2(esquina, Vector2(54, 8)), Color(0.04, 0.05, 0.08, 0.85))
		draw_rect(Rect2(esquina, Vector2(54 * aviso, 8)), COLOR_AVISO)
