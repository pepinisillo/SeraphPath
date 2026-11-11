# Owari no Seraph: Sed — Documento de diseño (ruta de Mika)

> Versión para tiempo real. Las reglas y los números exactos de movimiento, visión, sed y combate están en `reglas.md` y mandan sobre este documento.

## Resumen

*Sed* es un roguelike de sigilo y acción en tiempo real: controlas a Mikaela Hyakuya en expediciones desde Sanguinem hasta Shibuya para llegar a Yuu.

| Aspecto | Decisión |
| --- | --- |
| Género | Roguelike de sigilo y acción en tiempo real, un solo personaje |
| Vista | Isométrica 2D, tipo Hades |
| Partida | 30 a 45 minutos, con muerte permanente |
| Momento de la historia | Después de que Mika descubre que Yuu sigue vivo |
| Motor | Godot 4 con GDScript y renderer Forward+; PC primero, Android después |
| Tipo de proyecto | Fan juego gratuito, con arte y música propios |

**Relación central.** Yuu y Mika son almas gemelas, en sentido romántico. Es una decisión de este fan juego; el manga no lo hace explícito.

Tres pilares guían cada decisión de diseño:

1. **Todo poder tiene precio.** La sangre humana hace fuerte a Mika y le quita humanidad.
2. **Uno contra muchos.** Mika gana por posición y sorpresa, nunca por números.
3. **Información clara.** El jugador ve conos de visión, medidores de detección y patrullas antes de decidir.

La historia y el contenido están en `historia.md` y `contenido.md`.

## Mika como personaje jugable

Mika es muy fuerte y muy frágil: elimina de un golpe a quien no lo ha visto, pero rodeado por tres soldados cae en segundos.

| Habilidad | Coste | Efecto |
| --- | --- | --- |
| Golpe silencioso | Enfriamiento corto | Derriba sin ruido a un enemigo que no lo ha visto |
| Tajo | Enfriamiento corto | Daño de espada a un enemigo cercano; hace ruido |
| Impulso | Sube la sed | Dash corto; hace ruido |
| Sentidos | Enfriamiento largo | Revela enemigos y patrullas tras las paredes por unos segundos |
| Espada, bebe mi sangre | 3 de vida | Daño doble y más alcance durante unos segundos; los vampiros la huelen |
| Beber sangre | Mantener pulsado | Solo sobre un humano derribado; ver La sed |

La espada sigue el canon: es un arma de vampiro que se alimenta de la sangre de quien la empuña. Por eso su poder se paga con vida.

Las mejoras de espada (filos) se consiguen durante la partida y cambian una habilidad cada una.

## La sed

La sed es un medidor de 0 a 100 que sube solo y obliga a elegir entre debilitarse o beber sangre humana. No baja al cambiar de mapa: se arrastra durante toda la expedición.

| Tramo | Sed | Efecto |
| --- | --- | --- |
| Saciado | 0 a 29 | Regenera vida poco a poco |
| Estable | 30 a 59 | Sin efectos |
| Sediento | 60 a 89 | Más lento y no puede usar Sentidos |
| Frenesí | 90 a 100 | El jugador pierde el control: Mika ataca al humano más cercano y bebe |

| Fuente | Sed | Otros efectos | Coste |
| --- | --- | --- | --- |
| Vial de sangre de Krul | Baja 40 | Ninguno | Escaso |
| Sangre humana | Baja a 0 | Cura toda la vida y da una mejora para el resto de la partida | 1 punto de Humanidad |

### Humanidad

Mika empieza con 3 puntos de Humanidad y pierde 1 cada vez que bebe sangre humana, por decisión propia o en Frenesí. Con 0 se convierte en vampiro completo: gana poder permanente, pero cambia el final.

En el canon basta un solo trago para completar la transformación. Aquí son tres para que el jugador pueda equivocarse una vez y sentir que se acerca al límite.

Los viales nunca alcanzan para toda la expedición: hacia la mitad de la partida, el jugador tiene que decidir a quién y cuándo.

## Sigilo

- **Visión.** Cada enemigo ve en un cono frente a él. Los muros lo cortan y la sombra lo acorta a la mitad.
- **Detección gradual.** Un medidor sobre cada enemigo se llena mientras ve a Mika: rápido de cerca, lento de lejos.
- **Ruido.** El Tajo, el Impulso y la espada activa hacen ruido. Quien lo oye va a investigar.
- **Cuerpos.** Un soldado derribado puede ser descubierto por otra patrulla.
- **Objetivo.** Llegar a la salida. Cada mapa ofrece un objetivo opcional, como robar un vial o derribar a un oficial.

### Estados de alerta

| Estado | Qué hacen los enemigos | Cómo se sale |
| --- | --- | --- |
| Oculto | Siguen su patrulla | Ven u oyen algo → Sospecha |
| Sospecha | Investigan el punto durante unos segundos | Nada en ese tiempo → Oculto; ven a Mika → Alarma |
| Alarma | Persiguen a Mika; llegan refuerzos; no hay Golpe silencioso | Un tiempo sin verlo → Sospecha |

## Enemigos

Hay tres bandos y cada uno pide un sigilo distinto: de los humanos Mika esconde el cuerpo, de los vampiros esconde sus intenciones, y a los Jinetes los usa.

| Enemigo | Bando | Comportamiento | Cómo lo enfrenta Mika |
| --- | --- | --- | --- |
| Soldado raso | Ejército | Patrulla fija, a menudo en pareja | Golpe silencioso; evitar los grupos |
| Portador de arma maldita | Ejército | Élite con cono largo y ataque a distancia | El Golpe silencioso solo lo aturde |
| Hechicero de talismanes | Ejército | Coloca talismanes que revelan a Mika si los pisa | Derribarlo apaga sus talismanes |
| Vampiro común | Vampiros | No ataca a Mika al verlo; lo delata si lo ve atacar vampiros, robar viales o entrar en zonas prohibidas | Actuar fuera de su vista; huele la espada activa |
| Jinete del Apocalipsis | Monstruos | Persigue solo a humanos e ignora a los vampiros | Atraerlo con ruido hacia las patrullas |
| Noble vampiro | Vampiros | Jefe de zona, con fases y ataques anunciados | Combate abierto |

| Enemigo | Vida | Daño |
| --- | --- | --- |
| Soldado raso | 4 | 2 |
| Hechicero de talismanes | 4 | 1 |
| Portador de arma maldita | 10 | 4 |
| Vampiro común | 8 | 3 |
| Jinete del Apocalipsis | 14 | 5 |
| Jefe de zona | 30 | 6 |

Solo se puede beber de humanos derribados. Los vampiros y los Jinetes no dan sangre.

## Estructura de la expedición

Una expedición cruza 3 zonas de 5 paradas cada una, y cada zona termina en un jefe.

| Zona | Lugar | Predominan | Jefe |
| --- | --- | --- | --- |
| 1 | Sanguinem, la ciudad subterránea | Vampiros | Ferid Bathory: no se le vence, se le escapa |
| 2 | Ruinas de Shinjuku | Jinetes y patrullas de ambos bandos | Crowley Eusford: combate abierto |
| 3 | Shibuya, tras la muralla | Ejército | Guren Ichinose: combate contra un arma maldita |

Cada zona empieza con una infiltración, se divide en dos rutas de 2 paradas (una segura y una arriesgada) y vuelve a unirse en la Prueba de la sed y el jefe.

```
                ┌─ Refugio ──── Evento ───────┐
Infiltración ───┤                             ├── Prueba de la sed ── Jefe
                └─ Emboscada ── Infiltración ─┘
```

| Parada | Qué pasa | Qué deja |
| --- | --- | --- |
| Infiltración | Mapa con salida y objetivo opcional | Avance; a veces un vial o un filo |
| Emboscada | Mapa pequeño que empieza en Alarma | Un filo |
| Evento | Decisión narrativa en texto, sin mapa | Varía; suele ofrecer sangre a cambio de Humanidad |
| Refugio | Elegir: curar vida o mejorar la espada | Lo elegido |
| Prueba de la sed | Escena dentro de la mente de Mika | Un recuerdo |
| Jefe | Mapa único de la zona | Paso a la siguiente zona |

## Pruebas de la sed

La versión de Mika de la prueba del contrato: un mapa dentro de su mente donde su instinto vampiro lo tienta a beber, con la forma y la voz de personas de sus recuerdos.

- Mika no puede atacar.
- Los ecos del recuerdo lo siguen y le ofrecen sangre.
- La sed sube el doble de rápido, y la salida es Yuu, al fondo del mapa.

| Resultado | Condición | Efecto |
| --- | --- | --- |
| Superada | Llega a la salida sin beber | Gana un recuerdo |
| Cedida | Bebe de un eco | Sed a 0 y una mejora; pierde 1 de Humanidad |
| Fallida | La sed llega a 100 | Despierta con la sed en 90 y el siguiente mapa empieza en Alarma |

## Progresión y finales

Lo que Mika consigue en una expedición se pierde al morir; solo los recuerdos pasan a la siguiente partida.

| Recurso | Dónde se consigue | Dura |
| --- | --- | --- |
| Filos de espada | Emboscadas, refugios y objetivos opcionales | La expedición |
| Viales de Krul | Infiltraciones y eventos | Hasta usarlos |
| Mejoras de sangre humana | Al beber | La expedición |
| Recuerdos | Pruebas superadas y jefes vencidos | Para siempre |

| Final | Humanidad | Qué pasa |
| --- | --- | --- |
| La sangre de Yuu | 3 | Llega como medio vampiro, sin haber bebido sangre humana. Yuu le ofrece la suya y Mika completa su transformación con él. Es el más difícil |
| En el límite | 1 o 2 | Llega a Yuu, que nota cuánto ha cambiado |
| Vampiro completo | 0 | Llega con todo su poder y ya no hay vuelta atrás |

El final con Humanidad 3 sigue al manga: la única sangre humana que Mika acepta es la de Yuu. Usa la misma acción Beber sangre que el jugador rechazó toda la partida, y esta vez no cuesta Humanidad.

## Estilo visual

Vista isométrica 2D tipo Hades: personajes grandes y expresivos, escenarios pintados y efectos vistosos en cada golpe. La paleta es fría; los colores cálidos se reservan para el peligro: ámbar para la sospecha, rojo para la sangre y la alarma.

| Decisión | Valor |
| --- | --- |
| Cámara | Isométrica 2:1, fija, siguiendo a Mika |
| Casilla de mapa | 128 × 64 px (rombo) |
| Personajes | 96 a 128 px de alto, 8 direcciones |
| Escenarios | Pintados en piezas grandes sobre la cuadrícula de casillas |
| Renderer | Forward+ |

### Cómo producir el arte

Hades usa modelos 3D convertidos a sprites 2D. Para una sola persona hay dos caminos, y se elige cuando el juego ya sea divertido con formas simples:

| Camino | Cómo | A favor | En contra |
| --- | --- | --- | --- |
| Modelos 3D renderizados a sprites | Modelar y animar en Blender; exportar cada animación desde 8 ángulos | Lo más parecido a Hades; se anima una vez para las 8 direcciones | Hay que aprender Blender |
| Animación por piezas | Dibujar a Mika en partes y animarlas con huesos en Godot (`Skeleton2D`) | Se dibuja poco y se ve fluido | Cada dirección necesita su propio juego de piezas |

### Paleta

| Uso | Color | Código |
| --- | --- | --- |
| Muros | Casi negro azulado | #14171F |
| Sombra | Azul noche | #1D2333 |
| Suelo de ruinas | Gris azulado oscuro | #2B303B |
| Detalles y bordes | Gris frío claro | #8A93A6 |
| Personaje jugable y texto | Blanco hueso | #E8E6DF |
| Soldados | Verde apagado | #5E6B5A |
| Vampiros | Violeta frío | #7A5FA8 |
| Viales y salida | Turquesa | #4FB8A8 |
| Sospecha | Ámbar | #E0A83A |
| Sangre, sed y alarma | Rojo | #C8323C |

### Sensación al jugar

- **Golpes con peso:** parada de 2 a 4 cuadros al conectar, sacudida leve de cámara y destello rojo.
- **Dash con rastro:** siluetas que se desvanecen detrás de Mika.
- **Sigilo legible:** conos de visión pintados en el suelo, ámbar donde ser visto causa sospecha y rojo donde causa alarma; medidor de detección sobre cada cabeza.
- **Muros que no estorban:** los que tapan a Mika se vuelven semitransparentes.
- **La sed se ve:** la pantalla pierde color según sube; en Frenesí solo queda el rojo.

### Arte por producir

| Pieza | Animaciones o variantes |
| --- | --- |
| Mika | Quieto, correr, Tajo, Golpe silencioso, dash, beber, daño, Frenesí |
| Soldado | Quieto, caminar, alerta, atacar, derribado |
| Eco | Flotar, ofrecer |
| Escenarios | Sanguinem, ruinas de Shinjuku, Shibuya |
| Efectos | Tajo, sangre, dash, vial, detección |
| Interfaz | Vida, sed, Humanidad, viales, estado de alerta |

## Preguntas abiertas

- [ ] ¿La Humanidad se pierde en tres tragos o en uno, como en el canon?
- [ ] ¿El Golpe silencioso mata o solo derriba? (Ahora derriba: los cuerpos pueden descubrirse y son los únicos de los que se bebe.)
- [ ] ¿Cuánto se respeta el canon? Los jefes y el orden de las zonas son una propuesta.

### Después: la ruta del escuadrón

| En la ruta de Mika | En la ruta del escuadrón |
| --- | --- |
| Una unidad | Cinco unidades |
| Sed | Posesión, un medidor por personaje |
| Prueba de la sed | Prueba del contrato con el demonio de cada arma |
