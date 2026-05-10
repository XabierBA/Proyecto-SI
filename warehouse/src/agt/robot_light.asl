/*******************************************************************************
 * ROBOT LIGHT - Particularidades
 *
 * Universidad de Vigo - Sistemas Inteligentes
 * Curso 2025-2026
 *
 * CAPACIDADES:
 *   - Peso maximo: 10 kg
 *   - Tamano maximo: 1x1
 *   - Velocidad: Alta (3)
 ******************************************************************************/

{ include("robot_common.asl") }

/* Particularidades del robot light */
/* Configuración específica de posición, capacidad y comportamiento de subasta. */
position(1,3).
base(1,3).
step_wait(150).            /* velocidad alta -> espera corta */
my_capacity(10, 1, 1).     /* peso, ancho, alto */
default_shelf("shelf_1").
exit_drop_cell(0, 0).
exit_corridor_y(4).



/* Subasta: máxima prioridad, puja primero */
bid_delay(0).
peer_bid_delay(robot_medium,  400).
peer_bid_delay(robot_heavy, 800).
peer_bid_delay(robot_heavy_2, 900).

/* Capacidades de los peers (peso, ancho, alto) - para evitar esperas innecesarias */
peer_capacity(robot_medium,  30, 1, 2).
peer_capacity(robot_heavy,  100, 2, 3).
peer_capacity(robot_heavy_2,100, 2, 3).

/* Celda asignada en zona de salida (0,0)-(2,1) */
exit_slot(0, 0).