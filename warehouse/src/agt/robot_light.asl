/*******************************************************************************
 * ROBOT LIGERO - Base (1,4)
 * Capacidad: 10kg, 1x1, Velocidad Alta
 *
 * PATHFINDING DINAMICO CON DIAGONAL Y EVITA SHELF:
 *   !move_step(CX,CY,TX,TY,Attempt) calcula el siguiente paso.
 *   !try_move(NX,NY,NextAttempt) comprueba si la celda es transitable:
 *     - Si libre (no SHELF, no robot): se mueve
 *     - Si ocupada: llama al siguiente intento
 *   Orden: 0=diagonal, 1=eje dominante, 2=secundario,
 *          3=lateral+, 4=lateral-, 5=atras, 6=esperar(300ms)
 ******************************************************************************/

state(idle).
pos(1, 4).
carrying(none).
current_task(none, none).

shelf_front("shelf_1", 10, 4).
shelf_front("shelf_2", 12, 4).
shelf_front("shelf_3", 14, 4).
shelf_front("shelf_4", 16, 4).
shelf_front("shelf_5", 10, 5).
shelf_front("shelf_6", 13, 5).
shelf_front("shelf_7", 16, 5).
shelf_front("shelf_8", 10, 9).
shelf_front("shelf_9", 14, 9).

!start.
+!start : true <-
    .print("[Light] Iniciado en (1,4). Diagonal + evita SHELF.");
    !work_cycle.

+!work_cycle : state(idle) <-
    request_task; .wait(2000); !work_cycle.
+!work_cycle : not state(idle) <-
    .wait(500); !work_cycle.

+task(CId, ShelfId) : state(idle) <-
    .print("[Light] Tarea: ", CId, " -> ", ShelfId);
    -+state(working); -+carrying(CId); -+current_task(CId, ShelfId);
    .send(scheduler, tell, task_assigned(CId, robot_light, ShelfId));
    !execute_task(CId, ShelfId).
+task(CId, ShelfId) : not state(idle) <- true.

+container_size(CId, W, H, Wt, Type) : true <-
    .print("[Light] Contenedor ", CId, ": ", W, "x", H, " ", Wt, "kg (", Type, ")").

+!execute_task(CId, ShelfId) : true <-
    -+state(moving);
    !navigate_to(1, 1);
    -+state(picking);
    pickup(CId); .wait(200);
    -+state(carrying);
    ?shelf_front(ShelfId, FX, FY);
    !navigate_to(FX, FY);
    -+state(dropping);
    drop_at(ShelfId); .wait(200);
    -+state(moving);
    !navigate_to(1, 4);
    -+state(idle); -+carrying(none); -+current_task(none, none);
    -task(CId, ShelfId);
    .send(scheduler, tell, task_done(CId, robot_light)).

-!execute_task(CId, ShelfId) : true <-
    .print("[Light] Fallo en tarea ", CId);
    -+state(idle); -+carrying(none); -+current_task(none, none);
    -task(CId, ShelfId).

/* ============================================================
 * NAVEGACION DINAMICA
 * ============================================================ */
+!navigate_to(TX, TY) : pos(TX, TY) <- true.
+!navigate_to(TX, TY) : pos(CX, CY) <-
    !move_step(CX, CY, TX, TY, 0);
    .wait(130);
    !navigate_to(TX, TY).

/* try_move: intenta moverse a (NX,NY). Si la celda es transitable se mueve,
   si no llama al siguiente intento (NextAttempt) de move_step */

/* Celda transitable: dentro de limites, no SHELF, no otro robot */
+!try_move(NX, NY, CX, CY, TX, TY, _) :
        NX >= 0 & NX < 20 & NY >= 0 & NY < 15 &
        not (NX >= 10 & NX <= 17 & NY >= 2 & NY <= 3) &
        not (NX >= 10 & NX <= 18 & NY >= 6 & NY <= 7) &
        not (NX >= 10 & NX <= 17 & NY >= 10 & NY <= 12) &
        not other_pos(_, NX, NY) <-
    !do_move(NX, NY).

/* Celda no transitable: probar siguiente alternativa */
+!try_move(_, _, CX, CY, TX, TY, NextAttempt) : true <-
    !move_step(CX, CY, TX, TY, NextAttempt).

/* ---- Intento 0: diagonal ---- */
+!move_step(CX, CY, TX, TY, 0) : TX \== CX & TY \== CY <-
    if (TX > CX) { DX = 1 } else { DX = -1 };
    if (TY > CY) { DY = 1 } else { DY = -1 };
    NX = CX + DX; NY = CY + DY;
    !try_move(NX, NY, CX, CY, TX, TY, 1).

+!move_step(CX, CY, TX, TY, 0) : true <-
    !move_step(CX, CY, TX, TY, 1).

/* ---- Intento 1: eje dominante ---- */
+!move_step(CX, CY, TX, TY, 1) : true <-
    AbsDX = math.abs(TX - CX);
    AbsDY = math.abs(TY - CY);
    if (AbsDX >= AbsDY) {
        if (TX > CX)   { NX = CX+1; NY = CY }
        elif (TX < CX) { NX = CX-1; NY = CY }
        elif (TY > CY) { NX = CX;   NY = CY+1 }
        else           { NX = CX;   NY = CY-1 }
    } else {
        if (TY > CY)   { NX = CX;   NY = CY+1 }
        elif (TY < CY) { NX = CX;   NY = CY-1 }
        elif (TX > CX) { NX = CX+1; NY = CY }
        else           { NX = CX-1; NY = CY }
    };
    !try_move(NX, NY, CX, CY, TX, TY, 2).

/* ---- Intento 2: eje secundario ---- */
+!move_step(CX, CY, TX, TY, 2) : true <-
    AbsDX = math.abs(TX - CX);
    AbsDY = math.abs(TY - CY);
    if (AbsDX >= AbsDY) {
        if (TY > CY)   { NX = CX;   NY = CY+1 }
        elif (TY < CY) { NX = CX;   NY = CY-1 }
        else           { NX = CX;   NY = CY+1 }
    } else {
        if (TX > CX)   { NX = CX+1; NY = CY }
        elif (TX < CX) { NX = CX-1; NY = CY }
        else           { NX = CX+1; NY = CY }
    };
    !try_move(NX, NY, CX, CY, TX, TY, 3).

/* ---- Intento 3: lateral + ---- */
+!move_step(CX, CY, TX, TY, 3) : true <-
    AbsDX = math.abs(TX - CX);
    AbsDY = math.abs(TY - CY);
    if (AbsDX >= AbsDY) { NX = CX; NY = CY+1 }
    else                { NX = CX+1; NY = CY };
    !try_move(NX, NY, CX, CY, TX, TY, 4).

/* ---- Intento 4: lateral - ---- */
+!move_step(CX, CY, TX, TY, 4) : true <-
    AbsDX = math.abs(TX - CX);
    AbsDY = math.abs(TY - CY);
    if (AbsDX >= AbsDY) { NX = CX; NY = CY-1 }
    else                { NX = CX-1; NY = CY };
    !try_move(NX, NY, CX, CY, TX, TY, 5).

/* ---- Intento 5: paso atras ---- */
+!move_step(CX, CY, TX, TY, 5) : true <-
    AbsDX = math.abs(TX - CX);
    AbsDY = math.abs(TY - CY);
    if (AbsDX >= AbsDY) {
        if (TX > CX) { NX = CX-1; NY = CY } else { NX = CX+1; NY = CY }
    } else {
        if (TY > CY) { NX = CX; NY = CY-1 } else { NX = CX; NY = CY+1 }
    };
    !try_move(NX, NY, CX, CY, TX, TY, 6).

/* ---- Intento 6: todos bloqueados -> esperar (light: 300ms) ---- */
+!move_step(_, _, _, _, 6) : true <-
    .print("[Light] Bloqueado, esperando 300ms");
    .wait(300).

+!do_move(NX, NY) : true <- move_to(NX, NY); -+pos(NX, NY).
-!do_move(NX, NY) <- .wait(400); !do_move(NX, NY).

/* ====== ERRORES ====== */
+error(conflict, Data) : true <-
    .send(supervisor, tell, error_report(robot_light, conflict, Data)); .wait(300).
+error(container_too_heavy, Data) : current_task(CId, ShelfId) & CId \== none <-
    .send(supervisor, tell, error_report(robot_light, container_too_heavy, Data));
    .send(scheduler, tell, task_error(CId, robot_light, container_too_heavy));
    -+state(idle); -+carrying(none); -+current_task(none, none); -task(CId, ShelfId).
+error(container_too_big, Data) : current_task(CId, ShelfId) & CId \== none <-
    .send(supervisor, tell, error_report(robot_light, container_too_big, Data));
    .send(scheduler, tell, task_error(CId, robot_light, container_too_big));
    -+state(idle); -+carrying(none); -+current_task(none, none); -task(CId, ShelfId).
+error(shelf_full, Data) : current_task(CId, ShelfId) & CId \== none <-
    .send(supervisor, tell, error_report(robot_light, shelf_full, Data));
    .send(scheduler, tell, task_error(CId, robot_light, shelf_full));
    -+state(idle); -+carrying(none); -+current_task(none, none); -task(CId, ShelfId).
+error(illegal_move, Data) : true <-
    .send(supervisor, tell, error_report(robot_light, illegal_move, Data)); -+state(idle).
+error(route_blocked, Data) : true <-
    .send(supervisor, tell, error_report(robot_light, route_blocked, Data)); .wait(600).
+error(ErrorType, Data) : true <-
    .send(supervisor, tell, error_report(robot_light, ErrorType, Data)).

+picked(CId)          : true <- .print("[Light] Recogido: ", CId).
+stored(CId, ShelfId) : true <- .print("[Light] Almacenado ", CId, " en ", ShelfId).
+robot_at(X, Y)       : true <- -+pos(X, Y).
+blocked(X, Y)        : true <- .print("[Light] Celda bloqueada: (", X, ",", Y, ")").
