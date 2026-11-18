class_name Filos
## Filos de la espada (docs/contenido.md): cada uno cambia una sola habilidad. Mika lleva como
## mucho FILOS_MAX a la vez, durante la expedición. Se ganan al superar una emboscada, en el
## refugio («Mejorar la espada») y en el evento «El filo exigente». Los números están en Config.

const MUDO := "mudo"
const LARGO := "largo"
const ARTERIAL := "arterial"
const SOMBRA := "sombra"
const DOBLE := "doble"
const VELOZ := "veloz"
const CAZADOR := "cazador"
const SEDIENTO := "sediento"
const PACIENTE := "paciente"
const KRUL := "krul"

const TODOS: Array[String] = [MUDO, LARGO, ARTERIAL, SOMBRA, DOBLE, VELOZ, CAZADOR, SEDIENTO, PACIENTE, KRUL]


static func nombre(id: String) -> String:
	match id:
		MUDO: return "Filo mudo"
		LARGO: return "Filo largo"
		ARTERIAL: return "Filo arterial"
		SOMBRA: return "Filo de sombra"
		DOBLE: return "Filo doble"
		VELOZ: return "Filo veloz"
		CAZADOR: return "Filo del cazador"
		SEDIENTO: return "Filo sediento"
		PACIENTE: return "Filo paciente"
		KRUL: return "Filo de Krul"
	return id


static func descripcion(id: String) -> String:
	match id:
		MUDO: return "El Tajo no hace ruido"
		LARGO: return "El Tajo alcanza el doble de distancia en línea recta"
		ARTERIAL: return "Matar con el Tajo baja la sed %d (bebe la espada, no Mika)" % Config.FILO_ARTERIAL_SED
		SOMBRA: return "Tras un Golpe silencioso, Mika va más rápido unos segundos"
		DOBLE: return "El Golpe silencioso derriba también a un segundo enemigo junto al primero"
		VELOZ: return "El Impulso no hace ruido"
		CAZADOR: return "Sentidos dura el doble y muestra los conos de visión"
		SEDIENTO: return "«Espada, bebe mi sangre» cuesta %d de vida, no %d" % [Config.ESPADA_COSTE_SEDIENTO, Config.ESPADA_COSTE]
		PACIENTE: return "Mientras Mika está en sombra, la sed no sube"
		KRUL: return "Cada vial baja la sed %d, no %d" % [-Config.FILO_KRUL_VIAL, -Config.VIAL_SED]
	return ""


## Dos filos al azar entre los que Mika no lleva.
static func dos_al_azar(llevados: Array[String], rng: RandomNumberGenerator) -> Array[String]:
	var posibles: Array[String] = []
	for id in TODOS:
		if not id in llevados:
			posibles.append(id)
	for i in range(posibles.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := posibles[i]
		posibles[i] = posibles[j]
		posibles[j] = t
	return posibles.slice(0, 2)
