/*******************************************************************************
 * SCHEDULER - Coordinador con Seleccion Inteligente de Estanteria
 * 
 * Universidad de Vigo - Sistemas Inteligentes
 * Curso 2025-2026
 * 
 * CAPACIDADES:
 *   - Clasificacion automatica de contenedores
 *   - Priorizacion de robots: light > medium > heavy
 *   - Seleccion de la estanteria mas pequena disponible
 *   - Seguimiento de estadisticas y gestion de errores
 * 
 ******************************************************************************/
/*******************************************************************************
 * SCHEDULER - Coordinador para Robots Autónomos
 * Universidad de Vigo - Sistemas Inteligentes
 ******************************************************************************/

/* ============================================================================
    ESTADO INICIAL Y CAPACIDADES
   ============================================================================ */

/* Estanterías: shelf_data(Id, MaxWeight, MaxVolume, CurrentWeight, CurrentVolume) */
shelf_data("shelf_1", 50, 8, 0, 0).
shelf_data("shelf_2", 50, 8, 0, 0).
shelf_data("shelf_3", 50, 8, 0, 0).
shelf_data("shelf_4", 50, 8, 0, 0).
shelf_data("shelf_5", 100, 12, 0, 0).
shelf_data("shelf_6", 100, 12, 0, 0).
shelf_data("shelf_7", 100, 12, 0, 0).
shelf_data("shelf_8", 200, 20, 0, 0).
shelf_data("shelf_9", 200, 20, 0, 0).

/* Tipos permitidos por estantería */
shelf_allows_type("shelf_1", "urgent").
shelf_allows_type("shelf_5", "urgent").
shelf_allows_type("shelf_8", "urgent").
shelf_allows_type("shelf_2", "standard"). shelf_allows_type("shelf_2", "fragile").
shelf_allows_type("shelf_3", "standard"). shelf_allows_type("shelf_3", "fragile").
shelf_allows_type("shelf_4", "standard"). shelf_allows_type("shelf_4", "fragile").
shelf_allows_type("shelf_6", "standard"). shelf_allows_type("shelf_6", "fragile").
shelf_allows_type("shelf_7", "standard"). shelf_allows_type("shelf_7", "fragile").
shelf_allows_type("shelf_9", "standard"). shelf_allows_type("shelf_9", "fragile").

/* Regla de validación de hueco */
shelf_fits(ShelfId, Weight, Area, Type) :-
    shelf_data(ShelfId, MaxW, MaxV, CurW, CurV) &
    CurW + Weight <= MaxW &
    CurV + Area <= MaxV &
    shelf_allows_type(ShelfId, Type).

/* Estadísticas */
stat_received(0). stat_completed(0). stat_errors(0).

/* Estados de robot */
robot_status(robot_light, idle). robot_status(robot_medium, idle). robot_status(robot_heavy, idle).

!start.
+!start <- .print("[Scheduler] Operativo en modo Autónomo").

/* ============================================================================
    DETECCIÓN Y PUBLICACIÓN (ÚNICO PLAN REVISADO)
   ============================================================================ */

+new_container(CId) : not pending_container(CId, _, _, _, _) <-
    ?stat_received(N); -stat_received(N); +stat_received(N+1);
    get_container_info(CId).

+container_info(CId, W, H, Weight, Type) : true <-
    -container_info(CId, W, H, Weight, Type);
    
    // Determinar grupo para fase de salida
    if (Type == "urgent") { Group = urgent; } else { Group = nonurgent; }

    if (output_phase(Group)) {
        .print("[Scheduler] RECHAZADO por fase de salida: ", CId);
    } else {
        .print("[Scheduler] PUBLICANDO: ", CId, " (", Type, ")");
        // Esto es lo que el robot lee en su main_loop
        .broadcast(tell, pending_container(CId, W, H, Weight, Type));
        .send(supervisor, tell, container_counted(CId, W, H, Weight, Type));
    }.

/* ============================================================================
    GESTIÓN DE TAREAS COMPLETADAS
   ============================================================================ */

+task_complete(CId, Robot)[source(_)] : true <-
    ?stat_completed(NC); -stat_completed(NC); +stat_completed(NC+1);
    
    .print("[Scheduler] Tarea completada por ", Robot, ": ", CId);
    .send(supervisor, tell, task_done(CId, Robot));
    
    // Actualizar estado del robot y limpiar el contenedor de la lista de pendientes
    -robot_status(Robot, busy);
    +robot_status(Robot, idle);
    -pending_container(CId, _, _, _, _); 
    -task_complete(CId, Robot)[source(_)].

/* ============================================================================
    BÚSQUEDA DE ESTANTERÍA (Para cuando el robot la pida)
   ============================================================================ */

+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_1", Weight, W*H, Type) <- ShelfId = "shelf_1".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_2", Weight, W*H, Type) <- ShelfId = "shelf_2".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_3", Weight, W*H, Type) <- ShelfId = "shelf_3".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_4", Weight, W*H, Type) <- ShelfId = "shelf_4".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_5", Weight, W*H, Type) <- ShelfId = "shelf_5".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_6", Weight, W*H, Type) <- ShelfId = "shelf_6".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_7", Weight, W*H, Type) <- ShelfId = "shelf_7".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_8", Weight, W*H, Type) <- ShelfId = "shelf_8".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_9", Weight, W*H, Type) <- ShelfId = "shelf_9".

-!find_best_shelf(_, _, _, _, _, _) <- .print("[Scheduler] ERROR: No hay estantería válida").

/* ============================================================================
    FASES DE SALIDA (GESTIONADAS POR SUPERVISOR)
   ============================================================================ */

+no_space(Group)[source(supervisor)] : not output_phase(Group) <-
    +output_phase(Group);
    .time(HH, MM, SS); .concat(HH, ":", MM, ":", SS, T);
    .print("EVENT | time=", T, " | agent=scheduler | type=output_phase_started | data=", Group).

+space_available(Group)[source(supervisor)] <-
    -output_phase(Group);
    .print("[Scheduler] Fase de salida finalizada para: ", Group).

+!report_shelves <- 
    for ( shelf_data(ID, _, _, W, V) ) {
        .send(supervisor, tell, shelf_report(ID, W, V));
    }.

/* ============================================================================
    ERRORES Y ESTADO
   ============================================================================ */

+robot_error(Robot, CId, ErrorType)[source(_)] <-
    .print("[Scheduler] Error reportado por ", Robot, ": ", ErrorType);
    ?stat_errors(N); -stat_errors(N); +stat_errors(N+1);
    .send(supervisor, tell, error_occurred(Robot, CId, ErrorType));
    -robot_status(Robot, busy); +robot_status(Robot, idle);
    -robot_error(Robot, CId, ErrorType)[source(_)].

+!estado <-
    ?stat_received(R); ?stat_completed(C); ?stat_errors(E);
    .print("[ESTADO] Recibidos:", R, " Completados:", C, " Errores:", E).