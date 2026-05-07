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

/* Bloqueo por estanterias y bordes */
blocked(X,Y) :- shelf_cell(X,Y).
blocked(X,Y) :- X < 0.
blocked(X,Y) :- X >= 20.
blocked(X,Y) :- Y < 0.
blocked(X,Y) :- Y >= 15.

/* Una celda esta bloqueada para acercarse si tiene un contenedor en el suelo */
container_blocked(X,Y) :- container_at(_, X, Y).

/* Celda transitable: ni bloqueada por estanteria/borde ni con contenedor */
walkable(X,Y) :- not blocked(X,Y) & not container_blocked(X,Y).


/* ============================================================================
 * INICIO Y BUCLE PRINCIPAL
 * ============================================================================ */

!start.

+!start <-
    .my_name(Me);
    .print("[", Me, "] Iniciado");
    !main_loop.

+!main_loop : state(idle) & returning(no) & base(BX, BY) & not position(BX, BY) <-
    -+returning(yes); !return_step; !main_loop.

+!main_loop : state(idle) & returning(yes) & base(BX, BY) & not position(BX, BY) <-
    !return_step; !main_loop.

+!main_loop : state(idle) <-
    -+returning(no); .wait(1000); !main_loop.

+!main_loop : state(busy) <- .wait(500); !main_loop.


/* ============================================================================
 * RETORNO A BASE
 * ============================================================================ */

+!return_step : base(BX, BY) & position(BX, BY) <- -+returning(no).

+!return_step : base(BX, BY) & position(MX, MY) & MY < BY & walkable(MX, MY+1) <-
    ?step_wait(W); move_to(MX, MY+1); .wait(W); -+position(MX, MY+1).

+!return_step : base(BX, BY) & position(MX, MY) & MY > BY & walkable(MX, MY-1) <-
    ?step_wait(W); move_to(MX, MY-1); .wait(W); -+position(MX, MY-1).

+!return_step : base(BX, BY) & position(MX, MY) & MX < BX & walkable(MX+1, MY) <-
    ?step_wait(W); move_to(MX+1, MY); .wait(W); -+position(MX+1, MY).

+!return_step : base(BX, BY) & position(MX, MY) & MX > BX & walkable(MX-1, MY) <-
    ?step_wait(W); move_to(MX-1, MY); .wait(W); -+position(MX-1, MY).

+!return_step <- .wait(300).
-!return_step <- .wait(300).


/* ============================================================================
 * RECEPCION DE TAREAS
 * ============================================================================ */

+task(CId, ShelfId)[source(scheduler)] : state(idle) <-
    -+state(busy);
    -+returning(no);
    +current_container(CId);
    +target_shelf(ShelfId);
    !execute_task(CId, ShelfId).

+task(CId, ShelfId)[source(scheduler)] : state(busy) <-
    .my_name(Me);
    .send(scheduler, tell, robot_error(Me, CId, robot_busy)).

/* Ejecucion de la tarea: navega a CUALQUIER celda ortogonalmente contigua
 * libre del contenedor (no diagonal) y lo recoge. */
+!execute_task(CId, ShelfId) <-
    get_container_info(CId);
    .wait(100);
    ?container_at(CId, CX, CY);
    !go_adjacent(CX, CY);
    pickup(CId);
    .wait(100);
    !get_shelf_dest(ShelfId, SX, SY);
    !go(SX, SY);
    drop_at(ShelfId);
    .wait(100);
    .my_name(Me);
    .send(scheduler, tell, task_complete(CId, Me));
    .print("[", Me, "] ", CId, " -> ", ShelfId, " OK");
    -+state(idle);
    -current_container(CId);
    -target_shelf(ShelfId).

/* go_adjacent(CX,CY): ir a una celda ortogonalmente contigua a (CX,CY)
 * que sea transitable (ni estanteria/borde ni otro contenedor).
 * Se prueban abajo, derecha, izquierda y arriba en ese orden. */
+!go_adjacent(CX, CY) : walkable(CX, CY+1) <- !go(CX, CY+1).
+!go_adjacent(CX, CY) : walkable(CX+1, CY) <- !go(CX+1, CY).
+!go_adjacent(CX, CY) : walkable(CX-1, CY) <- !go(CX-1, CY).
+!go_adjacent(CX, CY) : walkable(CX, CY-1) <- !go(CX, CY-1).
/* Si todas estan ocupadas momentaneamente, esperar y reintentar */
+!go_adjacent(CX, CY) <- .wait(500); !go_adjacent(CX, CY).


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
