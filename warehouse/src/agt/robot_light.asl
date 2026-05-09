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
position(1,3).
base(1,3).
step_wait(150).            /* velocidad alta -> espera corta */
my_capacity(10, 1, 1).     /* peso, ancho, alto */
default_shelf("shelf_1").



/* Subasta: máxima prioridad, puja primero */
bid_delay(0).
peer_bid_delay(robot_medium,  400).
peer_bid_delay(robot_heavy, 800).
peer_bid_delay(robot_heavy_2, 900).