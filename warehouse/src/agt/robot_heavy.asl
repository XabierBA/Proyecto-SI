/*******************************************************************************
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
