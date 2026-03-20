/*******************************************************************************
 * ROBOT LIGHT - Robot ligero (10kg, 1×1)
 *
 * Universidad de Vigo - Sistemas Inteligentes - Curso 2025-2026
 *
 * CARACTERÍSTICAS:
 *   - Capacidad: 10 kg
 *   - Tamaño máximo: 1×1
 *   - Velocidad: Alta (3)
 *   - Color GUI: Verde
 *
 * RESPONSABILIDADES:
 *   1. Mantener estado (idle/busy)
 *   2. Solicitar tareas cuando está idle
 *   3. Ejecutar tareas recibidas del scheduler
 *   4. Notificar al scheduler cuando completa una tarea
 *   5. Manejar errores y notificarlos
 ******************************************************************************/

/* ============================================================================
 * CREENCIAS INICIALES
 * ============================================================================ */

state(idle).
position(1, 3).          /* posición inicial en la GUI */
robot_type(light).
max_weight(10).
max_width(1).
max_height(1).

/* ============================================================================
 * INICIALIZACIÓN
 * ============================================================================ */

+!start : true <-
    .print("[Robot-Light] ============================================");
    .print("[Robot-Light] Robot ligero iniciado");
    .print("[Robot-Light] Capacidad: 10kg, Tamaño: 1x1");
    .print("[Robot-Light] Posición inicial: (1,3)");
    .print("[Robot-Light] ============================================");
    !main_loop.

/* ============================================================================
 * CICLO PRINCIPAL
 * ============================================================================ */

/* Estado idle → solicitar tarea */
+!main_loop : state(idle) <-
    .print("[Robot-Light] 📡 Solicitando tarea...");
    request_task();
    .wait(2000);                    /* esperar respuesta */
    !main_loop.

/* Estado busy → esperar mientras trabaja */
+!main_loop : state(busy) <-
    .print("[Robot-Light] 🏃‍♂️ Ocupado, trabajando...");
    .wait(2000);
    !main_loop.

/* ============================================================================
 * RECEPCIÓN Y EJECUCIÓN DE TAREAS
 * ============================================================================ */

/* Recibir nueva tarea del scheduler */
+task(ContainerId, ShelfId)[source(scheduler)] : state(idle) <-
    .print("[Robot-Light] 📦 Tarea recibida: ", ContainerId, " → ", ShelfId);
    -+state(busy);
    +current_container(ContainerId);
    +current_shelf(ShelfId);
    !execute_task(ContainerId, ShelfId).

/* Ejecutar tarea completa */
+!execute_task(ContainerId, ShelfId) : true <-
    .print("[Robot-Light] 🚀 Ejecutando tarea para ", ContainerId);
    
    /* Paso 1: Obtener información del contenedor */
    get_container_info(ContainerId);
    .wait(500);
    
    /* Paso 2: Obtener estantería libre (si no la tenemos) */
    // ShelfId ya viene en la tarea, pero podemos verificar si es válida
    .print("[Robot-Light] 📍 Objetivo: estantería ", ShelfId);
    
    /* Paso 3: Moverse al contenedor (zona de entrada) */
    .print("[Robot-Light] 🚶 Moviéndose a zona de entrada...");
    move_to(1, 1);                   /* posición estándar de contenedores */
    .wait(1000);
    
    /* Paso 4: Recoger contenedor */
    .print("[Robot-Light] 🎯 Recogiendo ", ContainerId);
    pickup(ContainerId);
    .wait(1000);
    
    /* Paso 5: Moverse a la estantería */
    .print("[Robot-Light] 🚶 Moviéndose a estantería ", ShelfId);
    // En una implementación real, necesitaríamos la posición de la estantería
    // Por ahora, movemos a una posición fija cerca de las estanterías
    move_to(12, 5);
    .wait(1000);
    
    /* Paso 6: Depositar contenedor */
    .print("[Robot-Light] 📦 Depositando en ", ShelfId);
    drop_at(ShelfId);
    .wait(1000);
    
    /* Paso 7: Notificar al scheduler que completó la tarea */
    .my_name(Me);
    .send(scheduler, tell, task_complete(ContainerId, Me));
    
    .print("[Robot-Light] ✅ Tarea completada: ", ContainerId);
    -+state(idle);
    -current_container(ContainerId);
    -current_shelf(ShelfId).

/* ============================================================================
 * ACTUALIZACIÓN DE POSICIÓN
 * ============================================================================ */

/* El entorno envía robot_at(X,Y) después de cada move_to */
+robot_at(X, Y) : true <-
    -+position(X, Y);
    .print("[Robot-Light] 📍 Posición actualizada: (", X, ",", Y, ")").

/* ============================================================================
 * MANEJO DE ERRORES
 * ============================================================================ */

/* Error del entorno */
+error(ErrorType, Data) : state(busy) <-
    .print("[Robot-Light] ❌ ERROR: ", ErrorType, " - ", Data);
    .my_name(Me);
    ?current_container(CId);
    .send(scheduler, tell, robot_error(Me, CId, ErrorType));
    -+state(idle);
    -current_container(CId);
    -current_shelf(_).

/* Error en estado idle (por si acaso) */
+error(ErrorType, Data) : state(idle) <-
    .print("[Robot-Light] ❌ ERROR (idle): ", ErrorType, " - ", Data);
    .my_name(Me);
    .send(scheduler, tell, robot_error(Me, "none", ErrorType)).

/* ============================================================================
 * INFORMACIÓN DE CONTENEDOR RECIBIDA
 * ============================================================================ */

+container_info(CId, W, H, Weight, Type) : true <-
    .print("[Robot-Light] 📊 Info ", CId, ": ", Weight, "kg, ", W, "x", H, ", ", Type).