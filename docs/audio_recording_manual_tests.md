# Pruebas manuales de grabación en Android

Estas pruebas deben ejecutarse en un dispositivo Android real. Usa una conversación de prueba sin datos clínicos ni datos identificables y verifica el archivo con audífonos después de cada caso.

## Preparación

1. Instala una compilación `release` o `profile` limpia.
2. Concede micrófono y notificaciones cuando Android los solicite.
3. Desactiva temporalmente la optimización de batería solo para comparar resultados; la prueba principal debe repetirse con la configuración normal del fabricante.
4. Abre una consulta, selecciona un paciente de prueba e inicia la grabación.
5. Confirma que aparece la notificación persistente “Consulta clínica en grabación”.

## Matriz reproducible

| Caso | Pasos | Resultado esperado |
|---|---|---|
| Bloqueo | Habla 15 s, bloquea 60 s mientras sigues hablando, desbloquea y habla 15 s | El contador se sincroniza, continúa “Grabando” solo tras verificar y el audio contiene los tres intervalos |
| Segundo plano | Graba, abre otra app 60 s y vuelve | No se pausa; la notificación sigue activa y el audio no tiene un corte |
| Pausa larga | Pausa 5 min, continúa y habla | El contador no avanza durante la pausa y el micrófono vuelve a capturar |
| Pulsaciones rápidas | Pausa y pulsa “Continuar” repetidamente | Solo se ejecuta una reanudación; no hay doble sesión ni bloqueo de botones |
| Varias pausas | Repite pausa/continuar diez veces | Cada estado coincide con el micrófono y el archivo final contiene solo los periodos activos |
| Llamada | Mientras graba, recibe/contesta/finaliza una llamada | La UI no afirma un estado falso; al volver sincroniza o crea un fragmento nuevo |
| Competencia de micrófono | Abre una app que intente usar el micrófono | Sanare recupera en un segmento o muestra el error conservando lo anterior |
| Audio cableado/Bluetooth | Conecta y desconecta auriculares durante la grabación | Se registra la interrupción técnica; la sesión sigue o se recupera sin perder fragmentos previos |
| Cierre accidental | Fuerza el cierre desde ajustes mientras existe audio y vuelve a abrir | Aparece el diálogo para continuar, finalizar o descartar; ninguna ruta se borra automáticamente |
| Poco almacenamiento | Ejecuta con el dispositivo casi lleno | Se muestra error, se detiene el contador y se conservan los fragmentos ya cerrados |
| Detener repetido | Pulsa detener rápidamente varias veces | Se procesa una sola detención y desaparecen servicio y notificación |
| Notificaciones denegadas | Deniega notificaciones y concede micrófono | Se avisa de la restricción; Android mantiene el servicio en controles del sistema |

## Comprobación final

Después de detener, verifica en Ajustes > Aplicaciones > Sanare que no quede un servicio activo y que la notificación desaparezca. Confirma que los archivos `_segment_001`, `_segment_002`, etc. existen, que se crea uno aproximadamente cada 5 minutos y que el SOAP respeta el orden de la conversación.

## Segmentación y red

1. Graba durante al menos 11 minutos y comprueba que el contador nunca vuelve a `00:00` durante los cambios de segmento de 5 minutos.
2. Desactiva Wi-Fi y datos antes del segundo segmento. La grabación debe continuar y mostrar fragmentos pendientes.
3. Reactiva la conexión y confirma que las subidas se reanudan sin intervención.
4. Detén la grabación sin conexión, cierra la aplicación y vuelve a abrirla. Los segmentos deben seguir disponibles.
5. Recupera la red y verifica los estados: Enviando segmentos, Transcribiendo audio, Generando registro SOAP y Completado. `Consolidando transcripción` aparece únicamente si se activa el fallback segmentado.
6. Comprueba que el botón `Reintentar ahora` no duplica registros en el backend.

No se usa solapamiento de audio. Android no garantiza dos capturas AAC simultáneas del mismo micrófono; se realiza un cierre e inicio inmediato del grabador para reducir el intervalo entre segmentos sin arriesgar la sesión completa.
