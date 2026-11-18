extends "res://pruebas/comun.gd"
## Los enemigos de la zona 3: el portador de arma maldita (ve más lejos, pega más y de lejos; el
## Golpe silencioso solo lo aturde) y el hechicero de talismanes (pisar uno revela a Mika;
## derribar al hechicero los apaga).

const ESCENA := "res://escenas/mapa_shibuya.tscn"


func _initialize():
	await process_frame
	print("A) Portador de arma maldita")
	var m: Mapa = await cargar_mapa(ESCENA)
	var pa: Portador = m.get_node("PA1")
	comprobar("más vida, más vista, más daño y de más lejos", [pa.vida, pa.alcance_vision, pa.dano, pa.distancia_golpe],
		[Config.PORTADOR_VIDA, Config.PORTADOR_VISION, Config.PORTADOR_DANO, Config.PORTADOR_DISTANCIA_GOLPE])
	pa.pos = Vector2(19.5, 0.5)
	pa.mirada = Vector2(0, 1)
	pa._pausa = 100.0
	m.mika.pos = Vector2(19.5, 7.5) # a 7 casillas: un soldado no lo vería
	comprobar("lo ve a 7 casillas", pa._puede_ver(m.mika.pos), true)
	m.queue_free()

	m = await cargar_mapa(ESCENA)
	pa = m.get_node("PA1")
	pa.pos = Vector2(19.5, 3.5)
	pa.mirada = Vector2(0, 1)
	pa._pausa = 100.0
	m.mika.pos = pa.pos + Vector2(0, -0.9) # a su espalda
	m.mika.mirada = Vector2(0, 1)
	paso(m)
	m.mika.golpe_silencioso()
	comprobar("el Golpe silencioso solo lo aturde", [pa.derribado, pa.aturdido > 0.0], [false, true])
	m.mika.pos = Vector2(28.5, 16.5) # lejos
	paso(m, Config.PORTADOR_ATURDIDO + 0.1)
	comprobar("al despertar, sospecha", [pa.aturdido <= 0.0, pa.estado], [true, Soldado.Estado.SOSPECHA])
	m.queue_free()

	m = await cargar_mapa(ESCENA)
	pa = m.get_node("PA1")
	pa.pos = Vector2(19.5, 3.5)
	pa.mirada = Vector2(0, 1)
	m.mika.pos = pa.pos + Vector2(0, 3.5)
	m.alerta.dar_alarma(m.mika.pos)
	var vida := m.mika.vida
	paso(m, 0.3)
	comprobar("en Alarma pega desde 3,5 casillas", m.mika.vida, vida - Config.PORTADOR_DANO)
	m.queue_free()

	print("B) Hechicero de talismanes")
	m = await cargar_mapa(ESCENA)
	await process_frame
	var h: Hechicero = m.get_node("H1")
	comprobar("sus talismanes", m.talismanes_activos(), [Vector2i(10, 7), Vector2i(10, 12), Vector2i(19, 7)])
	m.mika.pos = Vector2(10.5, 12.5) # encima de uno
	paso(m)
	comprobar("pisarlo revela a Mika: alarma", [m.alerta.activa, m.estadisticas.talismanes_pisados, m.talismanes_activos().size()], [true, 1, 2])
	m.queue_free()
	m = await cargar_mapa(ESCENA)
	await process_frame
	h = m.get_node("H1")
	h.derribar()
	paso(m)
	comprobar("derribar al hechicero apaga sus talismanes", m.talismanes_activos().size(), 0)
	m.mika.pos = Vector2(10.5, 12.5)
	paso(m)
	comprobar("y ya no revelan a nadie", m.alerta.activa, false)
	m.queue_free()
	terminar()
