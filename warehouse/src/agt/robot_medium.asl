state(idle).
position(2,3).

!start.

+!start
    <- .print("[Robot-Medium] Iniciado - Capacidad 30kg, tamaño 1x2");
       !main_loop.

+!main_loop : state(idle)
    <- .print("[Robot-Medium] Solicitando tarea...");
       request_task();
       .wait(2000);
       !main_loop.

+!main_loop : state(busy)
    <- .wait(1000);
       !main_loop.

+task(CId, ShelfId)[source(scheduler)] : state(idle)
    <- .print("[Robot-Medium] Tarea recibida: ", CId, " -> ", ShelfId);
       -+state(busy);
       +current_container(CId);
       +target_shelf(ShelfId);
       !execute_task(CId, ShelfId).

+!execute_task(CId, ShelfId)
    <- get_container_info(CId);
       .wait(500);
       .print("[Robot-Medium] Moviendo a zona de entrada");
       move_to(1,1);
       .wait(1000);
       .print("[Robot-Medium] Recogiendo ", CId);
       pickup(CId);
       .wait(1000);
       .print("[Robot-Medium] Moviendo a estantería");
       move_to(12,5);
       .wait(1000);
       .print("[Robot-Medium] Depositando");
       drop_at(ShelfId);
       .wait(1000);
       .my_name(Me);
       .send(scheduler, tell, task_complete(CId, Me));
       .print("[Robot-Medium] Tarea completada!");
       -+state(idle);
       -current_container(CId);
       -target_shelf(ShelfId).

+robot_at(X,Y)
    <- -+position(X,Y);
       .print("[Robot-Medium] Posición: (", X, ",", Y, ")").

+error(container_too_heavy, Data) : state(busy)
    <- .print("[Robot-Medium] ERROR: Contenedor muy pesado");
       .my_name(Me);
       ?current_container(CId);
       .send(scheduler, tell, robot_error(Me, CId, container_too_heavy));
       -+state(idle);
       -current_container(CId).

+error(container_too_big, Data) : state(busy)
    <- .print("[Robot-Medium] ERROR: Contenedor muy grande");
       .my_name(Me);
       ?current_container(CId);
       .send(scheduler, tell, robot_error(Me, CId, container_too_big));
       -+state(idle);
       -current_container(CId).

+error(conflict, Data) : state(busy)
    <- .print("[Robot-Medium] ERROR: Colisión detectada, reintentando");
       .wait(2000);
       ?current_container(CId);
       ?target_shelf(ShelfId);
       !execute_task(CId, ShelfId).

+error(route_blocked, Data) : state(busy)
    <- .print("[Robot-Medium] ERROR: Ruta bloqueada, buscando alternativa");
       .wait(1000);
       ?current_container(CId);
       ?target_shelf(ShelfId);
       !execute_task(CId, ShelfId).

+error(shelf_full, Data) : state(busy)
    <- .print("[Robot-Medium] ERROR: Estantería llena");
       .my_name(Me);
       ?current_container(CId);
       .send(scheduler, tell, robot_error(Me, CId, shelf_full));
       -+state(idle);
       -current_container(CId).

+error(Tipo, Data)
    <- .print("[Robot-Medium] ERROR: ", Tipo);
       .my_name(Me);
       .send(scheduler, tell, robot_error(Me, none, Tipo));
       -+state(idle).