class_name Mejoras
## Mejoras de sangre: se ganan al beber sangre humana y duran toda la expedición.
## Los números de sus efectos están en Config.

const FUERZA := "fuerza"
const VIGOR := "vigor"
const VELOCIDAD := "velocidad"
const OLFATO := "olfato"
const REGENERACION := "regeneracion"

const TODAS: Array[String] = [FUERZA, VIGOR, VELOCIDAD, OLFATO, REGENERACION]


static func nombre(id: String) -> String:
	match id:
		FUERZA: return "Fuerza"
		VIGOR: return "Vigor"
		VELOCIDAD: return "Velocidad"
		OLFATO: return "Olfato"
		REGENERACION: return "Regeneración"
	return id


static func descripcion(id: String) -> String:
	match id:
		FUERZA: return "El Tajo hace %d de daño más" % Config.MEJORA_FUERZA
		VIGOR: return "%d de vida máxima más" % Config.MEJORA_VIGOR
		VELOCIDAD: return "Se mueve más rápido"
		OLFATO: return "Ve a todos los humanos a través de las paredes"
		REGENERACION: return "Recupera vida con cualquier nivel de sed"
	return ""
