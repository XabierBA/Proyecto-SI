/*******************************************************************************
 * ROBOT HEAVY - Robot pesado (100kg, 2×3)
 *
 * CARACTERÍSTICAS:
 *   - Capacidad: 100 kg
 *   - Tamaño máximo: 2×3
 *   - Velocidad: Baja (1)
 *   - Color GUI: Magenta
 ******************************************************************************/

/* ============================================================================
 * CREENCIAS INICIALES
 * ============================================================================ */

state(idle).
position(3, 3).          /* posición inicial en la GUI */
robot_type(heavy).
max_weight(100).
max_width(2).
max_height(3).

/* ============================================================================
 * INICIALIZACIÓN
 * ============================================================================ */

+!start : true <-
    .print("[Robot-Heavy] ============================================");
    .print("[Robot-Heavy] Robot pesado iniciado");
    .print("[Robot-Heavy] Capacidad: 100kg, Tamaño: 2×3");
    .print("[Robot-Heavy] Posición inicial: (3,3)");
    .print("[Robot-Heavy] ============================================");
    !main_loop.

/* ============================================================================
 * CICLO PRINCIPAL
 * ============================================================================ */

+!main_loop : state(idle) <-
    .print("[Robot-Heavy] 📡 Solicitando tarea...");
    request_task();
    .wait(2000);
    !main_loop.

+!main_loop : state(busy) <-
    .print("[Robot-Heavy] 🏃‍♂️ Ocupado, trabajando...");
    .wait(2000);
    !main_loop.

/* ============================================================================
 * RECEPCIÓN Y EJECUCIÓN DE TAREAS
 * ============================================================================ */

+task(ContainerId, ShelfId)[source(scheduler)] : state(idle) <-
    .print("[Robot-Heavy] 📦 Tarea recibida: ", ContainerId, " → ", ShelfId);
    -+state(busy);
    +current_container(ContainerId);
    +current_shelf(ShelfId);
    !execute_task(ContainerId, ShelfId).

+!execute_task(ContainerId, ShelfId) : true <-
    .print("[Robot-Heavy] 🚀 Ejecutando tarea para ", ContainerId);
    
    get_container_info(ContainerId);
    .wait(500);
    
    .print("[Robot-Heavy] 📍 Objetivo: estantería ", ShelfId);
    
    .print("[Robot-Heavy] 🚶 Moviéndose a zona de entrada...");
    move_to(1, 1);
    .wait(1000);
    
    .print("[Robot-Heavy] 🎯 Recogiendo ", ContainerId);
    pickup(ContainerId);
    .wait(1000);
    
    .print("[Robot-Heavy] 🚶 Moviéndose a estantería ", ShelfId);
    move_to(12, 5);
    .wait(1000);
    
    .print("[Robot-Heavy] 📦 Depositando en ", ShelfId);
    drop_at(ShelfId);
    .wait(1000);
    
    .my_name(Me);
    .send(scheduler, tell, task_complete(ContainerId, Me));
    
    .print("[Robot-Heavy] ✅ Tarea completada: ", ContainerId);
    -+state(idle);
    -current_container(ContainerId);
    -current_shelf(ShelfId).

/* ============================================================================
 * ACTUALIZACIÓN DE POSICIÓN
 * ============================================================================ */

+robot_at(X, Y) : true <-
    -+position(X, Y);
    .print("[Robot-Heavy] 📍 Posición actualizada: (", X, ",", Y, ")").

/* ============================================================================
 * MANEJO DE ERRORES
 * ============================================================================ */

+error(ErrorType, Data) : state(busy) <-
    .print("[Robot-Heavy] ❌ ERROR: ", ErrorType, " - ", Data);
    .my_name(Me);
    ?current_container(CId);
    .send(scheduler, tell, robot_error(Me, CId, ErrorType));
    -+state(idle);
    -current_container(CId);
    -current_shelf(_).

+error(ErrorType, Data) : state(idle) <-
    .print("[Robot-Heavy] ❌ ERROR (idle): ", ErrorType, " - ", Data);
    .my_name(Me);
    .send(scheduler, tell, robot_error(Me, "none", ErrorType)).

+container_info(CId, W, H, Weight, Type) : true <-
    .print("[Robot-Heavy] 📊 Info ", CId, ": ", Weight, "kg, ", W, "x", H, ", ", Type).