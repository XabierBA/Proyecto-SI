/*******************************************************************************
 * ROBOT MEDIUM - Robot mediano (30kg, 1×2)
 *
 * CARACTERÍSTICAS:
 *   - Capacidad: 30 kg
 *   - Tamaño máximo: 1×2
 *   - Velocidad: Media (2)
 *   - Color GUI: Azul
 ******************************************************************************/

/* ============================================================================
 * CREENCIAS INICIALES
 * ============================================================================ */

state(idle).
position(2, 3).          /* posición inicial en la GUI */
robot_type(medium).
max_weight(30).
max_width(1).
max_height(2).

/* ============================================================================
 * INICIALIZACIÓN
 * ============================================================================ */

+!start : true <-
    .print("[Robot-Medium] ============================================");
    .print("[Robot-Medium] Robot mediano iniciado");
    .print("[Robot-Medium] Capacidad: 30kg, Tamaño: 1×2");
    .print("[Robot-Medium] Posición inicial: (2,3)");
    .print("[Robot-Medium] ============================================");
    !main_loop.

/* ============================================================================
 * CICLO PRINCIPAL
 * ============================================================================ */

+!main_loop : state(idle) <-
    .print("[Robot-Medium] 📡 Solicitando tarea...");
    request_task();
    .wait(2000);
    !main_loop.

+!main_loop : state(busy) <-
    .print("[Robot-Medium] 🏃‍♂️ Ocupado, trabajando...");
    .wait(2000);
    !main_loop.

/* ============================================================================
 * RECEPCIÓN Y EJECUCIÓN DE TAREAS
 * ============================================================================ */

+task(ContainerId, ShelfId)[source(scheduler)] : state(idle) <-
    .print("[Robot-Medium] 📦 Tarea recibida: ", ContainerId, " → ", ShelfId);
    -+state(busy);
    +current_container(ContainerId);
    +current_shelf(ShelfId);
    !execute_task(ContainerId, ShelfId).

+!execute_task(ContainerId, ShelfId) : true <-
    .print("[Robot-Medium] 🚀 Ejecutando tarea para ", ContainerId);
    
    get_container_info(ContainerId);
    .wait(500);
    
    .print("[Robot-Medium] 📍 Objetivo: estantería ", ShelfId);
    
    .print("[Robot-Medium] 🚶 Moviéndose a zona de entrada...");
    move_to(1, 1);
    .wait(1000);
    
    .print("[Robot-Medium] 🎯 Recogiendo ", ContainerId);
    pickup(ContainerId);
    .wait(1000);
    
    .print("[Robot-Medium] 🚶 Moviéndose a estantería ", ShelfId);
    move_to(12, 5);
    .wait(1000);
    
    .print("[Robot-Medium] 📦 Depositando en ", ShelfId);
    drop_at(ShelfId);
    .wait(1000);
    
    .my_name(Me);
    .send(scheduler, tell, task_complete(ContainerId, Me));
    
    .print("[Robot-Medium] ✅ Tarea completada: ", ContainerId);
    -+state(idle);
    -current_container(ContainerId);
    -current_shelf(ShelfId).

/* ============================================================================
 * ACTUALIZACIÓN DE POSICIÓN
 * ============================================================================ */

+robot_at(X, Y) : true <-
    -+position(X, Y);
    .print("[Robot-Medium] 📍 Posición actualizada: (", X, ",", Y, ")").

/* ============================================================================
 * MANEJO DE ERRORES
 * ============================================================================ */

+error(ErrorType, Data) : state(busy) <-
    .print("[Robot-Medium] ❌ ERROR: ", ErrorType, " - ", Data);
    .my_name(Me);
    ?current_container(CId);
    .send(scheduler, tell, robot_error(Me, CId, ErrorType));
    -+state(idle);
    -current_container(CId);
    -current_shelf(_).

+error(ErrorType, Data) : state(idle) <-
    .print("[Robot-Medium] ❌ ERROR (idle): ", ErrorType, " - ", Data);
    .my_name(Me);
    .send(scheduler, tell, robot_error(Me, "none", ErrorType)).

+container_info(CId, W, H, Weight, Type) : true <-
    .print("[Robot-Medium] 📊 Info ", CId, ": ", Weight, "kg, ", W, "x", H, ", ", Type).