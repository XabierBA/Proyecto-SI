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

/* Tipo permitido por estanteria:
 *   shelf_1, shelf_5, shelf_8 -> solo "urgent"
 *   resto                     -> "standard" y "fragile" */
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

/* Regla: una estanteria puede almacenar un contenedor
 * si no supera ni el peso ni el volumen maximos
 * Y el tipo de paquete esta permitido en esa estanteria */
shelf_fits(ShelfId, Weight, Area, Type) :-
    shelf_data(ShelfId, MaxW, MaxV, CurW, CurV) &
    CurW + Weight <= MaxW &
    CurV + Area <= MaxV &
    shelf_allows_type(ShelfId, Type).

/* Estadisticas globales del scheduler */
stat_received(0).
stat_assigned(0).
stat_completed(0).
stat_errors(0).

/* Estado de bloqueo por grupo de tipo:
 *   output_phase(urgent)    -> fase de salida activa para urgentes
 *   output_phase(nonurgent) -> fase de salida activa para no urgentes
 * Ausencia del belief = aceptacion normal */


/* ============================================================================
 * PLANES PRINCIPALES
 * ============================================================================ */

!start.

/* Iniciamos el scheduler */
+!start : true <- .print("[Scheduler] Iniciado").


/* ============================================================================
 * DETECCION DE NUEVOS CONTENEDORES
 * ============================================================================ */

/* Si llega un contenedor nuevo y aun no esta pendiente, solicitar su informacion.
 * El filtrado por output_phase se hace en +container_info para evitar
 * llamadas dobles a get_container_info que generan percepciones duplicadas. */
+new_container(CId) : not pending(CId, _, _, _, _) <-
    ?stat_received(N); -stat_received(N); +stat_received(N+1);
    get_container_info(CId).

/* Si el contenedor ya estaba registrado como pendiente, ignorarlo */
+new_container(CId) : pending(CId, _, _, _, _) <- true.


/* ============================================================================
 * CLASIFICACION DE CONTENEDORES
 * ============================================================================ */

/* Ignorar container_info de contenedores ya asignados (el robot llama get_container_info
 * dentro de execute_task; no queremos reclasificarlo). */
+container_info(CId, W, H, Weight, Type) : not pending(CId, _, _, _, _) & stored_at(CId, _) <-
    -container_info(CId, W, H, Weight, Type).

+container_info(CId, W, H, Weight, Type) : not pending(CId, _, _, _, _) & robot_task(_, CId, _) <-
    -container_info(CId, W, H, Weight, Type).

/* Si la fase de salida esta activa para ese tipo, descartar */
+container_info(CId, W, H, Weight, "urgent") : output_phase(urgent) <-
    -container_info(CId, W, H, Weight, "urgent");
    .print("[Scheduler] IGNORADO (output_phase urgente activa): ", CId).

+container_info(CId, W, H, Weight, "standard") : output_phase(nonurgent) <-
    -container_info(CId, W, H, Weight, "standard");
    .print("[Scheduler] IGNORADO (output_phase nonurgent activa): ", CId).

+container_info(CId, W, H, Weight, "fragile") : output_phase(nonurgent) <-
    -container_info(CId, W, H, Weight, "fragile");
    .print("[Scheduler] IGNORADO (output_phase nonurgent activa): ", CId).

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
    /* Seguimiento persistente: que paquete esta en que estanteria */
    ?robot_task(Robot, CId, ShelfId);
    +stored_at(CId, ShelfId);
    .print("[Scheduler] Completado: ", Robot, " entrego ", CId, " en ", ShelfId);
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

/* Mientras exista algun contenedor pendiente y no marcado como skip,
 * intentar asignarlo en este ciclo. */
+!try_assign_pending : pending(CId, W, H, Weight, Type) & not skip(CId) <-
    !try_assign(CId, W, H, Weight, Type);
    !try_assign_pending.

/* Si todos los pendientes tienen skip o no hay pendientes,
 * limpiar los skips del ciclo y terminar. */
+!try_assign_pending <- .abolish(skip(_)).

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

/* Si ningun robot puede asumir la tarea en este momento, marcar como skip para este ciclo */
+!try_assign(CId, W, H, Weight, Type) : true <- +skip(CId).


/* ============================================================================
 * SELECCION DE ESTANTERIA Y ASIGNACION
 * ============================================================================ */

/* Buscar la mejor estanteria disponible, actualizar estados, reservar capacidad y enviar la tarea al robot */

+!do_assign(CId, W, H, Weight, Type, Robot) : true <-
    !find_best_shelf(CId, W, H, Weight, Type, ShelfId);
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

/* Si no se encuentra una estanteria valida, informar por pantalla y marcar skip para no reintentar en este ciclo */
-!do_assign(CId, W, H, Weight, Type, Robot) : true <-
    .print("[Scheduler] Sin estanteria para ", CId);
    +skip(CId).

/* Buscar la estanteria mas pequena que pueda almacenar el contenedor
 * respetando la restriccion de tipo de paquete */

/* Probar primero las estanterias pequenas */
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

/* Si no cabe en pequenas, probar las medianas */
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_5", Weight, W*H, Type)
    <- ShelfId = "shelf_5".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_6", Weight, W*H, Type)
    <- ShelfId = "shelf_6".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_7", Weight, W*H, Type)
    <- ShelfId = "shelf_7".

/* Si no cabe en medianas, probar las grandes */
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_8", Weight, W*H, Type)
    <- ShelfId = "shelf_8".
+!find_best_shelf(CId, W, H, Weight, Type, ShelfId)
    : shelf_fits("shelf_9", Weight, W*H, Type)
    <- ShelfId = "shelf_9".

/* Ninguna estanteria cabe: el plan falla y do_assign maneja el error */
-!find_best_shelf(_, _, _, _, _, _) <-
    .print("[Scheduler] Sin estanteria disponible").


/* ============================================================================
 * GESTION DE FASE DE SALIDA (avisos del supervisor)
 * ============================================================================ */

/* El supervisor avisa de que no queda espacio para contenedores urgentes */
+no_space(urgent)[source(supervisor)] : not output_phase(urgent) <-
    +output_phase(urgent);
    .time(HH, MM, SS); .concat(HH, ":", MM, ":", SS, T);
    .print("EVENT | time=", T, " | agent=scheduler | type=output_phase_started | data=urgent");
    .print("[Scheduler] Fase de salida URGENTE activada - sin asignacion de urgentes");
    !start_output_cycle(urgent).

/* El supervisor avisa de que no queda espacio para contenedores no urgentes */
+no_space(nonurgent)[source(supervisor)] : not output_phase(nonurgent) <-
    +output_phase(nonurgent);
    .time(HH, MM, SS); .concat(HH, ":", MM, ":", SS, T);
    .print("EVENT | time=", T, " | agent=scheduler | type=output_phase_started | data=nonurgent");
    .print("[Scheduler] Fase de salida NO URGENTE activada - sin asignacion de standard/fragile");
    !start_output_cycle(nonurgent).

/* Avisos duplicados ignorados (la fase ya estaba activa) */
+no_space(_)[source(supervisor)] <- true.

/* El supervisor avisa de que ha vuelto a haber espacio: desactivar fase de salida */
+space_available(urgent)[source(supervisor)] <-
    -output_phase(urgent);
    .print("[Scheduler] Fase de salida URGENTE desactivada - reanudando aceptacion");
    !try_assign_pending.

+space_available(nonurgent)[source(supervisor)] <-
    -output_phase(nonurgent);
    .print("[Scheduler] Fase de salida NO URGENTE desactivada - reanudando aceptacion");
    !try_assign_pending.

/* Ciclo de salida: los robots sacan contenedores almacenados del tipo bloqueado.
 * Por ahora registra el inicio y espera a que los robots vacieen las estanterias.
 * Cuando task_done llegue y el supervisor detecte espacio libre, mandara space_available. */
+!start_output_cycle(Group) <-
    .print("[Scheduler] Iniciando vaciado de estanterias para grupo: ", Group).

/* El scheduler reporta al supervisor el estado actual de sus estanterias */
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