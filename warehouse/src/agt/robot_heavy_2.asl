/*******************************************************************************
 * ROBOT HEAVY 2 - Particularidades
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

/* Particularidades del robot heavy 2 */
position(4,3).
base(4,3).
step_wait(500).            /* velocidad baja */
my_capacity(100, 2, 3).    /* peso, ancho, alto */
default_shelf("shelf_8").



/* Subasta: cuarta prioridad — delay mayor que heavy_1
   para que entre los dos pesados también haya orden determinista */
bid_delay(900).
peer_bid_delay(robot_light,   0).
peer_bid_delay(robot_medium,  400).
peer_bid_delay(robot_heavy, 800).