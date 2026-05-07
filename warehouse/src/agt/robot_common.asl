/*******************************************************************************
 * ROBOT COMMON - Logica compartida por todos los robots (herencia)
 *
 * Universidad de Vigo - Sistemas Inteligentes
 * Curso 2025-2026
 *
 * Cada robot especifico (light/medium/heavy) hace { include("robot_common.asl") }
 * y define solo sus particularidades:
 *   - position(X,Y), base(X,Y)
 *   - step_wait(MS)         ms de espera segun velocidad
 *   - my_capacity(MW,W,H)   peso y dimensiones maximas (para ask a peers)
 *   - default_shelf("..")   estanteria por defecto
 ******************************************************************************/

/* Estado inicial comun */
state(idle).
returning(no).

/* Declaracion de celdas de las estanterias */
shelf_cell(10,2). shelf_cell(11,2). shelf_cell(10,3). shelf_cell(11,3).
shelf_cell(12,2). shelf_cell(13,2). shelf_cell(12,3). shelf_cell(13,3).
shelf_cell(14,2). shelf_cell(15,2). shelf_cell(14,3). shelf_cell(15,3).
shelf_cell(16,2). shelf_cell(17,2). shelf_cell(16,3). shelf_cell(17,3).
shelf_cell(10,6). shelf_cell(11,6). shelf_cell(12,6).
shelf_cell(10,7). shelf_cell(11,7). shelf_cell(12,7).
shelf_cell(13,6). shelf_cell(14,6). shelf_cell(15,6).
shelf_cell(13,7). shelf_cell(14,7). shelf_cell(15,7).
shelf_cell(16,6). shelf_cell(17,6). shelf_cell(18,6).
shelf_cell(16,7). shelf_cell(17,7). shelf_cell(18,7).
shelf_cell(10,10). shelf_cell(11,10). shelf_cell(12,10). shelf_cell(13,10).
shelf_cell(10,11). shelf_cell(11,11). shelf_cell(12,11). shelf_cell(13,11).
shelf_cell(10,12). shelf_cell(11,12). shelf_cell(12,12). shelf_cell(13,12).
shelf_cell(14,10). shelf_cell(15,10). shelf_cell(16,10). shelf_cell(17,10).
shelf_cell(14,11). shelf_cell(15,11). shelf_cell(16,11). shelf_cell(17,11).
shelf_cell(14,12). shelf_cell(15,12). shelf_cell(16,12). shelf_cell(17,12).

/* Definición de Zonas Especiales (para evitar tráfico) */
// Salida: (0,0) a (2,1)
is_exit_zone(X,Y) :- X >= 0 & X <= 2 & Y >= 0 & Y <= 1.
// Clasificación: (3,0) a (4,1)
is_class_zone(X,Y) :- X >= 3 & X <= 4 & Y >= 0 & Y <= 1.
// Entrada: (5,0) a (7,1)
is_entry_zone(X,Y) :- X >= 5 & X <= 7 & Y >= 0 & Y <= 1.

/* Bloqueo por estanterias, bordes y zonas de trabajo */
blocked(X,Y) :- shelf_cell(X,Y).

/* Bloqueo de bordes del mapa (0-19 en X, 0-14 en Y) */
blocked(X,Y) :- X < 0 | X >= 20 | Y < 0 | Y >= 15.

/* NUEVA REGLA: Zona prohibida desde (0,0) hasta (6,0) */
/* Nota: Si quieres que no pisen la fila 0 desde la columna 0 a la 6: */
blocked(X,Y) :- X >= 0 & X <= 6 & Y == 0.
blocked(X,Y) :- X >= 0 & X <= 7 & Y == 1.


/* REGLA CRÍTICA: Los robots solo pueden entrar en las zonas de trabajo... */
// (Aquí sigue el resto de tu código...)

/* REGLA CRÍTICA: Los robots solo pueden entrar en las zonas de trabajo 
   si tienen una tarea asignada. Si no, se consideran bloqueadas para navegación general.
*/
blocked(X,Y) :- is_exit_zone(X,Y) & not state(busy).
blocked(X,Y) :- is_class_zone(X,Y) & not state(busy).

/* Una celda está bloqueada si tiene CUALQUIER contenedor (incluido el mío) */
container_blocked(X,Y) :- container_at(_, X, Y).

/* Celda transitable: Suelo vacío, sin estanterías ni contenedores de ningún tipo */
walkable(X,Y) :- not blocked(X,Y) & not container_blocked(X,Y).




/* REGLA CRÍTICA: Los robots solo pueden entrar en las zonas de trabajo 
   si tienen una tarea asignada. Si no, se consideran bloqueadas para navegación general.
*/
blocked(X,Y) :- is_exit_zone(X,Y) & not state(busy).
blocked(X,Y) :- is_class_zone(X,Y) & not state(busy).

/* Una celda está bloqueada si tiene CUALQUIER contenedor (incluido el mío) */
container_blocked(X,Y) :- container_at(_, X, Y).

/* Celda transitable: Suelo vacío, sin estanterías ni contenedores de ningún tipo */
walkable(X,Y) :- not blocked(X,Y) & not container_blocked(X,Y).


/* ============================================================================
   INICIO Y BUCLE PRINCIPAL (Corregido)
   ============================================================================ */

!start.

+!start <- .my_name(Me); .print("[", Me, "] Iniciado autónomamente");!main_loop.

// Caso 1: Está libre y NO está en su base -> Vuelve un paso y chequea
+!main_loop : state(idle) & base(BX, BY) & not position(BX, BY) <-
    !return_step;
    !check_for_tasks; 
    .wait(300);
    !main_loop.

// Caso 2: Está libre y YA está en su base -> Espera y chequea
+!main_loop : state(idle) <-
    !check_for_tasks;
    .wait(1000);
    !main_loop.

// Caso 3: Está ocupado -> Espera a que termine la tarea
+!main_loop : state(busy) <- 
    .wait(1000); 
    !main_loop.

/* ============================================================================
   LÓGICA DE AUTONOMÍA
   ============================================================================ */
/* ============================================================================
    LÓGICA DE PRIORIDAD Y ASIGNACIÓN
   ============================================================================ */

+!check_for_tasks : pending_container(CId, W, H, Weight, Type)[source(scheduler)] <-
    // 1. Calculamos un retraso basado en nuestra capacidad (Prioridad)
    ?my_capacity(MaxWeight, _, _);
    
    // Jerarquía: Light (0ms) < Medium (400ms) < Heavy (800ms)
    if (MaxWeight <= 10) { 
        Delay = 0; 
    } else { 
        if (MaxWeight <= 30) { Delay = 400; }
        else { Delay = 800; }
    }
    
    .wait(Delay);
    
    // 2. Tras la espera, comprobamos si el paquete SIGUE disponible
    // Si un robot más pequeño lo tomó, ya no existirá la creencia.
    if (pending_container(CId, W, H, Weight, Type)) {
        !intentar_tomar_tarea(CId, W, H, Weight, Type);
    }.

+!check_for_tasks <- true.

+!intentar_tomar_tarea(CId, W, H, Weight, Type) : state(idle) <-
    ?my_capacity(MaxW, MaxH, MaxV);
    if (Weight <= MaxW) {
        // --- BLOQUEO DE TAREA ---
        // 1. Borramos de nuestra mente para no entrar en bucle
        -pending_container(CId, W, H, Weight, Type)[source(scheduler)];
        
        // 2. AVISO A OTROS ROBOTS: Borradlo de vuestra mente inmediatamente
        .broadcast(untell, pending_container(CId, W, H, Weight, Type));
        
        // 3. AVISO AL SCHEDULER: Deja de anunciar este contenedor
        .send(scheduler, untell, pending_container(CId, W, H, Weight, Type));

        .print("He ganado la prioridad para el contenedor: ", CId);
        
        -+state(busy);
        !decidir_estanteria(Type, ShelfId);
        !execute_task(CId, ShelfId);
    }.
    // Si es urgente, va a la estantería 1
+!decidir_estanteria("urgent", "shelf_1").

// Si es standard o fragile, va a la estantería 2 (o la que tú decidas)
+!decidir_estanteria("standard", "shelf_2").
+!decidir_estanteria("fragile", "shelf_2").

// Plan genérico por si llega un tipo desconocido (evita que el robot se bloquee)
+!decidir_estanteria(CualquierTipo, "shelf_2") : true.


/* ============================================================================
   EJECUCIÓN DE TAREA (ÚNICO Y LIMPIO)
   ============================================================================ */

+!execute_task(CId, ShelfId) <-
    +current_container(CId);
    +target_shelf(ShelfId);
    
    .print("Yendo a zona de ENTRADA (5,0)...");
    !go(5,0); 
    
    get_container_info(CId); .wait(400); // Un poco más de tiempo para percibir
    ?container_at(CId, CX, CY);
    
    .print("Recogiendo ", CId, " en ", CX, ",", CY);
    !go_adjacent(CX, CY);
    pickup(CId);
    .wait(200);
    
    .print("Llevando a estantería: ", ShelfId);
    !get_shelf_dest(ShelfId, SX, SY);
    !go(SX, SY);
    drop_at(ShelfId);
    
    .print("Tarea finalizada con éxito.");
    .send(scheduler, tell, task_complete(CId, .my_name));
    
    -current_container(CId);
    -target_shelf(ShelfId);
    -+state(idle).
/* ... (Aquí añade tus planes de navegación !go, !go_adjacent, !do_step y !get_shelf_dest que ya tenías) ... */
/* --- 1. Adyacencia sin usar .abs (evita el error de carga) --- */
+!go_adjacent(CX, CY) : position(MX, MY) & ( (MX == CX & (MY == CY+1 | MY == CY-1)) | (MY == CY & (MX == CX+1 | MX == CX-1)) ) <- 
    .print("Ya estoy en posición adyacente para recoger.");
    true.

/* --- 2. Modificación de la navegación para ser más robusta --- */
// Si el plan go_adjacent falla en el test de adyacencia, intentamos movernos
+!go_adjacent(CX, CY) <-
    // Intentamos ir a una de las 4 celdas adyacentes al contenedor
    if (walkable(CX, CY+1)) { !go(CX, CY+1); }
    else { if (walkable(CX, CY-1)) { !go(CX, CY-1); }
    else { if (walkable(CX+1, CY)) { !go(CX+1, CY); }
    else { if (walkable(CX-1, CY)) { !go(CX-1, CY); }
    else { .wait(500); !go_adjacent(CX, CY); }}}} .

/* --- 3. REGLAS DE BLOQUEO (Relajadas para permitir el inicio) --- */
// Es mejor que el robot SIEMPRE pueda caminar por las zonas de trabajo 
// pero que el Scheduler no lo mande allí a descansar.
// Borra o comenta las reglas de "blocked" basadas en state(busy) si el robot se queda congelado.

/* ============================================================================
 * NAVEGACION
 * ============================================================================ */

+!go(TX, TY) : position(TX, TY) <- true.

+!go(TX, TY) : position(MX, MY) & MY < TY & walkable(MX, MY+1) <-
    !do_step(MX, MY+1, TX, TY).
+!go(TX, TY) : position(MX, MY) & MY > TY & walkable(MX, MY-1) <-
    !do_step(MX, MY-1, TX, TY).
+!go(TX, TY) : position(MX, MY) & MX < TX & walkable(MX+1, MY) <-
    !do_step(MX+1, MY, TX, TY).
+!go(TX, TY) : position(MX, MY) & MX > TX & walkable(MX-1, MY) <-
    !do_step(MX-1, MY, TX, TY).

+!go(TX, TY) : position(MX, MY) & MY \== TY & walkable(MX-1, MY) <-
    !do_step(MX-1, MY, TX, TY).
+!go(TX, TY) : position(MX, MY) & MY \== TY & walkable(MX+1, MY) <-
    !do_step(MX+1, MY, TX, TY).
+!go(TX, TY) : position(MX, MY) & MX \== TX & walkable(MX, MY-1) <-
    !do_step(MX, MY-1, TX, TY).
+!go(TX, TY) : position(MX, MY) & MX \== TX & walkable(MX, MY+1) <-
    !do_step(MX, MY+1, TX, TY).

+!go(TX, TY) : position(MX, MY) & walkable(MX, MY-1) <-
    !do_step(MX, MY-1, TX, TY).
+!go(TX, TY) : position(MX, MY) & walkable(MX, MY+1) <-
    !do_step(MX, MY+1, TX, TY).
+!go(TX, TY) : position(MX, MY) & walkable(MX-1, MY) <-
    !do_step(MX-1, MY, TX, TY).
+!go(TX, TY) : position(MX, MY) & walkable(MX+1, MY) <-
    !do_step(MX+1, MY, TX, TY).

+!go(TX, TY) <- .wait(1000); !go(TX, TY).


/* ============================================================================
 * PASOS
 * ============================================================================ */

+!do_step(NX, NY, TX, TY) <-
    ?step_wait(W); move_to(NX, NY); .wait(W); -+position(NX, NY); !go(TX, TY).

-!do_step(NX, NY, TX, TY) <-
    .wait(500); ?position(MX, MY); !retry_step(NX, NY, TX, TY, MX, MY).

+!retry_step(NX, NY, TX, TY, MX, MY) <-
    ?step_wait(W); move_to(NX, NY); .wait(W); -+position(NX, NY); !go(TX, TY).

-!retry_step(NX, NY, TX, TY, MX, MY) : NX \== MX & MY > 0 & walkable(MX, MY-1) <-
    ?step_wait(W); move_to(MX, MY-1); .wait(W); -+position(MX, MY-1); !go(TX, TY).
-!retry_step(NX, NY, TX, TY, MX, MY) : NX \== MX & walkable(MX, MY+1) <-
    ?step_wait(W); move_to(MX, MY+1); .wait(W); -+position(MX, MY+1); !go(TX, TY).
-!retry_step(NX, NY, TX, TY, MX, MY) : NY \== MY & walkable(MX-1, MY) <-
    ?step_wait(W); move_to(MX-1, MY); .wait(W); -+position(MX-1, MY); !go(TX, TY).
-!retry_step(NX, NY, TX, TY, MX, MY) : NY \== MY & walkable(MX+1, MY) <-
    ?step_wait(W); move_to(MX+1, MY); .wait(W); -+position(MX+1, MY); !go(TX, TY).
-!retry_step(NX, NY, TX, TY, MX, MY) <-
    .wait(1500); !go(TX, TY).


/* ============================================================================
 * DESTINOS OBJETIVO ESTANTERIAS (celdas adyacentes; el drop ahora admite
 * todo el contorno de la estanteria, asi que estas son referencia)
 * ============================================================================ */

+!get_shelf_dest("shelf_1", 10, 1).
+!get_shelf_dest("shelf_2", 12, 1).
+!get_shelf_dest("shelf_3", 14, 1).
+!get_shelf_dest("shelf_4", 16, 1).
+!get_shelf_dest("shelf_5", 10, 5).
+!get_shelf_dest("shelf_6", 13, 5).
+!get_shelf_dest("shelf_7", 16, 5).
+!get_shelf_dest("shelf_8", 10, 9).
+!get_shelf_dest("shelf_9", 14, 9).
+!get_shelf_dest(_, X, Y) : default_shelf(D) <- !get_shelf_dest(D, X, Y).

+robot_at(X,Y) <- -+position(X,Y).


/* ============================================================================
 * CONSULTA A OTROS ROBOTS (ASK con sus particularidades)
 *
 * Cuando un robot no puede manejar un contenedor consulta las capacidades
 * del resto via .send(askOne, my_capacity(_,_,_), ...). Cada robot publica
 * su my_capacity en su fichero especifico.
 * ============================================================================ */

+!ask_peers <-
    .my_name(Me);
    !ask_one_peer(robot_light,  Me);
    !ask_one_peer(robot_medium, Me);
    !ask_one_peer(robot_heavy,  Me).

/* No preguntar a uno mismo */
+!ask_one_peer(Peer, Me) : Peer == Me <- true.

+!ask_one_peer(Peer, Me) : Peer \== Me <-
    .send(Peer, askOne, my_capacity(_,_,_), my_capacity(MW,MWd,MHt), 1500);
    -+peer_capacity(Peer, MW, MWd, MHt);
    .print("[", Me, "] ", Peer, " capacidad: peso=", MW, ", ", MWd, "x", MHt).
-!ask_one_peer(_, _) <- true.


/* ============================================================================
 * MANEJO DE ERRORES (con consulta previa a peers)
 * ============================================================================ */

+error(container_too_heavy, _) : state(busy) <-
    .my_name(Me); ?current_container(CId); ?target_shelf(Sh);
    !ask_peers;
    .send(scheduler, tell, robot_error(Me, CId, container_too_heavy));
    -+state(idle); -current_container(CId); -target_shelf(Sh).

+error(container_too_big, _) : state(busy) <-
    .my_name(Me); ?current_container(CId); ?target_shelf(Sh);
    !ask_peers;
    .send(scheduler, tell, robot_error(Me, CId, container_too_big));
    -+state(idle); -current_container(CId); -target_shelf(Sh).

+error(too_far, _) : state(busy) <-
    .wait(300); ?current_container(CId); ?target_shelf(Sh);
    !execute_task(CId, Sh).

+error(conflict, _) <- true.
+error(route_blocked, _) <- true.
+error(container_blocking, _) <- .wait(300).

+error(shelf_full, _) : state(busy) <-
    .my_name(Me); ?current_container(CId); ?target_shelf(Sh);
    .send(scheduler, tell, robot_error(Me, CId, shelf_full));
    -+state(idle); -current_container(CId); -target_shelf(Sh).

+error(Tipo, _) <-
    .my_name(Me); .send(scheduler, tell, robot_error(Me, none, Tipo));
    -+state(idle).

-!execute_task(CId, ShelfId) <-
    .my_name(Me);
    .print("[", Me, "] FALLO ", CId);
    .send(scheduler, tell, robot_error(Me, CId, execution_failed));
    -+state(idle); -current_container(CId); -target_shelf(ShelfId).