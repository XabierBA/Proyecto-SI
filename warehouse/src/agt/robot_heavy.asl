/*******************************************************************************
<<<<<<< Updated upstream
 * ROBOT HEAVY - Peso máximo: 100 kg, Tamaño: 3×3, Velocidad: Baja (1)
 * Hereda de robot_base
 ******************************************************************************/

/* Configuración específica Heavy */
robot_type(heavy).
max_weight(100).
max_size(3).
speed(1).

position(3,3).
base(3,3).

/* Importar comportamiento base desde robot_base.asl */
/* Los planes vienen incluidos al usar esta como AgentClass */
=======
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
>>>>>>> Stashed changes
