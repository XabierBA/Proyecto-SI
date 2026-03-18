/*******************************************************************************
 * SCHEDULER - Agente Planificador y Coordinador de Tareas
 * Universidad de Vigo - Sistemas Inteligentes - Curso 2025-2026
 *
 * NOTA IMPORTANTE SOBRE LA ARQUITECTURA:
 *   El entorno Java (WarehouseArtifact) ya gestiona la asignacion directa de
 *   tareas a robots a traves de request_task(). Cuando un robot llama
 *   request_task(), el entorno busca el mejor contenedor y estanteria, marca
 *   al robot como ocupado y le envia la percepcion task(CId, ShelfId).
 *
 *   El rol del scheduler es:
 *   1. Recibir notificaciones de new_container y registrarlas
 *   2. Recibir notificaciones de los robots (task_done, task_error)
 *   3. Notificar al supervisor de todos los eventos
 *   4. Responder a peticiones de estadisticas del supervisor
 ******************************************************************************/

/* ============================================================================
 * CREENCIAS INICIALES
 * ============================================================================ */
total_containers_received(0).
total_tasks_done(0).
total_task_errors(0).

/* ============================================================================
 * INICIO
 * ============================================================================ */
!start.

+!start : true <-
    .print("[Scheduler] Iniciado. Monitorizando contenedores y robots.").

/* ============================================================================
 * NUEVO CONTENEDOR: registrar y notificar al supervisor
 * ============================================================================ */
+new_container(CId) : true <-
    ?total_containers_received(N);
    N1 = N + 1;
    -+total_containers_received(N1);
    .print("[Scheduler] Nuevo contenedor: ", CId, " | Total: ", N1).

/* ============================================================================
 * ROBOT NOTIFICA TAREA COMPLETADA
 * Robots envian: .send(scheduler, tell, task_done(CId, RobotName))
 * ============================================================================ */
+task_done(CId, Robot)[source(Robot)] : true <-
    ?total_tasks_done(N);
    N1 = N + 1;
    -+total_tasks_done(N1);
    .print("[Scheduler] Tarea completada: robot=", Robot, " contenedor=", CId);
    .send(supervisor, tell, task_done(CId, Robot)).

/* ============================================================================
 * ROBOT NOTIFICA ERROR EN TAREA
 * Robots envian: .send(scheduler, tell, task_error(CId, RobotName, Reason))
 * ============================================================================ */
+task_error(CId, Robot, Reason)[source(Robot)] : true <-
    ?total_task_errors(N);
    N1 = N + 1;
    -+total_task_errors(N1);
    .print("[Scheduler] Error de ", Robot, " en ", CId, ": ", Reason);
    .send(supervisor, tell, task_error(CId, Robot, Reason)).

/* ============================================================================
 * ROBOT NOTIFICA TAREA ASIGNADA (para notificar al supervisor)
 * Robots envian: .send(scheduler, tell, task_assigned(CId, RobotName, ShelfId))
 * ============================================================================ */
+task_assigned(CId, Robot, ShelfId)[source(Robot)] : true <-
    .print("[Scheduler] Tarea asignada: robot=", Robot, " cid=", CId, " shelf=", ShelfId);
    .send(supervisor, tell, task_assigned(CId, Robot, ShelfId)).

/* ============================================================================
 * RESPONDER A PETICION DE ESTADISTICAS DEL SUPERVISOR
 * ============================================================================ */
+stats_request[source(supervisor)] : true <-
    ?total_containers_received(R);
    ?total_tasks_done(A);
    ?total_task_errors(E);
    .send(supervisor, tell, stats(R, A, E, 0)).
