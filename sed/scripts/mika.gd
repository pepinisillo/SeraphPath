class_name Mika
extends Node2D
## Mika. Su posición real vive en coordenadas de casilla (pos); `position` solo se deriva al dibujar.
## Acciones: Tajo (daño y ruido), Golpe silencioso (derriba sin ruido), Impulso (dash con ruido),
## beber sangre de un humano derribado y tomar un vial de Krul.
## La sed sube sola; en Frenesí Mika pierde el control y va a beber del humano más cercano.
## En la Prueba de la sed no puede atacar ni tomar viales, no hay Frenesí, la sed sube más rápido
## (y más con ecos cerca) y solo puede beber de los ecos, que le cortan el paso.

signal mejora_pendiente(opciones: Array[String])
signal mejora_elegida
signal derrotada

const COLOR_CUERPO := Paleta.BLANCO_HUESO
const COLOR_CONTORNO := Paleta.DETALLES
const COLOR_FRENESI := Paleta.ROJO
const COLOR_MIRADA := Paleta.CALMA
const COLOR_TAJO := Paleta.BLANCO_HUESO
const COLOR_SANGRE := Paleta.ROJO

const ALTO_CAPSULA := 110.0 # px
const ANCHO_CAPSULA := 40.0 # px
const PASO_MAXIMO := 0.1 # casillas por subpaso, para no atravesar muros a gran velocidad
const TAJO_VISIBLE := 0.12 # s que se ve el arco del Tajo

var mapa: Mapa
var pos := Vector2.ZERO # casillas
var mirada := Vector2(1, 1).normalized() # dirección en casillas
var direccion := 0 # una de 8 direcciones de pantalla, 0 = derecha, en sentido horario
## Soldado al que derribaría ahora un Golpe silencioso (o null). Él dibuja la marca.
var objetivo_silencioso: Node2D = null # Soldado o Vampiro
## Cuerpo del que puede beber ahora (o null). Él dibuja el aviso.
var objetivo_beber: Soldado = null
## En la Prueba de la sed: eco del que puede beber ahora (o null). Él dibuja el aviso.
var objetivo_eco: Eco = null
## Ofreció una mejora y espera a que se elija.
var mejora_en_espera := false

# Estado vital
var vida := Config.VIDA_MIKA
var vida_max := Config.VIDA_MIKA
var sed := Config.SED_INICIAL
var humanidad := Config.HUMANIDAD_INICIAL
var viales := 0
var mejoras: Array[String] = []
var filos: Array[String] = [] # filos de la espada (como mucho Config.FILOS_MAX)
var caida := false
var rng := RandomNumberGenerator.new()

# Modificadores que ponen la expedición y los recuerdos (por defecto, las reglas de Config).
var sed_por_golpe := Config.SED_POR_GOLPE
var sed_impulso := Config.IMPULSO_SED
var tramo_lento := Config.SED_TRAMO_LENTO
var salvacion_disponible := false # recuerdo 4: sobrevive una vez con 1 de vida
var sed_congelada := false # evento «La carta sin enviar»: la sed no sube en este mapa

var _impulso_restante := 0.0 # s que quedan de dash; > 0 mientras dura
var _impulso_dir := Vector2.ZERO
var _enfriamiento_impulso := 0.0
var _enfriamiento_tajo := 0.0
var _enfriamiento_golpe := 0.0
var _tajo_restante := 0.0
var _acumulado_sed := 0.0
var _acumulado_regeneracion := 0.0
var _bebiendo = null # el Soldado derribado o el Eco del que bebe
var _beber_forzado := false # bebe en Frenesí: no hace falta mantener el botón
var _bebido := 0.0 # s que lleva bebiendo
var _vial_restante := 0.0
var _frenesi_restante := 0.0
var _respiro := 0.0
var _destello := 0.0 # s que quedan de destello rojo al recibir un golpe
var _hasta_silueta := 0.0 # s hasta la próxima silueta del rastro del dash
var _sentidos_restante := 0.0
var _enfriamiento_sentidos := 0.0
var _espada_restante := 0.0 # «Espada, bebe mi sangre»
var _sombra_restante := 0.0 # Filo de sombra: velocidad tras un Golpe silencioso


func iniciar(p_mapa: Mapa, p_pos: Vector2) -> void:
	mapa = p_mapa
	pos = p_pos
	position = Iso.a_pantalla(pos)
	$Camara.reset_smoothing()


func celda() -> Vector2i:
	return Vector2i(floori(pos.x), floori(pos.y))


func esta_impulsando() -> bool:
	return _impulso_restante > 0.0


func esta_bebiendo() -> bool:
	return _bebiendo != null


func en_frenesi() -> bool:
	return _frenesi_restante > 0.0


## El Frenesí pasó sin que bebiera: un respiro antes de poder volver a perderse.
func en_respiro() -> bool:
	return _respiro > 0.0


## El jugador no la controla: Frenesí o el trago que lo cierra.
func sin_control() -> bool:
	return en_frenesi() or (esta_bebiendo() and _beber_forzado)


## Fracción completada de lo que está bebiendo (sangre o vial), o -1 si no bebe nada.
func progreso_bebida() -> float:
	if esta_bebiendo():
		return _bebido / Config.BEBER_DURACION
	if _vial_restante > 0.0:
		return 1.0 - _vial_restante / Config.VIAL_DURACION
	return -1.0


func tiene_mejora(id: String) -> bool:
	return id in mejoras


func tiene_filo(id: String) -> bool:
	return id in filos


## Sentidos activos: los enemigos se ven tras las paredes.
func revelando() -> bool:
	return _sentidos_restante > 0.0


func espada_activa() -> bool:
	return _espada_restante > 0.0


func sentidos_listos() -> bool:
	return _enfriamiento_sentidos <= 0.0 and sed < tramo_lento


## Sentidos: revela a todos los enemigos tras las paredes unos segundos. Enfriamiento largo;
## sediento no se puede usar.
func usar_sentidos() -> bool:
	if not sentidos_listos() or mapa.prueba_de_la_sed:
		return false
	_sentidos_restante = Config.SENTIDOS_DURACION * (2.0 if tiene_filo(Filos.CAZADOR) else 1.0)
	_enfriamiento_sentidos = Config.SENTIDOS_ENFRIAMIENTO
	return true


func coste_espada() -> int:
	return Config.ESPADA_COSTE_SEDIENTO if tiene_filo(Filos.SEDIENTO) else Config.ESPADA_COSTE


## «Espada, bebe mi sangre»: paga vida y durante unos segundos el Tajo hace el doble de daño y
## llega más lejos. Los vampiros cercanos la huelen. No mata a Mika: con poca vida no se puede.
func activar_espada() -> bool:
	if espada_activa() or vida <= coste_espada() or mapa.prueba_de_la_sed:
		return false
	vida -= coste_espada()
	_espada_restante = Config.ESPADA_DURACION
	_destello = Config.DESTELLO_DURACION
	return true

func velocidad() -> float:
	if mapa != null and mapa.prueba_de_la_sed:
		return Config.PRUEBA_VELOCIDAD_MIKA
	var base := Config.VELOCIDAD_MIKA_SEDIENTO if sed >= tramo_lento else Config.VELOCIDAD_MIKA
	base += Config.MEJORA_VELOCIDAD if tiene_mejora(Mejoras.VELOCIDAD) else 0.0
	return base + (Config.FILO_SOMBRA_VELOCIDAD if _sombra_restante > 0.0 else 0.0)


func dano_tajo() -> int:
	var dano := Config.TAJO_DANO + (Config.MEJORA_FUERZA if tiene_mejora(Mejoras.FUERZA) else 0)
	return dano * (2 if espada_activa() else 1)


func alcance_tajo() -> float:
	return Config.TAJO_ALCANCE * (Config.ESPADA_ALCANCE if espada_activa() else 1.0)


## El Tajo alcanza al objetivo: en el arco normal o, con el Filo largo, el doble de lejos en
## línea recta (un arco estrecho delante).
func _alcanza_tajo(objetivo: Node2D) -> bool:
	if _al_alcance(objetivo, alcance_tajo()):
		return true
	if not tiene_filo(Filos.LARGO) or objetivo.derribado:
		return false
	var hacia: Vector2 = objetivo.pos - pos
	return hacia.length() <= alcance_tajo() * 2.0 and absf(angle_difference(mirada.angle(), hacia.angle())) <= deg_to_rad(Config.FILO_LARGO_ANGULO) / 2.0


func _physics_process(delta: float) -> void:
	if mapa == null or caida or mapa.terminado:
		return
	_enfriamiento_impulso -= delta
	_enfriamiento_tajo -= delta
	_enfriamiento_golpe -= delta
	_tajo_restante -= delta
	_respiro -= delta
	_destello -= delta
	_sentidos_restante -= delta
	_enfriamiento_sentidos -= delta
	_espada_restante -= delta
	_sombra_restante -= delta
	_actualizar_sed(delta)
	_actualizar_regeneracion(delta)
	if mapa.prueba_de_la_sed:
		if sed >= Config.SED_MAX:
			mapa.terminar(false, "fallida")
			return
	elif sed >= Config.SED_TRAMO_FRENESI and not en_frenesi() and not esta_bebiendo() and _respiro <= 0.0:
		_frenesi_restante = Config.FRENESI_DURACION

	objetivo_beber = _buscar_cuerpo()
	objetivo_eco = _buscar_eco()
	if esta_bebiendo():
		_seguir_bebiendo(delta)
	elif en_frenesi():
		_frenesi(delta)
	elif _vial_restante > 0.0:
		_seguir_con_vial(delta)
	elif esta_impulsando():
		_impulsar(delta)
	else:
		_control(delta)

	if mapa.es_salida(celda()):
		mapa.terminar(true)
		return

	objetivo_silencioso = null if sin_control() else _buscar_objetivo_silencioso()
	direccion = Formas.direccion_8(mirada)
	position = Iso.a_pantalla(pos)
	queue_redraw()


func _control(delta: float) -> void:
	var entrada := Input.get_vector("mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo")
	if entrada != Vector2.ZERO:
		var dir := Iso.direccion_desde_pantalla(entrada)
		mover(dir * velocidad() * delta)
		mirada = dir.normalized()
	if Input.is_action_just_pressed("impulso"):
		impulso(entrada)
	elif mapa.prueba_de_la_sed:
		if Input.is_action_pressed("beber"):
			empezar_a_beber() # en su mente no hay ataques ni viales
	elif Input.is_action_just_pressed("tajo"):
		tajo()
	elif Input.is_action_just_pressed("golpe_silencioso"):
		golpe_silencioso()
	elif Input.is_action_just_pressed("vial"):
		tomar_vial()
	elif Input.is_action_just_pressed("sentidos"):
		usar_sentidos()
	elif Input.is_action_just_pressed("espada"):
		activar_espada()
	elif Input.is_action_pressed("beber"):
		empezar_a_beber()


# --- Sed, vida y Humanidad ---

func sumar_sed(cantidad: int) -> void:
	if sed_congelada and cantidad > 0:
		return
	sed = clampi(sed + cantidad, 0, Config.SED_MAX)


## Fuera: +1 cada SED_INTERVALO s. En la Prueba de la sed: +1 cada PRUEBA_SED_INTERVALO s,
## y otro +1 en ese tiempo por cada eco a menos de PRUEBA_ECO_DISTANCIA casillas.
func _actualizar_sed(delta: float) -> void:
	var ritmo := 1.0 / Config.SED_INTERVALO # puntos por segundo
	if mapa.prueba_de_la_sed:
		ritmo = (1.0 + ecos_cerca()) / Config.PRUEBA_SED_INTERVALO
	elif tiene_filo(Filos.PACIENTE) and mapa.es_sombra(celda()):
		ritmo = 0.0 # Filo paciente: en sombra la sed no sube
	_acumulado_sed += delta * ritmo
	while _acumulado_sed >= 1.0:
		_acumulado_sed -= 1.0
		sumar_sed(1)


func ecos_cerca() -> int:
	var n := 0
	for eco in mapa.ecos():
		if not eco.bebido and pos.distance_to(eco.pos) < Config.PRUEBA_ECO_DISTANCIA:
			n += 1
	return n


func _actualizar_regeneracion(delta: float) -> void:
	var regenera := sed <= Config.SED_TRAMO_REGENERA or tiene_mejora(Mejoras.REGENERACION)
	if not regenera or vida >= vida_max:
		_acumulado_regeneracion = 0.0
		return
	_acumulado_regeneracion += delta
	if _acumulado_regeneracion >= Config.REGENERACION_INTERVALO:
		_acumulado_regeneracion -= Config.REGENERACION_INTERVALO
		vida += 1


func recibir_golpe(dano: int) -> void:
	if caida:
		return
	vida -= dano
	sumar_sed(sed_por_golpe)
	if vida <= 0 and salvacion_disponible:
		vida = 1 # recuerdo 4, «La puerta»: una vez por expedición
		salvacion_disponible = false
	_destello = Config.DESTELLO_DURACION
	mapa.efectos.golpe_recibido(pos)
	if vida <= 0:
		vida = 0
		caida = true
		mapa.efectos.caida()
		_bebiendo = null
		_frenesi_restante = 0.0
		queue_redraw()
		derrotada.emit()


func elegir_mejora(id: String) -> void:
	if tiene_mejora(id):
		return
	mejoras.append(id)
	if id == Mejoras.VIGOR:
		vida_max += Config.MEJORA_VIGOR
		vida += Config.MEJORA_VIGOR
	mejora_en_espera = false
	mejora_elegida.emit()


# --- Beber ---

## Empieza a beber del cuerpo (o, en la Prueba de la sed, del eco) más cercano.
## Si no es forzado, hay que mantener el botón.
func empezar_a_beber(forzado := false) -> bool:
	var fuente = objetivo_eco if mapa.prueba_de_la_sed else objetivo_beber
	if fuente == null or esta_bebiendo():
		return false
	_bebiendo = fuente
	_beber_forzado = forzado
	_bebido = 0.0
	if _bebiendo.pos.distance_to(pos) > 0.01:
		mirada = (_bebiendo.pos - pos).normalized()
	return true


func _seguir_bebiendo(delta: float) -> void:
	if not _beber_forzado and not Input.is_action_pressed("beber"):
		_bebiendo = null # soltó el botón: no bebe
		return
	_bebido += delta
	if _bebido >= Config.BEBER_DURACION:
		_terminar_de_beber()


func _terminar_de_beber() -> void:
	var fuente = _bebiendo
	if fuente is Eco:
		fuente.beber()
	else:
		fuente.bebido = true
	_bebiendo = null
	_beber_forzado = false
	_frenesi_restante = 0.0
	sed = 0
	_acumulado_sed = 0.0
	vida = vida_max
	humanidad = maxi(0, humanidad - 1)
	mapa.estadisticas.sangre_bebida += 1
	mapa.efectos.trago(pos, Paleta.ROJO)
	_ofrecer_mejora()
	if fuente is Eco:
		mapa.ceder()


## Dos mejoras al azar entre las que aún no tiene. La interfaz muestra la elección.
func _ofrecer_mejora() -> void:
	var disponibles: Array[String] = []
	for id in Mejoras.TODAS:
		if not tiene_mejora(id):
			disponibles.append(id)
	if disponibles.is_empty():
		return
	mejora_en_espera = true
	for i in range(disponibles.size() - 1, 0, -1): # barajar con el generador propio
		var j := rng.randi_range(0, i)
		var tmp := disponibles[i]
		disponibles[i] = disponibles[j]
		disponibles[j] = tmp
	mejora_pendiente.emit(disponibles.slice(0, 2))


func _buscar_eco() -> Eco:
	var mejor: Eco = null
	for eco in mapa.ecos():
		if not eco.bebido and pos.distance_to(eco.pos) <= Config.BEBER_DISTANCIA:
			if mejor == null or pos.distance_to(eco.pos) < pos.distance_to(mejor.pos):
				mejor = eco
	return mejor


func _buscar_cuerpo() -> Soldado:
	var mejor: Soldado = null
	for soldado in mapa.soldados():
		if soldado.derribado and not soldado.bebido and pos.distance_to(soldado.pos) <= Config.BEBER_DISTANCIA:
			if mejor == null or pos.distance_to(soldado.pos) < pos.distance_to(mejor.pos):
				mejor = soldado
	return mejor


# --- Vial ---

func tomar_vial() -> bool:
	if viales <= 0 or _vial_restante > 0.0:
		return false
	_vial_restante = Config.VIAL_DURACION
	return true


func _seguir_con_vial(delta: float) -> void:
	_vial_restante -= delta
	if _vial_restante <= 0.0:
		_vial_restante = 0.0
		viales -= 1
		sumar_sed(Config.FILO_KRUL_VIAL if tiene_filo(Filos.KRUL) else Config.VIAL_SED)
		mapa.efectos.trago(pos, Paleta.TURQUESA)


# --- Frenesí ---

## Va por el humano más cercano: si está en pie lo derriba con el Tajo, y luego bebe.
func _frenesi(delta: float) -> void:
	_frenesi_restante -= delta
	if _frenesi_restante <= 0.0:
		_frenesi_restante = 0.0
		_respiro = Config.FRENESI_RESPIRO # no encontró a nadie: un respiro antes de volver a perderse
		return
	var presa := _humano_mas_cercano()
	if presa == null:
		return
	var hacia := presa.pos - pos
	if presa.derribado and hacia.length() <= Config.BEBER_DISTANCIA:
		objetivo_beber = presa
		empezar_a_beber(true)
		_frenesi_restante = 0.0
		return
	if not presa.derribado and hacia.length() <= Config.TAJO_ALCANCE * 0.9:
		mirada = hacia.normalized()
		tajo()
		return
	var camino := mapa.camino(pos, presa.pos)
	if camino.is_empty():
		return
	var paso := camino[0] - pos
	if paso.length() > 0.001:
		mirada = paso.normalized()
		mover(mirada * minf(velocidad() * delta, paso.length()))


func _humano_mas_cercano() -> Soldado:
	var mejor: Soldado = null
	for soldado in mapa.soldados():
		if soldado.bebido:
			continue
		if mejor == null or pos.distance_to(soldado.pos) < pos.distance_to(mejor.pos):
			mejor = soldado
	return mejor


# --- Acciones de combate ---

## Daña a todos los soldados al alcance delante de Mika. Hace ruido.
func tajo() -> bool:
	if _enfriamiento_tajo > 0.0 or esta_impulsando():
		return false
	_enfriamiento_tajo = Config.TAJO_ENFRIAMIENTO
	_tajo_restante = TAJO_VISIBLE
	var conecto := false
	var a_un_vampiro := false
	for soldado in mapa.atacables():
		if _alcanza_tajo(soldado) and not soldado.derribado:
			a_un_vampiro = a_un_vampiro or soldado is Vampiro
			soldado.recibir_dano(dano_tajo())
			if soldado.derribado:
				mapa.estadisticas.derribados_con_tajo += 1
				if soldado is Soldado and tiene_filo(Filos.ARTERIAL):
					sumar_sed(Config.FILO_ARTERIAL_SED) # bebe la espada: no cuesta Humanidad
			if conecto:
				mapa.efectos.salpicar(soldado.pos, Paleta.ROJO, 18)
			else:
				mapa.efectos.tajo_conectado(soldado.pos) # una sola parada por Tajo
			conecto = true
	if a_un_vampiro:
		mapa.acto_prohibido("ataque")
	if not tiene_filo(Filos.MUDO):
		mapa.hacer_ruido(pos)
	return true


## Derriba sin ruido al soldado (o vampiro) marcado. Sin objetivo válido no hace nada.
func golpe_silencioso() -> bool:
	if _enfriamiento_golpe > 0.0 or esta_impulsando():
		return false
	var objetivo := _buscar_objetivo_silencioso()
	if objetivo == null:
		return false
	_enfriamiento_golpe = Config.GOLPE_SILENCIOSO_ENFRIAMIENTO
	var golpeados: Array = [objetivo]
	if tiene_filo(Filos.DOBLE):
		# Filo doble: también al enemigo más cercano junto al primero, si admite el golpe.
		var segundo: Node2D = null
		for otro in mapa.atacables():
			if otro != objetivo and otro.pos.distance_to(objetivo.pos) <= Config.FILO_DOBLE_DISTANCIA and otro.admite_golpe_silencioso():
				if segundo == null or otro.pos.distance_to(objetivo.pos) < segundo.pos.distance_to(objetivo.pos):
					segundo = otro
		if segundo != null:
			golpeados.append(segundo)
	for golpeado in golpeados:
		golpeado.recibir_golpe_silencioso()
		mapa.estadisticas.derribados_en_silencio += 1
		if golpeado is Vampiro:
			mapa.acto_prohibido("ataque")
		mapa.efectos.derribo_silencioso(golpeado.pos)
	if tiene_filo(Filos.SOMBRA):
		_sombra_restante = Config.FILO_SOMBRA_DURACION
	return true


## Dash hacia donde apunta la entrada (o hacia donde mira, si no hay entrada). Sube la sed
## y hace ruido donde empieza.
func impulso(entrada: Vector2) -> bool:
	if _enfriamiento_impulso > 0.0 or esta_impulsando():
		return false
	_impulso_dir = Iso.direccion_desde_pantalla(entrada).normalized() if entrada != Vector2.ZERO else mirada
	mirada = _impulso_dir
	_impulso_restante = Config.IMPULSO_DURACION
	_enfriamiento_impulso = Config.IMPULSO_ENFRIAMIENTO
	_hasta_silueta = 0.0
	sumar_sed(sed_impulso)
	if not tiene_filo(Filos.VELOZ):
		mapa.hacer_ruido(pos)
	return true


func _impulsar(delta: float) -> void:
	_hasta_silueta -= delta
	if _hasta_silueta <= 0.0:
		mapa.efectos.silueta(pos)
		_hasta_silueta += Config.RASTRO_INTERVALO
	var tramo := minf(delta, _impulso_restante)
	mover(_impulso_dir * (Config.IMPULSO_DISTANCIA / Config.IMPULSO_DURACION) * tramo)
	_impulso_restante -= tramo
	if _impulso_restante < 0.0001:
		_impulso_restante = 0.0 # evita un fotograma extra por redondeo


## Soldado en pie, a menos de `alcance` casillas y dentro del arco de ataque delante de Mika.
func _al_alcance(soldado: Node2D, alcance: float) -> bool:
	if soldado.derribado:
		return false
	var hacia: Vector2 = soldado.pos - pos
	if hacia.length() > alcance:
		return false
	if hacia.length() < 0.3:
		return true # encima de él: no importa hacia dónde mire
	return absf(angle_difference(mirada.angle(), hacia.angle())) <= deg_to_rad(Config.ATAQUE_ANGULO) / 2.0


func _buscar_objetivo_silencioso() -> Node2D:
	var mejor: Node2D = null
	for soldado in mapa.atacables():
		if _al_alcance(soldado, Config.GOLPE_SILENCIOSO_ALCANCE) and soldado.admite_golpe_silencioso():
			if mejor == null or pos.distance_to(soldado.pos) < pos.distance_to(mejor.pos):
				mejor = soldado
	return mejor


# --- Movimiento ---

## Mueve en coordenadas de casilla, deslizando contra los muros.
func mover(desplazamiento: Vector2) -> void:
	var pasos := maxi(1, ceili(desplazamiento.length() / PASO_MAXIMO))
	var paso := desplazamiento / pasos
	for i in pasos:
		pos += paso
		_salir_de_ecos()
		_salir_de_muros()


## Los ecos cortan el paso: Mika no puede atravesarlos.
func _salir_de_ecos() -> void:
	var minimo := Config.RADIO_MIKA + Config.PRUEBA_ECO_RADIO
	for eco in mapa.ecos():
		if eco.bebido:
			continue
		var dif := pos - eco.pos
		var dist := dif.length()
		if dist < minimo:
			pos = eco.pos + (dif / dist if dist > 0.0001 else Vector2.RIGHT) * minimo


## Empuja el círculo de Mika fuera de cualquier casilla de muro que toque.
func _salir_de_muros() -> void:
	var r := Config.RADIO_MIKA
	var base := celda()
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := base + Vector2i(dx, dy)
			if not mapa.es_muro(c):
				continue
			var cercano := Vector2(
				clampf(pos.x, c.x, c.x + 1.0),
				clampf(pos.y, c.y, c.y + 1.0))
			var dif := pos - cercano
			var dist := dif.length()
			if dist < r:
				if dist > 0.0001:
					pos += dif / dist * (r - dist)
				else:
					# El centro quedó dentro del muro: salir por el lado más cercano.
					pos = Vector2(c) + Vector2(0.5, 0.5) + (pos - Vector2(c) - Vector2(0.5, 0.5)).normalized() * (0.5 + r)


# --- Dibujo ---

func _draw() -> void:
	if caida:
		Formas.caido(self, ALTO_CAPSULA * 0.8, ANCHO_CAPSULA * 0.8, COLOR_CUERPO.darkened(0.3), COLOR_CONTORNO)
		return
	if _tajo_restante > 0.0:
		_dibujar_tajo()
	Formas.mirada(self, mirada, COLOR_MIRADA)
	var cuerpo := COLOR_CUERPO
	if _destello > 0.0:
		cuerpo = cuerpo.lerp(Paleta.ROJO, _destello / Config.DESTELLO_DURACION)
	if esta_impulsando():
		cuerpo.a = 0.6
	var contorno := COLOR_FRENESI if sin_control() else COLOR_CONTORNO
	Formas.capsula(self, ALTO_CAPSULA, ANCHO_CAPSULA, cuerpo, contorno)

	var progreso := progreso_bebida()
	if progreso >= 0.0:
		var centro := Vector2(0, -ALTO_CAPSULA - 24.0)
		draw_arc(centro, 12.0, 0.0, TAU, 24, Color(0, 0, 0, 0.6), 5.0)
		draw_arc(centro, 12.0, -PI / 2.0, -PI / 2.0 + TAU * progreso, 24, COLOR_SANGRE, 5.0)


## Arco en el suelo con el alcance y el ángulo reales del Tajo.
func _dibujar_tajo() -> void:
	var medio := deg_to_rad(Config.ATAQUE_ANGULO) / 2.0
	var puntos := PackedVector2Array()
	for i in 13:
		var angulo := mirada.angle() - medio + 2.0 * medio * i / 12.0
		var punto := Vector2.from_angle(angulo) * Config.TAJO_ALCANCE
		puntos.append(Iso.a_pantalla(punto) - Iso.a_pantalla(Vector2.ZERO))
	var alfa := _tajo_restante / TAJO_VISIBLE
	draw_polyline(puntos, Color(COLOR_TAJO, alfa), 6.0, true)
