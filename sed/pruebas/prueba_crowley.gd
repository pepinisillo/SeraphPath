extends "res://pruebas/comun.gd"
## Crowley Eusford, jefe de la zona 2: ataques con aviso (tajo, carga, torbellino), recuperación,
## segunda fase a media vida y rendición a 0. Y que sea justo: quedarse pegando sin esquivar
## pierde; salir de lo marcado en el suelo y pegarle mientras se recupera, gana.

const ESCENA := "res://escenas/mapa_cruce.tscn"


func _initialize():
	await process_frame
	print("A) Estructura")
	var m: Mapa = await cargar_mapa(ESCENA)
	var c: Crowley = m.crowley
	comprobar("Crowley está y se le puede atacar", [c != null, c in m.atacables(), c.vida], [true, true, Config.CROWLEY_VIDA])
	comprobar("no se le derriba por la espalda", c.admite_golpe_silencioso(), false)
	m.queue_free()

	print("B) Tajo con aviso: dentro duele, fuera no")
	m = await cargar_mapa(ESCENA)
	c = m.crowley
	m.mika.pos = c.pos + Vector2(-1.5, 0)
	var vida := m.mika.vida
	paso(m, Config.CROWLEY_PAUSA_ENTRE_ATAQUES + 0.05)
	comprobar("de cerca avisa un tajo", [c.estado, c.ataque], [Crowley.Estado.AVISA, Crowley.Ataque.TAJO])
	comprobar("Mika está dentro de lo marcado", c.en_zona_de_ataque(m.mika.pos), true)
	paso(m, Config.CROWLEY_AVISO + 0.05)
	comprobar("si no se mueve, le alcanza", m.mika.vida, vida - Config.CROWLEY_DANO)
	comprobar("y Crowley se queda recuperándose", c.estado, Crowley.Estado.RECUPERA)
	m.queue_free()
	m = await cargar_mapa(ESCENA)
	c = m.crowley
	m.mika.pos = c.pos + Vector2(-1.5, 0)
	vida = m.mika.vida
	paso(m, Config.CROWLEY_PAUSA_ENTRE_ATAQUES + 0.05)
	m.mika.pos = c.pos + Vector2(1.2, 0) # se pone a su espalda
	paso(m, Config.CROWLEY_AVISO + 0.05)
	comprobar("saliendo del abanico, falla", m.mika.vida, vida)
	m.queue_free()

	print("C) Carga de lejos")
	m = await cargar_mapa(ESCENA)
	c = m.crowley
	m.mika.pos = c.pos + Vector2(-6.5, 1.0)
	paso(m, Config.CROWLEY_PAUSA_ENTRE_ATAQUES + 0.05)
	comprobar("de lejos avisa una carga", [c.estado, c.ataque], [Crowley.Estado.AVISA, Crowley.Ataque.CARGA])
	m.queue_free()

	print("D) Daño, segunda fase y rendición")
	m = await cargar_mapa(ESCENA)
	c = m.crowley
	c.recibir_dano(4)
	comprobar("en guardia, el Tajo apenas le hace daño", c.vida, Config.CROWLEY_VIDA - 1)
	c.estado = Crowley.Estado.RECUPERA
	c.recibir_dano(4)
	comprobar("mientras se recupera, el Tajo entra entero", c.vida, Config.CROWLEY_VIDA - 5)
	c.recibir_dano(Config.CROWLEY_VIDA / 2)
	comprobar("a media vida, segunda fase", c.fase, 2)
	c.recibir_dano(100)
	comprobar("a 0 se rinde y Mika pasa", [c.estado, m.terminado], [Crowley.Estado.RENDIDO, true])
	m.queue_free()
	paused = false

	print("E) Justo: pegando sin esquivar pierde; esquivando y castigando gana")
	var sin_esquivar := await _pelear(false)
	print("    sin esquivar: gana=%s, vida de Mika %d, vida de Crowley %d, %.1f s" % sin_esquivar)
	comprobar("sin esquivar, cae", sin_esquivar[1] <= 0, true)
	var esquivando := await _pelear(true)
	print("    esquivando: gana=%s, vida de Mika %d, vida de Crowley %d, %.1f s" % esquivando)
	comprobar("esquivando y pegando en la recuperación, gana", esquivando[0], true)

	print("F) La zona 2 en la expedición")
	var e := EstadoExpedicion.actual()
	e.nueva()
	e.pasar_de_zona()
	comprobar("zona 2: Shinjuku", [e.zona, e.datos_zona().nombre, e.escena_infiltracion()], [2, "Ruinas de Shinjuku", "res://escenas/mapa_shinjuku.tscn"])
	e.indice = 1
	e.elegir_ruta("arriesgada")
	e.indice = 2
	comprobar("la ruta arriesgada pasa por la estación", e.escena_infiltracion(), "res://escenas/mapa_estacion.tscn")
	comprobar("el jefe es Crowley", [e.nombre_parada("jefe"), e.datos_zona().mapa_jefe], ["Jefe: Crowley Eusford", ESCENA])
	comprobar("los eventos de la zona 2", Eventos.de_zona(2).map(func(ev): return ev.id), ["soldado_atrapado", "jinete_dormido", "clinica", "carta"])
	e.indice = 5
	comprobar("tras Crowley no hay zona 3: se acaba", [e.zona_terminada(), e.ZONAS.has(3)], [true, false])
	e.activa = false
	terminar()


## Jugador automático. Sin `esquivar`: se pega a Crowley y da Tajos sin parar. Con `esquivar`:
## si va a estar dentro de lo marcado, se aparta; mientras Crowley se recupera, entra y le pega;
## si no, guarda distancia. Devuelve [ganó, vida de Mika, vida de Crowley, segundos].
func _pelear(esquivar: bool) -> Array:
	var m: Mapa = await cargar_mapa(ESCENA)
	var c: Crowley = m.crowley
	var mika := m.mika
	var t := 0.0
	while t < 90.0 and not m.terminado and not mika.caida:
		var hacia := c.pos - mika.pos
		var paso_mika := Vector2.ZERO
		if not esquivar:
			if hacia.length() > 1.0:
				paso_mika = hacia.normalized()
		elif c.estado == Crowley.Estado.AVISA and (c.en_zona_de_ataque(mika.pos) or hacia.length() < Config.CROWLEY_TORBELLINO_RADIO + 0.5):
			paso_mika = _salida(m, c, mika.pos)
		elif c.estado == Crowley.Estado.RECUPERA:
			if hacia.length() > 1.0:
				paso_mika = hacia.normalized()
		elif hacia.length() < 3.0:
			paso_mika = -hacia.normalized()
		var nueva := mika.pos + paso_mika * Config.VELOCIDAD_MIKA * DT
		if not m.es_muro(Vector2i(nueva.floor())) and nueva.x > 0 and nueva.y > 0 and nueva.x < m.ancho and nueva.y < m.alto:
			mika.pos = nueva
		if hacia.length() <= Config.TAJO_ALCANCE and (not esquivar or c.estado == Crowley.Estado.RECUPERA):
			mika.mirada = hacia.normalized()
			mika.tajo()
		mika.sed = 0
		paso(m)
		t += DT
	var resultado := [m.terminado and not mika.caida, mika.vida, c.vida, t]
	m.queue_free()
	paused = false
	return resultado


## Hacia dónde apartarse: lejos de Crowley y, en una carga, a un lado de la línea.
func _salida(m: Mapa, c: Crowley, p: Vector2) -> Vector2:
	var fuera := p - c.pos
	if c.ataque == Crowley.Ataque.CARGA:
		var cerca := Geometry2D.get_closest_point_to_segment(p, c._desde, c._hasta)
		fuera = p - cerca
		if fuera.length() < 0.01:
			fuera = Vector2(-(c._hasta - c._desde).y, (c._hasta - c._desde).x)
	fuera = fuera.normalized()
	if m.es_muro(Vector2i((p + fuera * 0.6).floor())):
		fuera = Vector2(-fuera.y, fuera.x)
	return fuera
