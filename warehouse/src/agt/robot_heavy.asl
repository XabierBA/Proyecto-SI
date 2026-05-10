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
/* Configuración específica de posición, capacidad y prioridad de subasta. */
position(3,3).
base(3,3).
step_wait(500).            /* velocidad baja */
my_capacity(100, 2, 3).    /* peso, ancho, alto */
default_shelf("shelf_9").
exit_drop_cell(2, 0).
exit_corridor_y(8).



/* Subasta: tercera prioridad */
bid_delay(800).
peer_bid_delay(robot_light,   0).
peer_bid_delay(robot_medium,  400).
peer_bid_delay(robot_heavy_2, 900).

peer_capacity(robot_light,    10, 1, 1).
peer_capacity(robot_medium,   30, 1, 2).
peer_capacity(robot_heavy_2, 100, 2, 3).

exit_slot(2, 0).