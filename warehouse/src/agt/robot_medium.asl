/*******************************************************************************
<<<<<<< Updated upstream
 * ROBOT MEDIUM - Peso máximo: 30 kg, Tamaño: 2×2, Velocidad: Media (2)
 * Hereda de robot_base
 ******************************************************************************/

/* Configuración específica Medium */
robot_type(medium).
max_weight(30).
max_size(2).
speed(2).

position(2,3).
base(2,3).

/* Importar comportamiento base desde robot_base.asl */
/* Los planes vienen incluidos al usar esta como AgentClass */
=======
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
>>>>>>> Stashed changes
