*******************************************************************************
 * SUPERVISOR - Agente de Monitorizacion y Gestion de Errores
 * Universidad de Vigo - Sistemas Inteligentes - Curso 2025-2026
 *
 * RESPONSABILIDADES:
 *   1. Contar contenedores recibidos, almacenados y errores
 *   2. Gestionar los 6 tipos de error del entorno 
 *   3. Calcular estadisticas globales del sistema
 *   4. Detectar situaciones anomalas y emitir alertas
 *
 * MENSAJES RECIBIDOS DEL SCHEDULER:
 *   task_assigned(CId, Robot, ShelfId)
 *   task_done(CId, Robot)
 *   task_error(CId, Robot, Reason)
 *   container_queued(CId, Weight, W, H)
 *   assignment_error(CId, Weight, W, H)
 *
 * MENSAJES DIRECTOS DE LOS ROBOTS:
 *   error_report(Robot, Type, Data)
 *
 * 6 TIPOS DE ERROR:
 *   container_too_heavy  container_too_big  shelf_full
 *   illegal_move  conflict  route_blocked
 ******************************************************************************/


 // Creencias iniciales 
 

total_received(0).
total_stored(0).
total_errors(0).

errors_by_type(container_too_heavy, 0).
errors_by_type(container_too_big,   0).
errors_by_type(shelf_full,          0).
errors_by_type(illegal_move,        0).
errors_by_type(conflict,            0).
errors_by_type(route_blocked,       0).

tasks_done_by_robot(robot_light,  0).
tasks_done_by_robot(robot_medium, 0).
tasks_done_by_robot(robot_heavy,  0).

errors_by_robot(robot_light,  0).
errors_by_robot(robot_medium, 0).
errors_by_robot(robot_heavy,  0).

alert_threshold_robot_errors(5).
alert_threshold_total_errors(10).


 // Inicio del agente
 
!start.

+!start : true <-
    .print("[Supervisor] Comenzando supervision.").

//Se encarga de crear el nuevo contenedor

+new_container(CId) : true <-
    ?total_received(N);             
    N1 = N + 1;                    //aumenta en 1 la cantidad de contendores reconocidos
    -total_received(_);
    +total_received(N1);          
    .print("[Supervisor] Nuevo contenedor registrado: ", CId,
           " | Total recibidos: ", N1).

//Nos indica que tarea ha asignado el scheduler

+task_assigned(CId, Robot, ShelfId)[source(scheduler)] : true <-  // recibe del agente scheduler , la tarea que a asignado y a que estanteria y a que Robot
    .print("[Supervisor] Tarea asignada | contenedor=", CId,
           " robot=", Robot, " estanteria=", ShelfId).

//Nos indica cuando un robot ha completado alguna tarea

+task_done(CId, Robot)[source(scheduler)] : true <-
    ?total_stored(N);
    N1 = N + 1;                     //aumenta en 1 la cantidad de actividades commpletadas .
    -total_stored(_);
    +total_stored(N1);
    ?tasks_done_by_robot(Robot, K);   
    K1 = K + 1;                        //aumenta en 1 la cantidad de tareas hechas por el robot.
    -tasks_done_by_robot(Robot, _);     //nos indica que tipo de robot realizó la actividad
    +tasks_done_by_robot(Robot, K1);
    .print("[Supervisor] Almacenado OK | contenedor=", CId,
           " robot=", Robot, " | Total almacenados: ", N1);
    if (N1 mod 5 == 0) { !print_summary }.

//Nos informa si se ha producido un error en alguna tarea

+task_error(CId, Robot, Reason)[source(scheduler)] : true <-  //el scheduler nos manda si se produjo algun error.
    .print("[Supervisor] ERROR en tarea | contenedor=", CId,
           " robot=", Robot, " motivo=", Reason);
    !register_error(Robot, Reason).

//Nos informa el scheduler si algun contenedor a sido añadido a una cola ( esperando su turno para poder actuar).
+container_queued(CId, Weight, W, H)[source(scheduler)] : true <- // El scheduler nos informa que contenedor y con que caracteristicas ha sido añadido a la cola
    .print("[Supervisor] Contenedor encolado | id=", CId,
           " peso=", Weight, "kg | tamano=", W, "x", H).


 //Nos informa un  robot si se ha producido algun error ya sea en una tarea u otra cosa.
+error_report(Robot, Type, Data)[source(Robot)] : true <-   //El robor nos envia la informacion sobre que robot , de que tipo y los datos provenientes del error.
    .print("[Supervisor] ERROR directo de robot | robot=", Robot,
           " tipo=", Type, " datos=", Data);
    !register_error(Robot, Type).  //registra el error correspondiente.

/
 //AQUI SE MUESTRAN LOS  DIFERENTES TIPOS DE ERRORES QUE PUEDE DETECTAR EL SUPERVISOR
+error(container_too_heavy, Data) : true <-
    .print("[Supervisor] ALERTA - container_too_heavy: ", Data);
    !register_error_no_robot(container_too_heavy).

+error(container_too_big, Data) : true <-
    .print("[Supervisor] ALERTA - container_too_big: ", Data);
    !register_error_no_robot(container_too_big).

+error(shelf_full, Data) : true <-
    .print("[Supervisor] ALERTA - shelf_full: ", Data);
    !register_error_no_robot(shelf_full).

+error(illegal_move, Data) : true <-
    .print("[Supervisor] ALERTA - illegal_move: ", Data);
    !register_error_no_robot(illegal_move).

+error(conflict, Data) : true <-
    .print("[Supervisor] ALERTA - conflict: ", Data);
    !register_error_no_robot(conflict).

+error(route_blocked, Data) : true <-
    .print("[Supervisor] ALERTA - route_blocked: ", Data);
    !register_error_no_robot(route_blocked).

// no_shelf_available: todas las estanterias llenas para ese contenedor 
+error(no_shelf_available, Data) : true <-
    .print("[Supervisor] INFO - sin estanteria disponible: ", Data).

// Cualquier otro error no catalogado lo registra sin contarlo 
+error(_, _) : true <- true.

+blocked(X, Y) : true <-
    .print("[Supervisor] Celda bloqueada en: (", X, ",", Y, ")").

//Registra errores esta vez conociendo el tipo de robot del que se trata
+!register_error(Robot, Type) : true <-  //Apunta el mismo el error producido y del tipo y de que robot proviene
    ?total_errors(E);
    E1 = E + 1;           //aumenta en 1 la cantidad de errores
    -total_errors(_);
    +total_errors(E1);     // lo almacena en total_errors
    !increment_error_type(Type);   //incrementa el contador de errores del tipo de robor correspondiente
    ?errors_by_robot(Robot, ER);
    ER1 = ER + 1;                //aumenta en 1 los errores producidos por el robot
    -errors_by_robot(Robot, _);
    +errors_by_robot(Robot, ER1);
    !check_robot_alert(Robot);  //comprueba la cantidad de errores que ya tuvo el robor
    !check_total_errors_alert.  //comprueba el total de errores 

//Registra el error esta vez sin conocer el tipo de robot que es
+!register_error_no_robot(Type) : true <-
    ?total_errors(E);
    E1 = E + 1;         //aumenta en 1 el contador de errores
    -total_errors(_);
    +total_errors(E1);
    !increment_error_type(Type);
    !check_total_errors_alert.

//Incrementa el error segun el tipo
+!increment_error_type(Type) : errors_by_type(Type, N) <-
    N1 = N + 1;
    -errors_by_type(Type, _);
    +errors_by_type(Type, N1).

+!increment_error_type(Type) : not errors_by_type(Type, _) <-
    .print("[Supervisor] Tipo de error no catalogado: ", Type).

//DIFERENTES ALERTAS PARA PODER LLEVAR LA CUENTA DE LOS ERRORES
+!check_robot_alert(Robot) :
        errors_by_robot(Robot, ER) &
        alert_threshold_robot_errors(T) &
        ER >= T <-
    .print("[Supervisor] *** ALERTA  Robot con demasiados errores: ",
           Robot, " (", ER, " errores)").
+!check_robot_alert(_) : true <- true.

+!check_total_errors_alert :
        total_errors(E) &
        alert_threshold_total_errors(T) &
        E >= T <-
    .print("[Supervisor] *** ALERTA GLOBAL *** Errores totales: ", E).
+!check_total_errors_alert : true <- true.


 // RESUMEN ESTADISTICO 
 

+!print_summary : true <-
    ?total_received(R);
    ?total_stored(S);
    ?total_errors(E);
    ?tasks_done_by_robot(robot_light,  TL);
    ?tasks_done_by_robot(robot_medium, TM);
    ?tasks_done_by_robot(robot_heavy,  TH);
    ?errors_by_robot(robot_light,  EL);
    ?errors_by_robot(robot_medium, EM);
    ?errors_by_robot(robot_heavy,  EH);
    ?errors_by_type(container_too_heavy, ETH);
    ?errors_by_type(container_too_big,   ETB);
    ?errors_by_type(shelf_full,          ESF);
    ?errors_by_type(illegal_move,        EIM);
    ?errors_by_type(conflict,            ECO);
    ?errors_by_type(route_blocked,       ERB);
    .print("[Supervisor]  ESTADISTICAS DEL ALMACEN :  ");
    .print("  Contenedores recibidos  : ", R);
    .print("  Contenedores almacenados: ", S);
    .print("  Errores totales         : ", E);
    .print("   Rendimiento por robot  :");
    .print("  robot_light  | completados: ", TL, " | errores: ", EL);
    .print("  robot_medium | completados: ", TM, " | errores: ", EM);
    .print("  robot_heavy  | completados: ", TH, " | errores: ", EH);
    .print("   Errores por tipo :");
    .print("  container_too_heavy : ", ETH);
    .print("  container_too_big   : ", ETB);
    .print("  shelf_full          : ", ESF);
    .print("  illegal_move        : ", EIM);
    .print("  conflict            : ", ECO);
    .print("  route_blocked       : ", ERB);
    // Tasa de exito = almacenados / (almacenados + errores_de_tarea)
      //Mide cuantos intentos se ejecutaron correctamente
    Intentados = S + E;
    if (Intentados > 0) {
        Tasa = (S * 100) / Intentados;
        .print("  Tasa de exito (entregas): ", Tasa, "%")
    };
    // Tasa de cobertura = almacenados / recibidos 
    if (R > 0) {
        Cobertura = (S * 100) / R;
        .print("  Cobertura del almacen:    ", Cobertura, "%")
    };
    
//Funciones para que otros agentes puedan solicitar la informacion
+print_summary_request[source(_)] : true <- !print_summary.

+request_scheduler_stats[source(_)] : true <-
    .send(scheduler, tell, stats_request).

+stats(R, A, E, NP)[source(scheduler)] : true <-
    .print("[Supervisor] Stats Scheduler: recibidos=", R,
           " asignados=", A, " errores=", E, " en cola=", NP).