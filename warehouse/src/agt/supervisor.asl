/*******************************************************************************
 * SUPERVISOR - Monitor Activo del Sistema
 * 
 * Universidad de Vigo - Sistemas Inteligentes
 * Curso 2025-2026
 * 
 * CAPACIDADES:
 *   - Seguimiento de contenedores recibidos por tipo
 *   - Conteo de tareas completadas
 *   - Registro y notificacion de errores
 *   - Generacion periodica de reportes del sistema
 * 
 ******************************************************************************/

/* ============================================================================
 *  Estadisticas globales del supervisor
 *  total_errores: numero total de errores detectados
 *  total_completados: tareas finalizadas correctamente
 *  standard_count, fragile_count, urgent_count: contenedores recibidos por tipo
 *  ============================================================================ */

total_errores(0).
total_completados(0).
standard_count(0).
fragile_count(0).
urgent_count(0).


/* ============================================================================
 * PLANES PRINCIPALES
 * ============================================================================ */

!start.

/* Iniciamos el supervisor y arrancamos el bucle de monitorizacion */
+!start <-
    .print("[Supervisor] Iniciado - reportes cada 30s");
    !monitor_loop.


/* ============================================================================
 * BUCLE DE MONITORIZACION
 * ============================================================================ */

/* Esperar 30 segundos, generar un reporte y repetir indefinidamente */
+!monitor_loop <-
    .wait(30000);
    !generar_reporte;
    !monitor_loop.


/* ============================================================================
 * GENERACION DE REPORTES
 * ============================================================================ */

/* Consultar las estadisticas acumuladas, imprimir el informe y solicitar al scheduler el estado actual de los robots */
+!generar_reporte <-
    ?total_errores(E);
    ?total_completados(TC);
    ?standard_count(S);
    ?fragile_count(F);
    ?urgent_count(U);
    .print("");
    .print("=========== REPORTE SUPERVISOR ===========");
    .print("  Contenedores recibidos por tipo:");
    .print("    Standard: ", S);
    .print("    Fragile:  ", F);
    .print("    Urgent:   ", U);
    .print("    Total:    ", S+F+U);
    .print("  Tareas completadas: ", TC);
    .print("  Errores totales:    ", E);
    .print("  --- Estado de robots ---");
    .send(scheduler, achieve, estado);
    .print("==========================================");
    .print("").


/* ============================================================================
 * MENSAJES DEL SCHEDULER
 * ============================================================================ */

/* Cuando el scheduler notifica un contenedor standard, aumentar su contador */
+container_counted(CId, W, H, Weight, "standard")[source(_)] <-
    ?standard_count(N); -standard_count(N); +standard_count(N+1).

/* Cuando el scheduler notifica un contenedor fragile, aumentar su contador */
+container_counted(CId, W, H, Weight, "fragile")[source(_)] <-
    ?fragile_count(N); -fragile_count(N); +fragile_count(N+1).

/* Cuando el scheduler notifica un contenedor urgent, aumentar su contador */
+container_counted(CId, W, H, Weight, "urgent")[source(_)] <-
    ?urgent_count(N); -urgent_count(N); +urgent_count(N+1).

/* Cuando una tarea termina correctamente, actualizar el total completado */
+task_done(CId, Robot)[source(_)] <-
    ?total_completados(N); -total_completados(N); +total_completados(N+1).

/* Cuando se recibe un error, aumentar el contador e imprimir el detalle */
+error_occurred(Robot, CId, Tipo)[source(_)] <-
    ?total_errores(N); -total_errores(N); +total_errores(N+1);
    .print("[Supervisor] ERROR: ", Robot, " - ", Tipo, " - ", CId).


/* ============================================================================
 * REPORTE MANUAL
 * ============================================================================ */

/* Permitir lanzar el mismo informe periodico de forma manual */
+!reporte <- !generar_reporte.
