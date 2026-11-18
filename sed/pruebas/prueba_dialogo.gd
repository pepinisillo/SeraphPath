extends "res://pruebas/comun.gd"
## Escenas con diálogo (novela visual): lectura del guion en Markdown (una línea, un golpe;
## listas; secciones dentro de otra), quién habla, comentario del otro Yuu según la Humanidad,
## avance, pantalla en negro y saltar; textos de la Prueba de la sed, eventos y refugios.
## Usa un guion de muestra, no el real (el real no está en git).

const CARPETA := "user://guion_prueba"

const INICIO := """# Bloque de muestra

## Inicio

*(Se ve una sola vez.)*

Narración uno.
—Línea uno —dijo una voz—. Sigue.

---

## Cada expedición

*(Nota.)*

Viales: {viales}.

---

## Recuerdos

### 1. El primero

Krul, narración.

—Línea dos —dijo Krul.

*(Pantalla en negro. Pasos.)*

—**Línea tres** —dijo Mika.

—Línea cuatro.

—Línea cinco.

[Akane] —Línea seis.

**Mika, ahora:** «Línea ahora.»

**El otro Yuu, hambriento:** «Hambre.»

**El otro Yuu, lleno:** «Lleno.»

### 2. El segundo

Otro texto.
"""

const PRUEBAS := """# Pruebas

## Zona 1 — Sanguinem

### Entrada

Entrada uno.

### Escena del fondo: «La primera»

Fondo largo.

### Versión corta

Fondo corto.

---

## Zona 2 — Shinjuku

### Entrada

Entrada dos.

---

## Frases de los ecos

### Hambriento (Humanidad 3)

1. «Frase A.»
2. «Frase B.»

### Satisfecho (Humanidad 2)

1. «Frase C.»

---

## Salidas

### Superada

**Zona 1.** Salió uno.

**Zona 2.** Salió dos.

### Cedida

*(Bebe.)*

Texto de cedida.

*(Variante de la zona 3.)*

Texto de la variante.

### Fallida

*(Sed 100.)*

Texto de fallida.

---

## Voz en el Frenesí

1. «Uno.»
2. «Dos.»
3. *(Si el Frenesí pasa sin que beba.)* «Tres.»

---

## «Sin voz» (Humanidad 0)

*(Sustituye a la prueba.)*

Texto sin voz.
"""

const EVENTOS := """# Eventos

## Eventos

### 1. La doncella de Krul (zona 1)

La doncella, narración.
—Línea —dijo ella.

**◆ El otro Yuu:** «Línea rombo.»

**Aceptar** *(1 vial).*
Resultado A.

**Rechazar** *(nada).*
—Resultado B1.
—Resultado B2.

---

## Refugios

### Humanidad 3

1. «Refugio uno.»
2. *(Sed 60 o más.)* —Refugio dos —dijo el otro Yuu.
   —Refugio dos, segunda línea.
"""


const JEFES := """# Jefes

## Ferid Bathory — el hangar (zona 1)

### Antes

Antes uno.

**◆ El otro Yuu:** «Antes rombo.»

### Durante

*(Frases de Ferid mientras persigue.)*

1. «Persigue uno.»
2. «Persigue dos.»

*(Si Ferid lo atrapa: Mika pierde vida.)*

- «Atrapa uno.»

*(◆ El otro Yuu, durante.)*

- «Otro uno.»

### Después

Después uno.

**◆ El otro Yuu** narración rombo.

—Después rombo.

---
"""

const FINALES := """# Finales

## La sangre de Yuu (Humanidad 3, con los siete recuerdos)

*(La sed está en 100. La pantalla casi no tiene color.)*

Línea antes.

*(Aparece el botón Beber, el mismo de toda la partida. No hay otra opción. El juego espera a que el jugador lo mantenga pulsado.)*

—Línea después.

*(La cámara se queda en las manos de los dos. La sed baja despacio hasta 0. El color vuelve a la pantalla.)*

**Texto final.** «Final sangre.»

---

## Caído (Mika cae antes de llegar)

### La primera vez

Primera uno.

**Texto final.** «Final caído.»

### Las siguientes veces

*(Una al azar.)*

1. —Krul uno.

2. —Krul dos.

*(◆ El otro Yuu, después. Una al azar.)*

1. «Otro después.»

### Caído con Humanidad 0

Sin humanidad uno.

**Texto final.** «Final cero.»

---
"""


func _initialize():
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
	for par in [[Guion.ARCHIVO_INICIO, INICIO], [Guion.ARCHIVO_PRUEBAS, PRUEBAS], [Guion.ARCHIVO_EVENTOS, EVENTOS], [Guion.ARCHIVO_JEFES, JEFES], [Guion.ARCHIVO_FINALES, FINALES]]:
		var f := FileAccess.open(CARPETA.path_join(par[0]), FileAccess.WRITE)
		f.store_string(par[1])
		f.close()
	Guion.carpeta_pruebas = CARPETA
	Guion.olvidar()

	print("A) Lectura del guion")
	var inicio := Guion.inicio()
	comprobar("inicio: una línea, un golpe; acotación fuera; corta en ---", inicio.map(func(g): return [g.tipo, g.texto]),
		[["narracion", "Narración uno."], ["dialogo", "—Línea uno —dijo una voz—. Sigue."]])
	comprobar("cada expedición: viales en letra", [Guion.cada_expedicion(2)[0].texto, Guion.cada_expedicion(4)[0].texto],
		["Viales: dos.", "Viales: cuatro."])
	var r1 := Guion.recuerdo(1)
	comprobar("recuerdo 1: tipos", r1.map(func(g): return g.tipo), ["narracion", "dialogo", "negro", "dialogo", "dialogo", "dialogo", "dialogo", "ahora", "otro_yuu", "otro_yuu"])
	comprobar("negritas fuera", r1[3].texto, "—Línea tres —dijo Mika.")
	comprobar("variantes del otro Yuu", [r1[8].variante, r1[9].variante], ["hambriento", "lleno"])
	comprobar("el recuerdo 1 no se come el 2", Guion.recuerdo(2).map(func(g): return g.texto), ["Otro texto."])
	comprobar("título del recuerdo", Guion.titulo_recuerdo(1), "El primero")
	comprobar("recuerdo inexistente vacío", Guion.recuerdo(9).size(), 0)

	print("B) Quién habla")
	var hablan := Guion.asignar_hablantes(r1).map(func(g): return g.habla)
	comprobar("verbo, alternancia y [forzado]", hablan, ["", "Krul", "", "Mika", "Krul", "Mika", "Akane", "Mika, ahora", "El otro Yuu", "El otro Yuu"])
	comprobar("[Akane] se quita del texto", Guion.asignar_hablantes(r1)[6].texto, "—Línea seis.")
	comprobar("la narración que empieza por un nombre da quién habla después",
		Guion.asignar_hablantes(Guion.seccion(Guion.ARCHIVO_EVENTOS, "1. La doncella")).slice(0, 2).map(func(g): return g.habla), ["", "La doncella"])

	print("C) Otro Yuu según la Humanidad")
	var textos := func(h: int) -> Array:
		return Guion.segun_humanidad(r1, h).slice(8).map(func(g): return g.tipo + ":" + g.texto)
	comprobar("Humanidad 3: hambriento", textos.call(3), ["otro_yuu:«Hambre.»"])
	comprobar("Humanidad 2: lleno", textos.call(2), ["otro_yuu:«Lleno.»"])
	comprobar("Humanidad 1: lleno", textos.call(1), ["otro_yuu:«Lleno.»"])
	comprobar("Humanidad 0: silencio", textos.call(0), ["silencio:"])

	print("D) Prueba de la sed")
	comprobar("entrada de cada zona", [Guion.prueba_entrada(1)[0].texto, Guion.prueba_entrada(2)[0].texto], ["Entrada uno.", "Entrada dos."])
	comprobar("fondo largo y corto", [Guion.prueba_fondo(1, true)[0].texto, Guion.prueba_fondo(1, false)[0].texto], ["Fondo largo.", "Fondo corto."])
	comprobar("salida superada por zona", [Guion.prueba_salida(1, "superada")[0].texto, Guion.prueba_salida(2, "superada")[0].texto], ["Salió uno.", "Salió dos."])
	comprobar("cedida, y su variante en la zona 3", [Guion.prueba_salida(1, "cedida").map(func(g): return g.texto), Guion.prueba_salida(3, "cedida").map(func(g): return g.texto)], [["Texto de cedida."], ["Texto de la variante."]])
	comprobar("fallida", Guion.prueba_salida(1, "fallida").map(func(g): return g.texto), ["Texto de fallida."])
	comprobar("sin voz", Guion.prueba_sin_voz().map(func(g): return g.texto), ["Texto sin voz."])
	comprobar("frases de los ecos por Humanidad", [Guion.frases_ecos(3), Guion.frases_ecos(2), Guion.frases_ecos(1), Guion.frases_ecos(0)],
		[PackedStringArray(["Frase A.", "Frase B."]), PackedStringArray(["Frase C."]), PackedStringArray(), PackedStringArray()])
	var voz := Guion.voz_frenesi()
	comprobar("voz del Frenesí", [voz.normales, voz.sin_beber], [PackedStringArray(["Uno.", "Dos."]), PackedStringArray(["Tres."])])

	print("E) Eventos y refugios")
	var ev := Guion.evento("La doncella de Krul")
	comprobar("intro del evento, con la línea ◆", ev.intro.map(func(g): return g.tipo), ["narracion", "dialogo", "otro_yuu"])
	comprobar("cada opción con su texto", [ev.opciones.keys(), ev.opciones["Aceptar"].map(func(g): return g.texto), ev.opciones["Rechazar"].size()],
		[["Aceptar", "Rechazar"], ["Resultado A."], 2])
	comprobar("la línea ◆ no sale con Humanidad 0", Guion.segun_humanidad(ev.intro, 0).size(), 2)
	comprobar("evento sin texto", Guion.evento("No existe").intro.size(), 0)
	var rng := RandomNumberGenerator.new()
	var vistos := {}
	for i in 40:
		vistos[str(Guion.refugio(3, 70, rng).map(func(g): return g.texto))] = true
	comprobar("refugio con sed alta: las dos líneas", vistos.size(), 2)
	vistos = {}
	for i in 40:
		vistos[str(Guion.refugio(3, 20, rng).map(func(g): return g.texto))] = true
	comprobar("refugio con sed baja: solo la que no pide sed", vistos.keys(), ['["«Refugio uno.»"]'])
	comprobar("el elemento sangrado sigue al de su número", Guion.refugio(3, 70, rng).size() in [1, 2], true)

	print("E2) Jefes y final «Caído»")
	comprobar("antes del jefe", Guion.jefe_antes("Ferid Bathory").map(func(g): return g.tipo), ["narracion", "otro_yuu"])
	var durante := Guion.jefe_durante("Ferid Bathory")
	comprobar("frases durante, por grupo", [durante.persigue, durante.atrapa, durante.otro_yuu],
		[PackedStringArray(["Persigue uno.", "Persigue dos."]), PackedStringArray(["Atrapa uno."]), PackedStringArray(["Otro uno."])])
	var despues := Guion.jefe_despues("Ferid Bathory")
	comprobar("después: desde el ◆ sin dos puntos, todo es del otro Yuu", despues.map(func(g): return g.get("rombo", false)), [false, true, true])
	comprobar("con Humanidad 0 se omite ese tramo", Guion.segun_humanidad(despues, 0).map(func(g): return g.texto), ["Después uno."])
	comprobar("caído, la primera vez", Guion.caido(3, true, rng).map(func(g): return [g.tipo, g.texto]), [["narracion", "Primera uno."], ["final", "«Final caído.»"]])
	var siguiente := Guion.caido(3, false, rng)
	comprobar("caído, después: Krul al azar, el otro Yuu y el texto final", [siguiente.size(), siguiente[0].texto in ["—Krul uno.", "—Krul dos."], siguiente[1].tipo, siguiente[2].tipo], [3, true, "otro_yuu", "final"])
	comprobar("caído con Humanidad 1: el otro Yuu sigue saliendo", Guion.caido(1, false, rng).size(), 3)
	comprobar("caído con Humanidad 0", Guion.caido(0, false, rng).map(func(g): return g.texto), ["Sin humanidad uno.", "«Final cero.»"])

	print("E3) Final con indicaciones: sin color, beber obligatorio y el color que vuelve")
	var sangre := Guion.final("La sangre de Yuu")
	comprobar("tipos del final", sangre.map(func(g): return g.tipo), ["sin_color", "narracion", "beber", "dialogo", "color", "final"])
	comprobar("el botón Beber es obligatorio", sangre[2].obligatorio, true)
	var df := Dialogo.new()
	root.add_child(df)
	var bebio := [0]
	df.bebio.connect(func() -> void: bebio[0] += 1)
	df.empezar(sangre)
	comprobar("empieza casi sin color", [df._gris.visible, df._gris.material.get_shader_parameter("gris")], [true, Config.DIALOGO_GRIS])
	df.avanzar()
	df.avanzar()
	comprobar("llega al botón Beber y espera", [df.indice, df.esperando_beber], [2, true])
	df.avanzar()
	df.saltar()
	comprobar("ni avanzar ni saltar lo pasan", [df.indice, df.esperando_beber, df.acabado], [2, true, false])
	df.beber_ya()
	comprobar("al beber, sigue", [df.indice, bebio[0]], [3, 1])
	df.avanzar()
	df.avanzar()
	comprobar("el color vuelve poco a poco", [df.indice, df._esperando], [4, true])
	await create_timer(Config.DIALOGO_COLOR_VUELVE + 0.2).timeout
	comprobar("y vuelve del todo", [df._gris.material.get_shader_parameter("gris"), df.indice], [0.0, 5])
	df.queue_free()
	var opcional: Array[Dictionary] = [{"tipo": "beber", "texto": "", "obligatorio": false}, {"tipo": "narracion", "texto": "Sigue."}]
	df = Dialogo.new()
	root.add_child(df)
	df.empezar(opcional)
	df.avanzar()
	comprobar("si no es obligatorio, se puede seguir sin beber", [df.indice, df.esperando_beber], [1, false])
	df.queue_free()

	print("F) Avanzar, negro y saltar")
	var d := Dialogo.new()
	root.add_child(d)
	var fin := [0]
	d.terminado.connect(func() -> void: fin[0] += 1)
	d.empezar(Guion.segun_humanidad(r1, 3))
	comprobar("empieza por el primer golpe, sin letras", [d.indice, d._etiqueta.visible_characters], [0, 0])
	comprobar("retratos de quienes hablan", d._retratos.keys(), ["Krul", "Mika", "Akane", "El otro Yuu"])
	await create_timer(0.2).timeout
	comprobar("el texto aparece poco a poco", d._etiqueta.visible_characters > 0 and d._etiqueta.visible_ratio < 1.0, true)
	d.avanzar()
	comprobar("avanzar completa el texto", [d.indice, d._etiqueta.visible_ratio], [0, 1.0])
	d.avanzar()
	comprobar("avanzar pasa al siguiente, con su nombre", [d.indice, d._nombre.text], [1, "Krul"])
	comprobar("quien habla, a plena luz", d._retratos["Krul"].modulate.a, 1.0)
	comprobar("los demás, apagados", d._retratos["Mika"].modulate.a, Dialogo.OPACIDAD_CALLADO)
	d.avanzar()
	d.avanzar()
	comprobar("pasa al negro", [d.indice, d._esperando], [2, true])
	d.avanzar()
	comprobar("en el negro no se avanza a mano", d.indice, 2)
	await create_timer(Config.DIALOGO_NEGRO + 2 * Config.DIALOGO_FUNDIDO + 0.2).timeout
	comprobar("tras el negro sigue solo", [d.indice, d._esperando, d._negro.modulate.a], [3, false, 0.0])
	for i in 12:
		d.avanzar()
	comprobar("termina al avanzar tras la última línea, y se oculta", [d.acabado, fin[0], d.visible], [true, 1, false])
	d.queue_free()
	d = Dialogo.new()
	root.add_child(d)
	d.terminado.connect(func() -> void: fin[0] += 1)
	d.empezar(Guion.segun_humanidad(r1, 3))
	d.saltar()
	d.saltar()
	d.avanzar()
	comprobar("saltar termina una sola vez", [d.acabado, fin[0]], [true, 2])
	d.queue_free()

	print("G) Recuerdo 7 y Humanidad 0")
	var expe := EstadoExpedicion.actual()
	expe.archivo_recuerdos = "user://prueba_dialogo_recuerdos.cfg"
	expe.recuerdos = [1, 2, 3, 4, 5, 6]
	expe.humanidad = 0
	comprobar("con Humanidad 0 no se gana la confesión", [expe.ganar_recuerdo(), expe.recuerdos.size()], [0, 6])
	expe.humanidad = 1
	comprobar("con Humanidad 1 sí", expe.ganar_recuerdo(), 7)

	print("H) Escena antes de la expedición y salidas de la prueba")
	expe.inicio_visto = false
	expe.nueva()
	comprobar("la primera vez, el inicio completo", expe.escena_de_inicio().size(), 2)
	expe.inicio_visto = true
	comprobar("después, la caja con 4 viales (tiene el recuerdo 1)", expe.escena_de_inicio()[0].texto, "Viales: cuatro.")
	expe.fondos_vistos = []
	comprobar("superada la primera vez: fondo largo, negro y salida", expe.escena_salida_prueba("superada").map(func(g): return g.texto), ["Fondo largo.", "", "Salió uno."])
	comprobar("la segunda, la versión corta", expe.escena_salida_prueba("superada").map(func(g): return g.texto), ["Fondo corto.", "", "Salió uno."])
	comprobar("cedida, sin fondo", expe.escena_salida_prueba("cedida").map(func(g): return g.texto), ["Texto de cedida."])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(expe.archivo_recuerdos))

	for archivo in [Guion.ARCHIVO_INICIO, Guion.ARCHIVO_PRUEBAS, Guion.ARCHIVO_EVENTOS, Guion.ARCHIVO_JEFES, Guion.ARCHIVO_FINALES]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CARPETA.path_join(archivo)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CARPETA))
	Guion.carpeta_pruebas = ""
	Guion.olvidar()
	terminar()
