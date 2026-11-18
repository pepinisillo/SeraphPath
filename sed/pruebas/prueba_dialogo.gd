extends "res://pruebas/comun.gd"
## Escenas con diálogo: lectura del guion en Markdown, comentario del otro Yuu según la
## Humanidad, avance, pantalla en negro y saltar. Usa un guion de muestra, no el real
## (el real no está en git).

const CARPETA := "user://guion_prueba"

const MUESTRA := """# Bloque de muestra

## Inicio

*(Se ve una sola vez.)*

Mika despertó en el suelo
de un pasillo.

—Tres —dijo una voz—. Tres días.

---

## Recuerdos

### 1. El primero

Narración del recuerdo.

*(Pantalla en negro. Pasos.)*

—**Hola** —dijo Mika.

**Mika, ahora:** «Lo de ahora.»

**El otro Yuu, hambriento:** «Hambre.»

**El otro Yuu, lleno:** «Lleno.»

### 2. El segundo

Otro texto.
"""


func _initialize():
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
	var f := FileAccess.open(CARPETA.path_join(Guion.ARCHIVO_INICIO), FileAccess.WRITE)
	f.store_string(MUESTRA)
	f.close()
	Guion.carpeta_pruebas = CARPETA
	Guion.olvidar()

	print("A) Lectura del guion")
	var inicio := Guion.inicio()
	comprobar("inicio: acotación fuera, párrafo de dos líneas unido, corta en ---", inicio.map(func(g): return [g.tipo, g.texto]),
		[["narracion", "Mika despertó en el suelo de un pasillo."], ["dialogo", "—Tres —dijo una voz—. Tres días."]])
	var r1 := Guion.recuerdo(1)
	comprobar("recuerdo 1: tipos", r1.map(func(g): return g.tipo), ["narracion", "negro", "dialogo", "ahora", "otro_yuu", "otro_yuu"])
	comprobar("negritas fuera", r1[2].texto, "—Hola —dijo Mika.")
	comprobar("Mika, ahora", r1[3].texto, "«Lo de ahora.»")
	comprobar("variantes del otro Yuu", [r1[4].variante, r1[5].variante], ["hambriento", "lleno"])
	comprobar("el recuerdo 1 no se come el 2", Guion.recuerdo(2).map(func(g): return g.texto), ["Otro texto."])
	comprobar("título del recuerdo", Guion.titulo_recuerdo(1), "El primero")
	comprobar("recuerdo inexistente vacío", Guion.recuerdo(9).size(), 0)

	print("B) Otro Yuu según la Humanidad")
	var textos := func(h: int) -> Array:
		return Guion.segun_humanidad(r1, h).slice(4).map(func(g): return g.tipo + ":" + g.texto)
	comprobar("Humanidad 3: hambriento", textos.call(3), ["otro_yuu:«Hambre.»"])
	comprobar("Humanidad 2: lleno", textos.call(2), ["otro_yuu:«Lleno.»"])
	comprobar("Humanidad 1: lleno", textos.call(1), ["otro_yuu:«Lleno.»"])
	comprobar("Humanidad 0: silencio", textos.call(0), ["silencio:"])

	print("C) Avanzar, negro y saltar")
	var d := Dialogo.new()
	root.add_child(d)
	var fin := [0]
	d.terminado.connect(func() -> void: fin[0] += 1)
	d.empezar(Guion.segun_humanidad(r1, 3))
	comprobar("empieza por el primer golpe, sin letras", [d.indice, d._etiqueta.visible_characters], [0, 0])
	await create_timer(0.2).timeout
	comprobar("el texto aparece poco a poco", d._etiqueta.visible_characters > 0 and d._etiqueta.visible_ratio < 1.0, true)
	d.avanzar()
	comprobar("avanzar completa el texto", [d.indice, d._etiqueta.visible_ratio], [0, 1.0])
	d.avanzar()
	comprobar("avanzar pasa al negro", [d.indice, d._esperando], [1, true])
	d.avanzar()
	comprobar("en el negro no se avanza a mano", d.indice, 1)
	await create_timer(Config.DIALOGO_NEGRO + 2 * Config.DIALOGO_FUNDIDO + 0.2).timeout
	comprobar("tras el negro sigue solo", [d.indice, d._esperando, d._negro.modulate.a], [2, false, 0.0])
	comprobar("aún no terminó", fin[0], 0)
	d.saltar()
	var etiquetas := d.find_children("*", "Label", false, false).filter(func(e): return e != d._pista)
	comprobar("saltar enseña todo", [etiquetas.size(), d.acabado, fin[0]], [4, true, 1])
	comprobar("el último es el otro Yuu, completo", [etiquetas[-1].text, etiquetas[-1].visible_ratio], ["El otro Yuu: «Hambre.»", 1.0])
	d.avanzar()
	d.saltar()
	comprobar("terminado se emite una vez", fin[0], 1)
	d.queue_free()

	print("D) Recuerdo 7 y Humanidad 0")
	var expe := EstadoExpedicion.actual()
	expe.archivo_recuerdos = "user://prueba_dialogo_recuerdos.cfg"
	expe.recuerdos = [1, 2, 3, 4, 5, 6]
	expe.humanidad = 0
	comprobar("con Humanidad 0 no se gana la confesión", [expe.ganar_recuerdo(), expe.recuerdos.size()], [0, 6])
	expe.humanidad = 1
	comprobar("con Humanidad 1 sí", expe.ganar_recuerdo(), 7)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(expe.archivo_recuerdos))

	DirAccess.remove_absolute(ProjectSettings.globalize_path(CARPETA.path_join(Guion.ARCHIVO_INICIO)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CARPETA))
	Guion.carpeta_pruebas = ""
	terminar()
