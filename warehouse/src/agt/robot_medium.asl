/*******************************************************************************
 * ROBOT MEDIUM - Particularidades
 *
 * Universidad de Vigo - Sistemas Inteligentes
 * Curso 2025-2026
 *
 * CAPACIDADES:
 *   - Peso maximo: 30 kg
 *   - Tamano maximo: 1x2
 *   - Velocidad: Media (2)
 ******************************************************************************/

{ include("robot_common.asl") }

/* Particularidades del robot medium */
/* Configuración específica de posición, capacidad y prioridad de subasta. */
position(2,3).
base(2,3).
step_wait(300).            /* velocidad media */
my_capacity(30, 1, 2).     /* peso, ancho, alto */
default_shelf("shelf_5").
exit_drop_cell(1, 0).
exit_corridor_y(5).



/* Subasta: segunda prioridad */
bid_delay(400).
peer_bid_delay(robot_light,   0).
peer_bid_delay(robot_heavy, 800).
peer_bid_delay(robot_heavy_2, 900).

peer_capacity(robot_light,    10, 1, 1).
peer_capacity(robot_heavy,   100, 2, 3).
peer_capacity(robot_heavy_2, 100, 2, 3).

exit_slot(1, 0).