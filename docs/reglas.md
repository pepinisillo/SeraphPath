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

### Prueba de la sed

Un mapa dentro de la mente de Mika, donde no puede atacar. La sed sube 1 cada 1,5 s, y 1 más cada 1,5 s por cada eco a menos de 1,5 casillas.
Los ecos lo siguen a 1,9 casillas/s y le ofrecen sangre.

| Resultado | Condición |
| --- | --- |
| Superada | Llegar a la salida sin beber |
| Cedida | Beber (−1 Humanidad) |
| Fallida | Llegar a 100 de sed |

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
| `scripts/` | Un script por entidad, más `config.gd` (todos los números) e `iso.gd` (conversión entre casillas y pantalla) |
| `recursos/` | TileSet y otros recursos |
| `arte/` | Gráficos provisionales |

- **Números en un solo sitio:** todos los valores de la tabla de reglas están en `scripts/config.gd`. Para ajustar el juego basta con tocar ese archivo.
- **Mapas desde texto:** cada mapa se dibuja a partir de su plano de caracteres, igual que el del puesto de control.
- **Arte provisional:** hasta el paso 9 se usan formas simples: cápsulas para los personajes y rombos para las casillas.
- **Paleta:** fría. El ámbar se reserva para la sospecha y el rojo para la sangre, la sed y la alarma.
- **Commits:** pequeños, uno por paso jugable.
