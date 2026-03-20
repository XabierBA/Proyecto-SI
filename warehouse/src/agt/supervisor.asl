errores(0).
urgentes_procesados(0).
fragiles_procesados(0).
standard_procesados(0).

!start.

+!start
    <- .print("[Supervisor] Iniciado - Sistema de monitorización");
       .print("[Supervisor] Reportes cada 30 segundos");
       !monitor_loop.

+!monitor_loop
    <- .wait(30000);
       !generar_reporte;
       !monitor_loop.

+!generar_reporte
    <- ?errores(E);
       ?urgentes_procesados(U);
       ?fragiles_procesados(F);
       ?standard_procesados(S);
       .time(T);
       .print("");
       .print("========== REPORTE DEL SISTEMA ==========");
       .print("Tiempo: ", T, " segundos");
       .print("----------------------------------------");
       .print("Contenedores procesados:");
       .print("  - Standard: ", S);
       .print("  - Fragile:  ", F);
       .print("  - Urgent:   ", U);
       .print("----------------------------------------");
       .print("Total errores: ", E);
       .print("========================================");
       .print("");
       .send(scheduler, achieve, estado).

+robot_error(Robot,CId,Tipo)[source(_)]
    <- +errores(N);
       -errores(N);
       +errores(N+1);
       .time(T);
       .print("[Supervisor] [", T, "] ERROR: ", Robot, " - ", Tipo, " - ", CId).

+container_info(CId,W,H,Peso,standard)
    <- +standard_procesados(N);
       -standard_procesados(N);
       +standard_procesados(N+1).

+container_info(CId,W,H,Peso,fragile)
    <- +fragiles_procesados(N);
       -fragiles_procesados(N);
       +fragiles_procesados(N+1).

+container_info(CId,W,H,Peso,urgent)
    <- +urgentes_procesados(N);
       -urgentes_procesados(N);
       +urgentes_procesados(N+1).

+!reporte
    <- ?errores(E);
       ?urgentes_procesados(U);
       ?fragiles_procesados(F);
       ?standard_procesados(S);
       .print("");
       .print("========== REPORTE MANUAL ==========");
       .print("Standard: ", S, " | Fragile: ", F, " | Urgent: ", U);
       .print("Errores totales: ", E);
       .print("====================================");
       .send(scheduler, achieve, estado).