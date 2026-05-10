package warehouse;

import java.util.Map;
import java.util.Random;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import jason.asSyntax.Literal;
import jason.asSyntax.NumberTerm;
import jason.asSyntax.Structure;
import jason.environment.Environment;

/**
 * Artefacto del almacén automatizado.
 * Proporciona la API para la interacción de agentes con el entorno.
 * Gestiona la generación de contenedores, el grid, robots y estanterías.
 */
public class WarehouseArtifact extends Environment {

    // Dimensiones del almacén
    private static final int GRID_WIDTH = 20;
    private static final int GRID_HEIGHT = 15;

    // Posiciones en forma de L tumbada con el brazo largo abajo y el brazo
    // corto arriba a la derecha, en la parte exterior de la zona de entrada
    // (borde sur con el almacen + borde este con la zona de clasificacion):
    //
    // . . X <- (2,0)
    // X X X <- (0,1) (1,1) (2,1)
    //
    // La esquina superior izquierda (0,0) y la celda (1,0) quedan libres,
    // dando a los robots un pasillo recto por la fila y=0 para rodear.
    // Posiciones actualizadas para la nueva zona de entrada (5,0 a 7,1)
    private static final int[][] L_POSITIONS = {
            { 7, 0 }, { 5, 1 }, { 6, 1 }, { 7, 1 }
    };

    // Estructuras de datos del almacén
    private CellType[][] grid;
    private Map<String, Robot> robots;
    private Map<String, Container> containers;
    private Map<String, Shelf> shelves;
    private PriorityFIFOQueue pendingContainers;
    private Map<String, String> taskAssignments; // containerId -> robotId

    // GUI visual
    private WarehouseView view;

    // Contadores para generar IDs
    private int containerCounter = 0;

    // Métricas
    private int totalContainersProcessed = 0;
    private int totalErrors = 0;
    private long startTime;

    // Métricas del ciclo de salida (deadlines)
    private int deliveredUrgent = 0;
    private int deliveredNonurgent = 0;
    private int totalToDeliverUrgent = 0;
    private int totalToDeliverNonurgent = 0;
    private long deadlineEndUrgent = 0;
    private long deadlineEndNonurgent = 0;
    private String activeDeadline = "none";

    // Gestión del thread generador de contenedores
    private ExecutorService containerGeneratorExecutor;
    private volatile boolean running = true;

    @Override
    public void init(String[] args) {
        super.init(args);

        // Inicializar estructuras
        grid = new CellType[GRID_WIDTH][GRID_HEIGHT];
        robots = new ConcurrentHashMap<>();
        containers = new ConcurrentHashMap<>();
        shelves = new ConcurrentHashMap<>();
        pendingContainers = new PriorityFIFOQueue();
        taskAssignments = new ConcurrentHashMap<>();

        // Inicializar grid
        initializeGrid();

        // Crear robots
        initializeRobots();

        // Crear estanterías
        initializeShelves();

        // Crear GUI
        view = new WarehouseView(this, GRID_WIDTH, GRID_HEIGHT);
        view.setVisible(true);

        // Mensaje de bienvenida en la consola
        view.logMessage("========================================");
        view.logMessage("Sistema de almacén inicializado");
        view.logMessage("Rejilla: " + GRID_WIDTH + "x" + GRID_HEIGHT);
        view.logMessage("Robots: " + robots.size());
        view.logMessage("Estanterías: " + shelves.size());
        view.logMessage("========================================");
        view.logMessage("");

        // Iniciar generador de contenedores
        startContainerGenerator();

        // Agregar shutdown hook para limpieza apropiada
        Runtime.getRuntime().addShutdownHook(new Thread(this::stop));

        startTime = System.currentTimeMillis();

        System.out.println("Entorno de almacén inicializado");
        System.out.println("Tamaño de rejilla: " + GRID_WIDTH + "x" + GRID_HEIGHT);
        System.out.println("Robots: " + robots.size());
        System.out.println("Estanterías: " + shelves.size());
    }

    /**
     * Inicializa el grid con zonas reorganizadas
     */
    private void initializeGrid() {
        // Inicializar todos como vacíos
        for (int x = 0; x < GRID_WIDTH; x++) {
            for (int y = 0; y < GRID_HEIGHT; y++) {
                grid[x][y] = CellType.EMPTY;
            }
        }

        // Zona de SALIDA: (0,0) a (2,1)
        for (int x = 0; x <= 2; x++) {
            for (int y = 0; y <= 1; y++) {
                grid[x][y] = CellType.EXIT;
            }
        }

        // Zona de CLASIFICACIÓN: (3,0) a (4,1)
        for (int x = 3; x <= 4; x++) {
            for (int y = 0; y <= 1; y++) {
                grid[x][y] = CellType.CLASSIFICATION;
            }
        }

        // Zona de ENTRADA: (5,0) a (7,1)
        for (int x = 5; x <= 7; x++) {
            for (int y = 0; y <= 1; y++) {
                grid[x][y] = CellType.ENTRANCE;
            }
        }
    }

    /**
     * Crea los robots iniciales
     */
    private void initializeRobots() {
        // Robot Light
        Robot light = new Robot("robot_light", "light", 10, 1, 1, 3);
        light.setPosition(1, 3);
        robots.put("robot_light", light);

        // Robot Medium
        Robot medium = new Robot("robot_medium", "medium", 30, 1, 2, 2);
        medium.setPosition(2, 3);
        robots.put("robot_medium", medium);

        // Robot Heavy 1
        Robot heavy = new Robot("robot_heavy", "heavy", 100, 2, 3, 1);
        heavy.setPosition(3, 3);
        robots.put("robot_heavy", heavy);

        Robot heavy_2 = new Robot("robot_heavy_2", "heavy_2", 100, 2, 3, 1);
        heavy_2.setPosition(4, 3);
        robots.put("robot_heavy_2", heavy_2);

    }

    /**
     * Crea las estanterías del almacén
     */
    private void initializeShelves() {
        // Crear estanterías en el área de almacenamiento
        int shelfId = 1;

        // Fila de estanterías pequeñas
        for (int x = 10; x < 18; x += 2) {
            Shelf shelf = new Shelf("shelf_" + shelfId++, x, 2, 2, 2, 50, 8);
            shelves.put(shelf.getId(), shelf);
            grid[x][2] = CellType.SHELF;
            grid[x + 1][2] = CellType.SHELF;
            grid[x][3] = CellType.SHELF;
            grid[x + 1][3] = CellType.SHELF;
        }

        // Fila de estanterías medianas
        for (int x = 10; x < 18; x += 3) {
            Shelf shelf = new Shelf("shelf_" + shelfId++, x, 6, 3, 2, 100, 12);
            shelves.put(shelf.getId(), shelf);
            for (int dx = 0; dx < 3; dx++) {
                grid[x + dx][6] = CellType.SHELF;
                grid[x + dx][7] = CellType.SHELF;
            }
        }

        // Fila de estanterías grandes
        for (int x = 10; x < 16; x += 4) {
            Shelf shelf = new Shelf("shelf_" + shelfId++, x, 10, 4, 3, 200, 20);
            shelves.put(shelf.getId(), shelf);
            for (int dx = 0; dx < 4; dx++) {
                for (int dy = 0; dy < 3; dy++) {
                    grid[x + dx][10 + dy] = CellType.SHELF;
                }
            }
        }
    }

    /**
     * Inicia el generador automático de contenedores
     */
    private void startContainerGenerator() {
        containerGeneratorExecutor = Executors.newSingleThreadExecutor(r -> {
            Thread t = new Thread(r, "ContainerGenerator");
            t.setDaemon(true);
            return t;
        });

        containerGeneratorExecutor.submit(() -> {
            Random rand = new Random();
            while (running) {
                try {
                    Thread.sleep(3000);

                    if (!running)
                        break;

                    // Generar contenedor aleatorio
                    Container container = generateRandomContainer();
                    if (container == null) {
                        continue;
                    }
                    containers.put(container.getId(), container);
                    pendingContainers.offer(container);

                    System.out.println("Contenedor generado: " + container);

                    // Log a la consola de la GUI
                    if (view != null) {
                        view.logMessage(String.format("Nuevo contenedor: %s (%.1fkg, %s) [%dx%d] @(%d,%d)",
                                container.getId(), container.getWeight(), container.getType(),
                                container.getWidth(), container.getHeight(),
                                container.getX(), container.getY()));
                    }

                    // Notificar a los agentes
                    addPercept(Literal.parseLiteral("new_container(\"" + container.getId() + "\")"));
                    addPercept(Literal.parseLiteral(
                            "container_at(\"" + container.getId() + "\","
                                    + container.getX() + "," + container.getY() + ")"));

                    if (view != null) {
                        view.update();
                    }

                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
            System.out.println("Generador de contenedores detenido");
        });
    }

    /**
     * Detiene el entorno y finaliza el hilo generador de contenedores.
     */
    public void stop() {
        System.out.println("Deteniendo entorno de almacén...");
        running = false;

        if (containerGeneratorExecutor != null) {
            containerGeneratorExecutor.shutdown();
            try {
                if (!containerGeneratorExecutor.awaitTermination(5, TimeUnit.SECONDS)) {
                    containerGeneratorExecutor.shutdownNow();
                }
            } catch (InterruptedException e) {
                containerGeneratorExecutor.shutdownNow();
                Thread.currentThread().interrupt();
            }
        }

        System.out.println("Entorno de almacén detenido");
    }

    /**
     * Genera un contenedor con propiedades aleatorias y ubicacion de entrada.
     */
    private Container generateRandomContainer() {
        Random rand = new Random();
        String id = "container_" + (++containerCounter);

        // Tamaños posibles: 1x1, 1x2, 2x2, 2x3
        int[][] sizes = { { 1, 1 }, { 1, 2 }, { 2, 2 }, { 2, 3 } };
        int[] size = sizes[rand.nextInt(sizes.length)];

        // Peso aleatorio
        double weight = 5 + rand.nextDouble() * 95;

        // Tipo: standard (70%), fragile (15%), urgent (15%)
        String type;
        double r = rand.nextDouble();
        if (r < 0.70)
            type = "standard";
        else if (r < 0.85)
            type = "fragile";
        else
            type = "urgent";

        Container container = new Container(id, size[0], size[1], weight, type);

        int[] pos = findFreeLPosition();
        if (pos == null) {
            return null;
        }
        container.setPosition(pos[0], pos[1]);

        return container;
    }

    /**
     * Busca la primera posición libre en la zona de entrada en forma de L.
     */
    private int[] findFreeLPosition() {
        for (int[] pos : L_POSITIONS) {
            boolean free = true;
            for (Container c : containers.values()) {
                if (!c.isPicked() && c.getAssignedShelf() == null
                        && c.getX() == pos[0] && c.getY() == pos[1]) {
                    free = false;
                    break;
                }
            }
            if (free)
                return pos;
        }
        return null;
    }

    /**
     * Redirige la acción solicitada por el agente al método ejecutor correspondiente.
     */
    @Override
    public boolean executeAction(String agName, Structure action) {
        try {
            String actionName = action.getFunctor();

            switch (actionName) {
                case "move_to":
                    return executeMoveTo(agName, action);
                case "pickup":
                    return executePickup(agName, action);
                case "drop_at":
                    return executeDropAt(agName, action);
                case "pickup_from_shelf":
                    return executePickupFromShelf(agName, action);
                case "drop_at_exit":
                    return executeDropAtExit(agName, action);
                case "retire_from_exit":
                    return executeRetireFromExit(agName, action);
                case "register_deadline":
                    return executeRegisterDeadline(agName, action);
                case "end_deadline":
                    return executeEndDeadline(agName, action);
                case "get_container_info":
                    return executeGetContainerInfo(agName, action);
                default:
                    System.err.println("Unknown action: " + actionName);
                    return false;
            }
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Acción: move_to(X, Y)
     * Mueve el robot a la posición especificada
     */
    private boolean executeMoveTo(String agName, Structure action) {
        try {
            int targetX = (int) ((NumberTerm) action.getTerm(0)).solve();
            int targetY = (int) ((NumberTerm) action.getTerm(1)).solve();

            Robot robot = robots.get(agName);
            if (robot == null) {
                addError(agName, "robot_not_found", "Robot " + agName + " not found");
                return false;
            }

            if (targetX < 0 || targetX >= GRID_WIDTH || targetY < 0 || targetY >= GRID_HEIGHT) {
                addError(agName, "illegal_move", "Position out of bounds: (" + targetX + "," + targetY + ")");
                return false;
            }

            if (grid[targetX][targetY] == CellType.BLOCKED) {
                addError(agName, "route_blocked", "Position blocked: (" + targetX + "," + targetY + ")");
                return false;
            }

            for (Robot other : robots.values()) {
                if (!other.getId().equals(agName) && other.getX() == targetX && other.getY() == targetY) {
                    addError(agName, "conflict", "Conflict with " + other.getId());
                    return false;
                }
            }

            for (Container c : containers.values()) {
                if (!c.isPicked() && c.getAssignedShelf() == null
                        && c.getX() == targetX && c.getY() == targetY) {
                    addError(agName, "container_blocking",
                            "Container " + c.getId() + " at (" + targetX + "," + targetY + ")");
                    return false;
                }
            }

            robot.setPosition(targetX, targetY);

            // Si el robot lleva un contenedor, actualizar también su posición visual
            if (robot.isCarrying()) {
                Container carried = robot.getCarriedContainer();
                if (carried != null) {
                    carried.setPosition(targetX, targetY);
                }
            }

            if (view != null) {
                view.logMessage(String.format("%s se movió a (%d,%d)", agName, targetX, targetY));
            }

            removePerceptsByUnif(agName, Literal.parseLiteral("robot_at(_,_)"));
            addPercept(agName, Literal.parseLiteral("robot_at(" + targetX + "," + targetY + ")"));

            if (view != null) {
                view.update();
            }

            return true;

        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Acción: pickup(ContainerId)
     * Recoge un contenedor
     */
    private boolean executePickup(String agName, Structure action) {
        try {
            String containerId = action.getTerm(0).toString().replace("\"", "");
            Robot robot = robots.get(agName);
            Container container = containers.get(containerId);

            if (robot == null || container == null)
                return false;

            if (robot.distanceTo(container.getX(), container.getY()) > 1) {
                addError(agName, "too_far", "Distancia insuficiente");
                return false;
            }

            if (robot.pickup(container)) {
                container.setPicked(true);

                removePerceptsByUnif(Literal.parseLiteral("container_at(\"" + containerId + "\",_,_)"));
                removePerceptsByUnif(Literal.parseLiteral("new_container(\"" + containerId + "\")"));

                pendingContainers.remove(container);

                if (view != null) {
                    view.logMessage(String.format("%s recogió %s", agName, containerId));
                    view.update();
                }
                return true;
            }
            return false;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Acción: drop_at(ShelfId)
     * Deposita el contenedor en una estantería
     */
    private boolean executeDropAt(String agName, Structure action) {
        try {
            String shelfId = action.getTerm(0).toString().replace("\"", "");

            Robot robot = robots.get(agName);
            Shelf shelf = shelves.get(shelfId);

            if (robot == null || shelf == null) {
                addError(agName, "invalid_drop", "Robot or shelf not found");
                return false;
            }

            if (!robot.isCarrying()) {
                addError(agName, "not_carrying", "Robot is not carrying anything");
                return false;
            }

            int minDist = Integer.MAX_VALUE;
            for (int dx = 0; dx < shelf.getWidth(); dx++) {
                for (int dy = 0; dy < shelf.getHeight(); dy++) {
                    int d = robot.distanceTo(shelf.getX() + dx, shelf.getY() + dy);
                    if (d < minDist)
                        minDist = d;
                }
            }
            if (minDist > 1) {
                addError(agName, "too_far", "Shelf too far away");
                return false;
            }

            Container container = robot.getCarriedContainer();

            if (!shelf.canStore(container)) {
                addError(agName, "shelf_full", "Shelf " + shelfId + " cannot store container");
                return false;
            }

            shelf.store(container);
            robot.drop();
            container.setAssignedShelf(shelfId);

            totalContainersProcessed++;

            removePerceptsByUnif(agName, Literal.parseLiteral("picked(_)"));
            addPercept(agName, Literal.parseLiteral("stored(\"" + container.getId() + "\",\"" + shelfId + "\")"));

            if (view != null) {
                view.logMessage(String.format("%s almacenó %s en %s", agName, container.getId(), shelfId));
                view.update();
            }

            System.out.println(agName + " stored " + container.getId() + " at " + shelfId);

            if (view != null) {
                view.update();
            }

            return true;

        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Acción: get_container_info(ContainerId)
     * Recupera las propiedades del contenedor para el agente.
     */
    private boolean executeGetContainerInfo(String agName, Structure action) {
        try {
            String containerId = action.getTerm(0).toString().replace("\"", "");
            Container container = containers.get(containerId);

            if (container == null) {
                return false;
            }

            addPercept(agName, Literal.parseLiteral(
                    "container_info(\"" + containerId + "\"," +
                            container.getWidth() + "," +
                            container.getHeight() + "," +
                            container.getWeight() + ",\"" +
                            container.getType() + "\")"));

            return true;

        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Añade un percepto de error para el agente especificado.
     */
    private void addError(String agName, String errorType, String data) {
        totalErrors++;
        addPercept(agName, Literal.parseLiteral(
                "error(" + errorType + ",\"" + data + "\")"));
        System.err.println("ERROR [" + agName + "]: " + errorType + " - " + data);
    }

    // Getters
    public CellType[][] getGrid() {
        return grid;
    }

    public Map<String, Robot> getRobots() {
        return robots;
    }

    public Map<String, Container> getContainers() {
        return containers;
    }

    public Map<String, Shelf> getShelves() {
        return shelves;
    }

    public int getPendingContainersCount() {
        return pendingContainers.size();
    }

    public int getUrgentContainersCount() {
        return pendingContainers.urgentSize();
    }

    public int getNormalContainersCount() {
        return pendingContainers.normalSize();
    }

    public PriorityFIFOQueue getPendingQueue() {
        return pendingContainers;
    }

    public int getTotalContainersProcessed() {
        return totalContainersProcessed;
    }

    public int getTotalErrors() {
        return totalErrors;
    }

    public String getStatistics() {
        long elapsedTime = (System.currentTimeMillis() - startTime) / 1000;
        return String.format(
                "Time: %ds | Processed: %d | Pending: %d (Urgent: %d) | Errors: %d",
                elapsedTime, totalContainersProcessed, pendingContainers.size(), 
                pendingContainers.urgentSize(), totalErrors);
    }

    // ============================================================================
    // CLASE INTERNA: COLA DE PRIORIDAD FIFO
    // ============================================================================

    /**
     * Cola de prioridad FIFO para contenedores urgentes y normales.
     */
    public static class PriorityFIFOQueue {

        private ConcurrentLinkedQueue<Container> urgentQueue;
        private ConcurrentLinkedQueue<Container> normalQueue;

        public PriorityFIFOQueue() {
            this.urgentQueue = new ConcurrentLinkedQueue<>();
            this.normalQueue = new ConcurrentLinkedQueue<>();
        }

        /**
         * Añade un contenedor a la cola respetando prioridades
         * URGENTES: van a urgentQueue (se procesan primero)
         * NORMALES: van a normalQueue (se procesan después)
         */
        public void offer(Container container) {
            if ("urgent".equals(container.getType())) {
                urgentQueue.offer(container);
                System.out.println("[COLA] URGENTE añadido: " + container.getId() + 
                    " (Urgentes en cola: " + urgentQueue.size() + ")");
            } else {
                normalQueue.offer(container);
                System.out.println("[COLA] NORMAL añadido: " + container.getId());
            }
        }

        /**
         * Obtiene el siguiente contenedor de la cola
         * GARANTIZA que los URGENTES se procesan ANTES que los normales
         */
        public Container poll() {
            // PRIMERO: revisar urgentes
            Container urgent = urgentQueue.poll();
            if (urgent != null) {
                System.out.println("[COLA] Asignando URGENTE: " + urgent.getId());
                return urgent;
            }

            // SEGUNDO: revisar normales (solo si NO hay urgentes)
            Container normal = normalQueue.poll();
            if (normal != null) {
                System.out.println("[COLA] Asignando NORMAL: " + normal.getId());
            }
            return normal;
        }

        /**
         * Obtiene el siguiente sin removerlo
         */
        public Container peek() {
            Container urgent = urgentQueue.peek();
            if (urgent != null) {
                return urgent;
            }
            return normalQueue.peek();
        }

        /**
         * Obtiene el tamaño total de la cola
         */
        public int size() {
            return urgentQueue.size() + normalQueue.size();
        }

        /**
         * Obtiene el número de paquetes urgentes pendientes
         */
        public int urgentSize() {
            return urgentQueue.size();
        }

        /**
         * Obtiene el número de paquetes normales pendientes
         */
        public int normalSize() {
            return normalQueue.size();
        }

        /**
         * Revisa si la cola está vacía
         */
        public boolean isEmpty() {
            return urgentQueue.isEmpty() && normalQueue.isEmpty();
        }

        /**
         * Elimina un contenedor específico
         */
        public boolean remove(Container container) {
            return urgentQueue.remove(container) || normalQueue.remove(container);
        }

        /**
         * Verifica si un contenedor está en la cola
         */
        public boolean contains(Container container) {
            return urgentQueue.contains(container) || normalQueue.contains(container);
        }

        /**
         * Limpia la cola completamente
         */
        public void clear() {
            urgentQueue.clear();
            normalQueue.clear();
        }
    }

    /**
     * Acción: pickup_from_shelf(ContainerId, ShelfId)
     * Recoge un contenedor almacenado y actualiza el estado de la estantería.
     */
    private boolean executePickupFromShelf(String agName, Structure action) {
        try {
            String containerId = action.getTerm(0).toString().replace("\"", "");
            String shelfId = action.getTerm(1).toString().replace("\"", "");

            Robot robot = robots.get(agName);
            Shelf shelf = shelves.get(shelfId);
            Container container = containers.get(containerId);

            if (robot == null || shelf == null || container == null) {
                addError(agName, "invalid_pickup_from_shelf", "Robot, shelf o container no encontrado");
                return false;
            }

            if (robot.isCarrying()) {
                addError(agName, "already_carrying", "El robot ya lleva un contenedor");
                return false;
            }

            // Comprobar que el contenedor está realmente en esa estantería
            if (container.getAssignedShelf() == null || !container.getAssignedShelf().equals(shelfId)) {
                addError(agName, "container_not_in_shelf",
                        "Container " + containerId + " no está en " + shelfId);
                return false;
            }

            // Comprobar adyacencia a la estantería
            int minDist = Integer.MAX_VALUE;
            for (int dx = 0; dx < shelf.getWidth(); dx++) {
                for (int dy = 0; dy < shelf.getHeight(); dy++) {
                    int d = robot.distanceTo(shelf.getX() + dx, shelf.getY() + dy);
                    if (d < minDist) minDist = d;
                }
            }
            if (minDist > 1) {
                addError(agName, "too_far", "Shelf demasiado lejos");
                return false;
            }

            // Sacar el contenedor de la estantería: liberar capacidad y recogerlo
            try {
                shelf.remove(container.getId(),
                             (double) container.getWeight(),
                             container.getWidth() * container.getHeight());
            } catch (Exception ignored) {
                // contabilidad lógica también se hace en Jason via release_shelf
            }
            container.setAssignedShelf(null);
            container.setPicked(true);
            // Posicionar el contenedor en la posición del robot para que la vista lo dibuje
            container.setPosition(robot.getX(), robot.getY());
            robot.pickup(container);

            // Percepts consistentes con un pickup normal
            removePerceptsByUnif(Literal.parseLiteral("stored(\"" + containerId + "\",_)"));
            addPercept(agName, Literal.parseLiteral("picked(\"" + containerId + "\")"));
            addPercept(agName, Literal.parseLiteral("picked_from_shelf(\"" + containerId + "\",\"" + shelfId + "\")"));

            if (view != null) {
                view.logMessage(String.format("%s recogió %s de %s", agName, containerId, shelfId));
                view.update();
            }
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Acción: drop_at_exit(X, Y)
     * Deposita el contenedor en la zona de salida y actualiza sus percepciones.
     */
    private boolean executeDropAtExit(String agName, Structure action) {
        try {
            int targetX = (int) ((NumberTerm) action.getTerm(0)).solve();
            int targetY = (int) ((NumberTerm) action.getTerm(1)).solve();

            Robot robot = robots.get(agName);
            if (robot == null) {
                addError(agName, "invalid_drop_at_exit", "Robot no encontrado");
                return false;
            }

            if (!robot.isCarrying()) {
                addError(agName, "not_carrying", "El robot no lleva contenedor");
                return false;
            }

            // Validar que (X,Y) es zona de salida (X 0-2, Y 0-1)
            if (targetX < 0 || targetX > 2 || targetY < 0 || targetY > 1) {
                addError(agName, "not_exit_zone", "(" + targetX + "," + targetY + ") no es zona de salida");
                return false;
            }

            // Validar que el robot está en esa celda o adyacente
            int dx = Math.abs(robot.getX() - targetX);
            int dy = Math.abs(robot.getY() - targetY);
            if (dx + dy > 1) {
                addError(agName, "too_far_exit", "Robot demasiado lejos de la zona de salida");
                return false;
            }

            Container container = robot.getCarriedContainer();
            String containerId = container.getId();
            String containerType = container.getType();
            robot.drop();

            // Posicionar el contenedor en la celda de la zona de salida
            container.setPosition(targetX, targetY);
            container.setPicked(false);
            container.setAssignedShelf(null);

            // Incrementar contador de entregados según tipo
            if ("urgent".equals(containerType)) {
                deliveredUrgent++;
            } else {
                deliveredNonurgent++;
            }

            // Hacer visible su posición a todos los agentes
            removePerceptsByUnif(Literal.parseLiteral("container_at(\"" + containerId + "\",_,_)"));
            addPercept(Literal.parseLiteral("container_at(\"" + containerId + "\","
                    + targetX + "," + targetY + ")"));
            addPercept(Literal.parseLiteral("at_exit(\"" + containerId + "\")"));
            removePerceptsByUnif(agName, Literal.parseLiteral("picked(_)"));

            addPercept(agName, Literal.parseLiteral("delivered(\"" + containerId + "\")"));

            if (view != null) {
                view.logMessage(String.format("%s depositó %s en zona de salida (%d,%d)",
                        agName, containerId, targetX, targetY));
                view.update();
            }
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Acción: retire_from_exit(ContainerId)
     * Retira el contenedor de la zona de salida y limpia sus perceptos.
     */
    private boolean executeRetireFromExit(String agName, Structure action) {
        try {
            String containerId = action.getTerm(0).toString().replace("\"", "");
            Container container = containers.get(containerId);
            if (container == null) {
                addError(agName, "container_not_found", "Container " + containerId + " not found");
                return false;
            }
            removePerceptsByUnif(Literal.parseLiteral("container_at(\"" + containerId + "\",_,_)"));
            removePerceptsByUnif(Literal.parseLiteral("at_exit(\"" + containerId + "\")"));
            containers.remove(containerId);
            if (view != null) {
                view.logMessage(String.format("Transport retira %s de zona de salida", containerId));
                view.update();
            }
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Acción: register_deadline(Group, TotalToDeliver, EndTimeMs)
     * El scheduler informa al artifact del deadline activo.
     */
    private boolean executeRegisterDeadline(String agName, Structure action) {
        try {
            String group = action.getTerm(0).toString().replace("\"", "");
            int total = (int) ((NumberTerm) action.getTerm(1)).solve();
            long endTime = (long) ((NumberTerm) action.getTerm(2)).solve();
            if ("urgent".equals(group)) {
                totalToDeliverUrgent = total;
                deliveredUrgent = 0;
                deadlineEndUrgent = endTime;
                activeDeadline = "urgent";
            } else {
                totalToDeliverNonurgent = total;
                deliveredNonurgent = 0;
                deadlineEndNonurgent = endTime;
                activeDeadline = "nonurgent";
            }
            if (view != null) {
                view.logMessage(String.format("Deadline %s iniciado: %d contenedores a entregar",
                        group, total));
                view.update();
            }
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Acción: end_deadline(Group)
     * El scheduler informa al artifact que el deadline terminó.
     */
    private boolean executeEndDeadline(String agName, Structure action) {
        try {
            String group = action.getTerm(0).toString().replace("\"", "");
            activeDeadline = "none";
            if (view != null) {
                int delivered = "urgent".equals(group) ? deliveredUrgent : deliveredNonurgent;
                int total = "urgent".equals(group) ? totalToDeliverUrgent : totalToDeliverNonurgent;
                view.logMessage(String.format("Deadline %s terminado: %d/%d entregados",
                        group, delivered, total));
                view.update();
            }
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    // Getters para que la WarehouseView muestre la información del deadline
    public int getDeliveredUrgent()         { return deliveredUrgent; }
    public int getDeliveredNonurgent()      { return deliveredNonurgent; }
    public int getTotalToDeliverUrgent()    { return totalToDeliverUrgent; }
    public int getTotalToDeliverNonurgent() { return totalToDeliverNonurgent; }
    public String getActiveDeadline()       { return activeDeadline; }
    public long getDeadlineRemainingMs() {
        long now = System.currentTimeMillis();
        if ("urgent".equals(activeDeadline))    return Math.max(0, deadlineEndUrgent - now);
        if ("nonurgent".equals(activeDeadline)) return Math.max(0, deadlineEndNonurgent - now);
        return 0;
    }
}