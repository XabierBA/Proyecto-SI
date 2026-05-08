/*******************************************************************************
 * SCHEDULER - VERSIÓN FINAL
 * - URGENTES PRIMERO (sin loops infinitos)
 * - NINGÚN paquete se pierde
 * - skip() solo para marcar lo intentado EN ESTE CICLO
 * - Borrar skip() al final para reintentar todo en el siguiente ciclo
 ******************************************************************************/

robot_capacity(robot_light,  10,  1, 1, 3).
robot_capacity(robot_medium, 30,  1, 2, 2).
robot_capacity(robot_heavy,  100, 2, 3, 1).
robot_capacity(robot_heavy_2, 100, 2, 3, 1).

robot_status(robot_light,  idle).
robot_status(robot_medium, idle).
robot_status(robot_heavy,  idle).
robot_status(robot_heavy_2, idle).

robot_task(robot_light, none, none).
robot_task(robot_medium, none, none).
robot_task(robot_heavy, none, none).
robot_task(robot_heavy_2, none, none).

shelf_data("shelf_1", 50, 8, 0, 0).
shelf_data("shelf_2", 50, 8, 0, 0).
shelf_data("shelf_3", 50, 8, 0, 0).
shelf_data("shelf_4", 50, 8, 0, 0).
shelf_data("shelf_5", 100, 12, 0, 0).
shelf_data("shelf_6", 100, 12, 0, 0).
shelf_data("shelf_7", 100, 12, 0, 0).
shelf_data("shelf_8", 200, 20, 0, 0).
shelf_data("shelf_9", 200, 20, 0, 0).

shelf_allows_type("shelf_1", "urgent").
shelf_allows_type("shelf_2", "standard").
shelf_allows_type("shelf_2", "fragile").
shelf_allows_type("shelf_3", "standard").
shelf_allows_type("shelf_3", "fragile").
shelf_allows_type("shelf_4", "standard").
shelf_allows_type("shelf_4", "fragile").
shelf_allows_type("shelf_5", "urgent").
shelf_allows_type("shelf_6", "standard").
shelf_allows_type("shelf_6", "fragile").
shelf_allows_type("shelf_7", "standard").
shelf_allows_type("shelf_7", "fragile").
shelf_allows_type("shelf_8", "urgent").
shelf_allows_type("shelf_9", "standard").
shelf_allows_type("shelf_9", "fragile").

shelf_fits(ShelfId, Weight, Area, Type) :-
    shelf_data(ShelfId, MaxW, MaxV, CurW, CurV) &
    CurW + Weight <= MaxW &
    CurV + Area <= MaxV &
    shelf_allows_type(ShelfId, Type).

stat_received(0).
stat_assigned(0).
stat_completed(0).
stat_errors(0).

!start.

+!start : true <-
    .print("[Scheduler] ⭐ INICIADO - Prioridad URGENTES sin loops, sin pérdidas");
    !main_loop.

/* Main loop cada 100ms */
+!main_loop <-
    .wait(100);
    !check_all_pending;
    !main_loop.

/* PRIORIDAD ABSOLUTA: URGENTES PRIMERO */
+!check_all_pending <-
    !assign_all_urgents;
    !assign_all_normals;
    !clear_tried_this_cycle.

/* ========== URGENTES ========== */
/* Procesa UN urgente que no se haya intentado este ciclo */
+!assign_all_urgents : pending(CId, W, H, Weight, "urgent") & not skip(CId) <-
    .print("[⚡ URGENTE] Procesando: ", CId, " (", Weight, "kg)");
    +skip(CId);  /* Marcar que ya lo intentamos EN ESTE CICLO */
    !try_assign(CId, W, H, Weight, "urgent");
    !assign_all_urgents.  /* Ir por el siguiente urgente */

/* Ya no hay más urgentes sin skip */
+!assign_all_urgents <- true.

/* ========== NORMALES ========== */
/* Procesa UN normal que no se haya intentado este ciclo */
+!assign_all_normals : pending(CId, W, H, Weight, Type) & Type \== "urgent" & not skip(CId) <-
    .print("[📦 NORMAL] Procesando: ", CId, " (", Weight, "kg)");
    +skip(CId);  /* Marcar que ya lo intentamos EN ESTE CICLO */
    !try_assign(CId, W, H, Weight, Type);
    !assign_all_normals.  /* Ir por el siguiente normal */

/* Ya no hay más normales sin skip */
+!assign_all_normals <- true.

/* ========== LIMPIAR SKIP AL FINAL ========== */
/* Borrar todos los skip() para el SIGUIENTE ciclo */
+!clear_tried_this_cycle <-
    .abolish(skip(_)).


/* ========== NUEVOS CONTENEDORES ========== */
+new_container(CId) : not pending(CId, _, _, _, _) <-
    ?stat_received(N); -stat_received(N); +stat_received(N+1);
    get_container_info(CId).

+new_container(CId) : pending(CId, _, _, _, _) <- true.


/* ========== INFO DEL CONTENEDOR ========== */
+container_info(CId, W, H, Weight, Type) : not pending(CId, _, _, _, _) & stored_at(CId, _) <-
    -container_info(CId, W, H, Weight, Type).

+container_info(CId, W, H, Weight, Type) : not pending(CId, _, _, _, _) & robot_task(_, CId, _) <-
    -container_info(CId, W, H, Weight, Type).

+container_info(CId, W, H, Weight, "urgent") : output_phase(urgent) <-
    -container_info(CId, W, H, Weight, "urgent");
    .print("[Scheduler] IGNORADO (fase salida): ", CId).

+container_info(CId, W, H, Weight, "standard") : output_phase(nonurgent) <-
    -container_info(CId, W, H, Weight, "standard");
    .print("[Scheduler] IGNORADO (fase salida): ", CId).

+container_info(CId, W, H, Weight, "fragile") : output_phase(nonurgent) <-
    -container_info(CId, W, H, Weight, "fragile");
    .print("[Scheduler] IGNORADO (fase salida): ", CId).

+container_info(CId, W, H, Weight, Type) : true <-
    -container_info(CId, W, H, Weight, Type);
    .print("[Scheduler] NUEVO: ", CId, " (", Weight, "kg, ", Type, ")");
    .send(supervisor, tell, container_counted(CId, W, H, Weight, Type));
    +pending(CId, W, H, Weight, Type);
    !check_all_pending.


/* ========== TAREA COMPLETADA ========== */
+task_complete(CId, Robot)[source(_)] : true <-
    ?stat_completed(NC); -stat_completed(NC); +stat_completed(NC+1);
    ?robot_task(Robot, CId, ShelfId);
    +stored_at(CId, ShelfId);
    .print("[✅ HECHO] ", Robot, " -> ", CId);
    .send(supervisor, tell, task_done(CId, Robot));
    -robot_status(Robot, busy);
    +robot_status(Robot, idle);
    -robot_task(Robot, _, _);
    +robot_task(Robot, none, none);
    -task_complete(CId, Robot)[source(_)];
    !check_all_pending.


/* ========== INTENTAR ASIGNAR ========== */
+!try_assign(CId, W, H, Weight, Type)
    : robot_capacity(robot_light, MW, MWd, MHt, _)
    & Weight <= MW & W <= MWd & H <= MHt
    & robot_status(robot_light, idle)
    <- !do_assign(CId, W, H, Weight, Type, robot_light).

+!try_assign(CId, W, H, Weight, Type)
    : robot_capacity(robot_medium, MW, MWd, MHt, _)
    & Weight <= MW & W <= MWd & H <= MHt
    & robot_status(robot_medium, idle)
    <- !do_assign(CId, W, H, Weight, Type, robot_medium).

+!try_assign(CId, W, H, Weight, Type)
    : robot_capacity(robot_heavy, MW, MWd, MHt, _)
    & Weight <= MW & W <= MWd & H <= MHt
    & robot_status(robot_heavy, idle)
    <- !do_assign(CId, W, H, Weight, Type, robot_heavy).

+!try_assign(CId, W, H, Weight, Type)
    : robot_capacity(robot_heavy_2, MW, MWd, MHt, _)
    & Weight <= MW & W <= MWd & H <= MHt
    & robot_status(robot_heavy_2, idle)
    <- !do_assign(CId, W, H, Weight, Type, robot_heavy_2).

/* Sin robot disponible ahora - reintentar en el siguiente ciclo */
+!try_assign(CId, W, H, Weight, Type) <- true.


/* ========== HACER ASIGNACIÓN ========== */
+!do_assign(CId, W, H, Weight, Type, Robot) : true <-
    !find_best_shelf(CId, W, H, Weight, Type, ShelfId);
    -pending(CId, W, H, Weight, Type);
    -robot_status(Robot, idle);
    +robot_status(Robot, busy);
    -robot_task(Robot, _, _);
    +robot_task(Robot, CId, ShelfId);
    ?shelf_data(ShelfId, MaxW, MaxV, CurW, CurV);
    -shelf_data(ShelfId, MaxW, MaxV, CurW, CurV);
    +shelf_data(ShelfId, MaxW, MaxV, CurW + Weight, CurV + W*H);
    .send(Robot, tell, task(CId, ShelfId));
    .print("[ASIGNADO] ", Robot, " <- ", CId, " (", Type, ") -> ", ShelfId);
    ?stat_assigned(N); -stat_assigned(N); +stat_assigned(N+1).

-!do_assign(CId, W, H, Weight, Type, Robot) : true <-
    .print("[ERROR] No hay estanteria: ", CId, " (", Weight, "kg) - Reintentará en siguiente ciclo");
    +pending(CId, W, H, Weight, Type).


/* ========== ENCONTRAR MEJOR ESTANTERÍA ========== */
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_1", Weight, W*H, Type)
    <- ShelfId = "shelf_1".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_2", Weight, W*H, Type)
    <- ShelfId = "shelf_2".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_3", Weight, W*H, Type)
    <- ShelfId = "shelf_3".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_4", Weight, W*H, Type)
    <- ShelfId = "shelf_4".

+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_5", Weight, W*H, Type)
    <- ShelfId = "shelf_5".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_6", Weight, W*H, Type)
    <- ShelfId = "shelf_6".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_7", Weight, W*H, Type)
    <- ShelfId = "shelf_7".

+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_8", Weight, W*H, Type)
    <- ShelfId = "shelf_8".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_9", Weight, W*H, Type)
    <- ShelfId = "shelf_9".

-!find_best_shelf(_, _, _, _, _, _) <-
    .print("[ERROR] Sin estanteria disponible").


/* ========== FASES DE SALIDA ========== */
+no_space(urgent)[source(supervisor)] : not output_phase(urgent) <-
    +output_phase(urgent);
    .print("[Fase Salida] URGENTES activada").

+no_space(nonurgent)[source(supervisor)] : not output_phase(nonurgent) <-
    +output_phase(nonurgent);
    .print("[Fase Salida] NO-URGENTES activada").

+no_space(_)[source(supervisor)] <- true.

+space_available(urgent)[source(supervisor)] <-
    -output_phase(urgent);
    .print("[Fase Salida] URGENTES desactivada").

+space_available(nonurgent)[source(supervisor)] <-
    -output_phase(nonurgent);
    .print("[Fase Salida] NO-URGENTES desactivada").

+!start_output_cycle(Group) <-
    .print("[Ciclo Salida] Grupo: ", Group).


/* ========== REPORTES ========== */
+!report_shelves <-
    !send_shelf_report("shelf_1");
    !send_shelf_report("shelf_2");
    !send_shelf_report("shelf_3");
    !send_shelf_report("shelf_4");
    !send_shelf_report("shelf_5");
    !send_shelf_report("shelf_6");
    !send_shelf_report("shelf_7");
    !send_shelf_report("shelf_8");
    !send_shelf_report("shelf_9").

+!send_shelf_report(ShelfId) <-
    ?shelf_data(ShelfId, _, _, CW, CV);
    .send(supervisor, tell, shelf_report(ShelfId, CW, CV)).


/* ========== MANEJO DE ERRORES ========== */
+robot_error(Robot, CId, ErrorType)[source(_)]
    : pending(CId, W, H, Weight, Type) <-
    .print("[ERROR] ", Robot, " - ", CId, " - ", ErrorType);
    ?stat_errors(N); -stat_errors(N); +stat_errors(N+1);
    .send(supervisor, tell, error_occurred(Robot, CId, ErrorType));
    -robot_status(Robot, busy); +robot_status(Robot, idle);
    -robot_task(Robot, _, _); +robot_task(Robot, none, none);
    -robot_error(Robot, CId, ErrorType)[source(_)];
    !try_assign(CId, W, H, Weight, Type).

+robot_error(Robot, CId, ErrorType)[source(_)]
    : not pending(CId, _, _, _, _) <-
    .print("[ERROR] ", Robot, " - ", ErrorType);
    ?stat_errors(N); -stat_errors(N); +stat_errors(N+1);
    .send(supervisor, tell, error_occurred(Robot, CId, ErrorType));
    -robot_status(Robot, busy); +robot_status(Robot, idle);
    -robot_task(Robot, _, _); +robot_task(Robot, none, none);
    -robot_error(Robot, CId, ErrorType)[source(_)];
    !check_all_pending.


/* ========== ESTADO ========== */
+!estado : true <-
    ?stat_received(R); ?stat_assigned(A); ?stat_completed(C); ?stat_errors(E);
    .print("[Estado] Recibidos:", R, " | Asignados:", A, " | Completados:", C, " | Errores:", E).

+!print_status : true <- !estado.
