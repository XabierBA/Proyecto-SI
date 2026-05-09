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

/* Recibir aviso del supervisor */
+no_storage_space(Type)[source(supervisor)] <-
    -accepting_type(Type);
    +blocked_type(Type);
    .print("[Scheduler] Bloqueando nuevos contenedores de tipo: ", Type);
    !trigger_exit_cycle(Type).

/* Activar ciclo de salida */
+!trigger_exit_cycle(Type) <-
    .print("[Scheduler] Iniciando ciclo de salida para tipo: ", Type);
    for (pending(CId, _, _, _, Type)) {
        .send(robot_light,   tell, exit_required(CId, Type));
        .send(robot_medium,  tell, exit_required(CId, Type));
        .send(robot_heavy,   tell, exit_required(CId, Type));
        .send(robot_heavy_2, tell, exit_required(CId, Type))
    }.

/* Cuando el supervisor reporta que ya hay espacio, reanudar */
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
