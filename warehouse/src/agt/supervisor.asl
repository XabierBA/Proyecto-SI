/*******************************************************************************
 * SUPERVISOR - Monitor y gestor de errores del sistema
 *
 * Universidad de Vigo - Sistemas Inteligentes - Curso 2025-2026
 *
 * RESPONSABILIDADES:
 *   1. Monitorizar el estado general del sistema
 *   2. Recibir y registrar errores de robots y scheduler
 *   3. Generar reportes periódicos
 *   4. Detectar situaciones anómalas (robots bloqueados, etc.)
 ******************************************************************************/

/* ============================================================================
 * CREENCIAS INICIALES
 * ============================================================================ */

error_count(0).
report_interval(30).     /* segundos entre reportes automáticos */
last_report(0).

/* ============================================================================
 * INICIALIZACIÓN
 * ============================================================================ */

+!start : true <-
    .print("[Supervisor] ============================================");
    .print("[Supervisor] Sistema de monitorización iniciado");
    .print("[Supervisor] Reportes automáticos cada 30 segundos");
    .print("[Supervisor] ============================================");
    !monitoring_loop.

/* ============================================================================
 * CICLO DE MONITORIZACIÓN
 * ============================================================================ */

+!monitoring_loop : true <-
    .print("[Supervisor] 🔍 Monitorizando sistema...");
    .wait(5000);                      /* cada 5 segundos */
    !monitoring_loop.

/* ============================================================================
 * REPORTE PERIÓDICO
 * ============================================================================ */

/* Cada 30 segundos, solicitar estado al scheduler */
+!generate_report : true <-
    .time(T);
    ?last_report(LR);
    ?report_interval(RI);
    T - LR >= RI & T - LR < RI + 2 <-  /* margen para evitar múltiples disparos */
    .print("[Supervisor] 📊 Generando reporte periódico...");
    .send(scheduler, achieve, print_status);
    -+last_report(T).

/* ============================================================================
 * RECEPCIÓN DE ERRORES
 * ============================================================================ */

/* Error de robot */
+robot_error(Robot, CId, ErrorType)[source(_)] : true <-
    ?error_count(N);
    -error_count(N);
    +error_count(N+1);
    .time(T);
    .print("[Supervisor] ❌ ERROR REGISTRADO [", T, "]: ", 
           Robot, " - ", ErrorType, " - Contenedor: ", CId);
    
    /* Detectar patrones de error */
    +error_log(ErrorType, Robot, CId, T).

/* Error del scheduler (si envía alguno) */
+error(ErrorType, Data)[source(scheduler)] : true <-
    ?error_count(N);
    -error_count(N);
    +error_count(N+1);
    .print("[Supervisor] ❌ ERROR SCHEDULER: ", ErrorType, " - ", Data).

/* ============================================================================
 * ANÁLISIS DE ERRORES
 * ============================================================================ */

/* Detectar muchos errores del mismo tipo */
+!analyze_errors : error_count(N) & N > 10 <-
    .print("[Supervisor] ⚠️ ALERTA: Se han registrado ", N, " errores totales");
    .print("[Supervisor] Se recomienda revisar la configuración del sistema").

/* ============================================================================
 * COMANDOS EXTERNOS
 * ============================================================================ */

/* Solicitar reporte manual */
+!report : true <-
    ?error_count(E);
    .print("[Supervisor] 📊 REPORTE MANUAL");
    .print("[Supervisor] Total errores: ", E);
    .send(scheduler, achieve, print_status).

/* ============================================================================
 * INFORMACIÓN DE ESTADO DE ROBOTS (opcional)
 * ============================================================================ */

/* Escuchar estado de robots desde scheduler */
+robot_status(Robot, Status)[source(scheduler)] : true <-
    .print("[Supervisor] 🤖 Estado de ", Robot, ": ", Status).