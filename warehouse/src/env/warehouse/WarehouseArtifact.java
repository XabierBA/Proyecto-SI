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
 * Artefacto del almacén automatizado
 * Proporciona la API para que los agentes interactúen con el entorno
 */
public class WarehouseArtifact extends Environment {
    
    // Dimensiones del almacén
    private static final int GRID_WIDTH = 20;
    private static final int GRID_HEIGHT = 15;

    // Posiciones en forma de L tumbada con el brazo largo abajo y el brazo
    // corto arriba a la derecha, en la parte exterior de la zona de entrada
    // (borde sur con el almacen + borde este con la zona de clasificacion):
    //
    //   . . X       <- (2,0)
    //   X X X       <- (0,1) (1,1) (2,1)
    //
    // La esquina superior izquierda (0,0) y la celda (1,0) quedan libres,
    // dando a los robots un pasillo recto por la fila y=0 para rodear.
    // Posiciones actualizadas para la nueva zona de entrada (5,0 a 7,1)
    private static final int[][] L_POSITIONS = {
        {7, 0}, {5, 1}, {6, 1}, {7, 1}
    };
    
    // Estructuras de datos del almacén
    private CellType[][] grid;
    private Map<String, Robot> robots;
    private Map<String, Container> containers;
    private Map<String, Shelf> shelves;
    private ConcurrentLinkedQueue<Container> pendingContainers;
    private Map<String, String> taskAssignments; // containerId -> robotId
    
    // GUI visual
    private WarehouseView view;
    
    // Contadores para generar IDs
    private int containerCounter = 0;
    
    // Métricas
    private int totalContainersProcessed = 0;
    private int totalErrors = 0;
    private long startTime;
    
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
        pendingContainers = new ConcurrentLinkedQueue<>();
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
        view.logMessage("✨ ========================================");
        view.logMessage("🏢 Warehouse Management System Initialized");
        view.logMessage("   Grid: " + GRID_WIDTH + "x" + GRID_HEIGHT);
        view.logMessage("   Robots: " + robots.size());
        view.logMessage("   Shelves: " + shelves.size());
        view.logMessage("✨ ========================================");
        view.logMessage("");
        
        // Iniciar generador de contenedores
        startContainerGenerator();
        
        // Agregar shutdown hook para limpieza apropiada
        Runtime.getRuntime().addShutdownHook(new Thread(this::stop));
        
        startTime = System.currentTimeMillis();
        
        System.out.println("Warehouse environment initialized");
        System.out.println("Grid size: " + GRID_WIDTH + "x" + GRID_HEIGHT);
        System.out.println("Robots: " + robots.size());
        System.out.println("Shelves: " + shelves.size());
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
    
    // Robot Heavy 1 (Cambiamos el nombre a robot_heavy_1)
    Robot heavy = new Robot("robot_heavy", "heavy", 100, 2, 3, 1);
    heavy.setPosition(3, 3);
    robots.put("robot_heavy", heavy);

    // Robot Heavy 2 (Nueva instancia con ID único y posición distinta)
    //Robot heavy2 = new Robot("robot_heavy_2", "heavy", 100, 2, 3, 1);
    //heavy2.setPosition(4, 3); // Lo ponemos en la celda de al lado
    //robots.put("robot_heavy_2", heavy2);
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
            grid[x+1][2] = CellType.SHELF;
            grid[x][3] = CellType.SHELF;
            grid[x+1][3] = CellType.SHELF;
        }
        
        // Fila de estanterías medianas
        for (int x = 10; x < 18; x += 3) {
            Shelf shelf = new Shelf("shelf_" + shelfId++, x, 6, 3, 2, 100, 12);
            shelves.put(shelf.getId(), shelf);
            for (int dx = 0; dx < 3; dx++) {
                grid[x+dx][6] = CellType.SHELF;
                grid[x+dx][7] = CellType.SHELF;
            }
        }
        
        // Fila de estanterías grandes
        for (int x = 10; x < 16; x += 4) {
            Shelf shelf = new Shelf("shelf_" + shelfId++, x, 10, 4, 3, 200, 20);
            shelves.put(shelf.getId(), shelf);
            for (int dx = 0; dx < 4; dx++) {
                for (int dy = 0; dy < 3; dy++) {
                    grid[x+dx][10+dy] = CellType.SHELF;
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
                    Thread.sleep(3000); // Entre 5 y 10 segundos
                    
                    if (!running) break;
                    
                    // Generar contenedor aleatorio
                    Container container = generateRandomContainer();
                    if (container == null) {
                        // Zona de entrada llena, esperar al siguiente ciclo
                        continue;
                    }
                    containers.put(container.getId(), container);
                    pendingContainers.offer(container);
                    
                    System.out.println("New container generated: " + container);
                    
                    // Log a la consola de la GUI
                    if (view != null) {
                        view.logMessage(String.format("🆕 New container: %s (%.1fkg, %s) @(%d,%d)",
                            container.getId(), container.getWeight(), container.getType(),
                            container.getX(), container.getY()));
                    }
                    
                    // Notificar a los agentes (percepciones globales)
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
            System.out.println("Container generator stopped");
        });
    }
    
    /**
     * Detiene el entorno de forma limpia
     */
    public void stop() {
        System.out.println("Stopping warehouse environment...");
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
        
        System.out.println("Warehouse environment stopped");
    }
    
    /**
     * Genera un contenedor aleatorio
     */
    private Container generateRandomContainer() {
        Random rand = new Random();
        String id = "container_" + (++containerCounter);
        
        // Tamaños posibles: 1x1, 1x2, 2x2, 2x3
        int[][] sizes = {{1,1}, {1,2}, {2,2}, {2,3}};
        int[] size = sizes[rand.nextInt(sizes.length)];
        
        // Peso aleatorio
        double weight = 5 + rand.nextDouble() * 95; // 5 a 100 kg
        
        // Tipo: standard (70%), fragile (15%), urgent (15%)
        String type;
        double r = rand.nextDouble();
        if (r < 0.70) type = "standard";
        else if (r < 0.85) type = "fragile";
        else type = "urgent";
        
        Container container = new Container(id, size[0], size[1], weight, type);

        // Buscar primera posición libre en la L de la zona de entrada
        int[] pos = findFreeLPosition();
        if (pos == null) {
            return null; // todas las posiciones ocupadas; saltar generación
        }
        container.setPosition(pos[0], pos[1]);

        return container;
    }

    /**
     * Busca la primera posición libre en la L de la zona de entrada.
     * Devuelve null si todas están ocupadas.
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
            if (free) return pos;
        }
        return null;
    }
    
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
            
            // Verificar límites
            if (targetX < 0 || targetX >= GRID_WIDTH || targetY < 0 || targetY >= GRID_HEIGHT) {
                addError(agName, "illegal_move", "Position out of bounds: (" + targetX + "," + targetY + ")");
                return false;
            }
            
            // Verificar si hay obstáculos (excepto estanterías que son destinos válidos)
            if (grid[targetX][targetY] == CellType.BLOCKED) {
                addError(agName, "route_blocked", "Position blocked: (" + targetX + "," + targetY + ")");
                return false;
            }
            
            // Verificar conflictos con otros robots
            for (Robot other : robots.values()) {
                if (!other.getId().equals(agName) && other.getX() == targetX && other.getY() == targetY) {
                    addError(agName, "conflict", "Conflict with " + other.getId());
                    return false;
                }
            }

            // Verificar contenedores en el destino (no se puede pasar por encima)
            for (Container c : containers.values()) {
                if (!c.isPicked() && c.getAssignedShelf() == null
                        && c.getX() == targetX && c.getY() == targetY) {
                    addError(agName, "container_blocking",
                        "Container " + c.getId() + " at (" + targetX + "," + targetY + ")");
                    return false;
                }
            }
            
            // Mover robot
            robot.setPosition(targetX, targetY);
            
            // Log a la consola de la GUI
            if (view != null) {
                view.logMessage(String.format("➡️  %s moved to (%d,%d)", agName, targetX, targetY));
            }
            
            // Actualizar percepción
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

            if (robot == null || container == null) return false;

            if (robot.distanceTo(container.getX(), container.getY()) > 1) {
                addError(agName, "too_far", "Distancia insuficiente");
                return false;
            }

            if (robot.pickup(container)) {
                container.setPicked(true);
                
                // === LÍNEAS CRÍTICAS A MODIFICAR/AÑADIR ===
                // Borrar inmediatamente la percepción de posición para TODOS los agentes
                removePerceptsByUnif(Literal.parseLiteral("container_at(\"" + containerId + "\",_,_)"));
                removePerceptsByUnif(Literal.parseLiteral("new_container(\"" + containerId + "\")"));
                
                // Quitar de la cola de pendientes interna del Java
                pendingContainers.removeIf(c -> c.getId().equals(containerId));
                // =========================================

                if (view != null) {
                    view.logMessage(String.format("📦 %s recogió %s", agName, containerId));
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
            
            // Verificar distancia al contorno de la estantería (cualquier celda perimetral)
            int minDist = Integer.MAX_VALUE;
            for (int dx = 0; dx < shelf.getWidth(); dx++) {
                for (int dy = 0; dy < shelf.getHeight(); dy++) {
                    int d = robot.distanceTo(shelf.getX() + dx, shelf.getY() + dy);
                    if (d < minDist) minDist = d;
                }
            }
            if (minDist > 1) {
                addError(agName, "too_far", "Shelf too far away");
                return false;
            }
            
            Container container = robot.getCarriedContainer();
            
            // Verificar si cabe en la estantería
            if (!shelf.canStore(container)) {
                addError(agName, "shelf_full", "Shelf " + shelfId + " cannot store container");
                return false;
            }
            
            // Depositar
            shelf.store(container);
            robot.drop();
            container.setAssignedShelf(shelfId);
            
            totalContainersProcessed++;
            
            // Actualizar percepciones
            removePerceptsByUnif(agName, Literal.parseLiteral("picked(_)"));
            addPercept(agName, Literal.parseLiteral("stored(\"" + container.getId() + "\",\"" + shelfId + "\")"));
            
            if (view != null) {
                view.logMessage(String.format("✅ %s stored %s at %s", agName, container.getId(), shelfId));
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
     * Obtiene información sobre un contenedor
     */
    private boolean executeGetContainerInfo(String agName, Structure action) {
        try {
            String containerId = action.getTerm(0).toString().replace("\"", "");
            Container container = containers.get(containerId);
            
            if (container == null) {
                return false;
            }
            
            // Agregar percepción con información del contenedor
            addPercept(agName, Literal.parseLiteral(
                "container_info(\"" + containerId + "\"," + 
                container.getWidth() + "," + 
                container.getHeight() + "," + 
                container.getWeight() + ",\"" + 
                container.getType() + "\")"
            ));
            
            return true;
            
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }
    
    /**
     * Agrega un error a las percepciones
     */
    private void addError(String agName, String errorType, String data) {
        totalErrors++;
        addPercept(agName, Literal.parseLiteral(
            "error(" + errorType + ",\"" + data + "\")"
        ));
        System.err.println("ERROR [" + agName + "]: " + errorType + " - " + data);
    }
    
    // Getters para la vista
    public CellType[][] getGrid() { return grid; }
    public Map<String, Robot> getRobots() { return robots; }
    public Map<String, Container> getContainers() { return containers; }
    public Map<String, Shelf> getShelves() { return shelves; }
    public int getPendingContainersCount() { return pendingContainers.size(); }
    public int getTotalContainersProcessed() { return totalContainersProcessed; }
    public int getTotalErrors() { return totalErrors; }
    
    public String getStatistics() {
        long elapsedTime = (System.currentTimeMillis() - startTime) / 1000;
        return String.format(
            "Time: %ds | Processed: %d | Pending: %d | Errors: %d",
            elapsedTime, totalContainersProcessed, pendingContainers.size(), totalErrors
        );
    }
}