/* SCHEDULER - Coordinador con prioridad light>medium>heavy */

robot_capacity(robot_light,  10,  1, 1, 3).
robot_capacity(robot_medium, 30,  1, 2, 2).
robot_capacity(robot_heavy,  100, 2, 3, 1).

robot_status(robot_light,  idle).
robot_status(robot_medium, idle).
robot_status(robot_heavy,  idle).

stat_received(0).
stat_assigned(0).
stat_errors(0).

!start.

+!start : true <-
    .print("[Scheduler] Iniciado").

+new_container(CId) : not pending(CId, _, _, _, _) <-
    ?stat_received(N); -stat_received(N); +stat_received(N+1);
    .print("[Scheduler] Nuevo: ", CId);
    get_container_info(CId).

+new_container(CId) : pending(CId, _, _, _, _) <- true.

+container_info(CId, W, H, Weight, Type) : true <-
    -container_info(CId, W, H, Weight, Type);
    .print("[Scheduler] ", CId, ": ", Weight, "kg ", W, "x", H, " ", Type);
    +pending(CId, W, H, Weight, Type);
    !try_assign_pending.

+task_complete(CId, Robot)[source(_)] : true <-
    .print("[Scheduler] Libre: ", Robot);
    -robot_status(Robot, busy);
    +robot_status(Robot, idle);
    -task_complete(CId, Robot)[source(_)];
    !try_assign_pending.

+!try_assign_pending : pending(CId, W, H, Weight, Type) <-
    !try_assign(CId, W, H, Weight, Type);
    !try_assign_pending.

+!try_assign_pending : not pending(_, _, _, _, _) <- true.

+!try_assign(CId, W, H, Weight, Type)
    : robot_capacity(robot_light, MW, MWd, MHt, _)
    & Weight <= MW & W <= MWd & H <= MHt
    & robot_status(robot_light, idle)
    <- !do_assign(CId, W, H, Weight, Type, robot_light).

+!try_assign(CId, W, H, Weight, Type)
    : robot_capacity(robot_medium, MW, MWd, MHt, _)
    & Weight <= MW & W <= MWd & H <= MHt
    & robot_status(robot_medium, idle)
    <- !do_assign(CId, W, H, Weight, Type, robot_medium).

+!try_assign(CId, W, H, Weight, Type)
    : robot_capacity(robot_heavy, MW, MWd, MHt, _)
    & Weight <= MW & W <= MWd & H <= MHt
    & robot_status(robot_heavy, idle)
    <- !do_assign(CId, W, H, Weight, Type, robot_heavy).

+!try_assign(CId, W, H, Weight, Type) : true <-
    .print("[Scheduler] Cola: ", CId, " (", Weight, "kg)").

+!do_assign(CId, W, H, Weight, Type, Robot) : true <-
    get_free_shelf(CId);
    ?free_shelf(CId, ShelfId);
    -free_shelf(CId, ShelfId);
    -pending(CId, W, H, Weight, Type);
    -robot_status(Robot, idle);
    +robot_status(Robot, busy);
    .send(Robot, tell, task(CId, ShelfId));
    .print("[Scheduler] ", Robot, " -> ", CId, " -> ", ShelfId);
    ?stat_assigned(N); -stat_assigned(N); +stat_assigned(N+1).

-!do_assign(CId, W, H, Weight, Type, Robot) : true <-
    .print("[Scheduler] Sin estanteria para ", CId).

+robot_error(Robot, CId, ErrorType)[source(_)]
    : pending(CId, W, H, Weight, Type) <-
    ?stat_errors(N); -stat_errors(N); +stat_errors(N+1);
    -robot_status(Robot, busy); +robot_status(Robot, idle);
    -robot_error(Robot, CId, ErrorType)[source(_)];
    !try_assign(CId, W, H, Weight, Type).

+robot_error(Robot, CId, ErrorType)[source(_)]
    : not pending(CId, _, _, _, _) <-
    ?stat_errors(N); -stat_errors(N); +stat_errors(N+1);
    -robot_status(Robot, busy); +robot_status(Robot, idle);
    -robot_error(Robot, CId, ErrorType)[source(_)];
    !try_assign_pending.

+!print_status : true <-
    ?stat_received(R); ?stat_assigned(A); ?stat_errors(E);
    ?robot_status(robot_light, SL);
    ?robot_status(robot_medium, SM);
    ?robot_status(robot_heavy, SH);
    .print("[Scheduler] R:", R, " A:", A, " E:", E,
           " L=", SL, " M=", SM, " H=", SH).

+!estado : true <- !print_status.
