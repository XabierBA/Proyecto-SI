/*******************************************************************************
 * SCHEDULER - MODO AUTÓNOMO
 * Gestión de colas de contenedores y ciclo de salida con deadlines.
 *
 * ΔT = 30 000 ms (30 s). Justificación:
 *   - Un robot heavy tarda ~25 s en el viaje más largo (shelf_9 ↔ exit zone).
 *   - 30 s garantiza al menos 1 entrega por robot en el deadline corto.
 *   - Con 4 robots operando en paralelo, todos los urgentes (≤ 3 shelves)
 *     deben salir en ese margen; si no, la nota de "entregados" refleja
 *     lo real y el deadline largo cubre los no-urgentes en 2·ΔT = 60 s.
 *   - Total ciclo T0 + 3·ΔT = 90 s, suficiente para vaciar ambos grupos.
 ******************************************************************************/

/* --- Capacidades de Robots --- */
robot_capacity(robot_light,   10,  1, 1, 3).
robot_capacity(robot_medium,  30,  1, 2, 2).
robot_capacity(robot_heavy,  100,  2, 3, 1).
robot_capacity(robot_heavy_2,100,  2, 3, 1).

/* --- Configuración de Estanterías --- */
shelf_data("shelf_1",  50,  8, 0, 0).
shelf_data("shelf_2",  50,  8, 0, 0).
shelf_data("shelf_3",  50,  8, 0, 0).
shelf_data("shelf_4",  50,  8, 0, 0).
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

matches_group("urgent",   urgent).
matches_group("standard", nonurgent).
matches_group("fragile",  nonurgent).

/* Estado de aceptación por tipo */
accepting_type("urgent").
accepting_type("standard").
accepting_type("fragile").

/* Estadísticas */
stat_received(0). stat_completed(0). stat_errors(0).

/* ΔT en milisegundos */
delta_t(30000).

!start.

+!start <-
    .print("[Scheduler] MODO AUTÓNOMO OPERATIVO - Publicando para robots");
    !main_loop.

/* ========== CICLO DE REVISIÓN (Cada 500 ms) ========== */
+!main_loop <-
    .wait(500);
    !check_and_broadcast;
    !main_loop.

+!check_and_broadcast : output_phase_active <-
    /* Durante fase de salida, retiramos los pending_container del BB de los
     * robots para que no sigan pujando por ellos en lugar de los urgentes.
     * Este paso garantiza que la fase de salida tenga prioridad sobre nuevos
     * mensajes de entrada pendientes. */
    !untell_all_pending.

+!check_and_broadcast <-
    !broadcast_urgents;
    !broadcast_normals;
    .abolish(skip(_)).

+!untell_all_pending : pending(CId, W, H, Weight, Type) & not skip(CId) <-
    .broadcast(untell, pending_container(CId, W, H, Weight, Type));
    +skip(CId);
    !untell_all_pending.
+!untell_all_pending <- .abolish(skip(_)).

+!broadcast_urgents : pending(CId, W, H, Weight, "urgent") & not skip(CId) <-
    .broadcast(tell, pending_container(CId, W, H, Weight, "urgent"));
    +skip(CId);
    !broadcast_urgents.
+!broadcast_urgents <- true.

+!broadcast_normals : pending(CId, W, H, Weight, Type) & Type \== "urgent" & not skip(CId) <-
    .broadcast(tell, pending_container(CId, W, H, Weight, Type));
    +skip(CId);
    !broadcast_normals.
+!broadcast_normals <- true.

/* ========== RECEPCIÓN DE CONTENEDORES ========== */
+new_container(CId) : not pending(CId, _, _, _, _) <-
    ?stat_received(N); -stat_received(N); +stat_received(N+1);
    get_container_info(CId).

+container_info(CId, W, H, Weight, Type) <-
    -container_info(CId, W, H, Weight, Type);
    if (blocked_type(Type) | output_phase_active) {
        .print("[Scheduler] RECHAZADO (Fase Salida): ", CId)
    } else {
        .print("[Scheduler] NUEVO: ", CId, " (", Type, ")");
        +pending(CId, W, H, Weight, Type);
        .send(supervisor, tell, container_counted(CId, W, H, Weight, Type));
        !check_and_broadcast
    }.

/* ========== CICLO DE SALIDA ========== */

/* Supervisora detecta sin espacio → T0 = ahora, arranca ciclo.
 * El instante en que se recibe este mensaje es T0. */
+no_space(Group)[source(supervisor)] : not output_phase_active <-
    +output_phase_active;
    !block_group(Group);
    .time(HH, MM, SS); .concat(HH, ":", MM, ":", SS, T0);
    .print("EVENT | time=", T0, " | agent=scheduler | type=output_phase_started | data=", Group);
    !run_deadlines.

/* Ignorar si ya hay un ciclo activo */
+no_space(_)[source(supervisor)] <- true.

+!block_group(urgent) <-
    -accepting_type("urgent");
    +blocked_type("urgent").
+!block_group(nonurgent) <-
    -accepting_type("standard"); -accepting_type("fragile");
    +blocked_type("standard"); +blocked_type("fragile").

/* Secuencia: deadline corto (urgent) → deadline largo (nonurgent).
 * Ambos deadlines se ejecutan siempre, independientemente del grupo
 * que originó el ciclo: primero salen los urgentes, luego los no urgentes. */
+!run_deadlines <-
    !run_short_deadline;
    !run_long_deadline;
    !cleanup_output_phase.

/* --- Deadline corto: urgentes (duración ΔT = T0 + ΔT) ---
 * Solo se ejecuta si hay contenedores urgentes almacenados. */
+!run_short_deadline <-
    .findall(CId, stored(CId, _, "urgent"), L); .length(L, N);
    if (N > 0) {
        .time(HH, MM, SS); .concat(HH, ":", MM, ":", SS, T);
        +deadline_active(urgent);
        .broadcast(tell, deadline_active(urgent));
        .print("EVENT | time=", T, " | agent=scheduler | type=deadline_started | data=urgent");
        .send(supervisor, tell, deadline_started(urgent));
        !broadcast_exit_required(urgent);
        ?delta_t(D);
        EndMs = HH*3600000 + MM*60000 + SS*1000 + D;
        register_deadline("urgent", N, EndMs);
        .wait(D);
        .time(HH2, MM2, SS2); .concat(HH2, ":", MM2, ":", SS2, T2);
        -deadline_active(urgent);
        .broadcast(untell, deadline_active(urgent));
        .print("EVENT | time=", T2, " | agent=scheduler | type=deadline_ended | data=urgent");
        .send(supervisor, tell, deadline_ended(urgent));
        end_deadline("urgent");
        !call_transport(urgent)
    } else {
        .print("[Scheduler] Sin urgentes almacenados — saltando deadline urgente")
    }.

/* --- Deadline largo: no urgentes (duración 2·ΔT → T0 + 3·ΔT total) ---
 * Solo se ejecuta si hay contenedores no urgentes almacenados. */
+!run_long_deadline <-
    .findall(CId, (stored(CId, _, Type) & (Type == "standard" | Type == "fragile")), L); .length(L, N);
    if (N > 0) {
        .time(HH, MM, SS); .concat(HH, ":", MM, ":", SS, T);
        +deadline_active(nonurgent);
        .broadcast(tell, deadline_active(nonurgent));
        .print("EVENT | time=", T, " | agent=scheduler | type=deadline_started | data=nonurgent");
        .send(supervisor, tell, deadline_started(nonurgent));
        !broadcast_exit_required(nonurgent);
        ?delta_t(D);
        Long = D * 2;
        EndMs = HH*3600000 + MM*60000 + SS*1000 + Long;
        register_deadline("nonurgent", N, EndMs);
        .wait(Long);
        .time(HH2, MM2, SS2); .concat(HH2, ":", MM2, ":", SS2, T2);
        -deadline_active(nonurgent);
        .broadcast(untell, deadline_active(nonurgent));
        .print("EVENT | time=", T2, " | agent=scheduler | type=deadline_ended | data=nonurgent");
        .send(supervisor, tell, deadline_ended(nonurgent));
        end_deadline("nonurgent");
        !call_transport(nonurgent)
    } else {
        .print("[Scheduler] Sin no-urgentes almacenados — saltando deadline no-urgente")
    }.

/* ========== BROADCAST exit_required AL INICIO DE CADA DEADLINE ==========
 * Emite exit_required(CId, Type, ShelfId) a todos los robots para que
 * puedan actuar de forma autónoma sin depender del scheduler.
 * Los robots también buscan en su propio stored_at, así que esto es
 * un hint complementario para acelerar la reacción inicial.
 * ========================================================================== */

+!broadcast_exit_required(urgent) <-
    .findall(cid_shelf_type(CId, ShelfId, "urgent"),
             stored(CId, ShelfId, "urgent"),
             List);
    !send_exit_required_list(List).

+!broadcast_exit_required(nonurgent) <-
    .findall(cid_shelf_type(CId, ShelfId, Type),
             (stored(CId, ShelfId, Type) & (Type == "standard" | Type == "fragile")),
             List);
    !send_exit_required_list(List).

+!send_exit_required_list([]) <- true.
+!send_exit_required_list([cid_shelf_type(CId, ShelfId, Type) | Rest]) <-
    .broadcast(tell, exit_required(CId, Type, ShelfId));
    !send_exit_required_list(Rest).

/* Llamar al agente Transport */
+!call_transport(Group) <-
    .print("[Scheduler] Llamando a Transport para retirar grupo: ", Group);
    /* Construir la lista de contenedores en zona de salida para este grupo */
    !collect_at_exit_for_group(Group, ExitList);
    .send(transport, achieve, pickup_for_transport(Group, ExitList)).

/* Recolectar CIds en at_exit que corresponden al grupo */
+!collect_at_exit_for_group(urgent, ExitList) <-
    .findall(CId, at_exit(CId, "urgent"), ExitList).

+!collect_at_exit_for_group(nonurgent, ExitList) <-
    .findall(CId, (at_exit(CId, Type) & (Type == "standard" | Type == "fragile")), ExitList).

/* Limpieza al terminar el ciclo completo */
+!cleanup_output_phase <-
    -output_phase_active;
    .abolish(blocked_type(_));
    .abolish(accepting_type(_));
    +accepting_type("urgent");
    +accepting_type("standard");
    +accepting_type("fragile");
    .send(supervisor, tell, cycle_finished(urgent));
    .send(supervisor, tell, cycle_finished(nonurgent));
    .print("[Scheduler] Ciclo de salida completo, aceptando contenedores").

/* ========== TRACKING DE CONTENEDORES ALMACENADOS ========== */

+claim_reserved(CId, ShelfId)[source(_)] <-
    +shelf_assigned(CId, ShelfId).

+task_complete(CId, Robot)[source(_)] : pending(CId, W, H, Weight, Type) & shelf_assigned(CId, ShelfId) <-
    -pending(CId, W, H, Weight, Type);
    -shelf_assigned(CId, ShelfId);
    +stored(CId, ShelfId, Type);
    ?stat_completed(N); -stat_completed(N); +stat_completed(N+1);
    .send(supervisor, tell, task_done(CId, Robot)).

+task_complete(_, _)[source(_)] <- true.

/* Cuando un robot notifica que depositó un contenedor en zona de salida:
 * - FIX: registrar at_exit SIEMPRE (independientemente de si stored aún existe),
 *   usando el tipo que nos manda el robot directamente en container_delivered.
 *   Esto evita la condición de carrera donde stored ya fue eliminado antes
 *   de que llegue container_at_exit.
 * - Eliminar de stored si todavía estuviera ahí. */
+container_at_exit(CId)[source(_)] : stored(CId, ShelfId, Type) <-
    -stored(CId, ShelfId, Type);
    /* Sólo añadir at_exit si no existe ya (puede llegar duplicado) */
    if (not at_exit(CId, _)) {
        +at_exit(CId, Type)
    }.

/* FIX CRÍTICO: si stored ya no existe cuando llega container_at_exit
 * (el robot envió container_at_exit y container_delivered en orden inverso,
 * o stored fue limpiado por otra vía), intentamos recuperar el tipo
 * del mensaje container_delivered que debería llegar a continuación.
 * Por ahora marcamos at_exit con tipo "unknown" para que Transport lo retire. */
+container_at_exit(CId)[source(_)] : not stored(CId, _, _) & not at_exit(CId, _) <-
    .print("[Scheduler] AVISO: container_at_exit para ", CId, " sin stored activo — esperando container_delivered").

+container_at_exit(_)[source(_)] <- true.

/* container_delivered: fuente autoritativa del tipo.
 * Úsalo para registrar at_exit si container_at_exit llegó antes que stored se limpiara
 * (o si stored ya no existía por cualquier razón). */
+container_delivered(CId, Robot, Type)[source(_)] <-
    .time(HH, MM, SS); .concat(HH, ":", MM, ":", SS, T);
    .print("[Scheduler] container_delivered confirmado: ", CId, " por ", Robot, " tipo=", Type);
    /* Si at_exit aún no fue registrado, hacerlo ahora con el tipo del robot */
    if (not at_exit(CId, _)) {
        +at_exit(CId, Type)
    };
    /* Si stored sigue presente (llegó container_delivered antes que container_at_exit),
     * limpiarlo para evitar que el robot vuelva a intentar sacarlo. */
    if (stored(CId, ShelfId2, _)) {
        .findall(S, stored(CId, S, _), Shelves);
        for (.member(S2, Shelves)) {
            .abolish(stored(CId, S2, _))
        }
    };
    -container_delivered(CId, Robot, Type)[source(_)].

+robot_error(Robot, CId, Reason)[source(_)] <-
    ?stat_errors(N); -stat_errors(N); +stat_errors(N+1);
    .print("[Scheduler] ERROR robot=", Robot, " cid=", CId, " reason=", Reason).

+transport_done(Group)[source(transport)] <-
    .print("[Scheduler] Transport completó recogida grupo: ", Group).

+transport_picked(CId)[source(transport)] <-
    .abolish(at_exit(CId, _)).
