/*******************************************************************************
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
