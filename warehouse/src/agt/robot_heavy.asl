/*******************************************************************************
 * ROBOT HEAVY - Particularidades
 *
 * Universidad de Vigo - Sistemas Inteligentes
 * Curso 2025-2026
 *
 * CAPACIDADES:
 *   - Peso maximo: 100 kg
 *   - Tamano maximo: 2x3
 *   - Velocidad: Baja (1)
 ******************************************************************************/

{ include("robot_common.asl") }

/* Particularidades del robot heavy */
position(3,3).
base(3,3).
step_wait(500).            /* velocidad baja */
my_capacity(100, 2, 3).    /* peso, ancho, alto */
default_shelf("shelf_9").



/* Subasta: tercera prioridad */
bid_delay(800).
peer_bid_delay(robot_light,   0).
peer_bid_delay(robot_medium,  400).
peer_bid_delay(robot_heavy_2, 900).