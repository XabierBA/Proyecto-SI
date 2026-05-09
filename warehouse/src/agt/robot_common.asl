/*******************************************************************************
 * ROBOT COMMON - Lógica Fusionada y Autónoma
 ******************************************************************************/

/* --- Estado inicial común --- */
state(idle).
returning(no).

/* --- Mapa de estanterías --- */
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

/* --- Definiciones de zona --- */
is_exit_zone(X,Y)  :- X >= 0 & X <= 2 & Y >= 0 & Y <= 1.
is_class_zone(X,Y) :- X >= 3 & X <= 4 & Y >= 0 & Y <= 1.
is_entry_zone(X,Y) :- X >= 5 & X <= 7 & Y >= 0 & Y <= 1.

/* --- Colisiones y tránsito --- */
blocked(X,Y) :- shelf_cell(X,Y).
blocked(X,Y) :- X < 0 | X >= 20 | Y < 0 | Y >= 15.
blocked(X,Y) :- X >= 0 & X <= 6 & Y == 0.
blocked(X,Y) :- X >= 0 & X <= 7 & Y == 1.
blocked(X,Y) :- is_exit_zone(X,Y)  & not state(busy).
blocked(X,Y) :- is_class_zone(X,Y) & not state(busy).
blocked(X,Y) :- is_entry_zone(X,Y) & not state(busy).

container_blocked(X,Y) :- container_at(_, X, Y).
walkable(X,Y) :- not blocked(X,Y) & not container_blocked(X,Y).

/* --- Configuración local de estanterías --- */
shelf_local("shelf_1", 50,  8).  shelf_local("shelf_2", 50,  8).
shelf_local("shelf_3", 50,  8).  shelf_local("shelf_4", 50,  8).
shelf_local("shelf_5", 100, 12). shelf_local("shelf_6", 100, 12).
shelf_local("shelf_7", 100, 12). shelf_local("shelf_8", 200, 20).
shelf_local("shelf_9", 200, 20).

/* S1, S5, S8 → urgentes | S2-S4, S6-S7, S9 → estándar y frágiles */
shelf_allows_type_local("shelf_1", "urgent").
shelf_allows_type_local("shelf_5", "urgent").
shelf_allows_type_local("shelf_8", "urgent").
shelf_allows_type_local("shelf_2", "standard"). shelf_allows_type_local("shelf_2", "fragile").
shelf_allows_type_local("shelf_3", "standard"). shelf_allows_type_local("shelf_3", "fragile").
shelf_allows_type_local("shelf_4", "standard"). shelf_allows_type_local("shelf_4", "fragile").
shelf_allows_type_local("shelf_6", "standard"). shelf_allows_type_local("shelf_6", "fragile").
shelf_allows_type_local("shelf_7", "standard"). shelf_allows_type_local("shelf_7", "fragile").
shelf_allows_type_local("shelf_9", "standard"). shelf_allows_type_local("shelf_9", "fragile").

/* --- Capacidad --- */
can_handle(W, H, Weight) :-
    my_capacity(MW, MWd, MHt) & Weight <= MW & W <= MWd & H <= MHt.

shelf_fits_local(ShelfId, Weight, Area, Type) :-
    shelf_local(ShelfId, MaxW, MaxV) &
    shelf_allows_type_local(ShelfId, Type) &
    Weight <= MaxW & Area <= MaxV.

/* ============================================================================
 * INICIO Y BUCLE PRINCIPAL
 * ============================================================================ */

!start.

+!start <-
    .my_name(Me);
    .print("[", Me, "] Iniciado y autónomo");
    !main_loop.

+!main_loop : state(idle) & returning(no) & base(BX,BY) & not position(BX,BY) <-
    -+returning(yes); !return_step; !main_loop.

+!main_loop : state(idle) & returning(yes) & base(BX,BY) & not position(BX,BY) <-
    !return_step; !main_loop.

+!main_loop : state(idle) <-
    -+returning(no);
    !check_pending;
    .wait(1000);
    !main_loop.

+!main_loop : state(busy) <- .wait(500); !main_loop.

/* ============================================================================
 * SUBASTA DISTRIBUIDA ENTRE PEERS
 * ============================================================================ */

/* Reacción a anuncio: esperar delay propio antes de pujar */
+pending_container(CId, W, H, Weight, Type)[source(_)]
    : state(idle) & can_handle(W, H, Weight)
    & not claimed(CId) & not intending(CId) <-
    ?bid_delay(D);
    .wait(D);
    !bid_if_free(CId, W, H, Weight, Type).

+pending_container(_, _, _, _, _) <- true.

/* Búsqueda activa por si se perdió algún anuncio */
+!check_pending
    : pending_container(CId, W, H, Weight, Type)
    & can_handle(W, H, Weight)
    & not claimed(CId) & not intending(CId) <-
    ?bid_delay(D);
    .wait(D);
    !bid_if_free(CId, W, H, Weight, Type).
+!check_pending <- true.

/* Pujar solo si el contenedor sigue libre */
+!bid_if_free(CId, W, H, Weight, Type)
    : state(idle) & not claimed(CId) & not intending(CId) <-
    .my_name(Me);
    +intending(CId);
    .print("[", Me, "] Pujando por ", CId);
    !broadcast_intend(CId, Me);
    /* Ventana para recibir intenciones rivales */
    .wait(200);
    !resolve_bid(CId, W, H, Weight, Type).

+!bid_if_free(_, _, _, _, _) <- true.

/* Broadcast a los 3 peers conocidos */
+!broadcast_intend(CId, Me) <-
    !send_intend_to(robot_light,   CId, Me);
    !send_intend_to(robot_medium,  CId, Me);
    !send_intend_to(robot_heavy,   CId, Me);
    !send_intend_to(robot_heavy_2, CId, Me).

+!send_intend_to(Peer, CId, Me) : Peer \== Me <-
    .send(Peer, tell, intend(CId, Me)).
+!send_intend_to(_, _, _) <- true.

/* Rival con menor delay: retirarse */
+intend(CId, Other)[source(Other)]
    : intending(CId) & peer_bid_delay(Other, OtherD) & bid_delay(MyD) & OtherD < MyD <-
    .my_name(Me);
    -intending(CId);
    .print("[", Me, "] Retirado de ", CId, " — gana ", Other).

/* Rival con mayor o igual delay: ignorar, seguimos pujando */
+intend(CId, Other)[source(Other)] : intending(CId) & peer_bid_delay(Other, _) <- true.

/* Peer desconocido: retirarse por precaución */
+intend(CId, Other)[source(Other)] : intending(CId) <-
    .my_name(Me);
    -intending(CId);
    .print("[", Me, "] Retirado de ", CId, " — peer desconocido: ", Other).

+intend(_, _) <- true.

+!resolve_bid(CId, W, H, Weight, Type) : intending(CId) & state(idle) & not claimed(CId) <-
    .my_name(Me);
    ?bid_delay(MyD);
    !check_rivals(CId, Me, MyD);
    if (intending(CId)) {
        +claimed(CId);
        .broadcast(tell, claimed(CId));
        -intending(CId);
        -+state(busy);
        -+returning(no);
        +current_container(CId);
        +current_task_info(CId, W, H, Weight, Type);
        !find_shelf_local(CId, W, H, Weight, Type, ShelfId);
        +target_shelf(ShelfId);
        .print("[", Me, "] Subasta ganada: ", CId, " -> ", ShelfId);
        !execute_task(CId, ShelfId)
    }.

+!resolve_bid(CId, _, _, _, _) <-
    -intending(CId).
/* Chequeo activo: retirarse si hay un rival con menor delay en el BB */
+!check_rivals(CId, Me, MyD)
    : intend(CId, Rival) & peer_bid_delay(Rival, RD) & RD < MyD <-
    -intending(CId);
    .print("[", Me, "] Retirado de ", CId, " — gana ", Rival).

+!check_rivals(_, _, _) <- true.

/* ============================================================================
 * SELECCIÓN LOCAL DE ESTANTERÍA
 * ============================================================================ */

+!find_shelf_local(_, W, H, Weight, Type, "shelf_1") : shelf_fits_local("shelf_1", Weight, W*H, Type).
+!find_shelf_local(_, W, H, Weight, Type, "shelf_2") : shelf_fits_local("shelf_2", Weight, W*H, Type).
+!find_shelf_local(_, W, H, Weight, Type, "shelf_3") : shelf_fits_local("shelf_3", Weight, W*H, Type).
+!find_shelf_local(_, W, H, Weight, Type, "shelf_4") : shelf_fits_local("shelf_4", Weight, W*H, Type).
+!find_shelf_local(_, W, H, Weight, Type, "shelf_5") : shelf_fits_local("shelf_5", Weight, W*H, Type).
+!find_shelf_local(_, W, H, Weight, Type, "shelf_6") : shelf_fits_local("shelf_6", Weight, W*H, Type).
+!find_shelf_local(_, W, H, Weight, Type, "shelf_7") : shelf_fits_local("shelf_7", Weight, W*H, Type).
+!find_shelf_local(_, W, H, Weight, Type, "shelf_8") : shelf_fits_local("shelf_8", Weight, W*H, Type).
+!find_shelf_local(_, W, H, Weight, Type, "shelf_9") : shelf_fits_local("shelf_9", Weight, W*H, Type).

-!find_shelf_local(CId, _, _, _, _, ShelfId) <-
    ?default_shelf(D); ShelfId = D;
    .my_name(Me);
    .print("[", Me, "] Usando estantería default para ", CId, ": ", D).



    /* ============================================================================
 * SELECCIÓN ALTERNATIVA — excluye estanterías marcadas como llenas
 * ============================================================================ */

+!find_shelf_alt_local(_, W, H, Weight, Type, "shelf_1")
    : not shelf_blocked("shelf_1") & shelf_fits_local("shelf_1", Weight, W*H, Type).
+!find_shelf_alt_local(_, W, H, Weight, Type, "shelf_2")
    : not shelf_blocked("shelf_2") & shelf_fits_local("shelf_2", Weight, W*H, Type).
+!find_shelf_alt_local(_, W, H, Weight, Type, "shelf_3")
    : not shelf_blocked("shelf_3") & shelf_fits_local("shelf_3", Weight, W*H, Type).
+!find_shelf_alt_local(_, W, H, Weight, Type, "shelf_4")
    : not shelf_blocked("shelf_4") & shelf_fits_local("shelf_4", Weight, W*H, Type).
+!find_shelf_alt_local(_, W, H, Weight, Type, "shelf_5")
    : not shelf_blocked("shelf_5") & shelf_fits_local("shelf_5", Weight, W*H, Type).
+!find_shelf_alt_local(_, W, H, Weight, Type, "shelf_6")
    : not shelf_blocked("shelf_6") & shelf_fits_local("shelf_6", Weight, W*H, Type).
+!find_shelf_alt_local(_, W, H, Weight, Type, "shelf_7")
    : not shelf_blocked("shelf_7") & shelf_fits_local("shelf_7", Weight, W*H, Type).
+!find_shelf_alt_local(_, W, H, Weight, Type, "shelf_8")
    : not shelf_blocked("shelf_8") & shelf_fits_local("shelf_8", Weight, W*H, Type).
+!find_shelf_alt_local(_, W, H, Weight, Type, "shelf_9")
    : not shelf_blocked("shelf_9") & shelf_fits_local("shelf_9", Weight, W*H, Type).

-!find_shelf_alt_local(CId, _, _, _, _, _) <-
    .my_name(Me);
    .print("[", Me, "] Todas las estanterías compatibles agotadas para ", CId).


/* ============================================================================
 * ENTREGA A ESTANTERÍA ALTERNATIVA — el robot ya lleva el paquete, sin pickup
 * ============================================================================ */

+!try_deliver_to_next(CId, W, H, Weight, Type) <-
    !find_shelf_alt_local(CId, W, H, Weight, Type, NewShelf);
    +target_shelf(NewShelf);
    .my_name(Me);
    .print("[", Me, "] Redirigido a: ", NewShelf);
    !get_shelf_dest(NewShelf, SX, SY);
    !go(SX, SY);
    drop_at(NewShelf);
    .wait(100);
    .send(scheduler, tell, task_complete(CId, Me));
    .print("[", Me, "] COMPLETO (reasignado): ", CId, " -> ", NewShelf);
    .broadcast(untell, claimed(CId));
    -claimed(CId); -current_container(CId); -target_shelf(NewShelf);
    -current_task_info(CId, _, _, _, _);
    .abolish(shelf_blocked(_));
    -+state(idle).

/* drop_at falló en la nueva estantería → +error(shelf_full,_) lo gestionará */
-!try_deliver_to_next(CId, _, _, _, _) : error(shelf_full, _) & target_shelf(_) <- true.

/* find_shelf_alt_local falló (todas agotadas) → abortar y volver a base */
-!try_deliver_to_next(CId, _, _, _, _) <-
    .my_name(Me);
    .print("[", Me, "] Sin más estanterías para ", CId, " - abortando");
    .send(scheduler, tell, robot_error(Me, CId, no_shelf_available));
    .broadcast(untell, claimed(CId));
    -claimed(CId);
    -current_task_info(CId, _, _, _, _);
    -current_container(CId);
    -target_shelf(_);
    .abolish(shelf_blocked(_));
    !go_home_busy.

/* Navegar a base manteniéndose busy (zonas accesibles), idle solo al llegar */
+!go_home_busy <-
    ?base(BX, BY);
    .my_name(Me);
    .print("[", Me, "] Volviendo a base (sin paquete)");
    !go(BX, BY);
    -+state(idle);
    .print("[", Me, "] En base, listo").
/* ============================================================================
 * EJECUCIÓN DE TAREAS Y NAVEGACIÓN
 * ============================================================================ */

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
    .broadcast(untell, claimed(CId));
    -claimed(CId); -current_container(CId); -target_shelf(ShelfId);
    -+state(idle).

/* Si la causa es shelf_full: no limpiar nada, el handler de error lo gestiona */
-!execute_task(CId, ShelfId) : error(shelf_full, _) <- true.

/* Cualquier otro fallo: limpieza normal */
-!execute_task(CId, ShelfId) <-
    .my_name(Me);
    .print("[", Me, "] FALLO tarea ", CId);
    .send(scheduler, tell, robot_error(Me, CId, execution_failed));
    .broadcast(untell, claimed(CId));
    -claimed(CId); -current_container(CId); -target_shelf(ShelfId);
    -current_task_info(CId, _, _, _, _);
    .abolish(shelf_blocked(_));
    -+state(idle).

+!go_adjacent(CX, CY) : walkable(CX, CY+1) <- !go(CX, CY+1).
+!go_adjacent(CX, CY) : walkable(CX+1, CY) <- !go(CX+1, CY).
+!go_adjacent(CX, CY) : walkable(CX-1, CY) <- !go(CX-1, CY).
+!go_adjacent(CX, CY) : walkable(CX, CY-1) <- !go(CX, CY-1).
+!go_adjacent(CX, CY) <- .wait(500); !go_adjacent(CX, CY).

+!go(TX, TY) : position(TX, TY) <- true.
+!go(TX, TY) : position(MX, MY) & MY < TY & walkable(MX, MY+1) <- !do_step(MX, MY+1, TX, TY).
+!go(TX, TY) : position(MX, MY) & MY > TY & walkable(MX, MY-1) <- !do_step(MX, MY-1, TX, TY).
+!go(TX, TY) : position(MX, MY) & MX < TX & walkable(MX+1, MY) <- !do_step(MX+1, MY, TX, TY).
+!go(TX, TY) : position(MX, MY) & MX > TX & walkable(MX-1, MY) <- !do_step(MX-1, MY, TX, TY).
+!go(TX, TY) : position(MX, MY) & MY \== TY & walkable(MX-1, MY) <- !do_step(MX-1, MY, TX, TY).
+!go(TX, TY) : position(MX, MY) & MY \== TY & walkable(MX+1, MY) <- !do_step(MX+1, MY, TX, TY).
+!go(TX, TY) : position(MX, MY) & MX \== TX & walkable(MX, MY-1) <- !do_step(MX, MY-1, TX, TY).
+!go(TX, TY) : position(MX, MY) & MX \== TX & walkable(MX, MY+1) <- !do_step(MX, MY+1, TX, TY).
/* Escape: mover en cualquier dirección libre cuando el camino directo está bloqueado */
+!go(TX, TY) : position(MX, MY) & walkable(MX, MY-1) <- !do_step(MX, MY-1, TX, TY).
+!go(TX, TY) : position(MX, MY) & walkable(MX, MY+1) <- !do_step(MX, MY+1, TX, TY).
+!go(TX, TY) : position(MX, MY) & walkable(MX-1, MY) <- !do_step(MX-1, MY, TX, TY).
+!go(TX, TY) : position(MX, MY) & walkable(MX+1, MY) <- !do_step(MX+1, MY, TX, TY).
+!go(TX, TY) <- .wait(1000); !go(TX, TY).

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
-!retry_step(NX, NY, TX, TY, MX, MY) <- .wait(1500); !go(TX, TY).

/* ============================================================================
 * RETORNO A BASE
 * ============================================================================ */

+!return_step : base(BX,BY) & position(BX,BY) <- -+returning(no).
+!return_step : base(BX,BY) & position(MX,MY) & MY < BY & walkable(MX, MY+1) <-
    ?step_wait(W); move_to(MX, MY+1); .wait(W); -+position(MX, MY+1).
+!return_step : base(BX,BY) & position(MX,MY) & MY > BY & walkable(MX, MY-1) <-
    ?step_wait(W); move_to(MX, MY-1); .wait(W); -+position(MX, MY-1).
+!return_step : base(BX,BY) & position(MX,MY) & MX < BX & walkable(MX+1, MY) <-
    ?step_wait(W); move_to(MX+1, MY); .wait(W); -+position(MX+1, MY).
+!return_step : base(BX,BY) & position(MX,MY) & MX > BX & walkable(MX-1, MY) <-
    ?step_wait(W); move_to(MX-1, MY); .wait(W); -+position(MX-1, MY).
+!return_step <- .wait(300).
-!return_step <- .wait(300).

/* ============================================================================
 * ERRORES
 * ============================================================================ */

+error(container_too_heavy, _) : state(busy) <-
    .my_name(Me); ?current_container(CId); ?target_shelf(Sh);
    .send(scheduler, tell, robot_error(Me, CId, container_too_heavy));
    .broadcast(untell, claimed(CId));
    -claimed(CId); -current_container(CId); -target_shelf(Sh); -+state(idle).

+error(container_too_big, _) : state(busy) <-
    .my_name(Me); ?current_container(CId); ?target_shelf(Sh);
    .send(scheduler, tell, robot_error(Me, CId, container_too_big));
    .broadcast(untell, claimed(CId));
    -claimed(CId); -current_container(CId); -target_shelf(Sh); -+state(idle).

/* Estantería llena: marcarla y buscar la siguiente */
+error(shelf_full, _)
    : state(busy) & current_container(CId) & target_shelf(FullShelf)
    & current_task_info(CId, W, H, Weight, Type) <-
    .my_name(Me);
    .print("[", Me, "] Estantería llena: ", FullShelf, " - probando siguiente");
    +shelf_blocked(FullShelf);
    -target_shelf(FullShelf);
    !try_deliver_to_next(CId, W, H, Weight, Type).

/* Guardia de seguridad: si no hay target_shelf en BB, ignorar sin disparar handler genérico */
+error(shelf_full, _) <- true.

+error(too_far, _)           : state(busy) <- .wait(300); ?current_container(CId); ?target_shelf(Sh); !execute_task(CId, Sh).
+error(conflict, _)          <- true.
+error(route_blocked, _)     <- true.
+error(container_blocking, _) <- .wait(300).
+error(Tipo, _) <- .my_name(Me); .send(scheduler, tell, robot_error(Me, none, Tipo)); -+state(idle).

/* ============================================================================
 * DESTINOS DE ESTANTERÍAS
 * ============================================================================ */

+!get_shelf_dest("shelf_1", 10, 1). +!get_shelf_dest("shelf_2", 12, 1).
+!get_shelf_dest("shelf_3", 14, 1). +!get_shelf_dest("shelf_4", 16, 1).
+!get_shelf_dest("shelf_5", 10, 5). +!get_shelf_dest("shelf_6", 13, 5).
+!get_shelf_dest("shelf_7", 16, 5). +!get_shelf_dest("shelf_8", 10, 9).
+!get_shelf_dest("shelf_9", 14, 9).
+!get_shelf_dest(_, X, Y) : default_shelf(D) <- !get_shelf_dest(D, X, Y).

+robot_at(X,Y) <- -+position(X,Y).  
