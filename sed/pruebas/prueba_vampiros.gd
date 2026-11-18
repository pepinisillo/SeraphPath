extends "res://pruebas/comun.gd"
## Vampiro común: no reacciona a Mika por verlo, pero lo delata si lo ve en una zona prohibida,
## robando un vial, atacando a un vampiro o junto a un vampiro derribado. Se le puede callar
## derribándolo antes de que delate. Y los efectos de los eventos que dependen de ellos.

const PUESTO := "res://escenas/mapa_puesto_control.tscn"
const TUNELES := "res://escenas/mapa_tuneles.tscn"


## Deja al vampiro quieto en `p`, mirando hacia `mirada`.
func plantar(v: Vampiro, p: Vector2, mirada: Vector2) -> void:
	v.pos = p
	v.mirada = mirada.normalized()
	v._pausa = 100.0
	v._indice = 0
	v.ruta = [Vector2i(p.floor()), Vector2i(p.floor())] as Array[Vector2i]


func _initialize():
	await process_frame
	print("A) Verlo pasar no le importa")
	var m: Mapa = await cargar_mapa(PUESTO)
	var v: Vampiro = m.get_node("VP1")
	comprobar("hay un vampiro y zona prohibida", [m.vampiros().size(), m.es_prohibida(Vector2i(24, 12)), m.es_prohibida(Vector2i(24, 14))], [1, true, false])
	plantar(v, Vector2(24.5, 17.5), Vector2(0, -1))
	m.mika.pos = Vector2(24.5, 14.5)
	paso(m, 2.0)
	comprobar("lo ve, pero sigue en calma", [v.puede_ver(m.mika.pos), v.estado, m.alerta.activa], [true, Vampiro.Estado.CALMA, false])
	comprobar("los vampiros no dan sangre", v.bebido, true)

	print("B) Zona prohibida: lo delata")
	m.mika.pos = Vector2(24.5, 12.5)
	paso(m, Config.VAMPIRO_PROHIBIDA - 0.1)
	comprobar("un momento en la zona aún no", v.estado, Vampiro.Estado.CALMA)
	paso(m, 0.2)
	comprobar("si se queda, se convierte en testigo", [v.estado, v.motivo], [Vampiro.Estado.TESTIGO, "prohibida"])
	paso(m, Config.VAMPIRO_AVISO + 0.05)
	comprobar("pasado el aviso, delata: alarma", [v.estado, m.alerta.activa, m.estadisticas.delaciones], [Vampiro.Estado.DELATO, true, 1])
	paso(m, 1.0)
	comprobar("mientras dura la alarma no vuelve a delatar", [v.estado, m.estadisticas.delaciones], [Vampiro.Estado.DELATO, 1])
	m.queue_free()

	print("C) Callarlo a tiempo")
	m = await cargar_mapa(PUESTO)
	v = m.get_node("VP1")
	plantar(v, Vector2(24.5, 15.5), Vector2(0, -1))
	m.mika.pos = Vector2(24.5, 12.5)
	paso(m, Config.VAMPIRO_PROHIBIDA + 0.1)
	comprobar("testigo", v.estado, Vampiro.Estado.TESTIGO)
	m.mika.pos = v.pos + Vector2(0, -1.0)
	m.mika.mirada = Vector2(0, 1)
	m.mika.tajo()
	paso(m, Config.TAJO_ENFRIAMIENTO + 0.05)
	m.mika.tajo()
	paso(m, 0.1)
	comprobar("dos Tajos lo derriban antes de que delate", [v.derribado, m.alerta.activa], [true, false])
	m.queue_free()

	print("D) Golpe silencioso por la espalda")
	m = await cargar_mapa(PUESTO)
	v = m.get_node("VP1")
	plantar(v, Vector2(24.5, 15.5), Vector2(0, -1))
	m.mika.pos = v.pos + Vector2(0, 0.9)
	m.mika.mirada = Vector2(0, -1)
	paso(m)
	comprobar("por la espalda se le puede derribar en silencio", m.mika.objetivo_silencioso == v, true)
	m.mika.golpe_silencioso()
	paso(m, 0.1)
	comprobar("derribado, sin alarma", [v.derribado, m.alerta.activa], [true, false])
	m.queue_free()

	print("E) Robar un vial a la vista")
	m = await cargar_mapa(TUNELES)
	v = m.get_node("VT1")
	plantar(v, Vector2(25.5, 13.5), Vector2(3, 2))
	m.mika.pos = Vector2(28.5, 15.5) # encima del vial
	paso(m)
	comprobar("lo coge y el vampiro lo ve", [m.mika.viales, v.estado, v.motivo], [1, Vampiro.Estado.TESTIGO, "vial"])
	m.queue_free()

	print("F) Atacar a un vampiro delante de otro, y el cuerpo")
	m = await cargar_mapa(PUESTO)
	m.poner_vampiro_extra()
	comprobar("el vampiro de más del evento", [m.vampiros().size(), m.get_node("VampiroExtra").ruta], [2, [Vector2i(9, 0), Vector2i(20, 0)]])
	var otro: Vampiro = m.get_node("VampiroExtra")
	plantar(otro, Vector2(15.5, 4.5), Vector2(1, 0))
	v = m.get_node("VP1")
	plantar(v, Vector2(19.5, 4.5), Vector2(-1, 0))
	m.mika.pos = otro.pos + Vector2(-0.6, 0) # detrás del otro, a la vista de VP1
	m.mika.mirada = Vector2(1, 0)
	m.mika.tajo()
	paso(m)
	comprobar("VP1 lo ve atacar a un vampiro", [v.estado, v.motivo], [Vampiro.Estado.TESTIGO, "ataque"])
	m.queue_free()
	m = await cargar_mapa(PUESTO)
	m.poner_vampiro_extra()
	otro = m.get_node("VampiroExtra")
	plantar(otro, Vector2(15.5, 4.5), Vector2(-1, 0))
	v = m.get_node("VP1")
	plantar(v, Vector2(19.5, 4.5), Vector2(-1, 0))
	m.mika.pos = Vector2(1.5, 18.5) # lejos
	otro.derribar()
	paso(m)
	comprobar("VP1 ve el cuerpo y avisa", [v.estado, v.motivo], [Vampiro.Estado.TESTIGO, "cuerpo"])
	paso(m, Config.VAMPIRO_AVISO + 0.1)
	comprobar("la alarma va al cuerpo, no a Mika", [m.alerta.activa, m.alerta.ultima_posicion.distance_to(otro.pos) < 0.01], [true, true])
	m.queue_free()

	print("G) Eventos: vampiro de más y vampiros callados")
	var e := EstadoExpedicion.actual()
	e.nueva()
	e.aplicar_efectos(Eventos.por_id("doncella").opciones[0].efectos)
	e.aplicar_efectos(Eventos.por_id("lacus_rene").opciones[0].efectos)
	comprobar("los efectos ya no están «aún sin efecto»", [Eventos.describir(Eventos.por_id("doncella").opciones[0].efectos).contains("aún sin efecto"),
		Eventos.describir(Eventos.por_id("lacus_rene").opciones[0].efectos).contains("aún sin efecto")], [false, false])
	m = await cargar_mapa(PUESTO) # con la expedición en curso, el mapa aplica los efectos al cargarse
	comprobar("el siguiente mapa tiene un vampiro más y no lo delatan", [m.vampiros().size(), m.vampiros_callados], [2, true])
	v = m.get_node("VP1")
	plantar(v, Vector2(24.5, 15.5), Vector2(0, -1))
	m.mika.pos = Vector2(24.5, 12.5)
	paso(m, 2.5)
	comprobar("callados: en la zona prohibida no reacciona", v.estado, Vampiro.Estado.CALMA)
	m.queue_free()
	var m2: Mapa = await cargar_mapa(PUESTO)
	comprobar("solo dura un mapa", [m2.vampiros().size(), m2.vampiros_callados], [1, false])
	m2.queue_free()
	e.activa = false
	terminar()
