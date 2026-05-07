/*******************************************************************************
<<<<<<< Updated upstream
 * ROBOT LIGHT - Peso máximo: 10 kg, Tamaño: 1×1, Velocidad: Alta (3)
 * Hereda de robot_base
 ******************************************************************************/

/* Configuración específica Light */
robot_type(light).
max_weight(10).
max_size(1).
speed(3).

position(1,3).
base(1,3).

/* Importar comportamiento base desde robot_base.asl */
/* Los planes vienen incluidos al usar esta como AgentClass */
=======
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
>>>>>>> Stashed changes
