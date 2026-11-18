class_name Config
## Todos los números del juego en un solo sitio. Valores iniciales: se ajustan jugando.
## Distancias en casillas, tiempos en segundos.

# --- Vista ---
const ANCHO_CASILLA := 128.0 # px en pantalla
const ALTO_CASILLA := 64.0 # px en pantalla

# --- Mika ---
const VELOCIDAD_MIKA := 5.5 # casillas/s
const VELOCIDAD_MIKA_SEDIENTO := 3.5 # casillas/s, con sed >= SED_TRAMO_LENTO
const RADIO_MIKA := 0.3 # casillas, para chocar con muros
const VIDA_MIKA := 12

# --- Impulso ---
const IMPULSO_DISTANCIA := 4.0
const IMPULSO_DURACION := 0.15
const IMPULSO_ENFRIAMIENTO := 1.5
const IMPULSO_SED := 8

# --- Tajo ---
const TAJO_DANO := 4
const TAJO_ALCANCE := 1.25
const TAJO_ENFRIAMIENTO := 0.4
const ATAQUE_ANGULO := 120.0 # grados delante de Mika en los que alcanzan Tajo y Golpe silencioso

# --- Golpe silencioso ---
const GOLPE_SILENCIOSO_ALCANCE := 1.25
const GOLPE_SILENCIOSO_ENFRIAMIENTO := 0.5

# --- Sangre ---
const BEBER_DURACION := 2.0
const VIAL_SED := -40
const VIAL_DURACION := 0.5
const BEBER_DISTANCIA := 1.0 # casillas hasta el cuerpo
const VIAL_RADIO_RECOGER := 0.5 # casillas para recoger un vial del suelo

# --- Sed ---
const SED_MAX := 100
const SED_INICIAL := 30
const SED_INTERVALO := 3.0 # +1 cada tanto
const SED_POR_GOLPE := 3
const SED_TRAMO_REGENERA := 29 # 0–29 regenera
const SED_TRAMO_LENTO := 60 # 60–89 más lento y sin Sentidos
const SED_TRAMO_FRENESI := 90
const REGENERACION_INTERVALO := 6.0 # +1 de vida
const FRENESI_DURACION := 4.0
const FRENESI_RESPIRO := 3.0 # s de control si el Frenesí acaba sin beber, antes de que vuelva

# --- Mejoras de sangre ---
const MEJORA_FUERZA := 2 # daño extra del Tajo
const MEJORA_VIGOR := 4 # vida máxima extra
const MEJORA_VELOCIDAD := 1.0 # casillas/s extra

# --- Sensación (paso 9): solo dibujo y tiempo, no cambian reglas ---
const PARADA_TAJO := 0.05 # s congelado al conectar un Tajo (3 cuadros a 60 fps)
const PARADA_SILENCIOSO := 0.033 # s al derribar en silencio (2 cuadros)
const PARADA_RECIBIDO := 0.066 # s al recibir un golpe (4 cuadros)
const SACUDIDA_TAJO := 0.35 # trauma de cámara, de 0 a 1
const SACUDIDA_RECIBIDO := 0.5
const SACUDIDA_CAIDA := 0.9
const SACUDIDA_MAXIMA := 18.0 # px de desplazamiento con trauma 1
const SACUDIDA_CALMA := 1.6 # trauma que se pierde por segundo
const DESTELLO_DURACION := 0.15 # s que dura el destello rojo de quien recibe un golpe
const RASTRO_INTERVALO := 0.03 # s entre siluetas del dash
const RASTRO_DURACION := 0.25 # s que tarda en desvanecerse cada silueta
const SED_COLOR_INICIO := 30 # sed desde la que la pantalla empieza a perder color
const SED_COLOR_PERDIDO := 0.8 # color perdido justo antes del Frenesí (0 a 1)

# --- Resultado ---
const RESULTADO_ESPERA_CAIDA := 1.5 # s entre la caída de Mika y la pantalla de resultado

# --- Humanidad ---
const HUMANIDAD_INICIAL := 3

# --- Visión y detección enemiga ---
const VISION_ANGULO := 90.0 # grados
const VISION_ALCANCE := 5.0
const VISION_ALCANCE_SOMBRA := 2.5
const VISION_RAYOS := 48 # solo para dibujar el cono
const DETECCION_LEJOS := 1.2 # s para llenar
const DETECCION_CERCA := 0.3 # s para llenar
const DETECCION_DISTANCIA_CERCA := 3.0
const DETECCION_SOSPECHA := 0.5 # fracción del medidor que dispara la Sospecha
const DETECCION_VACIADO := 3.0 # s para vaciarse del todo cuando deja de verlo
const RUIDO_RADIO := 4.0
const RUIDO_ONDA_DURACION := 0.4 # s que dura la onda dibujada
const SOSPECHA_DURACION := 6.0
const ALARMA_REFUERZO_INTERVALO := 10.0
const ALARMA_REFUERZOS_MAX := 4
const ALARMA_OLVIDO := 10.0

# --- Soldado ---
const SOLDADO_VIDA := 4
const SOLDADO_DANO := 2
const SOLDADO_GOLPE_INTERVALO := 1.0
const SOLDADO_VELOCIDAD_PATRULLA := 2.8
const SOLDADO_VELOCIDAD_ALARMA := 4.4
const SOLDADO_PAUSA_RUTA := 0.6 # s quieto en cada punto de la ruta
const SOLDADO_GIRO := 6.0 # rad/s al girar la mirada
const RADIO_SOLDADO := 0.3
const SOLDADO_GIRO_BUSQUEDA := 1.6 # rad/s al mirar alrededor del punto investigado
const SOLDADO_DISTANCIA_GOLPE := 0.9 # en alarma se detiene a esta distancia de Mika

# --- Prueba de la sed ---
const PRUEBA_SED_INTERVALO := 1.5
const PRUEBA_ECO_DISTANCIA := 1.5
const PRUEBA_ECO_VELOCIDAD := 1.9
const PRUEBA_ECO_RADIO := 0.35 # casillas: los ecos cortan el paso a Mika
const PRUEBA_ECO_VOZ := 3.0 # casillas a las que se oye lo que dice un eco
const PRUEBA_SED_FALLIDA := 90 # sed con la que despierta si la prueba falla

# --- Escenas con diálogo ---
const DIALOGO_LETRAS_POR_S := 55.0 # velocidad del texto que aparece poco a poco
const DIALOGO_NEGRO := 2.5 # s de pantalla en negro (sin contar los fundidos)
const DIALOGO_FUNDIDO := 0.6 # s de cada fundido a negro
const DIALOGO_SILENCIO := 3.0 # s de silencio donde el otro Yuu ya no comenta (Humanidad 0)
