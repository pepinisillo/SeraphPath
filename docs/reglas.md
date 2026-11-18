# Reglas y estructura técnica

> Este documento recoge las reglas de juego en tiempo real, los números de partida y cómo está organizado el proyecto. Si algo de `diseno.md`, `historia.md` o `contenido.md` lo contradice, manda este documento.

*Sed* es un fan juego de Owari no Seraph centrado en Mika: gratuito, sin fines de lucro y con arte y música propios (sin imágenes, sprites ni audio oficiales). El juego y el código están en español.

## Qué es

Un roguelike de sigilo y acción **en tiempo real**, en 2D con **vista isométrica** al estilo de Hades, con un solo personaje jugable: Mika.
Cada expedición cruza varias paradas (infiltración, emboscada, evento, refugio, prueba de la sed, jefe) hasta llegar a Yuu.

El pilar central es que **todo poder tiene precio**: la sangre humana hace fuerte a Mika, pero le quita Humanidad.

## Documentos

| Documento | Contenido |
| --- | --- |
| `reglas.md` | Este documento: reglas en tiempo real, primer mapa, plan de construcción y organización del código |
| `diseno.md` | Sistemas, enemigos, estructura de la expedición y estilo visual |
| `historia.md` | Recuerdos, guiones y finales |
| `contenido.md` | Eventos, filos y mejoras de sangre |

## Motor y vista

- **Motor:** Godot 4 con GDScript, en 2D y con el renderer Forward+ (para brillos y partículas). Primero PC (teclado y ratón, o mando); Android después.
- **Vista isométrica 2:1:** cada casilla mide 128 × 64 px y el mapa es un `TileMapLayer` con forma isométrica.
- **Profundidad:** se ordena con Y-sort; lo que está más abajo en pantalla se dibuja delante.
- **Personajes:** de 96 a 128 px de alto, con animaciones en 8 direcciones.
- **Lógica separada del dibujo:** todas las distancias se miden en casillas del mapa. Visión, ruido y movimiento se calculan en coordenadas de casilla, y la vista isométrica solo convierte a píxeles al dibujar.
- **Controles:** las teclas siguen las diagonales isométricas, de modo que «arriba» en el teclado es «arriba» en pantalla.

## Controles

| Acción | Teclado y ratón | Mando |
| --- | --- | --- |
| Moverse | WASD o flechas | Stick izquierdo |
| Tajo | J o clic izquierdo | X |
| Golpe silencioso | K o clic derecho | Y |
| Impulso | Espacio | A |
| Beber sangre (mantener) | E | B |
| Tomar un vial | Q | LB |
| Elegir mejora | Flechas e Intro, o clic | Cruceta y A |
| Avanzar el diálogo | Intro, Espacio o clic | A |
| Saltar el diálogo | Esc | B |

Los ataques salen hacia donde mira Mika; el Impulso, hacia donde se mueve (o hacia donde mira, si está quieto).

## Reglas en tiempo real

Son valores de partida; se irán ajustando al jugar.

| Sistema | Regla |
| --- | --- |
| Movimiento de Mika | 5,5 casillas/s; con 60 de sed o más, 3,5 casillas/s |
| Impulso | Dash de 4 casillas en 0,15 s; enfriamiento de 1,5 s; sed +8; hace ruido |
| Vida | 12. Un soldado quita 2 por golpe, con 1 s entre golpes |
| Tajo | 4 de daño, alcance de 1,25 casillas, enfriamiento de 0,4 s; hace ruido |
| Golpe silencioso | Por la espalda o fuera del cono, sin alarma activa: derriba sin ruido |
| Beber sangre | Mantener 2 s junto a un humano derribado: sed a 0, vida completa, −1 Humanidad y una mejora de sangre |
| Vial de Krul | Sed −40; se bebe en 0,5 s |
| Sed | De 0 a 100. Empieza en 30. Sube 1 cada 3 s y 3 por cada golpe recibido |
| Tramos de sed | 0–29: regenera 1 de vida cada 6 s · 30–59: sin efecto · 60–89: más lento y sin Sentidos · 90+: Frenesí, 4 s sin control en los que Mika va por el humano más cercano y bebe |
| Humanidad | 3 puntos. Cada vez que bebe sangre humana pierde 1. Con 0 es un vampiro completo |
| Visión enemiga | Cono de 90° y alcance de 5 casillas; los muros lo cortan; en sombra el alcance baja a 2,5 casillas |
| Detección | Cada enemigo tiene un medidor visible sobre la cabeza. Se llena en 1,2 s si Mika está lejos dentro del cono y en 0,3 s a menos de 3 casillas. A la mitad: Sospecha (va a investigar). Lleno: Alarma |
| Ruido | Radio de 4 casillas: quien lo oye entra en Sospecha y va al origen |
| Sospecha | Investiga el punto durante 6 s y vuelve a su ruta |
| Alarma | Todos persiguen la última posición vista. Llega un refuerzo cada 10 s (máximo 4). Tras 10 s sin ver a Mika, baja a Sospecha |
| Cuerpos | Otra patrulla puede descubrir a un soldado derribado y entrar en Sospecha |
| Soldado | Vida 4; 2,8 casillas/s en patrulla y 4,4 casillas/s en alarma |

### Detalles de la detección

Decisiones que las reglas de arriba no fijan; sus valores están en `scripts/config.gd`.

- **El medidor se vacía** en 3 s cuando el soldado deja de ver a Mika. La Sospecha no termina por eso: termina al acabar de investigar.
- **Antes de la Sospecha,** si el soldado ve a Mika se detiene y se gira hacia él mientras el medidor sube.
- **Al investigar,** camina hasta el punto, mira alrededor durante 6 s y vuelve a su ruta. Si vuelve a ver a Mika, el punto pasa a ser donde está él.
- **En Alarma** se detiene a 0,9 casillas de Mika (luego será la distancia de golpe). Al llegar a la última posición vista sin verlo, mira alrededor.
- **Al apagarse la Alarma,** cada soldado queda en Sospecha con el medidor a la mitad e investiga la última posición vista.
- **Refuerzos:** aparecen en la casilla de entrada de refuerzos del mapa (en el puesto de control, la salida) y hacen guardia en ella. El máximo de 4 es por mapa.
- **Color del cono:** azul frío en calma, ámbar en Sospecha y rojo en Alarma. La zona cercana, a menos de 3 casillas, se pinta más intensa porque allí la detección es casi inmediata.

### Detalles del combate y el ruido

- **Arco de ataque:** el Tajo y el Golpe silencioso alcanzan a lo que está en un arco de 120° delante de Mika. El Tajo daña a todos los que haya dentro.
- **Golpe silencioso:** alcance de 1,25 casillas y enfriamiento de 0,5 s. Cuando hay un soldado que se puede derribar así, aparece un rombo sobre su cabeza. Sin objetivo válido no hace nada ni gasta el enfriamiento.
- **Derribado:** tanto el Tajo (si deja al soldado sin vida) como el Golpe silencioso lo dejan derribado, no muerto. El cuerpo se queda en el suelo.
- **Ruido:** se oye a través de los muros. Se dibuja como una onda en el suelo con el radio en que se oye. En Alarma no cambia nada, porque ya persiguen.
- **Impulso:** el ruido sale de donde empieza el dash. Los muros lo detienen.
- **Cuerpos:** cada cuerpo se descubre una sola vez. Quien lo ve va a investigarlo; la sombra también reduce a 2,5 casillas la distancia a la que se ve.

### Detalles de la sed y la sangre

- **Golpes de soldado:** en Alarma, el soldado que ve a Mika y está a 0,9 casillas o menos la golpea: 2 de vida y +3 de sed, como mucho uno por segundo.
- **Caída:** con vida 0, Mika cae y a los 1,5 s aparece la pantalla de resultado.
- **Beber:** se mantiene el botón junto a un cuerpo, a 1 casilla o menos. Soltarlo antes de los 2 s cancela sin coste. De cada cuerpo se bebe una sola vez, y se oscurece al quedar vacío.
- **Mejora de sangre:** al terminar de beber, el juego se pausa y ofrece dos mejoras al azar entre las que Mika aún no tiene. Fuerza da +2 de daño al Tajo, Vigor +4 de vida máxima, Velocidad +1 casilla/s, Olfato muestra en rojo a todos los humanos a través de los muros y Regeneración recupera vida con cualquier sed.
- **Humanidad 0:** Mika puede seguir bebiendo y ganando mejoras; la Humanidad no baja de 0. El poder permanente de vampiro completo y su efecto en el final quedan para más adelante.
- **Vial:** se recoge al pisar su casilla y se toma con su botón. Mika se detiene 0,5 s mientras lo bebe.
- **Frenesí:** Mika camina rodeando muros hacia el humano más cercano. Si está en pie lo derriba con el Tajo (que hace ruido) y después bebe; el trago también ocurre sin control. Si en 4 s no consigue empezar a beber, recupera el control 3 s y, si la sed sigue en 90 o más, el Frenesí vuelve.
- **Sentidos** todavía no existe, así que el tramo Sediento por ahora solo la hace más lenta.
- **Sed entre mapas:** por ahora la sed, la Humanidad y las mejoras viven en Mika y se reinician con el mapa. Pasarán a la expedición cuando se encadenen las paradas (paso 10).

### Final del mapa

- **Salida:** el mapa termina en cuanto Mika pisa la casilla de salida, aunque esté en Alarma o en Frenesí.
- **Resultado:** el juego se pausa y la pantalla muestra:
  - Si Mika superó el mapa o cayó.
  - El objetivo opcional (en el puesto de control, recoger el vial) y si se consiguió.
  - El tiempo, las veces que sonó la alarma, los derribados en silencio y con el Tajo, los cuerpos descubiertos, la sangre bebida y los viales recogidos.
  - La vida, la sed, la Humanidad y las mejoras con que termina Mika.
- **Menciones:** al superar el mapa aparecen «Sin dejar rastro» (ni alarma ni cuerpos descubiertos) o «Nadie dio la alarma», y «Sin beber sangre humana».
- **Botones:** «Jugar de nuevo» o «Volver a intentarlo» repiten el mapa, y «Salir del juego» cierra. Cuando se encadenen las paradas (paso 10), el éxito llevará a la siguiente.

### Prueba de la sed

Un mapa dentro de la mente de Mika, donde no puede atacar. La sed sube 1 cada 1,5 s, y 1 más cada 1,5 s por cada eco a menos de 1,5 casillas.
Los ecos lo siguen a 1,9 casillas/s y le ofrecen sangre.

| Resultado | Condición |
| --- | --- |
| Superada | Llegar a la salida sin beber |
| Cedida | Beber (−1 Humanidad) |
| Fallida | Llegar a 100 de sed |

Cómo está construida (escena `mapa_prueba_sed.tscn`; para jugarla sola, abrirla en Godot y pulsar F6):

- **Mapa:** un plano de 12 × 12 con cinco ecos (`e`) y Yuu en la salida, al fondo. No tiene cuellos de botella: ningún eco quieto puede cerrar el paso.
- **Lo que cambia en la mente:**
  - Mika no puede usar el Tajo, el Golpe silencioso ni los viales, y no hay Frenesí.
  - Sí puede usar el Impulso, que sigue costando sed.
  - Con 60 de sed sigue yendo más lenta.
- **Ecos:** siguen a Mika rodeando muros y **le cortan el paso**: no se pueden atravesar. Es una decisión propia para que la cercanía de los ecos importe.
  - Solo habla el más cercano a menos de 3 casillas, con una frase en la voz de Yuu.
  - Para beber de un eco se mantiene E a 1 casilla o menos durante 2 s.
- **Cedida:** tras beber se elige la mejora, y después aparece el resultado.
- **Fallida:** Mika queda con sed 90. Que el siguiente mapa empiece en Alarma se aplicará al encadenar paradas (paso 10).
- **Superada:** ganar el recuerdo también llega con el paso 10.
- **Dificultad:** la prueba automática la supera en unos 10 s con sed 38, yendo hacia Yuu y esquivando las casillas de los ecos. Con los valores actuales es fácil. Para endurecerla se puede subir la velocidad de los ecos, poner más ecos o hacer más largo el camino.

### Sensación al jugar

Todo esto es dibujo y ritmo del tiempo; no cambia ninguna regla. Los valores están en `scripts/config.gd` y el código en `scripts/efectos.gd`.

| Momento | Qué se siente |
| --- | --- |
| Tajo que conecta | Parada de 3 cuadros, sacudida leve, salpicadura de sangre y destello rojo en el soldado |
| Golpe silencioso | Parada de 2 cuadros y unas pocas gotas, sin sacudida |
| Golpe recibido | Parada de 4 cuadros, sacudida mayor, sangre y destello rojo en Mika |
| Caída de Mika | Sacudida fuerte |
| Impulso | Una silueta de Mika cada 0,03 s que se desvanece en 0,25 s |
| Beber sangre o un vial | Estallido de gotas rojas o turquesa |
| Sed | La pantalla pierde color desde sed 30 hasta un 80 % justo antes del Frenesí. En Frenesí todo queda gris rojizo salvo lo rojo |

- **Los colores cálidos no se apagan con la sed.** El ámbar de la sospecha y el rojo de la sangre y la alarma se conservan, así que las señales de peligro siguen leyéndose aunque el mundo se vuelva gris. Es una decisión propia: sin ella, el cono ámbar se perdía justo cuando Mika está más débil.
- **Las paradas** congelan el juego unos cuadros. Si se pisan, manda la más larga, y salir del mapa nunca deja el juego congelado.
- **El arte final** (sprites de 8 direcciones, escenarios pintados) no está hecho: el proyecto pide arte propio. Lo que hay son formas provisionales con estos efectos encima.

### Expedición

El juego empieza en la pantalla de título. Una expedición recorre las **tres zonas** (`ZONAS` en `scripts/expedicion.gd`): Sanguinem, las ruinas de Shinjuku y Shibuya. Cada una tiene la misma estructura:

```
                ┌─ Refugio ──── Evento ─────────┐
Infiltración ───┤                               ├── Prueba de la sed ── Jefe
                └─ Emboscada ── Infiltración ───┘
```

- **Viales:** cada expedición empieza con 2, los de la caja de Krul (4 con el recuerdo 1).
- **Estado entre paradas:** Mika arrastra vida, sed, Humanidad, viales y mejoras de una parada a la siguiente. Si cae, la expedición termina y solo se conservan los recuerdos.
- **Mapa de paradas:** muestra lo hecho, la parada actual y los avisos para el siguiente mapa (empieza en Sospecha o Alarma, la sed no sube, patrullas visibles). Sin el recuerdo 3, «El mapa», las dos rutas se ven como «? → ?».
- **Infiltración:** el puesto de control (mapa grande).
- **Emboscada:** el mismo puesto, empezando en Alarma. Su recompensa, un filo, llegará con los filos.
- **Refugio:**
  - Al entrar, una línea del guion al azar según la Humanidad; las marcadas «Sed 60 o más» solo con esa sed. Las que van entre «» las dice Mika.
  - Permite curar toda la vida.
  - «Mejorar la espada» aparece desactivado hasta que existan los filos.
- **Evento:** sale uno al azar de los de la zona 1 que no hayan salido en la expedición: «La doncella de Krul», «Lacus y René», «La copa de Ferid» y «La carta sin enviar».
  - «El filo exigente» queda fuera hasta que existan los filos.
  - Los efectos que dependen de vampiros aún no existen y la opción lo dice: «aún sin efecto».
  - Las opciones y sus efectos de los diez eventos están en `scripts/eventos.gd`; el texto, en el guion. Se ve la escena del evento, se elige y luego se ve lo que pasa con esa opción. Las líneas ◆ del otro Yuu solo salen con Humanidad 1 o más.
- **Prueba de la sed:**
  - Antes del mapa, la entrada de la zona.
  - Los ecos dicen las frases del guion según la Humanidad (hambriento con 3, satisfecho con 2, cariñoso con 1). Cada eco empieza por una frase distinta y la cambia cada 5 s.
  - Superada: la escena del fondo (entera la primera vez en cada zona, queda apuntado en `user://recuerdos.cfg`; después la versión corta), la salida y el siguiente recuerdo.
  - Cedida: el texto de cedida. Fallida: el de fallida, y el siguiente mapa empieza en Alarma.
  - **Sin voz:** con Humanidad 0 no hay prueba ni recuerdo; se ve el texto «Sin voz» y se sigue a la siguiente parada (regla del guion).
- **Voz en el Frenesí:** al perder el control sale arriba una frase del guion al azar durante 3 s; si el Frenesí pasa sin que beba, la de devolver el control.
- **Jefe:** Ferid Bathory en la zona 1, Crowley Eusford en la zona 2 y Guren Ichinose en la zona 3 (ver más abajo). Superarlo da un recuerdo y lleva a la zona siguiente; tras Guren, el final.
- **Finales** (`final.gd`, con su escena del guion): **La sangre de Yuu** con Humanidad 3 y los siete recuerdos; **Vampiro completo** con Humanidad 0; **En el límite** en los demás casos (también con Humanidad 3 si faltan recuerdos: decisión propia, el guion no lo dice). Los finales vistos se guardan en `user://recuerdos.cfg`.
  - En «La sangre de Yuu» la escena empieza casi sin color, se para en el botón Beber hasta que el jugador lo mantiene 2 s (ni avanzar ni saltar lo pasan; esta vez no cuesta Humanidad) y luego el color vuelve en 3 s. Son las acotaciones del guion: «la pantalla casi no tiene color», «aparece el botón Beber… no hay otra opción», «el color vuelve a la pantalla».
  - La música (no hay hasta que Mika muerde) llegará con el sonido.
- **Zonas:** al pasar de zona empiezan paradas nuevas (se vuelve a elegir ruta) y se acaba lo que duraba toda la zona (ver las patrullas). Mika conserva vida, sed, Humanidad, viales y mejoras. La Prueba de la sed usa el mismo mapa en todas las zonas, con la entrada, el fondo y la salida de su zona en el guion.
- **Final «Caído»:** al caer, la escena del guion: entera la primera vez (se cuentan las caídas en `user://recuerdos.cfg`) y después una línea de Krul al azar, otra del otro Yuu (Humanidad 1 o más) y el texto final; con Humanidad 0, su versión.
- **Inicio:** antes de la primera expedición se ve la escena con Krul, una sola vez (queda apuntado en `user://recuerdos.cfg`). En las siguientes sale solo la línea de la caja de Krul (sección «Cada expedición» del guion), donde `{viales}` se cambia por el número de viales en letra: «dos», o «cuatro» con el recuerdo 1.
- **Recuerdos:** se guardan en disco (`user://recuerdos.cfg`) y se pueden releer desde el título.
  - Se ganan en orden. El 7, «Lo que nunca dije», no se gana con Humanidad 0.
  - El comentario del otro Yuu depende de la Humanidad: «hambriento» con 3, «lleno» con 2 o 1, y con 0 un silencio de 3 s. En la galería del título se leen como con Humanidad 3.
- **Escenas con diálogo** (`scripts/dialogo.gd`), como en Hades (novela visual):
  - Detrás, un fondo: un paisaje (por ahora, un degradado frío) o, si la escena ocurre jugando, el propio mapa oscurecido (`sobre_mapa`).
  - Delante, los retratos de quienes hablan en la escena: Mika a la izquierda y los demás a la derecha. Quien habla está a plena luz y un poco más arriba; los demás, apagados. Por ahora son siluetas de color con forma de cápsula; el arte final solo cambia `_dibujar_retrato`.
  - Abajo, un cuadro con el nombre de quien habla y el texto, que aparece poco a poco, una línea del guion cada vez.
  - Avanzar completa la línea o pasa a la siguiente; tras la última, termina. Saltar termina la escena.
  - La acotación «Pantalla en negro» funde a negro 2,5 s. Narración en gris, diálogo en blanco hueso, «Mika, ahora» en turquesa y el otro Yuu en rojo.
- **Quién habla:** el guion no lo marca, así que `Guion.asignar_hablantes` lo deduce. Primero mira si la línea lo dice («—dijo Krul»). Si no, si la narración anterior empieza por un personaje («Krul levantó una ceja.»). Si tampoco, alterna entre los dos últimos que hablaron. Para corregirlo a mano, se pone `[Nombre]` al principio de la línea en el guion: `[Krul] —Bebe.`
- **Guion:** es provisional y **no está en git**. `scripts/guion.gd` lee los `.md` de `historia/guion/` (junto a `sed/`) o, si algún día se copia dentro del juego, de `sed/datos/guion/`. Cada línea no vacía es un golpe del diálogo; las líneas `*(…)*` son notas para el juego y no se enseñan. Las listas numeradas (frases de los ecos, refugios) admiten líneas sangradas debajo de cada número. Si no hay guion, el inicio no aparece y los recuerdos solo dicen su mejora. Cambiar los diálogos no exige tocar código.
- **Mejoras permanentes de los recuerdos:**
  1. Empieza con 4 viales en vez de 2.
  2. La sed sube 2 por golpe, no 3.
  3. Ves qué hay en cada ruta.
  4. Una vez por expedición sobrevive con 1 de vida.
  5. Sediento empieza en 70.
  6. El Impulso cuesta 5 de sed.
  7. Abre el final «La sangre de Yuu», que llegará con los finales.

## Primer mapa: «Puesto de control»

Cada carácter es una casilla: `#` muro · `.` suelo · `s` sombra · `M` inicio de Mika · `E` salida · `V` vial de Krul (opcional) · `x` zona prohibida (ver Vampiros comunes).
La columna 0 está a la izquierda y la fila 0 arriba, en coordenadas de casilla; en pantalla el mapa aparece girado en diagonal.

Es un mapa grande, de 30 × 20 casillas, como los Túneles. El puesto original de 10 × 10 es ahora el **patio central**, con sus cuatro soldados, y alrededor hay salas nuevas:

```
#########............###.....E
#########........#s...........
#########...##...#s...........
#########...ss.......###..##..
#########............###..s...
###############..#######......
###############.s#######......
###############..########..###
######...#......#########..###
######.#.#.##s#.#########s.###
######.#.s.##s#.#########..###
######...#......#########..###
########s###.##.#####.......##
.....#.......#V.#####..#....##
...s.#s##.##.##.#####.......##
.....#s##.##......s.........##
.....#s......##.#####....#..##
.......s##s#...s#####....s..##
.M..#.###############.......##
.....#########################
```

Recorrido: afueras (inicio, vacías) → patio central → por el norte, barracones y la puerta; o por el este, el almacén y un pasillo que sube a la puerta.

| Soldado | Ruta |
| --- | --- |
| S1 | Bucle (9,13) → (12,13) → (12,16) → (9,16), alrededor del bloque central del patio |
| S2 | Vaivén por la fila 11, entre (15,11) y (10,11) |
| S3 | Vaivén por la columna 15, de (15,12) a (15,16) |
| S4 | Vaivén por la fila 8, entre (14,8) y (11,8), junto a la salida del patio hacia los barracones |
| F1 | Vaivén por la fila 2 de la puerta, de (29,2) a (24,2) |
| B1, B2 | Grupo de los barracones. Sale al acercarse Mika a la esquina noreste del patio. B1 va y viene por la columna 10 y B2 por la 20 |
| P1 | Grupo de la puerta, la mitad de las partidas. Sale al entrar en el pasillo norte o en el del almacén. Vigila la entrada oeste por la columna 24 |
| A1 | Grupo del almacén, la mitad de las partidas. Sale al entrar en el pasillo del almacén. Va y viene por la fila 14 |

- **El vial** sigue donde estaba en el puesto original, ahora en (14,13).
- **Refuerzos:** entran por (24,0), junto a la puerta.
- **Ruta sin ser visto:** `prueba_puesto.gd` la busca con los grupos saliendo al pisar su zona y la reproduce. La que encuentra tarda unos 20 s (frente a 8,4 s yendo directo). Cruza el patio por la fila de abajo, espera en el pasillo del almacén y sube por el este. Ir directo a la salida te delata.
- **Cómo se ajustó:** P1 iba por la fila 6 y, con F1, tapaba del todo la boca del pasillo del almacén. Ahora vigila la entrada oeste.

### El puesto original (pruebas de los pasos)

El plano de 10 × 10, tal como estaba, sigue en `mapa_pasos.tscn`. Las pruebas de los pasos 1 a 7 lo usan, porque están escritas con sus coordenadas:

```
...#.....E
.#.#.##s#.
.#.s.##s#.
...#......
##s###.##.
.......#V.
s##.##.##.
s##.##....
s......##.
Ms##s#...s
```

Patrullas, en (columna, fila):

| Soldado | Ruta |
| --- | --- |
| S1 | Bucle (3,5) → (6,5) → (6,8) → (3,8) → (3,5), alrededor del bloque central |
| S2 | Vaivén por la fila 3, entre (9,3) y (4,3); empieza en (9,3) |
| S3 | Vaivén por la columna 9, de (9,4) a (9,8) |
| S4 | Vaivén por la fila 0, entre (8,0) y (5,0), vigilando la salida; empieza en (8,0) |

Cada soldado empieza en el primer punto de su ruta, mirando hacia el segundo. La prueba del paso 7 busca una ruta de la `M` a la `E` en la que nadie vea nunca a Mika, la reproduce en el juego y comprueba que **no basta con correr**: la ruta debe tardar al menos 1,4 veces lo que se tarda yendo directo. Tarda unos 8 s (frente a 3,5 s yendo directo) y exige esperar al principio y esconderse en el pasillo de sombra de la columna 7 hasta que S4 se dé la vuelta.

**Patrullas al azar** (en todos los mapas que se juegan): para que no baste con memorizar los tiempos, en cada partida cada soldado empieza en un punto al azar de su ruta (en vaivén, también en cualquier sentido) y se detiene en cada punto entre 0,4 y 1 s. Los soldados de los grupos empiezan siempre en el primer punto de su ruta. Las pruebas de los pasos tienen el azar apagado. `pruebas/prueba_patrullas.gd` prueba tres semillas en el Puesto de control y en los Túneles: todas empiezan seguras y todas tienen una ruta sin ser visto.

En la vista isométrica un muro tapa lo que tiene detrás, así que los muros que quedan entre la cámara y Mika se vuelven semitransparentes.

## Segundo mapa: «Túneles de abastecimiento»

La infiltración de la ruta arriesgada de la zona 1 (la primera sigue siendo el puesto de control). Escena `mapa_tuneles.tscn`; se juega solo con F6.

Es un mapa grande, de 30 × 18 casillas, al estilo de Hades: salas unidas por pasillos, con zonas vacías entre una sala vigilada y otra, y grupos de soldados que salen al acercarse Mika.

```
#########.............###....E
#########........ss...........
#########...##...##...........
#########...ss........###.#...
#########.............###.#...
################..#######.s...
################..#######.....
################s.#######.....
################..#######.....
################..#########s.#
############........#######..#
############........####s.....
......######..##....####......
......######..ss..............
........ss......ss............
................##..####....V.
.M....######........####s.....
......######........##########
```

Recorrido: sala de inicio (vacía) → pasillo → sala A (dos guardias fijos y pilares) → pasillo norte → sala B → pasillo → sala de la salida. Desde la sala A también se puede desviar al este, a la sala del vial, y subir a la salida por el sur.

| Soldado | Ruta |
| --- | --- |
| A1 | Fijo. Bucle por la sala A: (13,11) → (18,11) → (18,16) → (13,16) |
| A2 | Fijo. Vaivén por la fila 10, de (12,10) a (19,10), vigilando la entrada al pasillo norte |
| F1 | Fijo. Vaivén por la fila 1, de (29,1) a (25,1): viene hacia la entrada de la sala de la salida |
| B1, B2 | Grupo de la sala norte. Sale cuando Mika llega al final del primer pasillo. B1 va y viene por la columna 9 y B2 por la 21, junto a la salida de la sala |
| F2 | Grupo de la salida, la mitad de las partidas. Sale al entrar en el pasillo norte o en el pasillo del vial. Va y viene por la fila 8 |
| V1 | Grupo del vial, la mitad de las partidas. Sale al ir hacia la sala del vial. Va y viene por la fila 12 |

- **Refuerzos:** entran por (25,0), junto a la salida.
- **Ruta sin ser visto:** `prueba_tuneles.gd` la busca con los grupos saliendo cuando la ruta pisa su zona, como en el juego, y la reproduce. Tarda unos 21 s frente a 7,9 s yendo directo: hay que esperar en la sala de inicio a que A1 y A2 dejen paso y, al final, rodear a F1 por el sur. Además, la prueba hace que Mika vaya directo a la salida en el juego real y comprueba que lo ven.
- **Cómo se ajustó:** al principio cada grupo salía al entrar en su propia sala, y con el aviso y la gracia daba tiempo a cruzarla corriendo. Por eso las zonas se adelantaron a la sala o al pasillo anterior, y se añadieron A2 y F1 en la fila 1.

### Grupos que aparecen

Un grupo (`scripts/aparicion.gd`, nodo `Aparicion` con soldados como hijos) no está en el mapa hasta que Mika pisa una de sus zonas:

- **Aviso:** durante 1 s, un rombo azul late en el suelo donde va a salir cada soldado.
- **Aparición:** cada soldado sale en el primer punto de su ruta, sin empezar al azar.
- **Gracia:** durante 1 s recién aparecido no puede ver a Mika, para que aparecer delante de él no sea injusto.
- **Probabilidad:** con menos de 1, el grupo se sortea al empezar el mapa y en algunas partidas no sale nunca; su zona queda vacía.
- **Azar propio:** cada soldado y cada grupo sortea con su propio generador, sacado de la semilla del mapa y de su nombre. Así, que salga un grupo no cambia lo que sortean los demás.
- **Pruebas:** buscan la ruta sin ser visto grabando a los soldados fijos y, aparte, a cada grupo desde que sale. En la búsqueda, cada camino lleva cuándo salió cada grupo según por dónde pasó Mika. La planificación ve con margen (15° más de cono, media casilla más de alcance y todo lo que esté a menos de 1,2 casillas), porque solo mira cada 0,1 s. Ese margen la hace más prudente de la cuenta (las rutas que da son más lentas de lo necesario), así que solo se usa con grupos; `buscar_ruta` sigue sin margen. Para cada mapa nuevo con grupos, usar `buscar_ruta_con_apariciones` de `pruebas/comun.gd`.

## Vampiros comunes

`scripts/vampiro.gd`, `escenas/vampiro.tscn`. Patrullan como los soldados y ven igual (cono de 90°, 5 casillas, 2,5 en sombra), pero su cono es violeta y **no atacan a Mika ni les importa verlo pasar**: para ellos es uno de los suyos. Lo delatan si lo ven:

- **en una zona prohibida** (casillas `x` del plano, marcadas con un rombo violeta) durante 0,5 s seguidos,
- **robando un vial** (cogerlo a su vista),
- **atacando a un vampiro** (Tajo o Golpe silencioso), o
- **junto a un vampiro derribado** (la alarma va entonces al cuerpo).

Al verlo se queda quieto mirándolo, con un «!» y una barra roja. Si en 1,5 s nadie lo calla, da la alarma y los soldados del mapa van a por Mika. Se le puede callar derribándolo (vida 8: dos Tajos, o un Golpe silencioso si no está mirando a Mika), pero si otro vampiro lo ve, ese también lo delata. Mientras dura la alarma no vuelve a delatar. Los vampiros no dan sangre y el Frenesí no va por ellos.

- **Mapas:** VP1 recorre el almacén del Puesto de control (columna 24) y hay una franja prohibida en la boca del pasillo que sube a la puerta (filas 11 y 12). VT1 vigila la sala del vial de los Túneles, con el rincón del vial prohibido.
- **Eventos:** «La doncella de Krul» (aceptar) pone un vampiro de más en el siguiente mapa, en su `ruta_vampiro_extra` (en los barracones del Puesto, en la sala norte de los Túneles). «Lacus y René» (ir y fingir) hace que los vampiros del siguiente mapa no lo delaten. Los dos duran un solo mapa y no cuentan la Prueba de la sed. En la zona 1, los eventos están en la ruta segura, justo antes de la Prueba, así que su «siguiente mapa» es el hangar de Ferid, que no tiene vampiros: tendrán efecto de verdad cuando haya más zonas.
- **Pruebas:** `prueba_vampiros.gd`. La búsqueda de ruta sin ser visto graba también a los vampiros, pero solo cuentan en zonas prohibidas y en la casilla de un vial.

## Jinete del Apocalipsis

`scripts/jinete.gd`, `escenas/jinete.tscn`. Gris pizarra con borde blanco hueso, más grande que los demás. Caza humanos e **ignora a los vampiros y a Mika**: es una herramienta, no un enemigo.

- **Vaga** despacio (1,6 casillas/s) por su ruta, mirando con un cono de 120° y 6 casillas.
- **Acude a los ruidos** (a 3 casillas/s) desde 8 casillas, el doble que un soldado. El Tajo, el Impulso o cualquier ruido de Mika sirven de cebo.
- **Caza** al soldado que vea (a 4 casillas/s) y lo derriba de un golpe, sin alarma: queda un cuerpo que otra patrulla puede descubrir y del que Mika puede beber.
- Los ataques de Mika aún no le hacen nada (vida 14, para cuando se pueda).
- **Evento «El Jinete dormido»** (atraerlo al puesto humano): el siguiente mapa tiene 2 soldados menos y un Jinete suelto, en su `ruta_jinete_suelto`.
- **Prueba:** `prueba_jinete.gd`.

## Zona 2: Ruinas de Shinjuku

### «Ruinas de Shinjuku» (primera infiltración)

`mapa_shinjuku.tscn`, 32 × 20: calles de dos casillas entre edificios, escombros que cubren, una plaza con un Jinete y un patio vampiro prohibido con un vial.

```
##..#######..#######..######..##
......#.........s.......#......E
......s.........#.......s.......
##..#######..#######..######..##
##..#######..#######..xxxx##..##
##..#######s########..xxVx##s###
##..#######..#######..xxxx##..##
##..#######..#######..######..##
##..#######..#######..######..##
.......s.................#......
.......#.................s......
##..#######..s........######..##
##..#######...........######..##
##s########.........s#######s###
##..#######...........######..##
##..#######........s..######..##
......s.........#.......s.......
......#.........s.......#.......
M#..#######..#######..######..##
##..#######..#######..######..##
```

| Quién | Ruta |
| --- | --- |
| K1 | Vaivén por la calle de la fila 9, de (19,9) a (3,9): viene de frente |
| K2 | Vaivén por la calle de la columna 11, de (11,3) a (11,15) |
| K3 | Vaivén por la calle de la fila 16, de (31,16) a (17,16) |
| VS1 | Vampiro. Vaivén por la columna 21, junto al patio prohibido |
| J1 | Jinete. Bucle por la plaza |
| G1 | Grupo de la azotea (siempre). Sale al llegar a la calle de arriba o a la columna 28; vaivén por la fila 2 junto a la salida |

La ruta sin ser visto tarda unos 18 s (8,6 s yendo directo). Al principio también vigilaba K4 la calle de la salida, pero con G1 no quedaba hueco.

### «La estación hundida» (ruta arriesgada)

`mapa_estacion.tscn`, 30 × 14: dos andenes con columnas, las vías con trenes descarrilados (penumbra solo pegada a los vagones) y escaleras en las columnas 5, 14 y 23. La salida es una puerta estrecha a la que solo se entra por (28,1).

```
............................##
....#.....#...........#......E
................#...........##
..............................
#####..#######..#######..#####
.......sssssss...#####..s...s.
........#####....#####..s...s.
........#####...sssssss..###..
.......sssssss...........###..
#####..#######..#######..#####
..............................
....#...........#..........#..
M.........#...........#...xxxx
..........................xxVx
```

| Quién | Ruta |
| --- | --- |
| P1 | Andén de arriba, fila 3, de (12,3) a (28,3) |
| P2 | Andén de abajo, fila 10, de (6,10) a (20,10) |
| P3 | Andén de arriba, fila 0, de (1,0) a (13,0) |
| P4 | Vías, fila 8, de (23,8) a (1,8) |
| P5 | Centinela de la puerta, columna 27, de (27,0) a (27,3) |
| VE1 | Vampiro, junto al almacén prohibido del andén de abajo |
| J1 | Jinete, encerrado detrás del último tren, en la columna 28: solo sale si lo atrae un ruido |
| A1 | Grupo del andén (mitad de las partidas). Sale al subir por las escaleras de la columna 23 |

La ruta sin ser visto tarda unos 12 s (7,2 s yendo directo). Al principio las vías eran todas sombra y se cruzaban corriendo, y el Jinete, suelto por ellas, se comía a los soldados de los andenes.

## Portador de arma maldita y hechicero de talismanes

Los dos son soldados (`Portador` y `Hechicero` heredan de `Soldado`), con estos cambios:

- **Portador de arma maldita** (`portador.gd`): vida 10, ve hasta 8 casillas (cono largo), pega 4 y, en Alarma, desde 4 casillas con la espada maldita. El Golpe silencioso **solo lo aturde** 4 s; al despertar sospecha y mira alrededor. Se le ve la espada negra a la espalda.
- **Hechicero de talismanes** (`hechicero.gd`, `talisman.gd`): pega 1. Tiene talismanes en el suelo (`talismanes` en la escena). Si Mika pisa uno mientras el hechicero sigue en pie, el talismán lo revela: alarma en ese punto, y se quema. Derribar al hechicero apaga todos sus talismanes.
- **Pruebas:** `prueba_elite.gd`. La búsqueda de ruta trata como vista cualquier casilla con talismán, también las que solo se rozan al cruzar una esquina.

## Zona 3: Shibuya

### «Dentro de la muralla» (primera infiltración)

`mapa_shibuya.tscn`, 30 × 18: barracones en cuadrícula y una muralla interior en la columna 17 con solo dos puertas (filas 6 y 16).

```
.................#...........E
.................##...........
...#####...#######..######....
...#####...#######..######....
...#####...#######..######....
...#####...#######..######....
...sssss............ssssss.#..
.........#.......#............
...#####...#######..######....
...#####...#######..######....
...#####...#######..######....
...........ssssss#............
.................##...........
...#####...#######..######....
...#####...#######..######....
...#####...#######..######....
M..sssss.#..........ssssss....
.................#............
```

| Quién | Ruta |
| --- | --- |
| B1 | Fila 12, de (16,12) a (1,12) |
| PA1 | Portador. Columna 19, de (19,0) a (19,11), justo detrás de la muralla |
| H1 | Hechicero. Columna 9, de (9,1) a (9,6); talismanes en (10,7), (10,12) y (19,7) |
| B2 | Columna 27, de (27,16) a (27,7), en el acceso a la salida |
| B3 | Fila 16 (la puerta de abajo), de (27,16) a (10,16) |
| B4 | Fila 6 (la puerta de arriba), de (25,6) a (11,6) |
| GP1 | Grupo del patio (siempre): sale al entrar en la fila 6 o en la 11 del lado este; vaivén por la fila 1 |

La ruta sin ser visto tarda unos 20 s (8,1 s yendo directo). Sin la muralla interior había demasiados caminos y se cruzaba casi corriendo.

### «El hueco del río» (ruta arriesgada)

`mapa_rio.tscn`, 28 × 14: Mika llega en barca al muelle; almacenes en la orilla y la muralla de Shibuya en la columna 20, con el hueco del río en las filas 9 y 10.

```
....................#......E
..........#####.....#.......
...####...#####.....#.......
...####...#####.....#..#....
...####...#####.....#.......
...####...sssss.....#.....#.
...ssss.............#.......
.............####...#...#...
...####......####...#.......
...####......####...........
.............ssss...........
#########..#################
#########M.#################
############################
```

| Quién | Ruta |
| --- | --- |
| R1 | Fila 0, de (19,0) a (7,0) |
| PR1 | Portador. Columna 18, de (18,10) a (18,2), delante del hueco |
| HR1 | Hechicero. Fila 6, de (7,6) a (12,6); talismanes en (19,9), en la boca del hueco, y en (11,6) y (16,6) |
| R2 | Dentro, fila 1, de (27,1) a (21,1), junto a la salida |
| R3 | Dentro, columna 22, de (22,10) a (22,4) |
| RG1 | Grupo de la guardia (mitad de las partidas): sale al cruzar el hueco; columna 25 |

La ruta sin ser visto tarda unos 28 s (5,2 s yendo directo): hay que esperar mucho a que el portador mire hacia otro lado. Al principio había talismanes en las dos casillas del hueco y no se podía pasar sin derribar al hechicero.

## Jefe de la zona 1: Ferid Bathory, en el hangar

No se le vence: se le escapa. Escena `mapa_hangar.tscn` (40 × 12), script `scripts/ferid.gd`.

```
............##.......##..........##.....
....##......##.......##..........##.....
....##......##...##......##......##.....
....##...........##......##.............
........##.......##..........##.....#...
........##...##......##......##........E
M.......##...##......##......##........E
........##.......##..........##.....#...
....##...........##......##.............
....##......##...##......##......##.....
....##......##.......##..........##.....
............##.......##..........##.....
```

- **Objetivo:** llegar a la rampa del avión (la `E`, al fondo) mientras Ferid persigue a Mika. Los ataques de Mika no le hacen nada.
- **Persecución:** Ferid corre a 6,5 casillas/s, más que Mika (5,5), así que no basta con correr.
- **Embestida anunciada:** si está a 7 casillas o menos, ve a Mika y tiene el camino libre, marca en el suelo una línea roja durante 0,6 s y luego la recorre en 0,25 s. Apunta adonde va a estar Mika al acabar el aviso si sigue moviéndose igual: correr recto no salva; apartarse de la línea, sí. Tras embestir se queda 0,8 s recuperándose (la ventana para ganarle distancia) y no vuelve a embestir hasta 2 s después.
- **Segunda fase:** desde el segundo punto de control, embiste dos veces seguidas (la segunda con 0,35 s de aviso).
- **Atrapar:** a 0,6 casillas atrapa a Mika: le quita 3 de vida, lo devuelve al último punto de control (columnas 0, 15 y 27) y espera 1,5 s lejos de él. Si se queda sin vida, cae.
- **Escenas:** el «antes» del guion se ve sobre el propio hangar, con el juego en pausa. Mientras persigue, Ferid dice sus frases (bocadillo) y, con Humanidad 1 o más, el otro Yuu las suyas (arriba). Al llegar a la rampa, el «después» y un recuerdo.
- **Prueba:** `prueba_ferid.gd` comprueba cada parte y que sea justo con dos jugadores automáticos: el que corre sin esquivar acaba atrapado (pierde 3 de vida); el que se aparta de la línea llega limpio en unos 8 s.

## Jefe de la zona 2: Crowley Eusford, en el cruce

Combate abierto. Escena `mapa_cruce.tscn` (22 × 16, el autobús quemado y escombros), script `scripts/crowley.gd`.

```
......................
......................
......................
....s##s..............
............s#####s...
......................
......................
......................
.M.......s#...........
..................#...
......................
......................
....s##s........#s....
......................
......................
......................
```

- **Vida 30, daño 6** (los de jefe de zona de `diseno.md`). Barra de vida abajo, con la marca de la segunda fase.
- **Ataques, siempre anunciados en rojo en el suelo:**
  - **Tajo:** de cerca (2,2 casillas, más que el Tajo de Mika), un abanico de 140° delante de él; 0,7 s de aviso.
  - **Carga:** de 3,5 a 7 casillas, una línea que apunta adonde va a estar Mika; 0,7 s de aviso.
  - **Torbellino** (solo en la segunda fase, uno de cada dos ataques de cerca): un círculo de 2,6 casillas; 0,9 s de aviso.
- **Guardia y recuperación:** tras cada ataque se queda 0,9 s recuperándose (se le ve más oscuro). Solo entonces le entra el Tajo entero; el resto del tiempo para los golpes y le entra una cuarta parte.
- **Segunda fase** a media vida: un 30 % más rápido y avisos un 25 % más cortos.
- **Rendición:** cuando su vida llega a 0 se rinde («no me ganaste»): escena de después y un recuerdo.
- **Frases:** las del guion mientras pelea, la de la segunda fase, la de «con poca vida» (a un cuarto de vida) y las del otro Yuu (Humanidad 1 o más).
- **Prueba:** `prueba_crowley.gd`. Un jugador automático que solo se queda pegando cae con Crowley aún a 18; uno que sale de lo marcado y pega en la recuperación gana sin perder vida en unos 13 s.

## Jefe de la zona 3: Guren Ichinose, en el patio

Combate contra un arma maldita. Escena `mapa_patio.tscn` (22 × 16), script `scripts/guren.gd`, que hereda de Crowley con sus propios números (`GUREN_*` en `config.gd`; cada jefe da los suyos en `parametros()`).

```
......................
....######............
....s....s............
......................
...............s#.....
......................
......................
......................
.M........s#.......#..
......................
......................
.....#................
.....s.........s#.....
......................
......................
......................
```

- **Vida 30, daño 6.** Más rápido que Crowley (3,6 casillas/s), avisos más cortos (0,6 s) y recuperación más corta (0,8 s). En lugar de la carga, una **estocada** más larga, estrecha y rápida.
- **Segunda fase** a media vida: cambia la voz (Mahiru, el demonio de la espada) y su ataque especial son **tres sombras** de 1,3 casillas que caen donde va a estar Mika y a los dos lados (0,9 s de aviso).
- Guardia fuera de la recuperación (le entra una cuarta parte), como Crowley. Cuando su vida llega a 0 cae y deja pasar a Mika: escena de después y el final.
- **Prueba:** `prueba_guren.gd`. Sin esquivar se cae con Guren aún a 19; esquivando y castigando se gana sin perder vida en unos 13 s.

### Eventos de la zona 3

- **El desertor** (confiar): se salta la parada siguiente y su recompensa (si es la Prueba de la sed, el recuerdo). Nunca se salta al jefe.
- **El escuadrón de Yuu** (quedarse mirando): la siguiente Prueba de la sed empieza más cerca de la salida (`inicio_cerca` del mapa, (6,6)).
- **La escena del fondo de la zona 3** («En el suelo»): aparece el botón Beber. Se puede seguir sin beber; si se bebe, la prueba queda **cedida**: pierde el recuerdo recién ganado y 1 de Humanidad, la sed baja a 0, gana una mejora al azar y se ve el texto de cedida de la zona 3.

## Plan de construcción

Cada paso queda jugable antes de empezar el siguiente, y el arte final no entra hasta el paso 9.

1. Mapa isométrico con muros que chocan, Y-sort y Mika (una cápsula de color) moviéndose por las diagonales correctas.
2. Un soldado con ruta de patrulla y su cono de visión dibujado en el suelo.
3. Medidor de detección y los tres estados: Oculto, Sospecha y Alarma.
4. Golpe silencioso, Tajo, Impulso y ruido.
5. Sed con sus tramos, vial, beber sangre y Humanidad. HUD.
6. Salida del mapa y pantalla de resultado.
7. Primer mapa completo con sus 4 soldados, sombras y vial.
8. Prueba de la sed.
9. Pulido al estilo Hades: parada breve al golpear, sacudida de cámara, destellos, partículas y rastro del dash.
10. Eventos de texto y encadenado de paradas.

## Organización del proyecto

El proyecto de Godot vive en `sed/`.

| Carpeta | Contenido |
| --- | --- |
| `escenas/` | Una escena por entidad: `mika.tscn`, `soldado.tscn`, `eco.tscn`, `mapa_*.tscn`, `hud.tscn`. `mapa_pasos.tscn` es el puesto original de 10 × 10, solo para las pruebas |
| `scripts/` | Un script por entidad, más `config.gd` (todos los números), `paleta.gd` (los colores de la paleta) e `iso.gd` (conversión entre casillas y pantalla) |
| `recursos/` | TileSet y otros recursos |
| `arte/` | Gráficos provisionales |
| `pruebas/` | Pruebas automáticas de cada paso, sin ventana |
| `datos/` | Datos de los recuerdos (momento y mejora); el texto viene del guion, que no está en git |

- **Expedición:** vive en el autoload `Expedicion` (`scripts/expedicion.gd`). Los scripts la piden con `EstadoExpedicion.actual()`. Si se abre un mapa suelto con F6, no hay expedición y el mapa funciona solo.
- **Números en un solo sitio:** todos los valores de la tabla de reglas están en `scripts/config.gd`. Para ajustar el juego basta con tocar ese archivo.
- **Mapas desde texto:** cada mapa se dibuja a partir de su plano de caracteres, igual que el del puesto de control.
- **Arte provisional:** hasta el paso 9 se usan formas simples: cápsulas para los personajes y rombos para las casillas.
- **Paleta:** fría. El ámbar se reserva para la sospecha, el rojo para la sangre, la sed y la alarma, y el turquesa para los viales y la salida. Los colores salen de `scripts/paleta.gd`, con los códigos de `diseno.md`.
- **Commits:** pequeños, uno por paso jugable.
- **Pruebas:** desde `sed/`, `./pruebas/ejecutar.sh` ejecuta todas y dice cuáles fallan. Cada una se puede lanzar sola con `godot --headless --path . -s res://pruebas/prueba_paso5.gd`. `pruebas/comun.gd` incluye la búsqueda de una ruta sin ser visto, que sirve para comprobar cualquier mapa nuevo.
