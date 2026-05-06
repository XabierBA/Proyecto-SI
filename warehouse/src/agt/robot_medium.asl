/*******************************************************************************
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
