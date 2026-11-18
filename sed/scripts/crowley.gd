class_name Crowley
extends Node2D
## Crowley Eusford, jefe de la zona 2: combate abierto. Se acerca a Mika y ataca, siempre con
## aviso en el suelo:
## - Tajo: un abanico delante de él, de cerca.
## - Carga: una línea larga, de lejos (apunta adonde va a estar Mika, como Ferid).
## - Torbellino (solo en la segunda fase): un círculo a su alrededor.
## Tras cada ataque se queda un momento recuperándose: es cuando hay que pegarle (el resto del
## tiempo para los golpes y solo le entra una cuarta parte). A media vida
## empieza la segunda fase (más rápido, avisos más cortos). Cuando su vida llega a 0 se rinde:
## no se le vence del todo, pero deja pasar a Mika.
## Su posición vive en casillas.

enum Estado { ACECHA, AVISA, ATACA, RECUPERA, RENDIDO }
enum Ataque { TAJO, CARGA, TORBELLINO, SOMBRAS }

const COLOR_CUERPO := Paleta.VAMPIROS
const COLOR_CONTORNO := Paleta.BLANCO_HUESO
const COLOR_AVISO := Paleta.ROJO
const ALTO_CAPSULA := 132.0
const ANCHO_CAPSULA := 52.0

var mapa: Mapa
var pos := Vector2.ZERO # casillas
var mirada := Vector2(1, 0)
var vida := 0
var derribado := false # nunca: solo se rinde (para que Mika pueda apuntarle como a los demás)
var estado := Estado.ACECHA
var ataque := Ataque.TAJO
var fase := 1
var golpes_dados := 0 # veces que alcanzó a Mika
var frase := ""
var frases := {}

var _tiempo := 0.0
var _desde := Vector2.ZERO # carga: de dónde sale
var _hasta := Vector2.ZERO # y adónde llega
var _ya_golpeo := false # un ataque solo alcanza una vez
var _frase_restante := 0.0
var _hasta_frase := 2.0
var _hasta_otro_yuu := Config.FERID_FRASE_OTRO_YUU
var _numero_frase := 0
var _dicho_poca_vida := false
var _mika_antes := Vector2.ZERO
var _velocidad_mika := Vector2.ZERO
var _destello := 0.0
var _ataques_de_cerca := 0
var _p := {} # los números de este jefe (ver parametros)
var _sombras: Array[Vector2] = [] # Mahiru: dónde caen las sombras


## Los números de este jefe (Crowley: los CROWLEY_* de config.gd). Otro jefe de combate (Guren)
## hereda de este y da los suyos.
func parametros() -> Dictionary:
	return {
		"VIDA": Config.CROWLEY_VIDA, "DANO": Config.CROWLEY_DANO, "VELOCIDAD": Config.CROWLEY_VELOCIDAD,
		"AVISO": Config.CROWLEY_AVISO, "AVISO_TORBELLINO": Config.CROWLEY_AVISO_TORBELLINO,
		"RECUPERACION": Config.CROWLEY_RECUPERACION, "DANO_EN_GUARDIA": Config.CROWLEY_DANO_EN_GUARDIA,
		"PAUSA_ENTRE_ATAQUES": Config.CROWLEY_PAUSA_ENTRE_ATAQUES, "TAJO_ALCANCE": Config.CROWLEY_TAJO_ALCANCE,
		"TAJO_ANGULO": Config.CROWLEY_TAJO_ANGULO, "CARGA_ALCANCE": Config.CROWLEY_CARGA_ALCANCE,
		"CARGA_MINIMA": Config.CROWLEY_CARGA_MINIMA, "CARGA_DISTANCIA": Config.CROWLEY_CARGA_DISTANCIA,
		"CARGA_DURACION": Config.CROWLEY_CARGA_DURACION, "CARGA_ANCHO": Config.CROWLEY_CARGA_ANCHO,
		"TORBELLINO_RADIO": Config.CROWLEY_TORBELLINO_RADIO, "FASE2_VIDA": Config.CROWLEY_FASE2_VIDA,
		"FASE2_AVISO": Config.CROWLEY_FASE2_AVISO, "FASE2_VELOCIDAD": Config.CROWLEY_FASE2_VELOCIDAD,
		"POCA_VIDA": Config.CROWLEY_POCA_VIDA, "NOMBRE": "Crowley Eusford", "COLOR": Paleta.VAMPIROS,
	}


## El ataque especial de la segunda fase (Crowley: el torbellino).
func ataque_de_fase2() -> Ataque:
	return Ataque.TORBELLINO


func iniciar(p_mapa: Mapa, celda: Vector2i) -> void:
	mapa = p_mapa
	_p = parametros()
	vida = _p.VIDA
	pos = Vector2(celda) + Vector2(0.5, 0.5)
	frases = Guion.jefe_durante(_p.NOMBRE)
	position = Iso.a_pantalla(pos)


func _physics_process(delta: float) -> void:
	if mapa == null or mapa.mika == null or mapa.terminado or estado == Estado.RENDIDO:
		return
	var mika := mapa.mika
	if delta > 0.0 and _mika_antes != Vector2.ZERO:
		var v := (mika.pos - _mika_antes) / delta
		_velocidad_mika = _velocidad_mika.lerp(v, 0.3) if v.length() < 20.0 else Vector2.ZERO
	_mika_antes = mika.pos
	_tiempo += delta
	_destello -= delta
	match estado:
		Estado.ACECHA:
			_acechar(delta)
		Estado.AVISA:
			if _tiempo >= _aviso():
				_cambiar(Estado.ATACA)
				_ya_golpeo = false
		Estado.ATACA:
			_atacar()
		Estado.RECUPERA:
			if _tiempo >= _p.RECUPERACION:
				_cambiar(Estado.ACECHA)
	_hablar(delta)
	position = Iso.a_pantalla(pos)
	queue_redraw()


func _cambiar(nuevo: Estado) -> void:
	estado = nuevo
	_tiempo = 0.0


func _aviso() -> float:
	var base: float = _p.AVISO_TORBELLINO if ataque in [Ataque.TORBELLINO, Ataque.SOMBRAS] else _p.AVISO
	return base * (_p.FASE2_AVISO if fase == 2 else 1.0)


func _velocidad() -> float:
	return _p.VELOCIDAD * (_p.FASE2_VELOCIDAD if fase == 2 else 1.0)


## Se acerca; de cerca da un tajo (o, en la segunda fase, a veces un torbellino); de lejos, carga.
func _acechar(delta: float) -> void:
	var mika := mapa.mika
	var distancia := pos.distance_to(mika.pos)
	var hacia := mika.pos - pos
	if hacia.length() > 0.001:
		mirada = hacia.normalized()
	if _tiempo < _p.PAUSA_ENTRE_ATAQUES:
		_acercarse(delta)
		return
	if distancia <= _p.TAJO_ALCANCE:
		_ataques_de_cerca += 1
		# En la segunda fase, uno de cada dos ataques de cerca es el especial (torbellino o sombras).
		_preparar(ataque_de_fase2() if fase == 2 and _ataques_de_cerca % 2 == 0 else Ataque.TAJO)
	elif distancia <= _p.CARGA_ALCANCE and distancia >= _p.CARGA_MINIMA and mapa.hay_linea_de_vision(pos, mika.pos):
		_preparar(Ataque.CARGA)
	else:
		_acercarse(delta)


func _acercarse(delta: float) -> void:
	var camino := mapa.camino(pos, mapa.mika.pos)
	if camino.is_empty() or pos.distance_to(mapa.mika.pos) <= _p.TAJO_ALCANCE * 0.8:
		return
	var paso := camino[0] - pos
	var avance := _velocidad() * delta
	pos = camino[0] if paso.length() <= avance else pos + paso.normalized() * avance


func _preparar(cual: Ataque) -> void:
	ataque = cual
	if cual == Ataque.SOMBRAS:
		# Tres sombras: donde va a estar Mika y a los dos lados de ese punto.
		var previsto: Vector2 = mapa.mika.pos + _velocidad_mika * _aviso()
		var lado := Vector2(-mirada.y, mirada.x) * Config.GUREN_SOMBRAS_SEPARACION
		_sombras = [previsto, previsto + lado, previsto - lado]
	if cual == Ataque.CARGA:
		var previsto: Vector2 = mapa.mika.pos + _velocidad_mika * (_aviso() + _p.CARGA_DURACION * 0.5)
		var hacia: Vector2 = previsto - pos
		mirada = hacia.normalized() if hacia.length() > 0.001 else mirada
		var deseado := minf(hacia.length() + 1.5, _p.CARGA_DISTANCIA)
		var largo := mapa.distancia_hasta_muro(pos, mirada, deseado)
		_desde = pos
		_hasta = pos + mirada * maxf(0.0, (largo - 0.35) if largo < deseado else largo)
	_cambiar(Estado.AVISA)


func _atacar() -> void:
	var mika := mapa.mika
	match ataque:
		Ataque.TAJO:
			if not _ya_golpeo and en_zona_de_ataque(mika.pos):
				_golpear()
			_cambiar(Estado.RECUPERA)
		Ataque.TORBELLINO, Ataque.SOMBRAS:
			if not _ya_golpeo and en_zona_de_ataque(mika.pos):
				_golpear()
			_cambiar(Estado.RECUPERA)
		Ataque.CARGA:
			var f := clampf(_tiempo / _p.CARGA_DURACION, 0.0, 1.0)
			pos = _desde.lerp(_hasta, f)
			if not _ya_golpeo and pos.distance_to(mika.pos) <= _p.CARGA_ANCHO:
				_golpear()
			if f >= 1.0:
				_cambiar(Estado.RECUPERA)


## ¿El punto está dentro del ataque que va a dar ahora? (lo que se dibuja en el suelo)
func en_zona_de_ataque(punto: Vector2) -> bool:
	var hacia := punto - pos
	match ataque:
		Ataque.TAJO:
			return hacia.length() <= _p.TAJO_ALCANCE and absf(angle_difference(mirada.angle(), hacia.angle())) <= deg_to_rad(_p.TAJO_ANGULO) / 2.0
		Ataque.TORBELLINO:
			return hacia.length() <= _p.TORBELLINO_RADIO
		Ataque.SOMBRAS:
			for sombra in _sombras:
				if punto.distance_to(sombra) <= Config.GUREN_SOMBRAS_RADIO:
					return true
			return false
		_:
			var cerca := Geometry2D.get_closest_point_to_segment(punto, _desde, _hasta)
			return punto.distance_to(cerca) <= _p.CARGA_ANCHO


func _golpear() -> void:
	_ya_golpeo = true
	golpes_dados += 1
	mapa.mika.recibir_golpe(_p.DANO)


## Mika le da con el Tajo. Fuera de la recuperación para los golpes con la espada: solo le
## entra una parte (CROWLEY_DANO_EN_GUARDIA).
func recibir_dano(cantidad: int) -> void:
	if estado == Estado.RENDIDO:
		return
	if estado != Estado.RECUPERA:
		cantidad = ceili(cantidad * _p.DANO_EN_GUARDIA)
	vida = maxi(0, vida - cantidad)
	_destello = Config.DESTELLO_DURACION
	if fase == 1 and vida <= _p.VIDA * _p.FASE2_VIDA:
		fase = 2
		_decir_de("fase2", 0)
	elif not _dicho_poca_vida and vida <= _p.VIDA * _p.POCA_VIDA:
		_dicho_poca_vida = true
		_decir_de("poca_vida", 0)
	if vida <= 0:
		rendirse()


## «Suficiente. Me rindo»: el combate termina y Mika pasa.
func rendirse() -> void:
	estado = Estado.RENDIDO
	frase = ""
	mapa.terminar(true)


func admite_golpe_silencioso() -> bool:
	return false # a un noble no se le derriba por la espalda


func _hablar(delta: float) -> void:
	_frase_restante -= delta
	if _frase_restante <= 0.0:
		frase = ""
	_hasta_frase -= delta
	if _hasta_frase <= 0.0:
		_hasta_frase = Config.FERID_FRASE + 1.0
		_decir_de("persigue", _numero_frase)
		_numero_frase += 1
	_hasta_otro_yuu -= delta
	if _hasta_otro_yuu <= 0.0:
		_hasta_otro_yuu = Config.FERID_FRASE_OTRO_YUU
		var del_otro: PackedStringArray = frases.get("otro_yuu", PackedStringArray())
		var hud := mapa.get_node_or_null("HUD")
		if mapa.mika.humanidad >= 1 and not del_otro.is_empty() and hud:
			hud.decir(del_otro[randi() % del_otro.size()])


func _decir_de(clave: String, numero: int) -> void:
	var lista: PackedStringArray = frases.get(clave, PackedStringArray())
	if lista.is_empty():
		return
	frase = lista[numero % lista.size()]
	_frase_restante = Config.FERID_FRASE


func _draw() -> void:
	if estado == Estado.AVISA:
		var f := clampf(_tiempo / _aviso(), 0.0, 1.0)
		var color := Color(COLOR_AVISO, 0.25 + 0.45 * f)
		match ataque:
			Ataque.TAJO:
				var puntos := PackedVector2Array([Vector2.ZERO])
				var medio := deg_to_rad(_p.TAJO_ANGULO) / 2.0
				for i in 13:
					var a := mirada.angle() - medio + 2.0 * medio * i / 12.0
					puntos.append(Iso.a_pantalla(pos + Vector2.from_angle(a) * _p.TAJO_ALCANCE) - position)
				draw_colored_polygon(puntos, color)
			Ataque.TORBELLINO:
				var puntos := PackedVector2Array()
				for i in 24:
					puntos.append(Iso.a_pantalla(pos + Vector2.from_angle(TAU * i / 24.0) * _p.TORBELLINO_RADIO) - position)
				draw_colored_polygon(puntos, color)
			Ataque.CARGA:
				draw_line(Iso.a_pantalla(_desde) - position, Iso.a_pantalla(_hasta) - position, color, 10.0 + 10.0 * f)
			Ataque.SOMBRAS:
				for sombra in _sombras:
					var puntos := PackedVector2Array()
					for i in 20:
						puntos.append(Iso.a_pantalla(sombra + Vector2.from_angle(TAU * i / 20.0) * Config.GUREN_SOMBRAS_RADIO) - position)
					draw_colored_polygon(puntos, color)
	var color_cuerpo: Color = _p.get("COLOR", COLOR_CUERPO)
	var cuerpo := color_cuerpo.lerp(Paleta.BLANCO_HUESO, 0.6) if _destello > 0.0 else color_cuerpo
	if estado == Estado.RECUPERA:
		cuerpo = cuerpo.darkened(0.3) # se ve que está expuesto
	Formas.capsula(self, ALTO_CAPSULA, ANCHO_CAPSULA, cuerpo, COLOR_CONTORNO)
	if frase != "":
		var fuente := ThemeDB.fallback_font
		var ancho := fuente.get_string_size(frase, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 20
		draw_rect(Rect2(-ancho / 2.0, -ALTO_CAPSULA - 58, ancho, 26), Color(0.04, 0.05, 0.08, 0.85))
		draw_string(fuente, Vector2(-ancho / 2.0, -ALTO_CAPSULA - 40), frase, HORIZONTAL_ALIGNMENT_CENTER, ancho, 16, Paleta.BLANCO_HUESO)
