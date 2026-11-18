# Dificultad medida con jugadores automáticos

Lo genera `sed/pruebas/informe_dificultad.gd` (2026-11-18). Son jugadores perfectos: un jugador de verdad tarda más y se equivoca, así que esto marca el suelo de la dificultad, no la experiencia.

## Infiltraciones

Con patrullas al azar (semillas 1, 2, 3) y los grupos saliendo al pisar su zona. «Ruta» es lo que tarda la ruta sin ser visto más corta que encuentra la planificación (prudente); «directo», lo que se tarda corriendo sin esperar; «¿corriendo te ven?», si ir directo te delata.

«Menos exacto» repite cada ruta 5 veces llegando a cada casilla hasta 0,15 s tarde (sin acumularlo), como alguien que reacciona algo tarde: cuántas veces sigue sin ser visto.

| Mapa | Ruta sin ser visto (s) | Directo (s) | Veces más | ¿Corriendo te ven? | Menos exacto |
| --- | --- | --- | --- | --- | --- |
| Puesto de control | 21.8, 19.6, 20.7 | 8.4 | 2.5 | 3 de 3 | 15 de 15 |
| Túneles de abastecimiento | 14.5, 16.2, 9.1 | 7.9 | 1.7 | 2 de 3 | 15 de 15 |
| Ruinas de Shinjuku | 9.0, 14.0, 14.1 | 8.6 | 1.4 | 2 de 3 | 15 de 15 |
| La estación hundida | 9.5, 12.7, 13.7 | 7.2 | 1.7 | 3 de 3 | 15 de 15 |
| Dentro de la muralla | 18.7, 11.4, 10.5 | 8.1 | 1.7 | 3 de 3 | 15 de 15 |
| El hueco del río | 27.7, 6.7, 10.6 | 5.2 | 2.9 | 3 de 3 | 15 de 15 |

## Jefes

Dos jugadores: uno que no esquiva nada y otro que sale de lo marcado en el suelo (y, contra Crowley y Guren, solo pega mientras se recuperan).

| Jefe | Sin esquivar | Esquivando |
| --- | --- | --- |
| Ferid (llegar a la rampa) | llega, atrapado 1 veces, vida 9, 9.5 s | llega, atrapado 0 veces, vida 12, 8.1 s |
| Crowley | pierde, vida de Mika 0, del jefe 18, 4.0 s | gana, vida de Mika 12, del jefe 0, 12.8 s |
| Guren | pierde, vida de Mika 0, del jefe 19, 3.7 s | gana, vida de Mika 12, del jefe 0, 13.3 s |

## Prueba de la sed

Un jugador que va derecho hacia Yuu rodeando a los ecos.

| Mapa | Sed al entrar | Resultado | Tiempo (s) | Sed al salir |
| --- | --- | --- | --- | --- |
| mapa_prueba_sed.tscn | 30 | superada | 11.4 | 58 |
| mapa_prueba_sed.tscn | 55 | superada | 11.4 | 83 |
| mapa_prueba_sed.tscn | 70 | superada | 11.4 | 98 |
| mapa_prueba_calle.tscn | 30 | superada | 9.2 | 59 |
| mapa_prueba_calle.tscn | 55 | superada | 9.2 | 84 |
| mapa_prueba_calle.tscn | 70 | superada | 9.2 | 99 |
| mapa_prueba_cuarto.tscn | 30 | superada | 7.3 | 61 |
| mapa_prueba_cuarto.tscn | 55 | superada | 7.3 | 86 |
| mapa_prueba_cuarto.tscn | 70 | fallida | 6.1 | 90 |
