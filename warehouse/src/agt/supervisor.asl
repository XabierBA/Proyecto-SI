/* SUPERVISOR - Monitor activo del sistema */
/* Recibe datos del scheduler via mensajes tell */

total_errores(0).
total_completados(0).
standard_count(0).
fragile_count(0).
urgent_count(0).

!start.

+!start <-
    .print("[Supervisor] Iniciado - reportes cada 30s");
    !monitor_loop.

+!monitor_loop <-
    .wait(30000);
    !generar_reporte;
    !monitor_loop.

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

/* ===== MENSAJES DEL SCHEDULER ===== */

/* Contenedor recibido: clasificar por tipo */
+container_counted(CId, W, H, Weight, "standard")[source(_)] <-
    ?standard_count(N); -standard_count(N); +standard_count(N+1).

+container_counted(CId, W, H, Weight, "fragile")[source(_)] <-
    ?fragile_count(N); -fragile_count(N); +fragile_count(N+1).

+container_counted(CId, W, H, Weight, "urgent")[source(_)] <-
    ?urgent_count(N); -urgent_count(N); +urgent_count(N+1).

/* Tarea completada */
+task_done(CId, Robot)[source(_)] <-
    ?total_completados(N); -total_completados(N); +total_completados(N+1).

/* Error ocurrido */
+error_occurred(Robot, CId, Tipo)[source(_)] <-
    ?total_errores(N); -total_errores(N); +total_errores(N+1);
    .print("[Supervisor] ERROR: ", Robot, " - ", Tipo, " - ", CId).

/* ===== REPORTE MANUAL ===== */

+!reporte <- !generar_reporte.
