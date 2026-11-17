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
- **Recuerdos:** se guardan en disco (`user://recuerdos.cfg`) y se pueden releer desde el título. Los guiones se copiaron de `historia.md` a `sed/datos/recuerdos.json`; si cambias un guion, actualiza los dos.
- **Mejoras permanentes de los recuerdos:**
  1. Empieza con 2 viales.
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
| S2 | Vaivén por la fila 3, de (4,3) a (9,3) |
| S3 | Vaivén por la columna 9, de (9,4) a (9,8) |
| S4 | Vaivén por la fila 0, de (5,0) a (8,0), vigilando la salida |

En la vista isométrica un muro tapa lo que tiene detrás, así que los muros que quedan entre la cámara y Mika se vuelven semitransparentes.

Cada soldado empieza en el primer punto de su ruta, mirando hacia el segundo. La prueba automática del paso 7 busca una ruta de la `M` a la `E` en la que nadie vea nunca a Mika y la reproduce en el juego. Con las rutas actuales existe, y es muy rápida: saliendo al instante y siguiendo la espalda de las patrullas (columna 3, fila 5, columna 6, fila 3 y columna 9), Mika llega a la salida en unos 5 s, porque los cuatro soldados empiezan alejándose de ese camino. Si se quiere que el mapa exija esperar o usar las sombras, basta con cambiar dónde empieza alguna patrulla.

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
| `datos/` | Textos del juego copiados de `docs/` (guiones de los recuerdos) |

- **Expedición:** vive en el autoload `Expedicion` (`scripts/expedicion.gd`). Los scripts la piden con `EstadoExpedicion.actual()`. Si se abre un mapa suelto con F6, no hay expedición y el mapa funciona solo.
- **Números en un solo sitio:** todos los valores de la tabla de reglas están en `scripts/config.gd`. Para ajustar el juego basta con tocar ese archivo.
- **Mapas desde texto:** cada mapa se dibuja a partir de su plano de caracteres, igual que el del puesto de control.
- **Arte provisional:** hasta el paso 9 se usan formas simples: cápsulas para los personajes y rombos para las casillas.
- **Paleta:** fría. El ámbar se reserva para la sospecha, el rojo para la sangre, la sed y la alarma, y el turquesa para los viales y la salida. Los colores salen de `scripts/paleta.gd`, con los códigos de `diseno.md`.
- **Commits:** pequeños, uno por paso jugable.
- **Pruebas:** desde `sed/`, `./pruebas/ejecutar.sh` ejecuta todas y dice cuáles fallan. Cada una se puede lanzar sola con `godot --headless --path . -s res://pruebas/prueba_paso5.gd`.
