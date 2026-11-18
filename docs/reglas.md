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

El juego empieza en la pantalla de título. Una expedición recorre hoy la **zona 1** completa:

```
                ┌─ Refugio ──── Evento ─────────┐
Infiltración ───┤                               ├── Prueba de la sed ── Jefe
                └─ Emboscada ── Infiltración ───┘
```

- **Viales:** cada expedición empieza con 2, los de la caja de Krul (4 con el recuerdo 1).
- **Estado entre paradas:** Mika arrastra vida, sed, Humanidad, viales y mejoras de una parada a la siguiente. Si cae, la expedición termina y solo se conservan los recuerdos.
- **Mapa de paradas:** muestra lo hecho, la parada actual y los avisos para el siguiente mapa (empieza en Sospecha o Alarma, la sed no sube, patrullas visibles). Sin el recuerdo 3, «El mapa», las dos rutas se ven como «? → ?».
- **Infiltración:** el puesto de control.
- **Emboscada:** el mismo puesto, empezando en Alarma. Su recompensa, un filo, llegará con los filos.
- **Refugio:**
  - Muestra la línea de Mika según su Humanidad (de `historia.md`).
  - Permite curar toda la vida.
  - «Mejorar la espada» aparece desactivado hasta que existan los filos.
- **Evento:** sale uno al azar de los de la zona 1 que no hayan salido en la expedición: «La doncella de Krul», «Lacus y René», «La copa de Ferid» y «La carta sin enviar».
  - «El filo exigente» queda fuera hasta que existan los filos.
  - Los efectos que dependen de vampiros aún no existen y la opción lo dice: «aún sin efecto».
  - Los datos de los diez eventos están en `scripts/eventos.gd`.
- **Prueba de la sed:**
  - Superada: desbloquea el siguiente recuerdo y lo enseña.
  - Fallida: el siguiente mapa empieza en Alarma.
- **Jefe:** Ferid Bathory aún no existe. Llegar a él termina, por ahora, la expedición.
- **Inicio:** antes de la primera expedición se ve la escena con Krul, una sola vez (queda apuntado en `user://recuerdos.cfg`). En las siguientes sale solo la línea de la caja de Krul (sección «Cada expedición» del guion), donde `{viales}` se cambia por el número de viales en letra: «dos», o «cuatro» con el recuerdo 1.
- **Recuerdos:** se guardan en disco (`user://recuerdos.cfg`) y se pueden releer desde el título.
  - Se ganan en orden. El 7, «Lo que nunca dije», no se gana con Humanidad 0.
  - El comentario del otro Yuu depende de la Humanidad: «hambriento» con 3, «lleno» con 2 o 1, y con 0 un silencio de 3 s. En la galería del título se leen como con Humanidad 3.
- **Escenas con diálogo** (`scripts/dialogo.gd`): el texto aparece poco a poco, párrafo a párrafo, y los ya leídos quedan arriba más apagados. Avanzar completa el párrafo o pasa al siguiente; saltar enseña todo de golpe. La acotación «Pantalla en negro» funde a negro 2,5 s. Narración en gris, diálogo en blanco hueso, «Mika, ahora» en turquesa y el otro Yuu en rojo. Los retratos llegarán con el arte.
- **Guion:** es provisional y **no está en git**. `scripts/guion.gd` lee los `.md` de `historia/guion/` (junto a `sed/`) o, si algún día se copia dentro del juego, de `sed/datos/guion/`. Los párrafos se separan con una línea en blanco; las líneas `*(…)*` son notas para el juego y no se enseñan. Si no hay guion, el inicio no aparece y los recuerdos solo dicen su mejora. Cambiar los diálogos no exige tocar código.
- **Mejoras permanentes de los recuerdos:**
  1. Empieza con 4 viales en vez de 2.
  2. La sed sube 2 por golpe, no 3.
  3. Ves qué hay en cada ruta.
  4. Una vez por expedición sobrevive con 1 de vida.
  5. Sediento empieza en 70.
  6. El Impulso cuesta 5 de sed.
  7. Abre el final «La sangre de Yuu», que llegará con los finales.

## Primer mapa: «Puesto de control»

Cada carácter es una casilla: `#` muro · `.` suelo · `s` sombra · `M` inicio de Mika · `E` salida · `V` vial de Krul (opcional).
La columna 0 está a la izquierda y la fila 0 arriba, en coordenadas de casilla; en pantalla el mapa aparece girado en diagonal.

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

En la vista isométrica un muro tapa lo que tiene detrás, así que los muros que quedan entre la cámara y Mika se vuelven semitransparentes.

Cada soldado empieza en el primer punto de su ruta, mirando hacia el segundo. La prueba automática del paso 7 busca una ruta de la `M` a la `E` en la que nadie vea nunca a Mika, la reproduce en el juego y comprueba que **no basta con correr**: la ruta debe tardar al menos 1,4 veces lo que se tarda yendo directo.

Al principio S2 y S4 empezaban en (4,3) y (5,0), alejándose del camino de Mika, y se podía cruzar el mapa en unos 5 s corriendo a la espalda de las patrullas. Ahora empiezan en el otro extremo. La ruta sin ser visto tarda unos 8 s (frente a 3,5 s yendo directo) y exige esperar al principio y esconderse en el pasillo de sombra de la columna 7 hasta que S4 se dé la vuelta.

## Segundo mapa: «Túneles de abastecimiento»

La infiltración de la ruta arriesgada de la zona 1 (la primera sigue siendo el puesto de control). Escena `mapa_tuneles.tscn`; se juega solo con F6.

```
......#.....sE
.####.#.###.s.
.#ss#...#.#...
.#..#.###.#...
...........#..
##.###s###.#.#
M..#.....#....
.#.#.###.#.##.
.#.......#.V#.
.#####.#####..
......s.......
```

| Soldado | Ruta |
| --- | --- |
| T1 | Vaivén por el pasillo de la fila 4, de (10,4) a (0,4): empieza en el extremo lejano y viene hacia Mika |
| T2 | Bucle por el salón central: (4,6) → (8,6) → (8,8) → (4,8) |
| T3 | Vaivén por la columna 12, de (12,3) a (12,6), vigilando el acceso derecho a la salida |
| T4 | Vaivén por la fila 0, de (7,0) a (11,0), junto a la salida |
| T5 | Vaivén por la fila 10, de (13,10) a (3,10); no llega a la columna 0 para no ver el inicio |

- **Diseño:** 14 × 11 casillas, sin cuellos de botella absolutos: a la salida se llega por la fila 0 o por la columna derecha. El vial está en un rincón junto a la ruta de T3. Los refuerzos entran por (13,10).
- **Ruta sin ser visto:** la prueba `prueba_tuneles.gd` comprueba que existe, la reproduce en el juego y verifica que no basta con correr. La más rápida tarda unos 7 s (frente a 3,8 s yendo directo) y obliga a esconderse en la sombra de (2,2) y (3,3) hasta que pase T1.
- **Cómo se ajustó:** en la primera versión bastaba con correr por la fila 10 y luego por la fila 4 detrás de T1. Por eso se añadió T5 y se invirtió la ruta de T1.

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
| `escenas/` | Una escena por entidad: `mika.tscn`, `soldado.tscn`, `eco.tscn`, `mapa_*.tscn`, `hud.tscn` |
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
