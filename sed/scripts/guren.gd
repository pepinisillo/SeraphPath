class_name Guren
extends Crowley
## Guren Ichinose, jefe de la zona 3: combate contra un arma maldita. Pelea como Crowley (tajo,
## una estocada de lejos, guardia fuera de la recuperación), pero más rápido y con avisos más
## cortos. En la segunda fase la voz cambia (Mahiru, el demonio de la espada) y su ataque
## especial son tres sombras que caen alrededor de donde va a estar Mika.
## Cuando su vida llega a 0 cae y deja pasar a Mika.

const COLOR_ESPADA := Color(0.05, 0.05, 0.07)


func parametros() -> Dictionary:
	return {
		"VIDA": Config.GUREN_VIDA, "DANO": Config.GUREN_DANO, "VELOCIDAD": Config.GUREN_VELOCIDAD,
		"AVISO": Config.GUREN_AVISO, "AVISO_TORBELLINO": Config.GUREN_AVISO_SOMBRAS,
		"RECUPERACION": Config.GUREN_RECUPERACION, "DANO_EN_GUARDIA": Config.GUREN_DANO_EN_GUARDIA,
		"PAUSA_ENTRE_ATAQUES": Config.GUREN_PAUSA_ENTRE_ATAQUES, "TAJO_ALCANCE": Config.GUREN_TAJO_ALCANCE,
		"TAJO_ANGULO": Config.GUREN_TAJO_ANGULO, "CARGA_ALCANCE": Config.GUREN_ESTOCADA_ALCANCE,
		"CARGA_MINIMA": Config.GUREN_ESTOCADA_MINIMA, "CARGA_DISTANCIA": Config.GUREN_ESTOCADA_DISTANCIA,
		"CARGA_DURACION": Config.GUREN_ESTOCADA_DURACION, "CARGA_ANCHO": Config.GUREN_ESTOCADA_ANCHO,
		"TORBELLINO_RADIO": Config.GUREN_SOMBRAS_RADIO, "FASE2_VIDA": Config.GUREN_FASE2_VIDA,
		"FASE2_AVISO": Config.GUREN_FASE2_AVISO, "FASE2_VELOCIDAD": Config.GUREN_FASE2_VELOCIDAD,
		"POCA_VIDA": Config.GUREN_POCA_VIDA, "NOMBRE": "Guren Ichinose", "COLOR": Paleta.SOLDADOS,
	}


func ataque_de_fase2() -> Ataque:
	return Ataque.SOMBRAS


func _draw() -> void:
	super()
	# La espada maldita, negra.
	draw_line(Vector2(ANCHO_CAPSULA * 0.4, -ALTO_CAPSULA * 0.45), Vector2(ANCHO_CAPSULA * 1.4, -ALTO_CAPSULA * 0.05), COLOR_ESPADA, 8.0)
