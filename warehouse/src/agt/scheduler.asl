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

/* ============================================================================
 *  Declaracion de capacidades de los robots:
 *  Estanterias: shelf_data(Id, MaxWeight, MaxVolume, CurrentWeight, CurrentVolume)
 *  Pequenas (fila 1): 50kg, vol 8
 *  Medianas (fila 2): 100kg, vol 12
 *  Grandes (fila 3): 200kg, vol 20        
 *  ============================================================================ */
   
robot_capacity(robot_light,  10,  1, 1, 3).
robot_capacity(robot_medium, 30,  1, 2, 2).
robot_capacity(robot_heavy,  100, 2, 3, 1).

/* Estado inicial de los robots */
robot_status(robot_light,  idle).
robot_status(robot_medium, idle).
robot_status(robot_heavy,  idle).

/* Tarea actual asignada a cada robot */
robot_task(robot_light, none, none).
robot_task(robot_medium, none, none).
robot_task(robot_heavy, none, none).


/* ============================================================================
 *   Declaracion de estanterias:
 *  shelf_data(Id, MaxWeight, MaxVolume, CurrentWeight, CurrentVolume)
 *   - Pequenas (fila 1): 50kg, volumen 8
 *   - Medianas (fila 2): 100kg, volumen 12
 *   - Grandes (fila 3): 200kg, volumen 20 
 * ============================================================================ */

shelf_data("shelf_1", 50, 8, 0, 0).
shelf_data("shelf_2", 50, 8, 0, 0).
shelf_data("shelf_3", 50, 8, 0, 0).
shelf_data("shelf_4", 50, 8, 0, 0).
shelf_data("shelf_5", 100, 12, 0, 0).
shelf_data("shelf_6", 100, 12, 0, 0).
shelf_data("shelf_7", 100, 12, 0, 0).
shelf_data("shelf_8", 200, 20, 0, 0).
shelf_data("shelf_9", 200, 20, 0, 0).

/* Prioridad de estanteria: menor indice = probar primero */
/* Primero pequenas, luego medianas y por ultimo grandes */
shelf_order(1, "shelf_1").
shelf_order(2, "shelf_2").
shelf_order(3, "shelf_3").
shelf_order(4, "shelf_4").
shelf_order(5, "shelf_5").
shelf_order(6, "shelf_6").
shelf_order(7, "shelf_7").
shelf_order(8, "shelf_8").
shelf_order(9, "shelf_9").

/* Regla: una estanteria puede almacenar un contenedor
 * si no supera ni el peso ni el volumen maximos */
shelf_fits(ShelfId, Weight, Area) :-
    shelf_data(ShelfId, MaxW, MaxV, CurW, CurV) &
    CurW + Weight <= MaxW &
    CurV + Area <= MaxV.

/* Estadisticas globales del scheduler */
stat_received(0).
stat_assigned(0).
stat_completed(0).
stat_errors(0).


/* ============================================================================
 * PLANES PRINCIPALES
 * ============================================================================ */

!start.

/* Iniciamos el scheduler */
+!start : true <- .print("[Scheduler] Iniciado").


/* ============================================================================
 * DETECCION DE NUEVOS CONTENEDORES
 * ============================================================================ */

/* Si llega un contenedor nuevo y aun no esta pendiente, aumentar estadisticas y solicitar su informacion */

+new_container(CId) : not pending(CId, _, _, _, _) <-
    ?stat_received(N); -stat_received(N); +stat_received(N+1);
    get_container_info(CId).

/* Si el contenedor ya estaba registrado como pendiente, ignorarlo */
+new_container(CId) : pending(CId, _, _, _, _) <- true.


/* ============================================================================
 * CLASIFICACION DE CONTENEDORES
 * ============================================================================ */

/* Al recibir la informacion del contenedor, guardarlo como pendiente, notificar al supervisor e intentar asignarlo */
 
+container_info(CId, W, H, Weight, Type) : true <-
    -container_info(CId, W, H, Weight, Type);
    .print("[Scheduler] Recibido ", CId, ": ", Weight, "kg ", W, "x", H, " ", Type);
    /* Notificar al supervisor */
    .send(supervisor, tell, container_counted(CId, W, H, Weight, Type));
    +pending(CId, W, H, Weight, Type);
    !try_assign_pending.


/* ============================================================================
 * GESTION DE ROBOTS LIBRES
 * ============================================================================ */

/* Cuando un robot completa una tarea, actualizar estadisticas, avisar al supervisor, liberar al robot y continuar asignando pendientes */

+task_complete(CId, Robot)[source(_)] : true <-
    ?stat_completed(NC); -stat_completed(NC); +stat_completed(NC+1);
    .print("[Scheduler] Completado: ", Robot, " entrego ", CId);
    .send(supervisor, tell, task_done(CId, Robot));    /* Notificar supervisor */
    -robot_status(Robot, busy);
    +robot_status(Robot, idle);
    -robot_task(Robot, _, _);
    +robot_task(Robot, none, none);
    -task_complete(CId, Robot)[source(_)];
    !try_assign_pending.


/* ============================================================================
 * CICLO DE ASIGNACION
 * ============================================================================ */

/* Mientras exista algun contenedor pendiente, intentar asignarlo */
+!try_assign_pending : pending(CId, W, H, Weight, Type) <-
    !try_assign(CId, W, H, Weight, Type);
    !try_assign_pending.

/* Si ya no quedan contenedores pendientes, terminar */
+!try_assign_pending : not pending(_, _, _, _, _) <- true.

/* Prioridad de asignacion de robots: light > medium > heavy */

/* Si robot_light puede transportar el contenedor y esta libre, asignarlo */
+!try_assign(CId, W, H, Weight, Type)
    : robot_capacity(robot_light, MW, MWd, MHt, _)
    & Weight <= MW & W <= MWd & H <= MHt
    & robot_status(robot_light, idle)
    <- !do_assign(CId, W, H, Weight, Type, robot_light).

/* Si robot_medium puede transportar el contenedor y esta libre, asignarlo */
+!try_assign(CId, W, H, Weight, Type)
    : robot_capacity(robot_medium, MW, MWd, MHt, _)
    & Weight <= MW & W <= MWd & H <= MHt
    & robot_status(robot_medium, idle)
    <- !do_assign(CId, W, H, Weight, Type, robot_medium).

/* Si robot_heavy puede transportar el contenedor y esta libre, asignarlo */
+!try_assign(CId, W, H, Weight, Type)
    : robot_capacity(robot_heavy, MW, MWd, MHt, _)
    & Weight <= MW & W <= MWd & H <= MHt
    & robot_status(robot_heavy, idle)
    <- !do_assign(CId, W, H, Weight, Type, robot_heavy).

/* Si ningun robot puede asumir la tarea en este momento, no hacer nada */
+!try_assign(CId, W, H, Weight, Type) : true <- true.


/* ============================================================================
 * SELECCION DE ESTANTERIA Y ASIGNACION
 * ============================================================================ */

/* Buscar la mejor estanteria disponible, actualizar estados, reservar capacidad y enviar la tarea al robot */

+!do_assign(CId, W, H, Weight, Type, Robot) : true <-
    !find_best_shelf(CId, W, H, Weight, ShelfId);
    -pending(CId, W, H, Weight, Type);
    -robot_status(Robot, idle);
    +robot_status(Robot, busy);
    -robot_task(Robot, _, _);
    +robot_task(Robot, CId, ShelfId);
    /* Actualizar ocupacion de estanteria */
    ?shelf_data(ShelfId, MaxW, MaxV, CurW, CurV);
    -shelf_data(ShelfId, MaxW, MaxV, CurW, CurV);
    +shelf_data(ShelfId, MaxW, MaxV, CurW + Weight, CurV + W*H);
    .send(Robot, tell, task(CId, ShelfId));
    .print("[Scheduler] ", Robot, " <- ", CId, " (", Weight, "kg ", Type, ") -> ", ShelfId);
    ?stat_assigned(N); -stat_assigned(N); +stat_assigned(N+1).

/* Si no se encuentra una estanteria valida, informar por pantalla */
-!do_assign(CId, W, H, Weight, Type, Robot) : true <-
    .print("[Scheduler] Sin estanteria para ", CId).

/* Buscar la estanteria mas pequena que pueda almacenar el contenedor */
/* Probar en orden: shelf_1..4 (pequenas), shelf_5..7 (medianas), shelf_8..9 (grandes) */

/* Probar primero las estanterias pequenas */
+!find_best_shelf(CId, W, H, Weight, ShelfId)
    : shelf_fits("shelf_1", Weight, W*H)
    <- ShelfId = "shelf_1".
+!find_best_shelf(CId, W, H, Weight, ShelfId)
    : shelf_fits("shelf_2", Weight, W*H)
    <- ShelfId = "shelf_2".
+!find_best_shelf(CId, W, H, Weight, ShelfId)
    : shelf_fits("shelf_3", Weight, W*H)
    <- ShelfId = "shelf_3".
+!find_best_shelf(CId, W, H, Weight, ShelfId)
    : shelf_fits("shelf_4", Weight, W*H)
    <- ShelfId = "shelf_4".

/* Si no cabe en pequenas, probar las medianas */
+!find_best_shelf(CId, W, H, Weight, ShelfId)
    : shelf_fits("shelf_5", Weight, W*H)
    <- ShelfId = "shelf_5".
+!find_best_shelf(CId, W, H, Weight, ShelfId)
    : shelf_fits("shelf_6", Weight, W*H)
    <- ShelfId = "shelf_6".
+!find_best_shelf(CId, W, H, Weight, ShelfId)
    : shelf_fits("shelf_7", Weight, W*H)
    <- ShelfId = "shelf_7".

/* Si no cabe en medianas, probar las grandes */
+!find_best_shelf(CId, W, H, Weight, ShelfId)
    : shelf_fits("shelf_8", Weight, W*H)
    <- ShelfId = "shelf_8".
+!find_best_shelf(CId, W, H, Weight, ShelfId)
    : shelf_fits("shelf_9", Weight, W*H)
    <- ShelfId = "shelf_9".

/* Ninguna cabe: usar get_free_shelf del entorno como fallback */
+!find_best_shelf(CId, W, H, Weight, ShelfId) <-
    get_free_shelf(CId);
    ?free_shelf(CId, ShelfId);
    -free_shelf(CId, ShelfId).


/* ============================================================================
 * MANEJO DE ERRORES
 * ============================================================================ */

/* Si ocurre un error con un contenedor que sigue pendiente,
 * registrar el error, liberar al robot e intentar reasignarlo */
+robot_error(Robot, CId, ErrorType)[source(_)]
    : pending(CId, W, H, Weight, Type) <-
    .print("[Scheduler] Error ", ErrorType, " de ", Robot, " con ", CId);
    ?stat_errors(N); -stat_errors(N); +stat_errors(N+1);
    .send(supervisor, tell, error_occurred(Robot, CId, ErrorType));
    -robot_status(Robot, busy); +robot_status(Robot, idle);
    -robot_task(Robot, _, _); +robot_task(Robot, none, none);
    -robot_error(Robot, CId, ErrorType)[source(_)];
    !try_assign(CId, W, H, Weight, Type).

/* Si ocurre un error con un contenedor no pendiente,
 * registrar el error, liberar al robot y continuar con el resto */
+robot_error(Robot, CId, ErrorType)[source(_)]
    : not pending(CId, _, _, _, _) <-
    .print("[Scheduler] Error ", ErrorType, " de ", Robot);
    ?stat_errors(N); -stat_errors(N); +stat_errors(N+1);
    .send(supervisor, tell, error_occurred(Robot, CId, ErrorType));
    -robot_status(Robot, busy); +robot_status(Robot, idle);
    -robot_task(Robot, _, _); +robot_task(Robot, none, none);
    -robot_error(Robot, CId, ErrorType)[source(_)];
    !try_assign_pending.


/* ============================================================================
 * CONSULTA DE ESTADO
 * ============================================================================ */

/* Mostrar estadisticas globales y estado actual de cada robot */
+!estado : true <-
    ?stat_received(R); ?stat_assigned(A); ?stat_completed(C); ?stat_errors(E);
    ?robot_status(robot_light, SL);
    ?robot_status(robot_medium, SM);
    ?robot_status(robot_heavy, SH);
    ?robot_task(robot_light, TL, DL);
    ?robot_task(robot_medium, TM, DM);
    ?robot_task(robot_heavy, TH, DH);
    .print("[Scheduler] Recibidos:", R, " Asignados:", A, " Completados:", C, " Errores:", E);
    .print("[Scheduler] Light=", SL, " [", TL, "->", DL, "]");
    .print("[Scheduler] Medium=", SM, " [", TM, "->", DM, "]");
    .print("[Scheduler] Heavy=", SH, " [", TH, "->", DH, "]").

/* Alias para imprimir el estado del scheduler */
+!print_status : true <- !estado.
