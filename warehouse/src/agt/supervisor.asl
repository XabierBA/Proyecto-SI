/*******************************************************************************
 * SUPERVISOR - Monitor Activo del Sistema
 * 
 * Universidad de Vigo - Sistemas Inteligentes
 * Curso 2025-2026
 * 
 * CAPACIDADES:
 *   - Seguimiento de contenedores recibidos por tipo
 *   - Conteo de tareas completadas
 *   - Registro y notificacion de errores
 *   - Generacion periodica de reportes del sistema
 * 
 ******************************************************************************/

/* ============================================================================
 *  Estadisticas globales del supervisor
 *  total_errores: numero total de errores detectados
 *  total_completados: tareas finalizadas correctamente
 *  standard_count, fragile_count, urgent_count: contenedores recibidos por tipo
 *  ============================================================================ */

total_errores(0).
total_completados(0).
standard_count(0).
fragile_count(0).
urgent_count(0).

/* Estado de espacio por grupo de tipo:
 *   space_full(urgent)   -> no hay hueco en shelf_1/5/8
 *   space_full(nonurgent)-> no hay hueco en shelf_2/3/4/6/7/9
 * Ausencia del belief = hay espacio disponible */

/* Estado inicial de ocupacion de estanterias (peso actual, volumen actual).
 * Se actualiza con shelf_report del scheduler tras cada tarea completada.
 * Inicializado a 0,0 para que any_*_shelf_free sea verdadero al arrancar. */
shelf_state("shelf_1", 0, 0).
shelf_state("shelf_2", 0, 0).
shelf_state("shelf_3", 0, 0).
shelf_state("shelf_4", 0, 0).
shelf_state("shelf_5", 0, 0).
shelf_state("shelf_6", 0, 0).
shelf_state("shelf_7", 0, 0).
shelf_state("shelf_8", 0, 0).
shelf_state("shelf_9", 0, 0).


/* ============================================================================
 * PLANES PRINCIPALES
 * ============================================================================ */

!start.

/* Iniciamos el supervisor y arrancamos el bucle de monitorizacion */
+!start <-
    .print("[Supervisor] Iniciado - reportes cada 30s");
    !monitor_loop.


/* ============================================================================
 * BUCLE DE MONITORIZACION
 * ============================================================================ */

/* Esperar 30 segundos, generar un reporte y repetir indefinidamente */
+!monitor_loop <-
    .wait(30000);
    !generar_reporte;
    !monitor_loop.


/* ============================================================================
 * GENERACION DE REPORTES
 * ============================================================================ */

/* Consultar las estadisticas acumuladas, imprimir el informe y solicitar al scheduler el estado actual de los robots */
+!generar_reporte <-
    ?total_errores(E);
    ?total_completados(TC);
    ?standard_count(S);
    ?fragile_count(F);
    ?urgent_count(U);
    .print("");
    .print("=========== REPORTE SUPERVISOR ===========");
    .print("  Contenedores recibidos por tipo:");
    .print("    Standard: ", S);
    .print("    Fragile:  ", F);
    .print("    Urgent:   ", U);
    .print("    Total:    ", S+F+U);
    .print("  Tareas completadas: ", TC);
    .print("  Errores totales:    ", E);
    .print("  --- Estado de robots ---");
    .send(scheduler, achieve, estado);
    .print("==========================================");
    .print("").


/* ============================================================================
 * MENSAJES DEL SCHEDULER
 * ============================================================================ */

/* Cuando el scheduler notifica un contenedor standard, aumentar su contador y comprobar espacio.
 * Solo procesamos el mensaje si viene del scheduler para evitar duplicados de otros agentes. */
+container_counted(CId, W, H, Weight, "standard")[source(scheduler)] <-
    ?standard_count(N); -standard_count(N); +standard_count(N+1);
    !check_space(nonurgent).

/* Ignorar container_counted de fuentes que no sean el scheduler */
+container_counted(CId, W, H, Weight, "standard")[source(S)] : S \== scheduler <- true.

/* Cuando el scheduler notifica un contenedor fragile, aumentar su contador y comprobar espacio */
+container_counted(CId, W, H, Weight, "fragile")[source(scheduler)] <-
    ?fragile_count(N); -fragile_count(N); +fragile_count(N+1);
    !check_space(nonurgent).

+container_counted(CId, W, H, Weight, "fragile")[source(S)] : S \== scheduler <- true.

/* Cuando el scheduler notifica un contenedor urgent, aumentar su contador y comprobar espacio */
+container_counted(CId, W, H, Weight, "urgent")[source(scheduler)] <-
    ?urgent_count(N); -urgent_count(N); +urgent_count(N+1);
    !check_space(urgent).

+container_counted(CId, W, H, Weight, "urgent")[source(S)] : S \== scheduler <- true.

/* ============================================================================
 * DETECCION DE FALTA DE ESPACIO
 * ============================================================================ */

/* Definición de grupos según tus objetivos concretos */
is_urgent_shelf(S) :- .member(S, ["shelf_1", "shelf_5", "shelf_8"]).
is_nonurgent_shelf(S) :- .member(S, ["shelf_2", "shelf_3", "shelf_4", "shelf_6", "shelf_7", "shelf_9"]).

/* Regla mejorada: no hay espacio si TODAS las estanterías del grupo están llenas */
// Comprobamos si NO existe ninguna estantería del grupo que tenga hueco
any_urgent_shelf_free :-
    is_urgent_shelf(S) & shelf_state(S, CW, CV) & 
    ((S == "shelf_1" & CW < 50 & CV < 8) | 
     (S == "shelf_5" & CW < 100 & CV < 12) | 
     (S == "shelf_8" & CW < 200 & CV < 20)).

any_nonurgent_shelf_free :-
    is_nonurgent_shelf(S) & shelf_state(S, CW, CV) & 
    (( (S=="shelf_2" | S=="shelf_3" | S=="shelf_4") & CW < 50 & CV < 8) |
     ( (S=="shelf_6" | S=="shelf_7") & CW < 100 & CV < 12) |
     ( S=="shelf_9" & CW < 200 & CV < 20)).

/* Plan para detectar falta de espacio para URGENTES */
+!check_space(urgent) : not any_urgent_shelf_free & not space_full(urgent) <-
    +space_full(urgent);
    .time(HH, MM, SS); .concat(HH, ":", MM, ":", SS, T);
    // LOG OBLIGATORIO
    .print("EVENT | time=", T, " | agent=supervisor | type=no_space_detected | data=urgent");
    // MENSAJE EXPLÍCITO AL SCHEDULER
    .send(scheduler, tell, no_space(urgent)).

/* Plan para detectar falta de espacio para NO URGENTES (Standard/Fragile) */
+!check_space(nonurgent) : not any_nonurgent_shelf_free & not space_full(nonurgent) <-
    +space_full(nonurgent);
    .time(HH, MM, SS); .concat(HH, ":", MM, ":", SS, T);
    // LOG OBLIGATORIO
    .print("EVENT | time=", T, " | agent=supervisor | type=no_space_detected | data=nonurgent");
    // MENSAJE EXPLÍCITO AL SCHEDULER
    .send(scheduler, tell, no_space(nonurgent)).

/* RESET: Si vuelve a haber espacio (cuando se vacíen las estanterías) */
+!check_space(Group) : (Group == urgent & any_urgent_shelf_free & space_full(urgent)) |
                      (Group == nonurgent & any_nonurgent_shelf_free & space_full(nonurgent)) <-
    -space_full(Group);
    .send(scheduler, untell, no_space(Group));
    .print("[Supervisor] Espacio recuperado en grupo: ", Group).

/* Fallback: si no hay cambios, no hacer nada */
+!check_space(_) <- true.


/* ============================================================================
 * REPORTE MANUAL
 * ============================================================================ */

/* Permitir lanzar el mismo informe periodico de forma manual */
+!reporte <- !generar_reporte.
