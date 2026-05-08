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
position(2,3).
base(2,3).
step_wait(300).            /* velocidad media */
my_capacity(30, 1, 2).     /* peso, ancho, alto */
default_shelf("shelf_5").
