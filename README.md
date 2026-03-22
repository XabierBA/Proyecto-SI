# Warehouse Management System — Grupo SI-52

**Sistema Multiagente para Gestión Logística de Almacén Automatizado**  
Universidad de Vigo · Sistemas Inteligentes · Curso 2025-2026

---

##  Ejecución

```bash
jason warehouse.mas2j
```

**Requisitos:** Java 21+ y Jason 3.3.0

No se requiere ningún paso de compilación adicional. 

---

## Autores — Grupo SI-52

| Nombre | Correo |
|--------|--------|
| María Amalia González Vázquez: amalia05gvz@gmail.com |
| David Alonso Pérez: davidalonsoperez1944@gmail.com |
| Xabier Barreiro Alberte: xabitic1@gmail.com |
| Brais Cajide González: braiscg15@gmail.com |
| Joel Cambón Facal: joelcambonfacal@gmail.com |
| Carla González González: carlitagonzalez88@gmail.com |

---

## Archivos implementados

Todos los agentes implementados se encuentran en `src/agt/`:

| Archivo | Descripción |
|---------|-------------|
| `robot_light.asl` | Robot ligero · 10 kg · 1×1 · velocidad alta (150 ms/paso) · base (1,3) |
| `robot_medium.asl` | Robot medio · 30 kg · 1×2 · velocidad media (300 ms/paso) · base (2,3) |
| `robot_heavy.asl` | Robot pesado · 100 kg · 2×3 · velocidad baja (500 ms/paso) · base (3,3) |
| `scheduler.asl` | Planificador central · clasificación, asignación y gestión de errores |
| `supervisor.asl` | Monitor del sistema · estadísticas y reportes cada 30 s |

---

## Descripción de la solución

### Robots (robot_light / robot_medium / robot_heavy)

Los tres robots comparten **exactamente la misma lógica de comportamiento** y se diferencian únicamente en sus parámetros operativos (tiempo de espera entre movimientos y capacidad máxima de carga). Esta decisión es deliberada: el Scheduler se encarga de verificar que el robot asignado puede transportar el contenedor, por lo que los robots no necesitan razonar sobre sus propias capacidades.

**Comportamiento principal:**
- Estado interno simplificado a `idle` / `busy`, más la creencia `returning` para controlar el retorno a base.
- Cuando están libres, vuelven automáticamente a su posición base y esperan allí.
- Reciben tareas directamente del Scheduler vía `.send` (no las solicitan activamente).
- Navegación mediante algoritmo **greedy por intentos sucesivos** en movimientos cardinales (arriba/abajo/izquierda/derecha), con mecanismo de reintento ante bloqueos.
- Las celdas de estanterías y bordes del mapa están declaradas explícitamente como bloqueadas.
- Antes de dirigirse a recoger, ejecutan `nudge_up` para evitar conflictos en el área de entrada.

**Manejo de errores:**
- `container_too_heavy` / `container_too_big` / `shelf_full` → notifica al Scheduler con `robot_error` y restaura estado a `idle`.
- `too_far` → fallo recuperable, espera y reintenta la tarea.
- `conflict` / `route_blocked` → ignorados, el mecanismo de reintento los gestiona implícitamente.
- Fallo inesperado en `execute_task` → notifica `execution_failed` y restaura `idle`.

---

## Scheduler

Agente coordinador central con **visión global del sistema**. No espera solicitudes de los robots: reacciona a los eventos del entorno y asigna tareas de forma proactiva.

**Decisiones de diseño clave:**

- **Prioridad de robots: `light → medium → heavy`**  
  Se asigna siempre el robot de menor capacidad suficiente que esté libre. Esto preserva los robots más potentes para las cargas que realmente los requieren.

- **Selección de estantería: la más pequeña que admita el contenedor**  
  Se prueban en orden `shelf_1..4` (pequeñas, 50 kg/vol 8) → `shelf_5..7` (medianas, 100 kg/vol 12) → `shelf_8..9` (grandes, 200 kg/vol 20). Si ninguna cabe, se recurre a `get_free_shelf` como fallback.

- **Cola de pendientes**  
  Los contenedores que llegan cuando todos los robots están ocupados se guardan como creencias `pending`. Cada vez que un robot queda libre, el Scheduler recorre la cola completa e intenta asignar todos los pendientes.

- **Ocupación de estanterías gestionada internamente**  
  El Scheduler actualiza `shelf_data` en el momento de la asignación (no espera al depósito), lo que hace la selección más eficiente sin consultar al entorno.

- **Notificación al Supervisor**  
  Cada contenedor clasificado (`container_counted`), cada tarea completada (`task_done`) y cada error (`error_occurred`) se notifican al Supervisor. El Scheduler es el único punto de notificación.

- **Recuperación ante errores**  
  Si el contenedor sigue en cola, libera el robot y reintenta la asignación inmediatamente. Si ya no está en cola, lanza un ciclo completo de asignación de pendientes.

---

### Supervisor

Agente de monitorización **pasiva y reactiva**. No interviene en la operativa del almacén.

- Genera un **reporte cada 30 segundos** con el desglose de contenedores por tipo (standard/fragile/urgent), tareas completadas y errores totales.
- El reporte puede lanzarse manualmente en cualquier momento con el plan `!reporte`.
- Durante el reporte, delega la consulta del estado de los robots al Scheduler vía `.send(scheduler, achieve, estado)`, evitando mantener una copia propia que pudiera desincronizarse.
- Los errores se registran con detalle completo: robot que los originó, contenedor afectado y tipo de fallo.

---

## Limitaciones conocidas

- La ocupación de estanterías se reserva en el momento de la asignación. Si una tarea falla antes del depósito, la capacidad reservada no se libera automáticamente.
- El algoritmo de navegación greedy no garantiza encontrar camino en tiempo acotado si el entorno está muy congestionado; confía en los reintentos para resolver bloqueos implícitamente.
- No hay detección ni resolución explícita de conflictos entre robots que intenten ocupar la misma celda simultáneamente.

---

## Documentación adicional

La memoria técnica completa se encuentra en `doc/memoria.pdf` e incluye:
- Diagramas de entorno, organización, objetivos e interacción (metodología Prometheus)
- Diagramas de agente y de tareas para cada agente
- Diagrama del ciclo de vida de una tarea
- Diagrama del flujo de información entre agentes
- Análisis de resultados y conclusiones por agente
