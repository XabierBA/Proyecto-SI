/*******************************************************************************
 * SCHEDULER - Agente Planificador Mejorado
 * 
 * CAMBIOS:
 * 1. Delega get_container_info al scheduler (no al entorno)
 * 2. Persistencia de localización: container_location(CId, ShelfId) permanente
 * 3. Mejora de selección de estantería con histórico
 ******************************************************************************/

/* ============================================================================
 * CREENCIAS INICIALES
 * ============================================================================ */

robot_capacity(robot_light,  10,  1, 1, 3).
robot_capacity(robot_medium, 30,  1, 2, 2).
robot_capacity(robot_heavy,  100, 2, 3, 1).

robot_status(robot_light,  idle).
robot_status(robot_medium, idle).
robot_status(robot_heavy,  idle).

stat_received(0).
stat_assigned(0).
stat_errors(0).

/* Posiciones de estanterías */
shelf_pos("shelf_1", 10, 2).
shelf_pos("shelf_2", 12, 2).
shelf_pos("shelf_3", 14, 2).
shelf_pos("shelf_4", 16, 2).
shelf_pos("shelf_5", 10, 6).
shelf_pos("shelf_6", 13, 6).
shelf_pos("shelf_7", 16, 6).
shelf_pos("shelf_8", 10, 10).
shelf_pos("shelf_9", 14, 10).

/* Capacidades de estanterías */
shelf_capacity("shelf_1", 50).
shelf_capacity("shelf_2", 50).
shelf_capacity("shelf_3", 50).
shelf_capacity("shelf_4", 50).
shelf_capacity("shelf_5", 100).
shelf_capacity("shelf_6", 100).
shelf_capacity("shelf_7", 100).
shelf_capacity("shelf_8", 200).
shelf_capacity("shelf_9", 200).

/* Ocupación de estanterías */
shelf_usage("shelf_1", 0).
shelf_usage("shelf_2", 0).
shelf_usage("shelf_3", 0).
shelf_usage("shelf_4", 0).
shelf_usage("shelf_5", 0).
shelf_usage("shelf_6", 0).
shelf_usage("shelf_7", 0).
shelf_usage("shelf_8", 0).
shelf_usage("shelf_9", 0).

/* ============================================================================
 * INICIALIZACIÓN
 * ============================================================================ */

!start.

+!start : true <-
    .print("[Scheduler] ============================================");
    .print("[Scheduler]  Sistema de planificación iniciado");
    .print("[Scheduler]  Prioridad: robot_light -> robot_medium -> robot_heavy");
    .print("[Scheduler]  Requisitos: Entorno delgado & Trazabilidad de cajas");
    .print("[Scheduler] ============================================").

/* ============================================================================
 * DETECCIÓN DE NUEVO CONTENEDOR
 * ============================================================================ */

+new_container(CId) : not pending(CId, _, _, _, _) <-
    ?stat_received(N); -stat_received(N); +stat_received(N+1);
    .print("[Scheduler] Nuevo contenedor en entrada: ", CId);
    /* El scheduler solicita info del contenedor al entorno */
    get_container_info(CId).

+new_container(CId) : pending(CId, _, _, _, _) <-
    true.

/* ============================================================================
 * INFORMACIÓN DEL CONTENEDOR RECIBIDA
 * ============================================================================ */

+container_info(CId, W, H, Weight, Type) : true <-
    -container_info(CId, W, H, Weight, Type);
    .print("[Scheduler]   Info: ", CId, " = ", Weight, "kg, ", W, "x", H, ", tipo: ", Type);
    +pending(CId, W, H, Weight, Type);
    !try_assign_pending.

/* ============================================================================
 * TAREA COMPLETADA - PERSISTENCIA DE LOCALIZACIÓN
 * ============================================================================ */

<<<<<<< Updated upstream
+task_complete(CId, Robot, ShelfId) : true <-
    .print("[Scheduler] ", Robot, " completó: ", CId, " -> ", ShelfId);
    
    /* [PERSISTENCIA] Guardar localización permanente del contenedor */
    +container_location(CId, ShelfId);
    
    /* Actualizar ocupación de estantería */
    ?assigned_weight(CId, Weight);
    -assigned_weight(CId, Weight);
    ?shelf_usage(ShelfId, Usage);
    -shelf_usage(ShelfId, Usage);
    +shelf_usage(ShelfId, Usage + Weight);
    
=======
/* Cuando un robot completa una tarea, actualizar estadisticas, avisar al supervisor, liberar al robot y continuar asignando pendientes */

+task_complete(CId, Robot)[source(_)] : true <-
    ?stat_completed(NC); -stat_completed(NC); +stat_completed(NC+1);
    /* Seguimiento persistente: que paquete esta en que estanteria */
    ?robot_task(Robot, CId, ShelfId);
    +stored_at(CId, ShelfId);
    .print("[Scheduler] Completado: ", Robot, " entrego ", CId, " en ", ShelfId);
    .send(supervisor, tell, task_done(CId, Robot));    /* Notificar supervisor */
>>>>>>> Stashed changes
    -robot_status(Robot, busy);
    +robot_status(Robot, idle);
    -task_complete(CId, Robot, ShelfId)[source(_)];
    !try_assign_pending.

/* ============================================================================
 * CICLO DE ASIGNACIÓN
 * ============================================================================ */

+try_assign_pending : pending(CId, W, H, Weight, Type) <-
    !try_assign(CId, W, H, Weight, Type);
    !try_assign_pending.

+!try_assign_pending : not pending(_, _, _, _, _) <- true.

/* ============================================================================
 * LÓGICA DE ASIGNACIÓN CON PRIORIDAD
 * ============================================================================ */

+!try_assign(CId, W, H, Weight, Type) :
        robot_capacity(robot_light, MaxW, MaxWidth, MaxHeight, _) &
        Weight =< MaxW & W =< MaxWidth & H =< MaxHeight &
        robot_status(robot_light, idle) <-
    !do_assign(CId, W, H, Weight, Type, robot_light).

+!try_assign(CId, W, H, Weight, Type) :
        robot_capacity(robot_medium, MaxW, MaxWidth, MaxHeight, _) &
        Weight =< MaxW & W =< MaxWidth & H =< MaxHeight &
        robot_status(robot_medium, idle) <-
    !do_assign(CId, W, H, Weight, Type, robot_medium).

+!try_assign(CId, W, H, Weight, Type) :
        robot_capacity(robot_heavy, MaxW, MaxWidth, MaxHeight, _) &
        Weight =< MaxW & W =< MaxWidth & H =< MaxHeight &
        robot_status(robot_heavy, idle) <-
    !do_assign(CId, W, H, Weight, Type, robot_heavy).

+!try_assign(CId, W, H, Weight, Type) : true <-
    .print("[Scheduler] En espera: Sin robot disponible para ", CId, " (", Weight, "kg)").

/* ============================================================================
 * EJECUTAR ASIGNACIÓN - SELECCIÓN INTELIGENTE DE ESTANTERÍA
 * ============================================================================ */

+!do_assign(CId, W, H, Weight, Type, Robot) : true <-
    !select_best_shelf(Weight, Type, ShelfId);
    
    -pending(CId, W, H, Weight, Type);
    -robot_status(Robot, idle);
    +robot_status(Robot, busy);
    
    /* Guardar peso para actualizar ocupación al completar */
    +assigned_weight(CId, Weight);
    +assigned_target(CId, ShelfId);
    
    .send(Robot, tell, task(CId, ShelfId));
    .print("[Scheduler] Asignado: ", Robot, " -> ", CId, " @ ", ShelfId);
    ?stat_assigned(N); -stat_assigned(N); +stat_assigned(N+1).

-!do_assign(CId, W, H, Weight, Type, Robot) : true <-
    .print("[Scheduler] Alerta: No se pudo asignar estantería para ", CId).

/* ============================================================================
 * SELECCIÓN INTELIGENTE DE ESTANTERÍA
 * ============================================================================ */

+!select_best_shelf(Weight, "urgent", ShelfId) : shelf_pos(ShelfId, _, _) <- 
    ShelfId = "shelf_1".

+!select_best_shelf(Weight, _, ShelfId) : Weight =< 10 <-
    !find_less_used_shelf(["shelf_1", "shelf_2", "shelf_3", "shelf_4"], ShelfId).

+!select_best_shelf(Weight, _, ShelfId) : Weight =< 30 <-
    !find_less_used_shelf(["shelf_5", "shelf_6", "shelf_7"], ShelfId).

<<<<<<< Updated upstream
+!select_best_shelf(Weight, _, ShelfId) : true <-
    !find_less_used_shelf(["shelf_8", "shelf_9"], ShelfId).
=======
/* Ninguna estanteria cabe: el plan falla y do_assign maneja el error */
-!find_best_shelf(_, _, _, _, _) <-
    .print("[Scheduler] Sin estanteria disponible").
>>>>>>> Stashed changes

/* Encuentra la estantería menos usada de una lista */
+!find_less_used_shelf([ShelfId], ShelfId) <- true.

+!find_less_used_shelf([H|T], BestShelf) : true <-
    !find_best_in_list([H|T], H, BestShelf).

+!find_best_in_list([S], Current, Current) <- true.

+!find_best_in_list([H|T], Current, BestShelf) : true <-
    ?shelf_usage(H, UsageH);
    ?shelf_usage(Current, UsageCurrent);
    (UsageH < UsageCurrent ->
        !find_best_in_list(T, H, BestShelf)
    ;
        !find_best_in_list(T, Current, BestShelf)
    ).

/* ============================================================================
 * MANEJO DE ERRORES
 * ============================================================================ */

+robot_error(Robot, CId, ErrorType) : pending(CId, W, H, Weight, Type) <-
    .print("[Scheduler] Error '", ErrorType, "' en ", Robot, " con ", CId);
    ?stat_errors(N); -stat_errors(N); +stat_errors(N+1);
    -robot_status(Robot, busy);
    +robot_status(Robot, idle);
    (assigned_target(CId, _) -> -assigned_target(CId, _) ; true);
    (assigned_weight(CId, _) -> -assigned_weight(CId, _) ; true);
    !try_assign(CId, W, H, Weight, Type).

+robot_error(Robot, CId, ErrorType) : not pending(CId, _, _, _, _) <-
    .print("[Scheduler] Error '", ErrorType, "' en ", Robot);
    ?stat_errors(N); -stat_errors(N); +stat_errors(N+1);
    -robot_status(Robot, busy);
    +robot_status(Robot, idle);
    (assigned_target(CId, _) -> -assigned_target(CId, _) ; true);
    (assigned_weight(CId, _) -> -assigned_weight(CId, _) ; true);
    !try_assign_pending.

/* ============================================================================
 * ESTADO DEL SCHEDULER
 * ============================================================================ */

+!print_status : true <-
    ?stat_received(R);
    ?stat_assigned(A);
    ?stat_errors(E);
    .print("[Scheduler] -- Estado del sistema --------------------");
    .print("[Scheduler]  Contenedores recibidos: ", R);
    .print("[Scheduler]  Asignaciones realizadas: ", A);
    .print("[Scheduler]  Errores gestionados: ", E);
    .print("[Scheduler] -------------------------------------------").

+!estado : true <- !print_status.
