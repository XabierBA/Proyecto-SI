/*******************************************************************************
 * SUPERVISOR - Agente de Monitorización y Gestión de Errores
 *
 * Universidad de Vigo - Sistemas Inteligentes - Curso 2025-2026
 *
 * RESPONSABILIDADES (según presentación del proyecto):
 *   1. Monitorizar contenedores recibidos, almacenados y errores
 *   2. Gestionar los 6 tipos de error definidos en el entorno
 *   3. Calcular estadísticas globales del sistema
 *   4. Detectar situaciones anómalas y emitir alertas
 *
 * FUENTES DE INFORMACIÓN:
 *   - Entorno (broadcast):
 *       +new_container(CId)               ? nuevo contenedor en entrada
 *       +error(Type, Data)                ? error detectado en un robot
 *       +blocked(X,Y)                     ? ruta bloqueada
 *   - Mensajes del Scheduler:
 *       task_assigned(CId, Robot, ShelfId)
 *       task_done(CId, Robot)
 *       task_error(CId, Robot, Reason)
 *       assignment_error(CId, Weight, W, H)
 *       container_queued(CId, Weight, W, H)
 *   - Mensajes directos de los Robots:
 *       error_report(Robot, Type, Data)   ? robot notifica error al supervisor
 *
 * TIPOS DE ERROR (slide 10 - obligatorio manejar todos):
 *   container_too_heavy ? Robot no puede cargar ese peso
 *   container_too_big   ? Robot no puede cargar ese tamaño
 *   shelf_full          ? Estantería sin espacio disponible
 *   illegal_move        ? Movimiento fuera de los límites del grid
 *   conflict            ? Colisión o conflicto entre dos robots
 *   route_blocked       ? Camino obstruido, robot no puede avanzar
 *
 * TIPOS DE CONTENEDOR (slide 4):
 *   standard (70%) - Normal
 *   fragile  (15%) - Requiere cuidado especial
 *   urgent   (15%) - Alta prioridad
 *
 ******************************************************************************/

/* ============================================================================
 * CREENCIAS INICIALES
 * ============================================================================ */

/* --- Contadores principales (requisito: recibidos / almacenados / errores) --- */
total_received(0).
total_stored(0).
total_errors(0).

/* --- Contadores por tipo de error (los 6 del entorno, slide 10) --- */
errors_by_type(container_too_heavy, 0).
errors_by_type(container_too_big,   0).
errors_by_type(shelf_full,          0).
errors_by_type(illegal_move,        0).
errors_by_type(conflict,            0).
errors_by_type(route_blocked,       0).

/* --- Tareas completadas por robot --- */
tasks_done_by_robot(robot_light,  0).
tasks_done_by_robot(robot_medium, 0).
tasks_done_by_robot(robot_heavy,  0).

/* --- Errores por robot --- */
errors_by_robot(robot_light,  0).
errors_by_robot(robot_medium, 0).
errors_by_robot(robot_heavy,  0).

/* --- Contenedores almacenados por tipo (standard / fragile / urgent) --- */
stored_by_type(standard, 0).
stored_by_type(fragile,  0).
stored_by_type(urgent,   0).

/* --- Umbrales de alerta --- */
alert_threshold_robot_errors(5).    // alerta si un robot acumula ? 5 errores
alert_threshold_total_errors(10).   // alerta global si errores totales ? 10


/* ============================================================================
 * INICIO
 * ============================================================================ */

!start.

+!start : true <-
    .print("[Supervisor] Monitorización iniciada. Vigilando 5 agentes.").


/* ============================================================================
 * PERCEPCIÓN DIRECTA DEL ENTORNO: nuevo contenedor
 *
 * El entorno emite new_container como broadcast a todos los agentes.
 * El supervisor simplemente lleva la cuenta.
 * ============================================================================ */

+new_container(CId) : true <-
    ?total_received(N);
    N1 = N + 1;
    -+total_received(N1);
    .print("[Supervisor] Nuevo contenedor registrado: ", CId, " | Total recibidos: ", N1).


/* ============================================================================
 * MENSAJES DEL SCHEDULER: tarea asignada
 *
 * El scheduler notifica al supervisor cada vez que asigna una tarea.
 * Formato: task_assigned(CId, Robot, ShelfId)
 * ============================================================================ */

+task_assigned(CId, Robot, ShelfId)[source(scheduler)] : true <-
    .print("[Supervisor] Tarea asignada | contenedor=", CId,
           " robot=", Robot, " estantería=", ShelfId).


/* ============================================================================
 * MENSAJES DEL SCHEDULER: tarea completada con éxito
 *
 * Formato: task_done(CId, Robot)
 * Se actualiza el contador global, el contador por robot, y
 * cada 5 almacenamientos se imprime un resumen automático.
 * ============================================================================ */

+task_done(CId, Robot)[source(scheduler)] : true <-
    // Contador global de almacenados
    ?total_stored(N);
    N1 = N + 1;
    -+total_stored(N1);
    // Contador por robot
    ?tasks_done_by_robot(Robot, K);
    K1 = K + 1;
    -+tasks_done_by_robot(Robot, K1);
    .print("[Supervisor] Almacenado correctamente | contenedor=", CId,
           " robot=", Robot, " | Total almacenados: ", N1);
    // Resumen automático cada 5 contenedores almacenados
    if (N1 mod 5 == 0) { !print_summary }.


/* ============================================================================
 * MENSAJES DEL SCHEDULER: error en una tarea
 *
 * Formato: task_error(CId, Robot, Reason)
 * Reason es uno de los 6 tipos definidos en el entorno.
 * ============================================================================ */

+task_error(CId, Robot, Reason)[source(scheduler)] : true <-
    .print("[Supervisor] ERROR en tarea | contenedor=", CId,
           " robot=", Robot, " motivo=", Reason);
    !register_error(Robot, Reason).


/* ============================================================================
 * MENSAJES DEL SCHEDULER: contenedor imposible de asignar
 *
 * Formato: assignment_error(CId, Weight, W, H)
 * Ocurre cuando el contenedor excede la capacidad máxima del sistema.
 * ============================================================================ */

+assignment_error(CId, Weight, W, H)[source(scheduler)] : true <-
    .print("[Supervisor] ERROR CRITICO: Contenedor imposible de asignar | id=", CId,
           " peso=", Weight, "kg | tamaño=", W, "x", H);
    ?total_errors(E);
    E1 = E + 1;
    -+total_errors(E1);
    !check_total_errors_alert.


/* ============================================================================
 * MENSAJES DEL SCHEDULER: contenedor encolado (todos los robots ocupados)
 *
 * Formato: container_queued(CId, Weight, W, H)
 * ============================================================================ */

+container_queued(CId, Weight, W, H)[source(scheduler)] : true <-
    .print("[Supervisor] Contenedor encolado | id=", CId,
           " peso=", Weight, "kg | tamaño=", W, "x", H).


/* ============================================================================
 * MENSAJES DIRECTOS DE LOS ROBOTS: notificación de error
 *
 * Los robots envían al supervisor cuando reciben una percepción de error:
 *   .send(supervisor, tell, error_report(MyName, ErrorType, Data))
 *
 * Formato: error_report(Robot, Type, Data)
 * ============================================================================ */

+error_report(Robot, Type, Data)[source(Robot)] : true <-
    .print("[Supervisor] ERROR directo de robot | robot=", Robot,
           " tipo=", Type, " datos=", Data);
    !register_error(Robot, Type).


/* ============================================================================
 * LOS 6 TIPOS DE ERROR DEL ENTORNO (slide 10)
 *
 * Si por algún motivo el supervisor recibe las percepciones de error
 * directamente del entorno (en caso de broadcast), las maneja aquí.
 * Cada uno tiene su mensaje específico según la presentación.
 * ============================================================================ */

// Robot muy ligero para el contenedor
+error(container_too_heavy, Data) : true <-
    .print("[Supervisor] ALERTA - container_too_heavy: Robot muy ligero | ", Data);
    !register_error_no_robot(container_too_heavy).

// Robot muy pequeño para el contenedor
+error(container_too_big, Data) : true <-
    .print("[Supervisor] ALERTA - container_too_big: Robot muy pequeño | ", Data);
    !register_error_no_robot(container_too_big).

// Estantería sin espacio disponible
+error(shelf_full, Data) : true <-
    .print("[Supervisor] ALERTA - shelf_full: Estantería sin espacio | ", Data);
    !register_error_no_robot(shelf_full).

// Movimiento fuera de los límites del grid
+error(illegal_move, Data) : true <-
    .print("[Supervisor] ALERTA - illegal_move: Movimiento fuera de límites | ", Data);
    !register_error_no_robot(illegal_move).

// Colisión o conflicto entre robots
+error(conflict, Data) : true <-
    .print("[Supervisor] ALERTA - conflict: Colisión entre robots | ", Data);
    !register_error_no_robot(conflict).

// Camino obstruido, robot bloqueado
+error(route_blocked, Data) : true <-
    .print("[Supervisor] ALERTA - route_blocked: Camino obstruido | ", Data);
    !register_error_no_robot(route_blocked).


/* ============================================================================
 * PERCEPCIÓN DIRECTA DEL ENTORNO: ruta bloqueada (slide 9)
 *
 * +blocked(X,Y) indica que una celda del grid está bloqueada.
 * ============================================================================ */

+blocked(X, Y) : true <-
    .print("[Supervisor] Celda bloqueada detectada en: (", X, ",", Y, ")").


/* ============================================================================
 * PLAN AUXILIAR: registrar error con robot conocido
 *
 * Incrementa todos los contadores correspondientes y lanza alertas.
 * ============================================================================ */

+!register_error(Robot, Type) : true <-
    // Contador global
    ?total_errors(E);
    E1 = E + 1;
    -+total_errors(E1);
    // Contador por tipo
    !increment_error_type(Type);
    // Contador por robot
    ?errors_by_robot(Robot, ER);
    ER1 = ER + 1;
    -+errors_by_robot(Robot, ER1);
    // Verificar umbrales de alerta
    !check_robot_alert(Robot);
    !check_total_errors_alert.


/* ============================================================================
 * PLAN AUXILIAR: registrar error sin robot identificado
 * ============================================================================ */

+!register_error_no_robot(Type) : true <-
    ?total_errors(E);
    E1 = E + 1;
    -+total_errors(E1);
    !increment_error_type(Type);
    !check_total_errors_alert.


/* ============================================================================
 * PLAN AUXILIAR: incrementar contador de un tipo de error específico
 * ============================================================================ */

// Tipo conocido ? incrementar su contador
+!increment_error_type(Type) : errors_by_type(Type, N) <-
    N1 = N + 1;
    -+errors_by_type(Type, N1).

// Tipo no catalogado ? avisar pero no romper
+!increment_error_type(Type) : not errors_by_type(Type, _) <-
    .print("[Supervisor] Tipo de error no catalogado: ", Type).


/* ============================================================================
 * PLAN AUXILIAR: alerta si un robot supera el umbral de errores
 * ============================================================================ */

+!check_robot_alert(Robot) :
        errors_by_robot(Robot, ER) &
        alert_threshold_robot_errors(Threshold) &
        ER >= Threshold <-
    .print("[Supervisor] *** ALERTA *** Robot con demasiados errores: ",
           Robot, " (", ER, " errores acumulados)").

+!check_robot_alert(_) : true <- true.


/* ============================================================================
 * PLAN AUXILIAR: alerta si los errores totales superan el umbral
 * ============================================================================ */

+!check_total_errors_alert :
        total_errors(E) &
        alert_threshold_total_errors(Threshold) &
        E >= Threshold <-
    .print("[Supervisor] *** ALERTA GLOBAL *** Errores totales del sistema: ", E).

+!check_total_errors_alert : true <- true.


/* ============================================================================
 * ESTADÍSTICAS: resumen completo del sistema
 *
 * Incluye los tres bloques exigidos en la presentación:
 *   - Contenedores: recibidos / almacenados / errores
 *   - Desglose por robot: tareas completadas y errores
 *   - Desglose por tipo de error (los 6 del entorno)
 *   - Tasa de éxito global
 * ============================================================================ */

+!print_summary : true <-
    // Contadores globales
    ?total_received(R);
    ?total_stored(S);
    ?total_errors(E);
    // Por robot
    ?tasks_done_by_robot(robot_light,  TL);
    ?tasks_done_by_robot(robot_medium, TM);
    ?tasks_done_by_robot(robot_heavy,  TH);
    ?errors_by_robot(robot_light,  EL);
    ?errors_by_robot(robot_medium, EM);
    ?errors_by_robot(robot_heavy,  EH);
    // Por tipo de error
    ?errors_by_type(container_too_heavy, ETH);
    ?errors_by_type(container_too_big,   ETB);
    ?errors_by_type(shelf_full,          ESF);
    ?errors_by_type(illegal_move,        EIM);
    ?errors_by_type(conflict,            ECO);
    ?errors_by_type(route_blocked,       ERB);
    // Imprimir resumen
    .print("[Supervisor] ========== ESTADÍSTICAS DEL ALMACÉN ==========");
    .print("  Contenedores recibidos  : ", R);
    .print("  Contenedores almacenados: ", S);
    .print("  Errores totales         : ", E);
    .print("  --- Rendimiento por robot ---");
    .print("  robot_light  | completados: ", TL, " | errores: ", EL);
    .print("  robot_medium | completados: ", TM, " | errores: ", EM);
    .print("  robot_heavy  | completados: ", TH, " | errores: ", EH);
    .print("  --- Errores por tipo ---");
    .print("  container_too_heavy : ", ETH, " (robot muy ligero)");
    .print("  container_too_big   : ", ETB, " (robot muy pequeño)");
    .print("  shelf_full          : ", ESF, " (sin espacio)");
    .print("  illegal_move        : ", EIM, " (fuera de límites)");
    .print("  conflict            : ", ECO, " (colisión entre robots)");
    .print("  route_blocked       : ", ERB, " (camino obstruido)");
    // Tasa de éxito: contenedores almacenados / recibidos
    if (R > 0) {
        Tasa = (S * 100) / R;
        .print("  Tasa de éxito: ", Tasa, "%")
    };
    .print("===================================================").


/* ============================================================================
 * CONSULTAS EXTERNAS
 * ============================================================================ */

// Otro agente (o manual) puede pedir el resumen
+print_summary_request[source(_)] : true <-
    !print_summary.

// Pedir estadísticas internas al scheduler
+request_scheduler_stats[source(_)] : true <-
    .send(scheduler, tell, stats_request).

// Recibir respuesta de estadísticas del scheduler
+stats(R, A, E, NP)[source(scheduler)] : true <-
    .print("[Supervisor] --- Stats del Scheduler ---");
    .print("  Recibidos : ", R, " | Asignados: ", A,
           " | Errores: ", E, " | En cola: ", NP).