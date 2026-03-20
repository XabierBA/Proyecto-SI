/*******************************************************************************
 * SCHEDULER - Agente Planificador y Coordinador de Tareas
 *
 * Universidad de Vigo - Sistemas Inteligentes - Curso 2025-2026
 *
 * RESPONSABILIDADES:
 *   1. Detectar nuevos contenedores (percepto new_container del entorno)
 *   2. Consultar sus características con get_container_info
 *   3. Asignar tareas a robots con PRIORIDAD: light → medium → heavy
 *      - Se asigna al robot de menor capacidad que pueda manejar el contenedor
 *      - Si ese robot está ocupado, se escala al siguiente nivel
 *      - Si ninguno puede atenderlo ahora, queda en cola de pendientes
 *   4. Escuchar mensajes task_complete de los robots para liberar su estado
 *      y relanzar la asignación sobre la cola de pendientes
 *   5. Gestionar errores notificados por los robots (robot_error)
 *
 * COMUNICACIÓN CON ROBOTS:
 *   → Scheduler envía:  .send(Robot, tell, task(CId, ShelfId))
 *   ← Robots envían:    .send(scheduler, tell, task_complete(CId, NombreRobot))
 *   ← Robots envían:    .send(scheduler, tell, robot_error(NombreRobot, CId, TipoError))
 *
 * NOTA: Los robots deben añadir al final de !execute_task:
 *   .my_name(Me); .send(scheduler, tell, task_complete(CId, Me)).
 ******************************************************************************/

/* ============================================================================
 * CREENCIAS INICIALES
 * ============================================================================ */

/* Capacidades de cada robot: robot_capacity(Nombre, MaxPeso_kg, MaxAncho, MaxAlto, Velocidad) */
robot_capacity(robot_light,  10,  1, 1, 3).
robot_capacity(robot_medium, 30,  1, 2, 2).
robot_capacity(robot_heavy,  100, 2, 3, 1).

/* Estado de disponibilidad de los robots */
robot_status(robot_light,  idle).
robot_status(robot_medium, idle).
robot_status(robot_heavy,  idle).

/* Estadísticas internas */
stat_received(0).
stat_assigned(0).
stat_queued(0).
stat_errors(0).

/* ============================================================================
 * INICIALIZACIÓN
 * ============================================================================ */

!start.

+!start : true <-
    .print("[Scheduler] ============================================");
    .print("[Scheduler]  Sistema de planificación de tareas iniciado");
    .print("[Scheduler]  Prioridad: robot_light → robot_medium → robot_heavy");
    .print("[Scheduler] ============================================").


/* ============================================================================
 * PASO 1 — DETECCIÓN DE NUEVO CONTENEDOR
 *
 * El entorno (WarehouseArtifact) emite el percepto global new_container(CId)
 * cada vez que genera un nuevo contenedor en la zona de entrada.
 * El scheduler lo intercepta y solicita sus características.
 * ============================================================================ */

/* Nuevo contenedor que aún no está en la cola de pendientes */
+new_container(CId) : not pending(CId, _, _, _, _) <-
    ?stat_received(N); -stat_received(N); +stat_received(N+1);
    .print("[Scheduler] 📦 Nuevo contenedor detectado: ", CId);
    get_container_info(CId).

/* Si el mismo CId ya está en cola (puede ocurrir si el percepto persiste),
   ignorarlo para evitar doble procesamiento */
+new_container(CId) : pending(CId, _, _, _, _) <-
    true. /* ya gestionado */


/* ============================================================================
 * PASO 2 — RECIBIR INFORMACIÓN Y ENCOLAR
 *
 * La acción get_container_info(CId) añade al scheduler el percepto:
 *   container_info(CId, Ancho, Alto, Peso, Tipo)
 * Lo eliminamos de las creencias tras leerlo para evitar re-disparos.
 * ============================================================================ */

+container_info(CId, W, H, Weight, Type) : true <-
    -container_info(CId, W, H, Weight, Type);           /* limpiar percepto */
    .print("[Scheduler]   → Info: ", CId, " = ",
           Weight, "kg, tamaño ", W, "×", H, ", tipo: ", Type);
    +pending(CId, W, H, Weight, Type);                  /* añadir a cola */
    !try_assign_pending.                                 /* intentar asignar */


/* ============================================================================
 * PASO 3 — NOTIFICACIÓN DE ROBOT LIBRE (mensaje del robot)
 *
 * Cuando un robot completa su tarea envía:
 *   .send(scheduler, tell, task_complete(CId, NombreRobot))
 *
 * El scheduler actualiza su estado interno y relanza la asignación.
 * ============================================================================ */

+task_complete(CId, Robot)[source(_)] : true <-
    .print("[Scheduler] ✅ Robot libre: ", Robot, " completó tarea sobre ", CId);
    -robot_status(Robot, busy);
    +robot_status(Robot, idle);
    !try_assign_pending.                                 /* revisar cola */


/* ============================================================================
 * PASO 4 — CICLO DE ASIGNACIÓN
 *
 * Recorre todos los contenedores pendientes e intenta asignar cada uno.
 * Si un contenedor no puede asignarse ahora (todos los robots válidos ocupados)
 * se queda en la cola; se reintentará en el siguiente evento de liberación.
 * ============================================================================ */

/* Hay al menos un pendiente → intentar asignar y seguir revisando */
+!try_assign_pending : pending(CId, W, H, Weight, Type) <-
    !try_assign(CId, W, H, Weight, Type);
    !try_assign_pending.

/* No quedan pendientes → fin del ciclo */
+!try_assign_pending : not pending(_, _, _, _, _) <- true.


/* ============================================================================
 * PASO 5 — LÓGICA DE ASIGNACIÓN CON PRIORIDAD
 *
 *  Prioridad: robot_light (1º)  → robot_medium (2º)  → robot_heavy (3º)
 *
 *  Para cada contenedor se prueban los planes EN ORDEN:
 *
 *   CASO 1: robot_light puede manejar el contenedor (peso ≤ 10, tamaño 1×1)
 *           Y está libre  →  asignar a robot_light
 *
 *   CASO 2: El contexto del caso 1 falló (light no puede o está ocupado).
 *           robot_medium puede manejarlo Y está libre  →  asignar a robot_medium
 *
 *   CASO 3: Los contextos de los casos 1 y 2 fallaron.
 *           robot_heavy puede manejarlo Y está libre  →  asignar a robot_heavy
 *
 *   CASO 4: Ninguno disponible ahora  →  mantener en cola (se reintentará
 *           cuando algún robot envíe task_complete)
 *
 *  Explicación de por qué el orden implica prioridad correcta:
 *  - Jason prueba los planes en orden de aparición en el fichero.
 *  - Si el plan 1 dispara (contexto verdadero), los planes 2 y 3 no se evalúan.
 *  - Si light PUEDE manejar el peso/tamaño pero ESTÁ OCUPADO,
 *    el contexto del plan 1 falla (robot_status(robot_light, idle) es falso)
 *    → se pasa al plan 2, que comprueba medium. Esto implementa la escalada.
 * ============================================================================ */

/* --- CASO 1: robot_light puede y está libre --- */
+!try_assign(CId, W, H, Weight, Type) :
        robot_capacity(robot_light, MaxW, MaxWidth, MaxHeight, _) &
        Weight =< MaxW & W =< MaxWidth & H =< MaxHeight &
        robot_status(robot_light, idle) <-
    .print("[Scheduler] 🔵 Asignando ", CId, " a robot_light",
           "  (", Weight, "kg ≤ ", MaxW, "kg)");
    !do_assign(CId, W, H, Weight, Type, robot_light).

/* --- CASO 2: light no puede o está ocupado → probar medium --- */
+!try_assign(CId, W, H, Weight, Type) :
        robot_capacity(robot_medium, MaxW, MaxWidth, MaxHeight, _) &
        Weight =< MaxW & W =< MaxWidth & H =< MaxHeight &
        robot_status(robot_medium, idle) <-
    .print("[Scheduler] 🟡 Asignando ", CId, " a robot_medium",
           "  (light no disponible)");
    !do_assign(CId, W, H, Weight, Type, robot_medium).

/* --- CASO 3: light y medium no pueden o están ocupados → probar heavy --- */
+!try_assign(CId, W, H, Weight, Type) :
        robot_capacity(robot_heavy, MaxW, MaxWidth, MaxHeight, _) &
        Weight =< MaxW & W =< MaxWidth & H =< MaxHeight &
        robot_status(robot_heavy, idle) <-
    .print("[Scheduler] 🔴 Asignando ", CId, " a robot_heavy",
           "  (light/medium no disponibles)");
    !do_assign(CId, W, H, Weight, Type, robot_heavy).

/* --- CASO 4: Ningún robot disponible ahora → dejar en cola --- */
+!try_assign(CId, W, H, Weight, Type) : true <-
    .print("[Scheduler] ⏳ Sin robot disponible para ", CId,
           " (", Weight, "kg, ", W, "×", H, ") — en cola");
    ?stat_queued(N); -stat_queued(N); +stat_queued(N+1).


/* ============================================================================
 * PASO 6 — EJECUTAR LA ASIGNACIÓN
 *
 * Una vez elegido el robot:
 *   1. Buscar la mejor estantería libre (get_free_shelf)
 *   2. Leer el percepto free_shelf y limpiarlo
 *   3. Eliminar el contenedor de la cola de pendientes
 *   4. Marcar el robot como ocupado
 *   5. Enviar la tarea al robot mediante .send(Robot, tell, task(CId, ShelfId))
 *
 * Si no hay estantería disponible, get_free_shelf devuelve false (acción falla)
 * y se activa el plan de fallo -!do_assign, que mantiene el contenedor pendiente.
 * ============================================================================ */

+!do_assign(CId, W, H, Weight, Type, Robot) : true <-
    get_free_shelf(CId);                                /* puede fallar */
    ?free_shelf(CId, ShelfId);                          /* leer resultado */
    -free_shelf(CId, ShelfId);                          /* limpiar percepto */
    -pending(CId, W, H, Weight, Type);                  /* quitar de cola */
    -robot_status(Robot, idle);
    +robot_status(Robot, busy);
    .send(Robot, tell, task(CId, ShelfId));             /* asignar al robot */
    .print("[Scheduler] ✅ ASIGNADO: ", Robot,
           " transportará ", CId, " → ", ShelfId);
    ?stat_assigned(N); -stat_assigned(N); +stat_assigned(N+1).

/* Plan de fallo: no hay estantería libre en este momento */
-!do_assign(CId, W, H, Weight, Type, Robot) : true <-
    .print("[Scheduler] ⚠️  Sin estantería para ", CId,
           " — se reintentará cuando haya espacio").
    /* El contenedor permanece en pending; se reintentará con el próximo evento */


/* ============================================================================
 * MANEJO DE ERRORES NOTIFICADOS POR ROBOTS
 *
 * El robot envía:
 *   .send(scheduler, tell, robot_error(NombreRobot, CId, TipoError))
 *
 * El scheduler libera al robot y, si el contenedor sigue en la cola,
 * intenta reasignarlo a otro robot.
 * ============================================================================ */

/* Error con el contenedor aún en cola de pendientes → reintentar con otro robot */
+robot_error(Robot, CId, ErrorType)[source(_)] :
        pending(CId, W, H, Weight, Type) <-
    .print("[Scheduler] ❌ Error '", ErrorType, "' en ", Robot,
           " con ", CId, " — liberando robot y reintentando");
    ?stat_errors(N); -stat_errors(N); +stat_errors(N+1);
    -robot_status(Robot, busy);
    +robot_status(Robot, idle);
    !try_assign(CId, W, H, Weight, Type).

/* Error pero el contenedor ya fue eliminado de la cola (raro) */
+robot_error(Robot, CId, ErrorType)[source(_)] :
        not pending(CId, _, _, _, _) <-
    .print("[Scheduler] ❌ Error '", ErrorType, "' en ", Robot,
           " con ", CId, " — contenedor ya no está en cola");
    ?stat_errors(N); -stat_errors(N); +stat_errors(N+1);
    -robot_status(Robot, busy);
    +robot_status(Robot, idle);
    !try_assign_pending.                                /* revisar cola igualmente */


/* ============================================================================
 * UTILIDAD: IMPRIMIR ESTADO DEL SCHEDULER
 *
 * Los robots (u otros agentes) pueden solicitar un resumen enviando:
 *   .send(scheduler, achieve, print_status)
 * ============================================================================ */

+!print_status : true <-
    ?stat_received(R);
    ?stat_assigned(A);
    ?stat_queued(Q);
    ?stat_errors(E);
    ?robot_status(robot_light,  SL);
    ?robot_status(robot_medium, SM);
    ?robot_status(robot_heavy,  SH);
    .print("[Scheduler] ── Estado del sistema ──────────────────");
    .print("[Scheduler]  Contenedores recibidos : ", R);
    .print("[Scheduler]  Tareas asignadas       : ", A);
    .print("[Scheduler]  Entradas en cola       : ", Q);
    .print("[Scheduler]  Errores gestionados    : ", E);
    .print("[Scheduler]  robot_light  → ", SL);
    .print("[Scheduler]  robot_medium → ", SM);
    .print("[Scheduler]  robot_heavy  → ", SH);
    .print("[Scheduler] ─────────────────────────────────────────").