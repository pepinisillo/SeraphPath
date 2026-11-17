#!/usr/bin/env bash
# Ejecuta todas las pruebas sin ventana. Uso, desde la carpeta sed/:  ./pruebas/ejecutar.sh
cd "$(dirname "$0")/.." || exit 1
fallos=0
for prueba in pruebas/prueba_*.gd; do
	salida=$(timeout 120 godot --headless --path . -s "res://$prueba" 2>&1)
	if grep -q "RESULTADO: OK" <<<"$salida" && ! grep -qE "SCRIPT ERROR|FALLO" <<<"$salida"; then
		echo "ok     $prueba"
	else
		echo "FALLO  $prueba"
		grep -E "FALLO|ERROR" <<<"$salida" | head -20
		fallos=$((fallos + 1))
	fi
done
exit $fallos
