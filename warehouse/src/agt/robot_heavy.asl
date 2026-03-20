/* ROBOT HEAVY - 100kg, 2x3, velocidad baja */
/* Anti-oscilacion: recuerda ultimo desvio para no repetirlo */

state(idle).
position(3,3).
last_detour(none). /* none, up, down, left, right */

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

blocked(X,Y) :- shelf_cell(X,Y).
blocked(X,Y) :- X < 0.
blocked(X,Y) :- X >= 20.
blocked(X,Y) :- Y < 0.
blocked(X,Y) :- Y >= 15.

!start.

+!start <-
    .print("[Robot-Heavy] Iniciado - 100kg 2x3");
    !main_loop.

+!main_loop : state(idle) <- .wait(2000); !main_loop.
+!main_loop : state(busy) <- .wait(2000); !main_loop.

+task(CId, ShelfId)[source(scheduler)] : state(idle) <-
    -+state(busy);
    +current_container(CId);
    +target_shelf(ShelfId);
    -+last_detour(none);
    !execute_task(CId, ShelfId).

+task(CId, ShelfId)[source(scheduler)] : state(busy) <-
    .my_name(Me);
    .send(scheduler, tell, robot_error(Me, CId, robot_busy)).

+!execute_task(CId, ShelfId) <-
    get_container_info(CId);
    .wait(500);
    -+last_detour(none);
    !go_to(1, 0);
    .print("[Robot-Heavy] pickup ", CId);
    pickup(CId);
    .wait(500);
    !get_shelf_target(ShelfId, SX, SY);
    -+last_detour(none);
    !go_to(SX, SY);
    .print("[Robot-Heavy] drop ", ShelfId);
    drop_at(ShelfId);
    .wait(500);
    .my_name(Me);
    .send(scheduler, tell, task_complete(CId, Me));
    .print("[Robot-Heavy] OK!");
    -+state(idle);
    -current_container(CId);
    -target_shelf(ShelfId).

/* ========== NAVEGACION CON MEMORIA DE DESVIO ========== */

+!go_to(TX, TY) : position(TX, TY) <- -+last_detour(none).

/* --- X difiere: intentar avanzar en X --- */
+!go_to(TX, TY) : position(MX, MY) & MX < TX & not blocked(MX+1, MY) <-
    !try_move(MX+1, MY, TX, TY).

+!go_to(TX, TY) : position(MX, MY) & MX > TX & not blocked(MX-1, MY) <-
    !try_move(MX-1, MY, TX, TY).

/* --- X bloqueado por shelf: desviar en Y, preferir ARRIBA si ultimo fue abajo --- */
+!go_to(TX, TY) : position(MX, MY) & MX \== TX & blocked(MX+1, MY) & last_detour(down) & not blocked(MX, MY-1) <-
    -+last_detour(up);
    !try_move(MX, MY-1, TX, TY).

+!go_to(TX, TY) : position(MX, MY) & MX \== TX & blocked(MX-1, MY) & last_detour(down) & not blocked(MX, MY-1) <-
    -+last_detour(up);
    !try_move(MX, MY-1, TX, TY).

+!go_to(TX, TY) : position(MX, MY) & MX \== TX & blocked(MX+1, MY) & last_detour(up) & not blocked(MX, MY+1) <-
    -+last_detour(down);
    !try_move(MX, MY+1, TX, TY).

+!go_to(TX, TY) : position(MX, MY) & MX \== TX & blocked(MX-1, MY) & last_detour(up) & not blocked(MX, MY+1) <-
    -+last_detour(down);
    !try_move(MX, MY+1, TX, TY).

/* X bloqueado, sin desvio previo: preferir ir hacia destino Y, o arriba por defecto */
+!go_to(TX, TY) : position(MX, MY) & MX < TX & blocked(MX+1, MY) & MY > TY & not blocked(MX, MY-1) <-
    -+last_detour(up);
    !try_move(MX, MY-1, TX, TY).

+!go_to(TX, TY) : position(MX, MY) & MX < TX & blocked(MX+1, MY) & not blocked(MX, MY-1) <-
    -+last_detour(up);
    !try_move(MX, MY-1, TX, TY).

+!go_to(TX, TY) : position(MX, MY) & MX < TX & blocked(MX+1, MY) & not blocked(MX, MY+1) <-
    -+last_detour(down);
    !try_move(MX, MY+1, TX, TY).

+!go_to(TX, TY) : position(MX, MY) & MX > TX & blocked(MX-1, MY) & MY > TY & not blocked(MX, MY-1) <-
    -+last_detour(up);
    !try_move(MX, MY-1, TX, TY).

+!go_to(TX, TY) : position(MX, MY) & MX > TX & blocked(MX-1, MY) & not blocked(MX, MY-1) <-
    -+last_detour(up);
    !try_move(MX, MY-1, TX, TY).

+!go_to(TX, TY) : position(MX, MY) & MX > TX & blocked(MX-1, MY) & not blocked(MX, MY+1) <-
    -+last_detour(down);
    !try_move(MX, MY+1, TX, TY).

/* --- Y difiere, X ya OK --- */
+!go_to(TX, TY) : position(MX, MY) & MX == TX & MY < TY & not blocked(MX, MY+1) <-
    !try_move(MX, MY+1, TX, TY).

+!go_to(TX, TY) : position(MX, MY) & MX == TX & MY > TY & not blocked(MX, MY-1) <-
    !try_move(MX, MY-1, TX, TY).

/* Y bloqueado por shelf: desviar en X con misma logica anti-oscilacion */
+!go_to(TX, TY) : position(MX, MY) & MX == TX & MY \== TY & last_detour(left) & not blocked(MX+1, MY) <-
    -+last_detour(right);
    !try_move(MX+1, MY, TX, TY).

+!go_to(TX, TY) : position(MX, MY) & MX == TX & MY \== TY & last_detour(right) & not blocked(MX-1, MY) <-
    -+last_detour(left);
    !try_move(MX-1, MY, TX, TY).

+!go_to(TX, TY) : position(MX, MY) & MX == TX & MY < TY & blocked(MX, MY+1) & not blocked(MX-1, MY) <-
    -+last_detour(left);
    !try_move(MX-1, MY, TX, TY).

+!go_to(TX, TY) : position(MX, MY) & MX == TX & MY < TY & blocked(MX, MY+1) & not blocked(MX+1, MY) <-
    -+last_detour(right);
    !try_move(MX+1, MY, TX, TY).

+!go_to(TX, TY) : position(MX, MY) & MX == TX & MY > TY & blocked(MX, MY-1) & not blocked(MX-1, MY) <-
    -+last_detour(left);
    !try_move(MX-1, MY, TX, TY).

+!go_to(TX, TY) : position(MX, MY) & MX == TX & MY > TY & blocked(MX, MY-1) & not blocked(MX+1, MY) <-
    -+last_detour(right);
    !try_move(MX+1, MY, TX, TY).

/* --- Fallback --- */
+!go_to(TX, TY) : position(MX, MY) & not blocked(MX, MY-1) <-
    -+last_detour(up);
    !try_move(MX, MY-1, TX, TY).
+!go_to(TX, TY) : position(MX, MY) & not blocked(MX, MY+1) <-
    -+last_detour(down);
    !try_move(MX, MY+1, TX, TY).
+!go_to(TX, TY) : position(MX, MY) & not blocked(MX+1, MY) <-
    -+last_detour(right);
    !try_move(MX+1, MY, TX, TY).
+!go_to(TX, TY) : position(MX, MY) & not blocked(MX-1, MY) <-
    -+last_detour(left);
    !try_move(MX-1, MY, TX, TY).

+!go_to(TX, TY) <- .wait(2000); -+last_detour(none); !go_to(TX, TY).

/* --- try_move con roomba_turn anti-oscilacion --- */
+!try_move(NX, NY, TX, TY) <-
    move_to(NX, NY);
    .wait(500);
    -+position(NX, NY);
    !go_to(TX, TY).

/* Colision con robot: girar 90, recordar desvio */
-!try_move(NX, NY, TX, TY) : position(MX, MY) & NX \== MX & last_detour(down) & not blocked(MX, MY-1) <-
    .wait(700); -+last_detour(up);
    move_to(MX, MY-1); .wait(500); -+position(MX, MY-1); !go_to(TX, TY).

-!try_move(NX, NY, TX, TY) : position(MX, MY) & NX \== MX & not blocked(MX, MY-1) <-
    .wait(700); -+last_detour(up);
    move_to(MX, MY-1); .wait(500); -+position(MX, MY-1); !go_to(TX, TY).

-!try_move(NX, NY, TX, TY) : position(MX, MY) & NX \== MX & not blocked(MX, MY+1) <-
    .wait(700); -+last_detour(down);
    move_to(MX, MY+1); .wait(500); -+position(MX, MY+1); !go_to(TX, TY).

-!try_move(NX, NY, TX, TY) : position(MX, MY) & NY \== MY & last_detour(right) & not blocked(MX-1, MY) <-
    .wait(700); -+last_detour(left);
    move_to(MX-1, MY); .wait(500); -+position(MX-1, MY); !go_to(TX, TY).

-!try_move(NX, NY, TX, TY) : position(MX, MY) & NY \== MY & not blocked(MX-1, MY) <-
    .wait(700); -+last_detour(left);
    move_to(MX-1, MY); .wait(500); -+position(MX-1, MY); !go_to(TX, TY).

-!try_move(NX, NY, TX, TY) : position(MX, MY) & NY \== MY & not blocked(MX+1, MY) <-
    .wait(700); -+last_detour(right);
    move_to(MX+1, MY); .wait(500); -+position(MX+1, MY); !go_to(TX, TY).

/* Todo fallo: esperar y reset */
-!try_move(NX, NY, TX, TY) <-
    .wait(1500); -+last_detour(none); !go_to(TX, TY).

/* ========== DESTINOS ========== */
+!get_shelf_target("shelf_1", 10, 1).
+!get_shelf_target("shelf_2", 12, 1).
+!get_shelf_target("shelf_3", 14, 1).
+!get_shelf_target("shelf_4", 16, 1).
+!get_shelf_target("shelf_5", 10, 5).
+!get_shelf_target("shelf_6", 13, 5).
+!get_shelf_target("shelf_7", 16, 5).
+!get_shelf_target("shelf_8", 10, 9).
+!get_shelf_target("shelf_9", 14, 9).
+!get_shelf_target(_, 10, 9).

+robot_at(X,Y) <- -+position(X,Y).

/* ========== ERRORES ========== */
+error(container_too_heavy, _) : state(busy) <-
    .my_name(Me); ?current_container(CId); ?target_shelf(Sh);
    .send(scheduler, tell, robot_error(Me, CId, container_too_heavy));
    -+state(idle); -current_container(CId); -target_shelf(Sh).
+error(container_too_big, _) : state(busy) <-
    .my_name(Me); ?current_container(CId); ?target_shelf(Sh);
    .send(scheduler, tell, robot_error(Me, CId, container_too_big));
    -+state(idle); -current_container(CId); -target_shelf(Sh).
+error(too_far, _) : state(busy) <-
    .wait(700); ?current_container(CId); ?target_shelf(Sh);
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
    .print("[Robot-Heavy] Fallo ", CId);
    .my_name(Me);
    .send(scheduler, tell, robot_error(Me, CId, execution_failed));
    -+state(idle); -current_container(CId); -target_shelf(ShelfId).
