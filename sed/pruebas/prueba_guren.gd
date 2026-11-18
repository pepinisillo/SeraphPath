extends "res://pruebas/comun.gd"
## Guren Ichinose, jefe de la zona 3: pelea como Crowley con sus propios números; en la segunda
## fase, las sombras de Mahiru. Y que sea justo.

const ESCENA := "res://escenas/mapa_patio.tscn"


func _initialize():
	await process_frame
	print("A) Estructura")
	var m: Mapa = await cargar_mapa(ESCENA)
	var g: Crowley = m.jefe_combate
	comprobar("Guren está, con sus números", [g is Guren, g.vida, g._p.NOMBRE], [true, Config.GUREN_VIDA, "Guren Ichinose"])
	m.queue_free()

	print("B) Segunda fase: sombras alrededor de donde va a estar Mika")
	m = await cargar_mapa(ESCENA)
	g = m.jefe_combate
	g.fase = 2
	g._ataques_de_cerca = 1 # el siguiente ataque de cerca es el especial
	m.mika.pos = g.pos + Vector2(-1.5, 0)
	paso(m, Config.GUREN_PAUSA_ENTRE_ATAQUES + 0.05)
	comprobar("avisa las sombras", [g.estado, g.ataque, g._sombras.size()], [Crowley.Estado.AVISA, Crowley.Ataque.SOMBRAS, 3])
	comprobar("Mika está debajo de una", g.en_zona_de_ataque(m.mika.pos), true)
	var vida := m.mika.vida
	paso(m, Config.GUREN_AVISO_SOMBRAS * Config.GUREN_FASE2_AVISO + 0.05)
	comprobar("si no se mueve, le alcanza", m.mika.vida, vida - Config.GUREN_DANO)
	m.queue_free()

	print("C) Justo: pegando sin esquivar pierde; esquivando y castigando gana")
	var sin_esquivar := await pelear_con_jefe(ESCENA, false)
	print("    sin esquivar: gana=%s, vida de Mika %d, vida de Guren %d, %.1f s" % sin_esquivar)
	comprobar("sin esquivar, cae", sin_esquivar[1] <= 0, true)
	var esquivando := await pelear_con_jefe(ESCENA, true)
	print("    esquivando: gana=%s, vida de Mika %d, vida de Guren %d, %.1f s" % esquivando)
	comprobar("esquivando y pegando en la recuperación, gana", esquivando[0], true)
	terminar()
