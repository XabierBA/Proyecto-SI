/*******************************************************************************
 * ROBOT HEAVY - Sistema de Gestión Logística de Almacén
 * 
 * Universidad de Vigo - Sistemas Inteligentes
 * Curso 2025-2026
 * 
 * CAPACIDADES:
 *   - Peso máximo: 100 kg
 *   - Tamaño máximo: 2×3
 *   - Velocidad: Baja (1)
 * 
 ******************************************************************************/

/* Estado inicial del Robot */
state(idle).
position(3,3).
base(3,3).
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

/* Declaracion del bloqueo por estanterias y bordes */
blocked(X,Y) :- shelf_cell(X,Y).
blocked(X,Y) :- X < 0.
blocked(X,Y) :- X >= 20.
blocked(X,Y) :- Y < 0.
blocked(X,Y) :- Y >= 15.


/* ============================================================================
 * PLANES PRINCIPALES
 * ============================================================================ */

!start.

/* Iniciamos el robot */
+!start <-
    .print("[Robot-Heavy] Iniciado");
    !main_loop.

/* Idle y no en base: dar un paso hacia base */
+!main_loop : state(idle) & returning(no) & base(BX, BY) & not position(BX, BY) <-
    -+returning(yes);
    !return_step;
    !main_loop.

+!main_loop : state(idle) & returning(yes) & base(BX, BY) & not position(BX, BY) <-
    !return_step;
    !main_loop.

/* Idle y en base o volviendo: esperar */
+!main_loop : state(idle) <-
    -+returning(no);
    .wait(1000);
    !main_loop.

+!main_loop : state(busy) <- .wait(500); !main_loop.

/* ============================================================================
 * PLAN MOVIMIENTO ROBOT HACIA BASE
 * ============================================================================ */

/* Si ya está en base, detiene el retorno */
+!return_step : base(BX, BY) & position(BX, BY) <- -+returning(no).

/* Si la base está arriba y la celda superior no está bloqueada */
+!return_step : base(BX, BY) & position(MX, MY) & MY < BY & not blocked(MX, MY+1) <-
    move_to(MX, MY+1); .wait(500); -+position(MX, MY+1).

/* Si la base está abajo y la celda inferior no está bloqueada */
+!return_step : base(BX, BY) & position(MX, MY) & MY > BY & not blocked(MX, MY-1) <-
    move_to(MX, MY-1); .wait(500); -+position(MX, MY-1).

/* Si la base está a la derecha y la celda derecha no está bloqueada */
+!return_step : base(BX, BY) & position(MX, MY) & MX < BX & not blocked(MX+1, MY) <-
    move_to(MX+1, MY); .wait(500); -+position(MX+1, MY).

/* Si la base está a la izquierda y la celda izquierda no está bloqueada */
+!return_step : base(BX, BY) & position(MX, MY) & MX > BX & not blocked(MX-1, MY) <-
    move_to(MX-1, MY); .wait(500); -+position(MX-1, MY).

/* Paso bloqueado: esperar */
+!return_step <- .wait(300).
-!return_step <- .wait(300).


/* ============================================================================
 * MANEJO DE TAREAS ASIGNADAS
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

+!execute_task(CId, ShelfId) <-
    get_container_info(CId);
    .wait(100);
    ?position(PX, PY);
    !nudge_up(PX, PY);
    !go(1, 0);
    pickup(CId);
    .wait(100);
    !get_shelf_dest(ShelfId, SX, SY);
    !go(SX, SY);
    drop_at(ShelfId);
    .wait(100);
    .my_name(Me);
    .send(scheduler, tell, task_complete(CId, Me));
    .print("[Robot-Heavy] ", CId, " -> ", ShelfId, " OK");
    -+state(idle);
    -current_container(CId);
    -target_shelf(ShelfId).

+!nudge_up(X, 0) <- true.
+!nudge_up(X, Y) : Y > 0 & not blocked(X, Y-1) <-
    move_to(X, Y-1); .wait(500); -+position(X, Y-1).
-!nudge_up(X, Y) <- .wait(400); !nudge_up(X, Y).

/* ============================================================================
 * NAVEGACIÓN
 * ============================================================================ */

/* Si ya está en el destino, termina */
+!go(TX, TY) : position(TX, TY) <- true.

/* Si Y destino > Y actual y la celda superior no está bloqueada */
+!go(TX, TY) : position(MX, MY) & MY < TY & not blocked(MX, MY+1) <-
    !do_step(MX, MY+1, TX, TY).

/* Si Y destino < Y actual y la celda inferior no está bloqueada */
+!go(TX, TY) : position(MX, MY) & MY > TY & not blocked(MX, MY-1) <-
    !do_step(MX, MY-1, TX, TY).

/* Si X destino > X actual y la celda derecha no está bloqueada */
+!go(TX, TY) : position(MX, MY) & MX < TX & not blocked(MX+1, MY) <-
    !do_step(MX+1, MY, TX, TY).

/* Si X destino < X actual y la celda izquierda no está bloqueada */
+!go(TX, TY) : position(MX, MY) & MX > TX & not blocked(MX-1, MY) <-
    !do_step(MX-1, MY, TX, TY).

/* Movimiento alternativo: si Y no es destino, intentar izquierda */
+!go(TX, TY) : position(MX, MY) & MY \== TY & not blocked(MX-1, MY) <-
    !do_step(MX-1, MY, TX, TY).

/* Movimiento alternativo: si Y no es destino, intentar derecha */
+!go(TX, TY) : position(MX, MY) & MY \== TY & not blocked(MX+1, MY) <-
    !do_step(MX+1, MY, TX, TY).

/* Movimiento alternativo: si X no es destino, intentar abajo */
+!go(TX, TY) : position(MX, MY) & MX \== TX & not blocked(MX, MY-1) <-
    !do_step(MX, MY-1, TX, TY).

/* Movimiento alternativo: si X no es destino, intentar arriba */
+!go(TX, TY) : position(MX, MY) & MX \== TX & not blocked(MX, MY+1) <-
    !do_step(MX, MY+1, TX, TY).

/* Movimiento por defecto: intentar abajo */
+!go(TX, TY) : position(MX, MY) & not blocked(MX, MY-1) <-
    !do_step(MX, MY-1, TX, TY).

/* Movimiento por defecto: intentar arriba */
+!go(TX, TY) : position(MX, MY) & not blocked(MX, MY+1) <-
    !do_step(MX, MY+1, TX, TY).

/* Movimiento por defecto: intentar izquierda */
+!go(TX, TY) : position(MX, MY) & not blocked(MX-1, MY) <-
    !do_step(MX-1, MY, TX, TY).

/* Movimiento por defecto: intentar derecha */
+!go(TX, TY) : position(MX, MY) & not blocked(MX+1, MY) <-
    !do_step(MX+1, MY, TX, TY).

/* Si no hay movimiento posible, esperar y reintentar */
+!go(TX, TY) <- .wait(1000); !go(TX, TY).

/* ============================================================================
 * PASOS
 * ============================================================================ */

+!do_step(NX, NY, TX, TY) <-
    move_to(NX, NY); .wait(500); -+position(NX, NY); !go(TX, TY).

-!do_step(NX, NY, TX, TY) <-
    .wait(500); ?position(MX, MY); !retry_step(NX, NY, TX, TY, MX, MY).

+!retry_step(NX, NY, TX, TY, MX, MY) <-
    move_to(NX, NY); .wait(500); -+position(NX, NY); !go(TX, TY).

-!retry_step(NX, NY, TX, TY, MX, MY) : NX \== MX & MY > 0 & not blocked(MX, MY-1) <-
    move_to(MX, MY-1); .wait(500); -+position(MX, MY-1); !go(TX, TY).
-!retry_step(NX, NY, TX, TY, MX, MY) : NX \== MX & not blocked(MX, MY+1) <-
    move_to(MX, MY+1); .wait(500); -+position(MX, MY+1); !go(TX, TY).
-!retry_step(NX, NY, TX, TY, MX, MY) : NY \== MY & not blocked(MX-1, MY) <-
    move_to(MX-1, MY); .wait(500); -+position(MX-1, MY); !go(TX, TY).
-!retry_step(NX, NY, TX, TY, MX, MY) : NY \== MY & not blocked(MX+1, MY) <-
    move_to(MX+1, MY); .wait(500); -+position(MX+1, MY); !go(TX, TY).
-!retry_step(NX, NY, TX, TY, MX, MY) <-
    .wait(1500); !go(TX, TY).


/* ============================================================================
 * DESTINOS OBJETIVO ESTANTERIAS
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
+!get_shelf_dest(_, 10, 9).

+robot_at(X,Y) <- -+position(X,Y).


/* ============================================================================
 * MANEJO DE ERRORES
 * ============================================================================ */

+error(container_too_heavy, _) : state(busy) <-
    .my_name(Me); ?current_container(CId); ?target_shelf(Sh);
    .send(scheduler, tell, robot_error(Me, CId, container_too_heavy));
    -+state(idle); -current_container(CId); -target_shelf(Sh).

+error(container_too_big, _) : state(busy) <-
    .my_name(Me); ?current_container(CId); ?target_shelf(Sh);
    .send(scheduler, tell, robot_error(Me, CId, container_too_big));
    -+state(idle); -current_container(CId); -target_shelf(Sh).

+error(too_far, _) : state(busy) <-
    .wait(300); ?current_container(CId); ?target_shelf(Sh);
    !execute_task(CId, Sh).

+error(conflict, _) <- true.

+error(route_blocked, _) <- true.

+error(shelf_full, _) : state(busy) <-
    .my_name(Me); ?current_container(CId); ?target_shelf(Sh);
    .send(scheduler, tell, robot_error(Me, CId, shelf_full));
    -+state(idle); -current_container(CId); -target_shelf(Sh).

+error(Tipo, _) <-
    .my_name(Me); .send(scheduler, tell, robot_error(Me, none, Tipo));
    -+state(idle).

-!execute_task(CId, ShelfId) <-
    .print("[Robot-Heavy] FALLO ", CId);
    .my_name(Me);
    .send(scheduler, tell, robot_error(Me, CId, execution_failed));
    -+state(idle); -current_container(CId); -target_shelf(ShelfId).
