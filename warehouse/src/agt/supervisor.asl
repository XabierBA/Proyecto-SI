/* SUPERVISOR */

errores(0).
urgentes_procesados(0).
fragiles_procesados(0).
standard_procesados(0).
total_completados(0).

!start.

+!start <-
    .print("[Supervisor] Iniciado");
    !monitor_loop.

+!monitor_loop <-
    .wait(30000);
    !generar_reporte;
    !monitor_loop.

+!generar_reporte <-
    ?errores(E);
    ?urgentes_procesados(U);
    ?fragiles_procesados(F);
    ?standard_procesados(S);
    ?total_completados(TC);
    .print("=== REPORTE ===");
    .print("Standard:", S, " Fragile:", F, " Urgent:", U);
    .print("Completados:", TC, " Errores:", E);
    .print("===============");
    .send(scheduler, achieve, estado).

+robot_error(Robot, CId, Tipo)[source(_)] <-
    ?errores(N); -errores(N); +errores(N+1).

+container_info(CId, W, H, Peso, "standard") <-
    ?standard_procesados(N); -standard_procesados(N); +standard_procesados(N+1).

+container_info(CId, W, H, Peso, "fragile") <-
    ?fragiles_procesados(N); -fragiles_procesados(N); +fragiles_procesados(N+1).

+container_info(CId, W, H, Peso, "urgent") <-
    ?urgentes_procesados(N); -urgentes_procesados(N); +urgentes_procesados(N+1).

+task_complete(CId, Robot)[source(_)] <-
    ?total_completados(N); -total_completados(N); +total_completados(N+1).

+!reporte <-
    ?errores(E); ?urgentes_procesados(U);
    ?fragiles_procesados(F); ?standard_procesados(S);
    ?total_completados(TC);
    .print("S:", S, " F:", F, " U:", U, " T:", TC, " E:", E);
    .send(scheduler, achieve, estado).
