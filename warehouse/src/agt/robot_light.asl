state(idle).
position(1,3).

!start.

+!start
    <- .print("[Robot-Light] Iniciado - Capacidad 10kg, tamaño 1x1");
       !main_loop.

+!main_loop : state(idle)
    <- .print("[Robot-Light] Solicitando tarea...");
       request_task();
       .wait(2000);
       !main_loop.

+!main_loop : state(busy)
    <- .wait(1000);
       !main_loop.

+task(CId, ShelfId)[source(scheduler)] : state(idle)
    <- .print("[Robot-Light] Tarea recibida: ", CId, " -> ", ShelfId);
       -+state(busy);
       +current_container(CId);
       +target_shelf(ShelfId);
       !get_shelf_position(ShelfId).

+!get_shelf_position(ShelfId)
    <- .print("[Robot-Light] Buscando posición de ", ShelfId);
       /* Por ahora usamos posición fija, idealmente habría que consultar al entorno */
       !execute_task(CId, 12, 5).

+!execute_task(CId, ShelfX, ShelfY)
    <- get_container_info(CId);
       .wait(500);
       .print("[Robot-Light] Moviendo a zona de entrada");
       move_to(1,1);
       .wait(1000);
       .print("[Robot-Light] Recogiendo ", CId);
       pickup(CId);
       .wait(1000);
       .print("[Robot-Light] Moviendo a estantería en (", ShelfX, ",", ShelfY, ")");
       move_to(ShelfX, ShelfY);
       .wait(1000);
       .print("[Robot-Light] Depositando");
       drop_at(ShelfId);
       .wait(1000);
       .my_name(Me);
       .send(scheduler, tell, task_complete(CId, Me));
       .print("[Robot-Light] Tarea completada!");
       -+state(idle);
       -current_container(CId);
       -target_shelf(ShelfId).

+robot_at(X,Y)
    <- -+position(X,Y);
       .print("[Robot-Light] Posición: (", X, ",", Y, ")").

+error(container_too_heavy, Data) : state(busy)
    <- .print("[Robot-Light] ERROR: Contenedor muy pesado");
       .my_name(Me);
       ?current_container(CId);
       .send(scheduler, tell, robot_error(Me, CId, container_too_heavy));
       -+state(idle);
       -current_container(CId).

+error(container_too_big, Data) : state(busy)
    <- .print("[Robot-Light] ERROR: Contenedor muy grande");
       .my_name(Me);
       ?current_container(CId);
       .send(scheduler, tell, robot_error(Me, CId, container_too_big));
       -+state(idle);
       -current_container(CId).

+error(conflict, Data) : state(busy)
    <- .print("[Robot-Light] ERROR: Colisión detectada, reintentando");
       .wait(2000);
       ?current_container(CId);
       ?target_shelf(ShelfId);
       !execute_task(CId, 12, 5).

+error(route_blocked, Data) : state(busy)
    <- .print("[Robot-Light] ERROR: Ruta bloqueada, buscando alternativa");
       .wait(1000);
       ?current_container(CId);
       ?target_shelf(ShelfId);
       !execute_task(CId, 12, 5).

+error(Tipo, Data)
    <- .print("[Robot-Light] ERROR: ", Tipo);
       .my_name(Me);
       .send(scheduler, tell, robot_error(Me, none, Tipo));
       -+state(idle).