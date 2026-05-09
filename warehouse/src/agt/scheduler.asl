/*******************************************************************************
 * SCHEDULER - MODO AUTÓNOMO (MERGED)
 * - Los robots eligen sus tareas (Pull) en lugar de recibirlas (Push).
 * - Prioridad URGENTE gestionada por publicación.
 * - Soporte para fases de salida y gestión de estanterías inteligente.
 ******************************************************************************/

/* --- Capacidades de Robots (Para validaciones internas si fueran necesarias) --- */
robot_capacity(robot_light,  10,  1, 1, 3).
robot_capacity(robot_medium, 30,  1, 2, 2).
robot_capacity(robot_heavy,  100, 2, 3, 1).
robot_capacity(robot_heavy_2, 100, 2, 3, 1).

/* --- Configuración de Estanterías --- */
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

!start.

+!start : true <-
    .print("[Scheduler] ⭐ MODO AUTÓNOMO OPERATIVO - Publicando para robots");
    !main_loop.

/* ========== CICLO DE REVISIÓN (Cada 500ms) ========== */
+!main_loop <-
    .wait(500);
    !check_and_broadcast;
    !main_loop.

+!check_and_broadcast <-
    !broadcast_urgents;
    !broadcast_normals;
    .abolish(skip(_)).

/* Publicar Urgentes */
+!broadcast_urgents : pending(CId, W, H, Weight, "urgent") & not skip(CId) <-
    .broadcast(tell, pending_container(CId, W, H, Weight, "urgent"));
    +skip(CId);
    !broadcast_urgents.
+!broadcast_urgents <- true.

/* Publicar Normales */
+!broadcast_normals : pending(CId, W, H, Weight, Type) & Type \== "urgent" & not skip(CId) <-
    .broadcast(tell, pending_container(CId, W, H, Weight, Type));
    +skip(CId);
    !broadcast_normals.
+!broadcast_normals <- true.

/* Estado por tipo: accepting / blocked */
accepting_type("urgent").
accepting_type("standard").
accepting_type("fragile").

/* Recibir aviso del supervisor (T0 = instante de recepción del no_space).
 * Bloqueamos tipo, registramos T0 y arrancamos el ciclo de salida. */
+no_space(Group)[source(supervisor)] <-
    !block_group(Group);
    .time(HH, MM, SS); .concat(HH, ":", MM, ":", SS, T0);
    +t0(Group, T0);
    +output_phase(Group);
    .print("EVENT | time=", T0, " | agent=scheduler | type=output_phase_started | data=", Group);
    !trigger_exit_cycle(Group).

/* Bloquear los tipos de contenedor del grupo afectado */
+!block_group(urgent) <-
    -accepting_type("urgent");
    +blocked_type("urgent").
+!block_group(nonurgent) <-
    -accepting_type("standard"); -accepting_type("fragile");
    +blocked_type("standard"); +blocked_type("fragile").

/* Compatibilidad con el handler anterior por si algún agente sigue mandando no_storage_space */
+no_storage_space(Type)[source(supervisor)] <-
    -accepting_type(Type);
    +blocked_type(Type);
    .print("[Scheduler] Bloqueando nuevos contenedores de tipo: ", Type);
    !trigger_exit_cycle(Type).

/* Activar ciclo de salida */
+!trigger_exit_cycle(Group) <-
    .print("[Scheduler] Iniciando ciclo de salida para grupo: ", Group);
    for (pending(CId, _, _, _, Type) & matches_group(Type, Group)) {
        .send(robot_light,   tell, exit_required(CId, Type));
        .send(robot_medium,  tell, exit_required(CId, Type));
        .send(robot_heavy,   tell, exit_required(CId, Type));
        .send(robot_heavy_2, tell, exit_required(CId, Type))
    }.

/* Mapeo tipo → grupo */
matches_group("urgent", urgent).
matches_group("standard", nonurgent).
matches_group("fragile", nonurgent).

/* Cuando el supervisor reporta que ya hay espacio, reanudar */
+space_available(Group)[source(supervisor)] <-
    !unblock_group(Group);
    -output_phase(Group);
    .print("[Scheduler] Reanudando aceptación de grupo: ", Group).

+!unblock_group(urgent) <-
    -blocked_type("urgent");
    +accepting_type("urgent").
+!unblock_group(nonurgent) <-
    -blocked_type("standard"); -blocked_type("fragile");
    +accepting_type("standard"); +accepting_type("fragile").

/* Compatibilidad con storage_available antiguo */
+storage_available(Type)[source(supervisor)] <-
    -blocked_type(Type);
    +accepting_type(Type);
    .print("[Scheduler] Reanudando aceptación de tipo: ", Type).


    

/* ========== RECEPCIÓN DE CONTENEDORES ========== */
+new_container(CId) : not pending(CId, _, _, _, _) <-
    ?stat_received(N); -stat_received(N); +stat_received(N+1);
    get_container_info(CId).

+container_info(CId, W, H, Weight, Type) : true <-
    -container_info(CId, W, H, Weight, Type);

    // Determinar grupo para fase de salida
    if (Type == "urgent") { Group = urgent; } else { Group = nonurgent; }

    if (output_phase(Group)) {
        .print("[Scheduler] 🚫 RECHAZADO (Fase Salida): ", CId);
    } else {
        .print("[Scheduler] 📥 NUEVO: ", CId, " (", Type, ")");
        +pending(CId, W, H, Weight, Type);
        .send(supervisor, tell, container_counted(CId, W, H, Weight, Type));
        !check_and_broadcast;
    }.
