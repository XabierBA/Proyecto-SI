/*******************************************************************************
 * ROBOT COMMON - Lógica Fusionada y Autónoma
 ******************************************************************************/

/* --- Estado inicial común --- */
state(idle).
returning(no).

/* Estanterías con paquetes en proceso - se añaden dinámicamente vía +shelf_in_progress */

/* --- Celdas de salida por robot (evitar colisiones) --- */
exit_drop_cell_robot(robot_light, 0, 0).
exit_drop_cell_robot(robot_medium, 1, 0).
exit_drop_cell_robot(robot_heavy, 2, 0).
exit_drop_cell_robot(robot_heavy_2, 2, 1).

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
/* Y=0 e Y=1 bloqueados, salvo zona de salida cuando ejecutamos tarea de salida.
 * Importante: durante una tarea de entrada, la zona de salida también está
 * bloqueada (sería una "trampa" porque desde X=2,Y=1 no se puede ir a X=3,Y=1). */
blocked(X,Y) :- X >= 0 & X <= 6 & Y == 0 & not (is_exit_zone(X,Y) & current_exit(_)).
blocked(X,Y) :- X >= 0 & X <= 7 & Y == 1 & not (is_exit_zone(X,Y) & current_exit(_)).
/* Bloquear explícitamente entry y class zone aunque alguna celda no caiga
 * en las reglas anteriores (ej: (7,0) que es entry zone pero X>6 Y=0). */
blocked(X,Y) :- is_entry_zone(X,Y) & not state(busy).
blocked(X,Y) :- is_entry_zone(X,Y) & current_exit(_).
blocked(X,Y) :- is_class_zone(X,Y).

container_blocked(X,Y) :- container_at(_, X, Y).
peer_blocks(X,Y) :- peer_position(_, X, Y).
walkable(X,Y) :- not blocked(X,Y) & not container_blocked(X,Y) & not peer_blocks(X,Y).

/* --- Configuración local de estanterías --- */
/* shelf_local(Id, MaxW, MaxV, UsedW, UsedV) */
shelf_local("shelf_1", 50,  8, 0, 0). shelf_local("shelf_2", 50,  8, 0, 0).
shelf_local("shelf_3", 50,  8, 0, 0). shelf_local("shelf_4", 50,  8, 0, 0).
shelf_local("shelf_5", 100, 12, 0, 0). shelf_local("shelf_6", 100, 12, 0, 0).
shelf_local("shelf_7", 100, 12, 0, 0). shelf_local("shelf_8", 200, 20, 0, 0).
shelf_local("shelf_9", 200, 20, 0, 0).

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

/* Algún peer con menor bid_delay también puede cargar este paquete.
 * Si no, no tiene sentido esperar — saltamos el delay para evitar inanición. */
peer_competes(W, H, Weight) :-
    bid_delay(MyD) & peer_bid_delay(Peer, PD) & PD < MyD &
    peer_capacity(Peer, PMW, PMWd, PMHt) &
    Weight <= PMW & W <= PMWd & H <= PMHt.

shelf_fits_local(ShelfId, Weight, Area, Type) :-
    shelf_local(ShelfId, MaxW, MaxV, UsedW, UsedV) &
    shelf_allows_type_local(ShelfId, Type) &
    not shelf_in_progress(ShelfId, _) &
    Weight + UsedW <= MaxW & Area + UsedV <= MaxV.

/* ============================================================================
 * INICIO Y BUCLE PRINCIPAL
 * ============================================================================ */

!start.

+!start <-
    .my_name(Me);
    .print("[", Me, "] Iniciado y autónomo");
    /* Broadcast posición inicial para que los peers la registren desde el inicio */
    ?position(IX, IY);
    .broadcast(tell, peer_at_pos(Me, IX, IY));
    !main_loop.

/* Durante deadline activo: sólo ciclo de salida, sin aceptar nuevas entradas */
+!main_loop : state(idle) & deadline_active(_) <-
    .abolish(bid_attempted(_));
    !check_exit_pending;
    .wait(100);
    !main_loop.

/* Sin deadline: ciclo normal de entrada y retorno a base */
+!main_loop : state(idle) <-
    .abolish(bid_attempted(_));
    !check_pending;
    .wait(100);
    !return_to_base_step;
    !main_loop.

+!main_loop : state(busy) <- .wait(200); !main_loop.

/* Volver a base paso a paso. En cada paso comprueba si está idle y no en base.
 * Si llega un pending compatible, check_pending lo cogerá en la siguiente iter
 * del main_loop (este loop se interrumpe al cambiar a busy). */
+!return_to_base_step
    : state(idle) & base(BX,BY) & not position(BX,BY) <-
    !return_step;
    !return_to_base_step.
+!return_to_base_step <- true.

/* ============================================================================
 * SUBASTA DISTRIBUIDA ENTRE PEERS
 * ============================================================================ */

/* Reacción a anuncio: urgentes con delay 0 adicional, resto con delay normal */
+pending_container(CId, W, H, Weight, "urgent")[source(_)]
    : state(idle) & can_handle(W, H, Weight)
    & not claimed(CId) & not intending(CId)
    & not no_shelf_available(CId) <-
    !bid_if_free(CId, W, H, Weight, "urgent").

/* Preempción: si llega urgente, estamos busy con un no-urgente y aún NO hemos
 * recogido el paquete actual, marcamos flag de preempción. execute_task lo
 * detectará en su siguiente paso y abortará voluntariamente. */
+pending_container(CId, W, H, Weight, "urgent")[source(_)]
    : state(busy) & can_handle(W, H, Weight)
    & not claimed(CId) & not intending(CId)
    & current_container(OldCId) & not carrying(OldCId)
    & current_task_info(OldCId, _, _, _, OldType) & OldType \== "urgent"
    & not preempt_pending(_)
    & not no_shelf_available(CId) <-
    .my_name(Me);
    .print("[", Me, "] PREEMPT marcado: soltar ", OldCId, " por urgente ", CId);
    +preempt_pending(CId).

+pending_container(CId, W, H, Weight, Type)[source(_)]
    : state(idle) & can_handle(W, H, Weight)
    & not claimed(CId) & not intending(CId)
    & not no_shelf_available(CId) <-
    !bid_if_free(CId, W, H, Weight, Type).

+pending_container(_, _, _, _, _) <- true.

/* Cuando algún robot informa que un container ya está hecho (entregado o
 * inexistente), todos limpiamos cualquier pending colgado para él. */
+container_done(CId)[source(_)] <-
    .abolish(pending_container(CId, _, _, _, _));
    .abolish(claimed(CId));
    -container_done(CId)[source(_)].

/* ============================================================================
 * CICLO DE SALIDA: respuesta a exit_required del scheduler
 * ============================================================================ */

/* Búsqueda activa: urgentes primero, luego el resto.
 * Procesamos TODOS los pending que podamos cargar en una pasada, marcando
 * cada CId con bid_attempted para evitar reintentar el mismo en esta pasada
 * si perdemos la subasta. Al finalizar limpiamos las marcas. */
+!check_pending
    : state(idle) & pending_container(CId, W, H, Weight, "urgent")
    & can_handle(W, H, Weight)
    & not claimed(CId) & not intending(CId) & not bid_attempted(CId)
    & not no_shelf_available(CId) <-
    +bid_attempted(CId);
    !bid_if_free(CId, W, H, Weight, "urgent");
    !check_pending.
+!check_pending
    : state(idle) & pending_container(CId, W, H, Weight, Type)
    & can_handle(W, H, Weight)
    & not claimed(CId) & not intending(CId) & not bid_attempted(CId)
    & not no_shelf_available(CId) <-
    +bid_attempted(CId);
    !bid_if_free(CId, W, H, Weight, Type);
    !check_pending.
+!check_pending <- .abolish(bid_attempted(_)).

/* Pujar solo si el contenedor sigue libre.
 * Marcamos intención INMEDIATAMENTE y broadcasteamos. Si algún peer con menor
 * delay puede cargar el paquete, esperamos nuestro bid_delay como ventana de
 * retirada; si no, pujamos sin esperar para evitar inanición. */
+!bid_if_free(CId, W, H, Weight, Type)
    : state(idle) & not claimed(CId) & not intending(CId) & peer_competes(W, H, Weight) <-
    .my_name(Me);
    +intending(CId);
    .print("[", Me, "] Pujando por ", CId);
    !broadcast_intend(CId, Me);
    ?bid_delay(D);
    .wait(D);
    !resolve_bid(CId, W, H, Weight, Type).

+!bid_if_free(CId, W, H, Weight, Type)
    : state(idle) & not claimed(CId) & not intending(CId) <-
    .my_name(Me);
    +intending(CId);
    .print("[", Me, "] Pujando por ", CId, " (sin rivales capaces)");
    !broadcast_intend(CId, Me);
    .wait(100);
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
        /* find_shelf_nearest falla si no hay hueco — el -!resolve_bid captura eso
         * y notifica no_fit al supervisor. Si hay candidata, se reserva INMEDIATAMENTE
         * antes de cualquier broadcast para evitar la ventana de carrera entre robots. */
        !find_shelf_nearest(CId, W, H, Weight, Type, ShelfId);
        !reserve_shelf(ShelfId, Weight, W*H);
        +claimed(CId);
        .broadcast(tell, claimed(CId));
        -intending(CId);
        -+state(busy);
        +current_container(CId);
        +current_task_info(CId, W, H, Weight, Type);
        +target_shelf(ShelfId);
        .send(scheduler, tell, claim_reserved(CId, ShelfId));
        .print("[", Me, "] Subasta ganada: ", CId, " -> ", ShelfId);
        !execute_task(CId, ShelfId)
    }.

+!resolve_bid(CId, _, _, _, _) <-
    -intending(CId).

/* Fallo de find_shelf_nearest (sin candidatas válidas): notificar supervisor */
-!resolve_bid(CId, _, _, _, Type) <-
    .my_name(Me);
    -intending(CId);
    .print("[", Me, "] Sin estantería para ", CId, " (", Type, ") — notificando supervisor");
    .send(supervisor, tell, no_fit(CId, Type));
    +no_shelf_available(CId).
/* Chequeo activo: retirarse si hay un rival con menor delay en el BB */
+!check_rivals(CId, Me, MyD)
    : intend(CId, Rival) & peer_bid_delay(Rival, RD) & RD < MyD <-
    -intending(CId);
    .print("[", Me, "] Retirado de ", CId, " — gana ", Rival).

+!check_rivals(_, _, _) <- true.

/* ============================================================================
 * SELECCIÓN LOCAL DE ESTANTERÍA — MÁS CERCANA CON HUECO (urgentes primero)
 * ============================================================================
 * Coordenadas de acceso (lateral sur/norte) de cada estantería:
 *   shelf_1(10,1/4)  shelf_2(12,1/4)  shelf_3(14,1/4)  shelf_4(16,1/4)
 *   shelf_5(10,5/8)  shelf_6(13,5/8)  shelf_7(16,5/8)
 *   shelf_8(10,9/13) shelf_9(14,9/13)
 * ============================================================================ */

/* Regla auxiliar: existe al menos una estantería que admite el paquete.
 * Evita aritmética en reglas Jason evaluando el producto manualmente.
 * Cubre todos los tamaños posibles según las capacidades de los robots
 * (light 1x1, medium 1x2, heavy 2x3). Sin fallback genérico: una cláusula
 * comodín con área 1 mentiría sobre el hueco real para tamaños mayores. */
shelf_available_for(1, 1, Weight, Type) :- shelf_fits_local(_, Weight, 1, Type).
shelf_available_for(1, 2, Weight, Type) :- shelf_fits_local(_, Weight, 2, Type).
shelf_available_for(1, 3, Weight, Type) :- shelf_fits_local(_, Weight, 3, Type).
shelf_available_for(2, 1, Weight, Type) :- shelf_fits_local(_, Weight, 2, Type).
shelf_available_for(2, 2, Weight, Type) :- shelf_fits_local(_, Weight, 4, Type).
shelf_available_for(2, 3, Weight, Type) :- shelf_fits_local(_, Weight, 6, Type).
shelf_available_for(3, 1, Weight, Type) :- shelf_fits_local(_, Weight, 3, Type).
shelf_available_for(3, 2, Weight, Type) :- shelf_fits_local(_, Weight, 6, Type).
shelf_available_for(3, 3, Weight, Type) :- shelf_fits_local(_, Weight, 9, Type).

/* Coordenadas de destino de cada estantería (puerta norte = y-1, puerta sur = y+height) */
shelf_access_north("shelf_1", 10, 1).  shelf_access_south("shelf_1", 10, 4).
shelf_access_north("shelf_2", 12, 1).  shelf_access_south("shelf_2", 12, 4).
shelf_access_north("shelf_3", 14, 1).  shelf_access_south("shelf_3", 14, 4).
shelf_access_north("shelf_4", 16, 1).  shelf_access_south("shelf_4", 16, 4).
shelf_access_north("shelf_5", 10, 5).  shelf_access_south("shelf_5", 10, 8).
shelf_access_north("shelf_6", 13, 5).  shelf_access_south("shelf_6", 13, 8).
shelf_access_north("shelf_7", 16, 5).  shelf_access_south("shelf_7", 16, 8).
shelf_access_north("shelf_8", 10, 9).  shelf_access_south("shelf_8", 10, 13).
shelf_access_north("shelf_9", 14, 9).  shelf_access_south("shelf_9", 14, 13).

/* Encontrar la estantería más cercana con hueco.
 * Itera la lista explícita en un plan (aritmética permitida en planes).
 * Usa pair(Dist, ShelfId) para evitar el operador - en listas. */
+!find_shelf_nearest(CId, W, H, Weight, Type, Best) <-
    Area = W * H;
    ?position(RX, RY);
    !collect_candidates(["shelf_1","shelf_2","shelf_3","shelf_4","shelf_5","shelf_6","shelf_7","shelf_8","shelf_9"], RX, RY, Weight, Area, Type, [], Candidates);
    .my_name(Me);
    .print("[", Me, "] Candidatas para ", CId, ": ", Candidates);
    !pick_best_shelf(Candidates, Best).

/* Iterar lista de estanterías y acumular pair(Dist,Id) para las válidas */
+!collect_candidates([], _, _, _, _, _, Acc, Acc).

+!collect_candidates([S|Rest], RX, RY, Weight, Area, Type, Acc, Result)
    : shelf_fits_local(S, Weight, Area, Type) & not shelf_blocked(S)
      & shelf_access_north(S, NX, NY) & shelf_access_south(S, SX, SY) <-
    DN2 = (RX-NX)*(RX-NX) + (RY-NY)*(RY-NY);
    DS2 = (RX-SX)*(RX-SX) + (RY-SY)*(RY-SY);
    if (DN2 <= DS2) { D = DN2 } else { D = DS2 };
    NewAcc = [pair(D,S)|Acc];
    !collect_candidates(Rest, RX, RY, Weight, Area, Type, NewAcc, Result).

+!collect_candidates([_|Rest], RX, RY, Weight, Area, Type, Acc, Result) <-
    !collect_candidates(Rest, RX, RY, Weight, Area, Type, Acc, Result).

/* Elegir el pair con menor distancia */
+!pick_best_shelf([pair(D,S) | Rest], Best) <-
    !pick_best_acc(Rest, D, S, Best).

/* Lista vacía: no hay estantería válida — fallar para que -!resolve_bid notifique al supervisor */
+!pick_best_shelf([], _) <-
    .my_name(Me);
    .print("[", Me, "] Sin candidatas válidas — fallo limpio");
    .fail.

+!pick_best_acc([], _, BestSoFar, BestSoFar).
+!pick_best_acc([pair(D,S) | Rest], CurD, CurBest, Best)
    : D < CurD <-
    !pick_best_acc(Rest, D, S, Best).
+!pick_best_acc([pair(_,_) | Rest], CurD, CurBest, Best) <-
    !pick_best_acc(Rest, CurD, CurBest, Best).

/* Compatibilidad: find_shelf_local ahora llama a find_shelf_nearest */
+!find_shelf_local(CId, W, H, Weight, Type, ShelfId) <-
    !find_shelf_nearest(CId, W, H, Weight, Type, ShelfId).

-!find_shelf_local(CId, _, _, Weight, Type, _) <-
    .my_name(Me);
    .print("[", Me, "] find_shelf_local falló para ", CId, " (", Type, ") — sin estantería válida");
    .fail.



/* ============================================================================
 * SELECCIÓN ALTERNATIVA — excluye estanterías marcadas como llenas
 * Reutiliza la misma lógica de distancia mínima
 * ============================================================================ */

+!find_shelf_alt_local(CId, W, H, Weight, Type, Best) <-
    !find_shelf_nearest(CId, W, H, Weight, Type, Best).


/* ============================================================================
 * ENTREGA A ESTANTERÍA ALTERNATIVA — el robot ya lleva el paquete, sin pickup
 * ============================================================================ */

+!try_deliver_to_next(CId, W, H, Weight, Type) <-
    !find_shelf_alt_local(CId, W, H, Weight, Type, NewShelf);
    +target_shelf(NewShelf);
    !reserve_shelf(NewShelf, Weight, W*H);
    .my_name(Me);
    .print("[", Me, "] Redirigido a: ", NewShelf);
    !get_shelf_dest(NewShelf, SX, SY);
    !go(SX, SY);
    drop_at(NewShelf);
    .wait(100);
    !update_shelf_used(NewShelf, Weight, W*H);
    +stored_at(CId, NewShelf, W, H, Weight, Type);
    .broadcast(tell, stored_at(CId, NewShelf, W, H, Weight, Type));
    .send(scheduler, tell, task_complete(CId, Me));
    .print("[", Me, "] COMPLETO (reasignado): ", CId, " -> ", NewShelf);
    .broadcast(untell, claimed(CId));
    .broadcast(tell, container_done(CId));
    .abolish(pending_container(CId, _, _, _, _));
    -claimed(CId); -current_container(CId); -target_shelf(NewShelf);
    -current_task_info(CId, _, _, _, _);
    -carrying(CId);
    .abolish(shelf_blocked(_));
    -+state(idle).

/* drop_at falló en la nueva estantería → +error(shelf_full,_) lo gestionará */
-!try_deliver_to_next(CId, _, _, _, _) : error(shelf_full, _) & target_shelf(_) <- true.

/* find_shelf_alt_local falló (todas agotadas) → abortar y volver a base */
-!try_deliver_to_next(CId, W, H, Weight, _) <-
    .my_name(Me);
    .print("[", Me, "] Sin más estanterías para ", CId, " - abortando");
    if (target_shelf(LastShelf)) {
        !release_shelf(LastShelf, Weight, W*H)
    };
    .send(scheduler, tell, robot_error(Me, CId, no_shelf_available));
    .broadcast(untell, claimed(CId));
    -claimed(CId);
    -current_task_info(CId, _, _, _, _);
    -current_container(CId);
    -target_shelf(_);
    -carrying(CId);
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


/* Reservar/liberar capacidad de una estantería (paquetes en tránsito).
 * Se sincroniza con los peers para que todos vean la misma vista de capacidad. */
+!reserve_shelf(ShelfId, Weight, Area) <-
    .my_name(Me);
    +shelf_in_progress(ShelfId, Me);
    ?shelf_local(ShelfId, MaxW, MaxV, UsedW, UsedV);
    NW = UsedW + Weight; NV = UsedV + Area;
    -shelf_local(ShelfId, MaxW, MaxV, UsedW, UsedV);
    +shelf_local(ShelfId, MaxW, MaxV, NW, NV);
    /* Forzar evaluación numérica con comparación dummy antes de enviar */
    NWnum = NW + 0; NVnum = NV + 0;
    .send(supervisor, tell, shelf_report(ShelfId, NWnum, NVnum));
    !notify_peers_reserve(Me, ShelfId, Weight, Area).

+!release_shelf(ShelfId, Weight, Area) <-
    .my_name(Me);
    -shelf_in_progress(ShelfId, Me);
    ?shelf_local(ShelfId, MaxW, MaxV, UsedW, UsedV);
    NW = UsedW - Weight; NV = UsedV - Area;
    -shelf_local(ShelfId, MaxW, MaxV, UsedW, UsedV);
    +shelf_local(ShelfId, MaxW, MaxV, NW, NV);
    NWnum = NW + 0; NVnum = NV + 0;
    .send(supervisor, tell, shelf_report(ShelfId, NWnum, NVnum));
    !notify_peers_release(Me, ShelfId, Weight, Area).

+!notify_peers_reserve(Me, S, W, A) <-
    !send_reserve(robot_light, Me, S, W, A);
    !send_reserve(robot_medium, Me, S, W, A);
    !send_reserve(robot_heavy, Me, S, W, A);
    !send_reserve(robot_heavy_2, Me, S, W, A);
    !broadcast_shelf_in_progress(S, Me).

+!send_reserve(Peer, Me, S, W, A) : Peer \== Me <-
    .send(Peer, tell, peer_reserved(S, W, A)).
+!send_reserve(_, _, _, _, _) <- true.

+!broadcast_shelf_in_progress(S, Me) <-
    .broadcast(tell, shelf_in_progress(S, Me)).

+!notify_peers_release(Me, S, W, A) <-
    !send_release(robot_light, Me, S, W, A);
    !send_release(robot_medium, Me, S, W, A);
    !send_release(robot_heavy, Me, S, W, A);
    !send_release(robot_heavy_2, Me, S, W, A);
    !broadcast_shelf_release(S, Me).

+!send_release(Peer, Me, S, W, A) : Peer \== Me <-
    .send(Peer, tell, peer_released(S, W, A)).
+!send_release(_, _, _, _, _) <- true.

+!broadcast_shelf_release(S, Me) <-
    .broadcast(tell, shelf_released(S, Me)).

/* Sincronización de reservas/liberaciones recibidas de peers */
+peer_reserved(ShelfId, Weight, Area)[source(_)] <-
    ?shelf_local(ShelfId, MaxW, MaxV, UsedW, UsedV);
    NW = UsedW + Weight; NV = UsedV + Area;
    -shelf_local(ShelfId, MaxW, MaxV, UsedW, UsedV);
    +shelf_local(ShelfId, MaxW, MaxV, NW, NV);
    -peer_reserved(ShelfId, Weight, Area)[source(_)].

+peer_released(ShelfId, Weight, Area)[source(_)] <-
    ?shelf_local(ShelfId, MaxW, MaxV, UsedW, UsedV);
    NW = UsedW - Weight; NV = UsedV - Area;
    -shelf_local(ShelfId, MaxW, MaxV, UsedW, UsedV);
    +shelf_local(ShelfId, MaxW, MaxV, NW, NV);
    -peer_released(ShelfId, Weight, Area)[source(_)].

/* Sincronizar estanterías en progreso desde peers */
+shelf_in_progress(ShelfId, Peer)[source(_)] <-
    +shelf_in_progress(ShelfId, Peer);
    -shelf_in_progress(ShelfId, Peer)[source(_)].

+shelf_released(ShelfId, Peer)[source(_)] <-
    -shelf_in_progress(ShelfId, Peer);
    -shelf_released(ShelfId, Peer)[source(_)].

/* Actualizar capacidad usada de una estantería tras entregar */
+!update_shelf_used(ShelfId, Weight, Area) <- true. /* reserva ya hecha al reclamar */

+!execute_task(CId, ShelfId) <-
    .my_name(Me);
    .print("[", Me, "] execute_task ", CId, " paso 1 get_container_info");
    get_container_info(CId);
    .wait(100);
    .print("[", Me, "] execute_task ", CId, " paso 2 ?container_at");
    if (not container_at(CId, _, _)) {
        .print("[", Me, "] container ", CId, " ya no existe — limpiando");
        ?current_task_info(CId, W, H, Weight, Type);
        !release_shelf(ShelfId, Weight, W*H);
        .broadcast(untell, claimed(CId));
        .broadcast(tell, container_done(CId));
        .abolish(pending_container(CId, _, _, _, _));
        -claimed(CId); -current_container(CId); -target_shelf(ShelfId);
        -current_task_info(CId, _, _, _, _);
        -+state(idle);
        .fail
    };
    ?container_at(CId, CX, CY);
    .print("[", Me, "] execute_task ", CId, " paso 3 go_adjacent ", CX, ",", CY);
    !go_adjacent(CX, CY);
    /* Antes del pickup, comprobar si hay flag de preempción por urgente */
    if (preempt_pending(_)) {
        .print("[", Me, "] PREEMPT activado: abortando ", CId);
        ?current_task_info(CId, W, H, Weight, Type);
        !release_shelf(ShelfId, Weight, W*H);
        .broadcast(untell, claimed(CId));
        -claimed(CId); -current_container(CId); -target_shelf(ShelfId);
        -current_task_info(CId, _, _, _, _);
        .abolish(preempt_pending(_));
        -+state(idle);
        .fail
    };
    .print("[", Me, "] execute_task ", CId, " paso 4 pickup");
    pickup(CId);
    +carrying(CId);
    .wait(100);
    .print("[", Me, "] execute_task ", CId, " paso 5 get_shelf_dest");
    !get_shelf_dest(ShelfId, SX, SY);
    .print("[", Me, "] execute_task ", CId, " paso 6 go ", SX, ",", SY);
    !go(SX, SY);
    .print("[", Me, "] execute_task ", CId, " paso 7 drop_at");
    ?current_task_info(CId, W, H, Weight, Type);
    /* VALIDACIÓN CRÍTICA: verificar que la estantería acepta este tipo */
    if (not shelf_allows_type_local(ShelfId, Type)) {
        .print("[", Me, "] ERROR CRÍTICO: ", ShelfId, " NO acepta tipo ", Type, " para ", CId);
        !release_shelf(ShelfId, Weight, W*H);
        .broadcast(untell, claimed(CId));
        .send(scheduler, tell, robot_error(Me, CId, wrong_shelf_type));
        -claimed(CId); -current_container(CId); -target_shelf(ShelfId);
        -current_task_info(CId, _, _, _, _);
        -carrying(CId);
        .abolish(shelf_blocked(_));
        -+state(idle);
        .fail
    };
    drop_at(ShelfId);
    .wait(100);
    ?current_task_info(CId, W, H, Weight, Type);
    !update_shelf_used(ShelfId, Weight, W*H);
    +stored_at(CId, ShelfId, W, H, Weight, Type);
    .broadcast(tell, stored_at(CId, ShelfId, W, H, Weight, Type));
    .send(scheduler, tell, task_complete(CId, Me));
    .print("[", Me, "] ", CId, " -> ", ShelfId, " OK");
    .broadcast(untell, claimed(CId));
    .broadcast(tell, container_done(CId));
    .abolish(pending_container(CId, _, _, _, _));
    -claimed(CId); -current_container(CId); -target_shelf(ShelfId);
    -current_task_info(CId, _, _, _, _);
    -carrying(CId);
    .abolish(shelf_blocked(_));
    -+state(idle).

/* Si la causa es shelf_full: no limpiar nada, el handler de error lo gestiona */
-!execute_task(CId, ShelfId) : error(shelf_full, _) <- true.

/* Cualquier otro fallo: liberar reserva y limpiar */
-!execute_task(CId, ShelfId) <-
    .my_name(Me);
    .print("[", Me, "] FALLO tarea ", CId);
    if (current_task_info(CId, W, H, Weight, _)) {
        !release_shelf(ShelfId, Weight, W*H)
    };
    .send(scheduler, tell, robot_error(Me, CId, execution_failed));
    .broadcast(untell, claimed(CId));
    -claimed(CId); -current_container(CId); -target_shelf(ShelfId);
    -current_task_info(CId, _, _, _, _);
    -carrying(CId);
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
/* Sin reglas de escape ciegas: si todas las direcciones útiles están bloqueadas,
 * esperar 1s y reintentar. peer_blocks se actualiza tras cada movimiento,
 * por lo que cuando el peer libera la celda el robot avanzará. Las reglas
 * de escape antiguas permitían retroceder hacia el origen, generando
 * oscilación infinita entre dos celdas adyacentes. */
+!go(TX, TY) <- .wait(1000); !go(TX, TY).

/* IMPORTANTE: no actualizamos position(NX,NY) localmente. Dejamos que el
 * entorno emita robot_at(NX,NY) tras un move exitoso; el handler +robot_at
 * hará -+position(X,Y). Si move_to falla, position queda inalterada y la
 * próxima iteración de !go reevaluará desde la posición real. */
+!do_step(NX, NY, TX, TY) <-
    ?step_wait(W); move_to(NX, NY); .wait(W); !go(TX, TY).

-!do_step(NX, NY, TX, TY) <-
    .wait(500); ?position(MX, MY); !retry_step(NX, NY, TX, TY, MX, MY).

+!retry_step(NX, NY, TX, TY, MX, MY) <-
    ?step_wait(W); move_to(NX, NY); .wait(W); !go(TX, TY).

-!retry_step(NX, NY, TX, TY, MX, MY) : NX \== MX & MY > 0 & walkable(MX, MY-1) <-
    ?step_wait(W); move_to(MX, MY-1); .wait(W); !go(TX, TY).
-!retry_step(NX, NY, TX, TY, MX, MY) : NX \== MX & walkable(MX, MY+1) <-
    ?step_wait(W); move_to(MX, MY+1); .wait(W); !go(TX, TY).
-!retry_step(NX, NY, TX, TY, MX, MY) : NY \== MY & walkable(MX-1, MY) <-
    ?step_wait(W); move_to(MX-1, MY); .wait(W); !go(TX, TY).
-!retry_step(NX, NY, TX, TY, MX, MY) : NY \== MY & walkable(MX+1, MY) <-
    ?step_wait(W); move_to(MX+1, MY); .wait(W); !go(TX, TY).
-!retry_step(NX, NY, TX, TY, MX, MY) <- .wait(1500); !go(TX, TY).

/* ============================================================================
 * RETORNO A BASE
 * ============================================================================ */

+!return_step : base(BX,BY) & position(BX,BY) <- -+returning(no).
+!return_step : base(BX,BY) & position(MX,MY) & MY < BY & walkable(MX, MY+1) <-
    ?step_wait(W); move_to(MX, MY+1); .wait(W).
+!return_step : base(BX,BY) & position(MX,MY) & MY > BY & walkable(MX, MY-1) <-
    ?step_wait(W); move_to(MX, MY-1); .wait(W).
+!return_step : base(BX,BY) & position(MX,MY) & MX < BX & walkable(MX+1, MY) <-
    ?step_wait(W); move_to(MX+1, MY); .wait(W).
+!return_step : base(BX,BY) & position(MX,MY) & MX > BX & walkable(MX-1, MY) <-
    ?step_wait(W); move_to(MX-1, MY); .wait(W).
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

/* Estantería llena: liberar reserva local, marcarla y buscar la siguiente */
+error(shelf_full, _)
    : state(busy) & current_container(CId) & target_shelf(FullShelf)
    & current_task_info(CId, W, H, Weight, Type) <-
    .my_name(Me);
    .print("[", Me, "] Estantería llena: ", FullShelf, " - probando siguiente");
    !release_shelf(FullShelf, Weight, W*H);
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
 * DESTINOS DE ESTANTERÍAS — lateral más cercano al robot
 * Para cada estantería se ofrecen los dos laterales (norte y sur).
 * Se elige el que minimice la distancia Manhattan desde la posición actual.
 * ============================================================================ */

+!get_shelf_dest(ShelfId, BestX, BestY) <-
    ?position(RX, RY);
    ?shelf_access_north(ShelfId, NX, NY);
    ?shelf_access_south(ShelfId, SX, SY);
    DN2 = (RX - NX) * (RX - NX) + (RY - NY) * (RY - NY);
    DS2 = (RX - SX) * (RX - SX) + (RY - SY) * (RY - SY);
    if (DN2 <= DS2) {
        BestX = NX; BestY = NY
    } else {
        BestX = SX; BestY = SY
    }.

/* Fallback si ShelfId no tiene datos de acceso (p.ej. default_shelf desconocida) */
-!get_shelf_dest(ShelfId, X, Y) <-
    .my_name(Me);
    .print("[", Me, "] Sin datos de acceso para ", ShelfId, " - usando (10,1)");
    X = 10; Y = 1.

+robot_at(X,Y) <-
    -+position(X,Y);
    .my_name(Me);
    .broadcast(tell, peer_at_pos(Me, X, Y)).

/* Recibir y mantener posiciones de los peers (sobreescribiendo la anterior).
 * Filtramos el caso en que el peer somos nosotros mismos para no bloquearnos. */
+peer_at_pos(Peer, X, Y)[source(_)] <-
    .my_name(Me);
    if (Peer == Me) {
        -peer_at_pos(Peer, X, Y)[source(_)]
    } else {
        .abolish(peer_position(Peer, _, _));
        +peer_position(Peer, X, Y);
        -peer_at_pos(Peer, X, Y)[source(_)]
    }.

/* ============================================================================
 * CICLO DE SALIDA — SEMANA 10
 * ============================================================================
 * Cuando el scheduler activa un deadline (urgent o nonurgent), envía:
 *   - active_deadline(Group) : tell con Group ∈ {urgent, nonurgent}
 *   - exit_required(CId, Type) : tell con cada contenedor a sacar
 *
 * Los robots compiten por exit_required usando subasta similar a la entrada.
 * El ganador va a la shelf donde está el contenedor (stored_at), simula
 * recogerlo (reciclando drop_at en sentido inverso: liberación de capacidad),
 * y va a una celda de zona de salida. Se notifica delivered al scheduler.
 * ============================================================================ */

/* Tipo del contenedor pertenece al deadline activo */
type_in_active_deadline(Type) :-
    deadline_active(urgent)    & Type == "urgent".
type_in_active_deadline(Type) :-
    deadline_active(nonurgent) & (Type == "standard" | Type == "fragile").

/* Reacción reactiva a exit_required (hint del scheduler): lanzar check inmediato */
+exit_required(CId, Type, ShelfId)[source(_)]
    : state(idle) & type_in_active_deadline(Type)
    & stored_at(CId, ShelfId, W, H, Weight, _)
    & can_handle(W, H, Weight)
    & not claimed_exit(CId) & not intending_exit(CId) <-
    !bid_exit_if_free(CId, W, H, Weight, Type, ShelfId).

+exit_required(_, _, _) <- true.

/* Búsqueda activa AUTÓNOMA: los robots escanean sus propios stored_at
 * para decidir qué contenedor transportar a la zona de salida.
 * No dependen de mensajes explícitos — deciden solos según el deadline activo. */
+!check_exit_pending
    : state(idle) & deadline_active(_)
    & stored_at(CId, ShelfId, W, H, Weight, Type)
    & type_in_active_deadline(Type)
    & can_handle(W, H, Weight)
    & not claimed_exit(CId) & not intending_exit(CId) <-
    !bid_exit_if_free(CId, W, H, Weight, Type, ShelfId);
    !check_exit_pending.
+!check_exit_pending <- true.

/* Subasta de salida: reaprovecha el delay normal */
+!bid_exit_if_free(CId, W, H, Weight, Type, ShelfId)
    : state(idle) & not claimed_exit(CId) & not intending_exit(CId)
    & peer_competes(W, H, Weight) <-
    .my_name(Me);
    +intending_exit(CId);
    .print("[", Me, "] Pujando SALIDA por ", CId);
    !broadcast_exit_intend(CId, Me);
    ?bid_delay(D);
    .wait(D);
    !resolve_exit_bid(CId, W, H, Weight, Type, ShelfId).

+!bid_exit_if_free(CId, W, H, Weight, Type, ShelfId)
    : state(idle) & not claimed_exit(CId) & not intending_exit(CId) <-
    .my_name(Me);
    +intending_exit(CId);
    .print("[", Me, "] Pujando SALIDA por ", CId, " (sin rivales capaces)");
    !broadcast_exit_intend(CId, Me);
    .wait(100);
    !resolve_exit_bid(CId, W, H, Weight, Type, ShelfId).

+!bid_exit_if_free(_, _, _, _, _, _) <- true.

+!broadcast_exit_intend(CId, Me) <-
    !send_exit_intend_to(robot_light, CId, Me);
    !send_exit_intend_to(robot_medium, CId, Me);
    !send_exit_intend_to(robot_heavy, CId, Me);
    !send_exit_intend_to(robot_heavy_2, CId, Me).

+!send_exit_intend_to(Peer, CId, Me) : Peer \== Me <-
    .send(Peer, tell, intend_exit(CId, Me)).
+!send_exit_intend_to(_, _, _) <- true.

/* Rival con menor delay: retirarse */
+intend_exit(CId, Other)[source(Other)]
    : intending_exit(CId) & peer_bid_delay(Other, OtherD) & bid_delay(MyD) & OtherD < MyD <-
    .my_name(Me);
    -intending_exit(CId);
    .print("[", Me, "] Retirado de SALIDA ", CId, " — gana ", Other).

+intend_exit(_, _) <- true.

/* Resolver subasta de salida con chequeo de rivales antes de reclamar */
+!resolve_exit_bid(CId, W, H, Weight, Type, ShelfId)
    : intending_exit(CId) & state(idle) & not claimed_exit(CId) <-
    .my_name(Me);
    ?bid_delay(MyD);
    !check_exit_rivals(CId, Me, MyD);
    if (intending_exit(CId)) {
        +claimed_exit(CId);
        .broadcast(tell, claimed_exit(CId));
        -intending_exit(CId);
        -+state(busy);
        +current_exit(CId);
        +current_exit_info(CId, W, H, Weight, Type, ShelfId);
        .print("[", Me, "] Subasta SALIDA ganada: ", CId);
        !execute_exit_task(CId, W, H, Weight, Type, ShelfId)
    } else {
        .print("[", Me, "] Retirado de SALIDA ", CId, " en resolve")
    }.

+!resolve_exit_bid(CId, _, _, _, _, _) <-
    -intending_exit(CId).

/* Chequeo activo: retirarse si hay un rival con menor delay en el BB */
+!check_exit_rivals(CId, Me, MyD)
    : intend_exit(CId, Rival) & peer_bid_delay(Rival, RD) & RD < MyD <-
    -intending_exit(CId);
    .print("[", Me, "] Retirado de SALIDA ", CId, " — gana ", Rival).

+!check_exit_rivals(_, _, _) <- true.

/* Ejecución de tarea de salida:
 *   1) ir a la shelf donde está el contenedor
 *   2) simular pickup (liberar capacidad y eliminar stored_at)
 *   3) ir a la zona de salida (celda 1,1 — pasable porque state(busy))
 *   4) emitir log container_delivered y notificar al scheduler */
+!execute_exit_task(CId, W, H, Weight, Type, ShelfId) <-
    .my_name(Me);
    /* Verificar que el container sigue existiendo en su shelf antes de salir */
    if (not stored_at(CId, ShelfId, _, _, _, _)) {
        .print("[", Me, "] container ", CId, " ya no en ", ShelfId, " — abortando exit");
        .broadcast(untell, claimed_exit(CId));
        .broadcast(tell, exit_done(CId));
        -claimed_exit(CId);
        -current_exit(CId);
        -current_exit_info(CId, _, _, _, _, _);
        -+state(idle);
        .fail
    };
    !get_shelf_dest(ShelfId, SX, SY);
    !go(SX, SY);
    .wait(100);
    /* Recoger físicamente el contenedor de la estantería */
    pickup_from_shelf(CId, ShelfId);
    .wait(100);
    Area = W*H; !release_shelf(ShelfId, Weight, Area);
    -stored_at(CId, ShelfId, _, _, _, _);
    .broadcast(untell, stored_at(CId, ShelfId, W, H, Weight, Type));
    +carrying_exit(CId);
    /* Ruta distinta por robot para evitar atascos:
     * 1) ir a fila exit_corridor_y manteniendo X actual
     * 2) ir horizontalmente a la columna del exit_drop_cell
     * 3) bajar (o subir) hasta la celda exit_drop_cell */
    ?exit_drop_cell(EX, EY);
    ?exit_corridor_y(CorrY);
    ?position(CX2, CY2);
    !go(CX2, CorrY);
    ?position(CX3, _);
    !go(EX, CorrY);
    ?position(_, CY3);
    !go(EX, EY);
    .wait(100);
    /* Depositar físicamente en la zona de salida */
    drop_at_exit(EX, EY);
    .wait(100);
    .time(HH, MM, SS); .concat(HH, ":", MM, ":", SS, T);
    .print("EVENT | time=", T, " | agent=", Me, " | type=container_delivered | data=", CId);
    .send(scheduler, tell, container_at_exit(CId));
    .send(scheduler, tell, container_delivered(CId, Me, Type));
    .broadcast(untell, claimed_exit(CId));
    .broadcast(tell, exit_done(CId));
    .abolish(exit_required(CId, _, _));
    -claimed_exit(CId);
    -current_exit_info(CId, _, _, _, _, _);
    -carrying_exit(CId);
    /* CRÍTICO: escapar de la zona de salida ANTES de retirar current_exit.
     * Si retirásemos current_exit aquí, las celdas de exit zone (donde
     * acabamos de soltar) se bloquean inmediatamente y el robot quedaría
     * atrapado. Navegamos a base aún en estado busy y con current_exit
     * activo para que las celdas sigan siendo transitables. */
    ?base(BX, BY);
    !go(BX, BY);
    -current_exit(CId);
    -+state(idle).

-!execute_exit_task(CId, _, _, _, _, _) <-
    .my_name(Me);
    .print("[", Me, "] FALLO tarea salida ", CId);
    .send(scheduler, tell, robot_error(Me, CId, exit_failed));
    .broadcast(untell, claimed_exit(CId));
    -claimed_exit(CId);
    -current_exit(CId);
    -current_exit_info(CId, _, _, _, _, _);
    -carrying_exit(CId);
    -+state(idle).

/* Sincronización de deadline_active desde scheduler.
 * Si el robot está idle, lanza inmediatamente check_exit_pending
 * para no esperar la próxima iteración del main_loop. */
+deadline_active(Group)[source(_)] <-
    .my_name(Me);
    .print("[", Me, "] Deadline activo: ", Group);
    if (state(idle)) {
        !check_exit_pending
    }.

-deadline_active(Group)[source(_)] <-
    .my_name(Me);
    .print("[", Me, "] Deadline finalizado: ", Group);
    /* Al terminar el deadline, hay espacio liberado: limpiar bloqueos locales
     * para que los contenedores pendientes puedan intentarse de nuevo */
    .abolish(no_shelf_available(_)).

/* Cuando otro robot informa que un container de salida ya está hecho,
 * limpiamos cualquier exit_required y claimed_exit colgado para él. */
+exit_done(CId)[source(_)] <-
    .abolish(exit_required(CId, _, _));
    .abolish(claimed_exit(CId));
    -exit_done(CId)[source(_)].
