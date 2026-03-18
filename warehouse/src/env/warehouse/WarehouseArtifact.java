package warehouse;

import jason.asSyntax.*;
import jason.environment.Environment;
import jason.environment.grid.Location;

import java.util.*;
import java.util.concurrent.*;
import java.util.stream.Collectors;

/**
 * Artefacto del almacén automatizado
 * Proporciona la API para que los agentes interactúen con el entorno
 */
public class WarehouseArtifact extends Environment {
    
    // Dimensiones del almacén
    private static final int GRID_WIDTH = 20;
    private static final int GRID_HEIGHT = 15;
    
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
     * Inicializa el grid con zonas
     */
    private void initializeGrid() {
        // Inicializar todos como vacíos
        for (int x = 0; x < GRID_WIDTH; x++) {
            for (int y = 0; y < GRID_HEIGHT; y++) {
                grid[x][y] = CellType.EMPTY;
            }
        }
        
        // Zona de entrada (arriba izquierda)
        for (int x = 0; x < 3; x++) {
            for (int y = 0; y < 2; y++) {
                grid[x][y] = CellType.ENTRANCE;
            }
        }
        
        // Zona de clasificación
        for (int x = 3; x < 7; x++) {
            for (int y = 0; y < 2; y++) {
                grid[x][y] = CellType.CLASSIFICATION;
            }
        }
    }
    
    /**
     * Crea los robots iniciales
     */
    private void initializeRobots() {
        // Posiciones iniciales: (1,4),(3,4),(5,4) - carriles x=1,x=3,x=5
        Robot light = new Robot("robot_light", "light", 10, 1, 1, 3);
        light.setPosition(1, 4);
        robots.put("robot_light", light);

        Robot medium = new Robot("robot_medium", "medium", 30, 1, 2, 2);
        medium.setPosition(3, 4);
        robots.put("robot_medium", medium);

        Robot heavy = new Robot("robot_heavy", "heavy", 100, 2, 3, 1);
        heavy.setPosition(5, 4);
        robots.put("robot_heavy", heavy);
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
                    Thread.sleep(5000 + rand.nextInt(5000)); // Entre 5 y 10 segundos
                    
                    if (!running) break;
                    
                    // Generar contenedor aleatorio
                    Container container = generateRandomContainer();
                    containers.put(container.getId(), container);
                    pendingContainers.offer(container);
                    
                    System.out.println("New container generated: " + container);
                    
                    // Log a la consola de la GUI incluyendo dimensiones
                    if (view != null) {
                        view.logMessage(String.format("NEW  %s: %dx%d, %.1fkg, %s",
                            container.getId(),
                            container.getWidth(), container.getHeight(),
                            container.getWeight(), container.getType()));
                    }
                    
                    // Notificar a los agentes
                    addPercept(Literal.parseLiteral("new_container(\"" + container.getId() + "\")"));
                    
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
        container.setPosition(1, 1); // Posición inicial en zona de entrada
        
        return container;
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
                case "request_task":
                    return executeRequestTask(agName, action);
                case "get_container_info":
                    return executeGetContainerInfo(agName, action);
                case "get_free_shelf":
                    return executeGetFreeShelf(agName, action);
                case "scan_surroundings":
                    return executeScanSurroundings(agName, action);
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
            
            // Verificar limites
            if (targetX < 0 || targetX >= GRID_WIDTH || targetY < 0 || targetY >= GRID_HEIGHT) {
                addError(agName, "illegal_move", "Position out of bounds: (" + targetX + "," + targetY + ")");
                return false;
            }
            
            // Verificar que el movimiento sea de maximo 1 paso (incluye diagonal: Chebyshev <= 1)
            int dx = Math.abs(targetX - robot.getX());
            int dy = Math.abs(targetY - robot.getY());
            if (dx > 1 || dy > 1) {
                addError(agName, "illegal_move", "Move too large (max 1 step): from ("
                    + robot.getX() + "," + robot.getY() + ") to (" + targetX + "," + targetY + ")");
                return false;
            }
            
            // Verificar obstaculos: BLOCKED y SHELF (los robots no pueden pisar estanterias)
            if (grid[targetX][targetY] == CellType.BLOCKED) {
                addError(agName, "route_blocked", "Position blocked: (" + targetX + "," + targetY + ")");
                return false;
            }
            if (grid[targetX][targetY] == CellType.SHELF) {
                addError(agName, "route_blocked", "Cannot enter shelf cell: (" + targetX + "," + targetY + ")");
                return false;
            }
            
            // Verificar conflictos con otros robots
            for (Robot other : robots.values()) {
                if (!other.getId().equals(agName) && other.getX() == targetX && other.getY() == targetY) {
                    addError(agName, "conflict", "Conflict with " + other.getId());
                    return false;
                }
            }
            
            // Mover robot
            robot.setPosition(targetX, targetY);
            
            // Log a la consola de la GUI
            if (view != null) {
                view.logMessage(String.format("➡️  %s moved to (%d,%d)", agName, targetX, targetY));
            }
            
            // Actualizar percepcion privada del robot que se mueve
            removePerceptsByUnif(agName, Literal.parseLiteral("robot_at(_,_)"));
            addPercept(agName, Literal.parseLiteral("robot_at(" + targetX + "," + targetY + ")"));
            
            // Broadcast de posiciones de TODOS los robots a TODOS los agentes
            // Permite que cada robot sepa donde estan los demas antes de moverse
            for (Robot r : robots.values()) {
                String rId = r.getId();
                // Eliminar percepcion antigua de este robot en todos los agentes
                removePerceptsByUnif("robot_light",  Literal.parseLiteral("other_pos(\"" + rId + "\",_,_)"));
                removePerceptsByUnif("robot_medium", Literal.parseLiteral("other_pos(\"" + rId + "\",_,_)"));
                removePerceptsByUnif("robot_heavy",  Literal.parseLiteral("other_pos(\"" + rId + "\",_,_)"));
                // Agregar posicion actualizada
                String posLiteral = "other_pos(\"" + rId + "\"," + r.getX() + "," + r.getY() + ")";
                addPercept("robot_light",  Literal.parseLiteral(posLiteral));
                addPercept("robot_medium", Literal.parseLiteral(posLiteral));
                addPercept("robot_heavy",  Literal.parseLiteral(posLiteral));
            }
            
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
            
            if (robot == null || container == null) {
                addError(agName, "invalid_pickup", "Robot or container not found");
                return false;
            }
            
            // Verificar distancia
            if (robot.distanceTo(container.getX(), container.getY()) > 1) {
                addError(agName, "too_far", "Container too far away");
                return false;
            }
            
            // Verificar capacidad
            if (!robot.canCarry(container)) {
                if (container.getWeight() > robot.getMaxWeight()) {
                    addError(agName, "container_too_heavy", 
                        "Container " + containerId + " is too heavy for " + agName);
                } else {
                    addError(agName, "container_too_big", 
                        "Container " + containerId + " is too big for " + agName);
                }
                return false;
            }
            
            // Recoger contenedor
            if (robot.pickup(container)) {
                container.setPicked(true);
                addPercept(agName, Literal.parseLiteral("picked(\"" + containerId + "\")"));
                
                if (view != null) {
                    view.logMessage(String.format("📦 %s picked up %s (%.1fkg)", agName, containerId, container.getWeight()));
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
            
            // Verificar distancia a la estantería
            if (robot.distanceTo(shelf.getX(), shelf.getY()) > 2) {
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
            robot.setBusy(false);        // FIX: liberar robot para nuevas tareas
            robot.setCurrentTask(null);
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
     * Acción: request_task()
     * Solicita una nueva tarea del scheduler
     */
    private boolean executeRequestTask(String agName, Structure action) {
        try {
            Robot robot = robots.get(agName);
            if (robot == null) return false;
            
            // Si ya está ocupado, no asignar nueva tarea
            if (robot.isBusy() || robot.isCarrying()) {
                return true;
            }
            
            // Buscar el contenedor OPTIMO para este robot especifico:
            // Cada robot solo coge contenedores en su rango de capacidad exclusivo
            // para evitar que heavy acapare trabajo de light/medium.
            Container container = findBestContainerForRobot(robot);
            if (container == null) {
                return true; // No hay contenedor adecuado para este robot ahora
            }
            
            // Buscar estanteria apropiada para este contenedor especifico
            Shelf bestShelf = findBestShelf(container);
            if (bestShelf == null) {
                // No hay estanteria disponible para este contenedor ahora.
                // En lugar de bloquearlo al frente de la cola, buscar si hay
                // OTRO contenedor en la cola que si tenga estanteria disponible.
                // Si no se encuentra ninguno, devolver este al final de la cola.
                Container alternative = null;
                Shelf altShelf = null;
                List<Container> skipped = new java.util.ArrayList<>();
                skipped.add(container); // ya lo sacamos, lo ponemos al final
                
                // Intentar con los siguientes contenedores de la cola
                Container next;
                while ((next = pendingContainers.poll()) != null) {
                    if (robot.canCarry(next)) {
                        Shelf s = findBestShelf(next);
                        if (s != null) {
                            alternative = next;
                            altShelf = s;
                            break;
                        }
                    }
                    skipped.add(next);
                }
                
                // Devolver todos los saltados al final de la cola (preservar orden)
                for (Container c : skipped) {
                    pendingContainers.offer(c);
                }
                
                if (alternative == null) {
                    // Ningun contenedor tiene estanteria disponible ahora
                    return true;
                }
                
                // Usar el contenedor alternativo
                container = alternative;
                bestShelf = altShelf;
            }
            
            // Asignar tarea
            taskAssignments.put(container.getId(), agName);
            robot.setBusy(true);
            robot.setCurrentTask(container.getId());
            
            // Notificar al agente con informacion de tamaño del contenedor
            addPercept(agName, Literal.parseLiteral(
                "task(\"" + container.getId() + "\",\"" + bestShelf.getId() + "\")"
            ));
            addPercept(agName, Literal.parseLiteral(
                "container_size(\"" + container.getId() + "\"," +
                container.getWidth() + "," + container.getHeight() + "," +
                String.format("%.1f", container.getWeight()) + ",\"" + container.getType() + "\")"
            ));
            
            System.out.println("Task assigned to " + agName + ": " + container.getId() +
                " [" + container.getWidth() + "x" + container.getHeight() +
                ", " + String.format("%.1f", container.getWeight()) + "kg, " +
                container.getType() + "] -> " + bestShelf.getId());
            
            // Log en GUI con dimensiones visibles
            if (view != null) {
                view.logMessage(String.format("TASK %s -> %s | %dx%d %.1fkg %s -> %s",
                    agName, container.getId(),
                    container.getWidth(), container.getHeight(),
                    container.getWeight(), container.getType(),
                    bestShelf.getId()));
            }
            
            return true;
            
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }
    
    /**
     * Encuentra la mejor estantería para un contenedor
     */
    private Shelf findBestShelf(Container container) {
        List<Shelf> availableShelves = shelves.values().stream()
            .filter(s -> s.canStore(container))
            .sorted(Comparator.comparingDouble(Shelf::getOccupancyPercentage))
            .collect(Collectors.toList());
        
        return availableShelves.isEmpty() ? null : availableShelves.get(0);
    }
    
    /**
     * Encuentra el contenedor optimo para un robot especifico.
     *
     * REGLA: robot minimo suficiente.
     *   - light  : busca en TODA la cola el primer contenedor que SOLO el puede cargar
     *              (nadie mas pequeno puede -> trivialmente todos los que puede)
     *   - medium : busca en TODA la cola el primer contenedor que light NO puede pero el SI
     *   - heavy  : busca en TODA la cola el primer contenedor que ni light ni medium pueden
     *
     * Si no hay exclusivo disponible para este robot:
     *   - light  : coge cualquiera que pueda
     *   - medium : coge cualquiera que pueda (light tampoco podria o no esta disponible)
     *   - heavy  : coge cualquiera que pueda (fallback para no quedarse idle)
     *
     * IMPORTANTE: busca en toda la cola, no solo el primero. Asi un contenedor
     * grande al principio de la cola no impide que light/medium cojan uno pequeno
     * que este mas atras.
     */
    private Container findBestContainerForRobot(Robot robot) {
        List<Container> queue = new java.util.ArrayList<>(pendingContainers);
        if (queue.isEmpty()) return null;

        Robot light  = robots.get("robot_light");
        Robot medium = robots.get("robot_medium");

        // PASO 1: buscar contenedor exclusivo recorriendo TODA la cola
        for (Container c : queue) {
            if (!robot.canCarry(c)) continue;

            boolean lightCan  = (light  != null) && light.canCarry(c);
            boolean mediumCan = (medium != null) && medium.canCarry(c);

            boolean isExclusive;
            if (robot.getId().equals("robot_light")) {
                // light coge todo lo que pueda (es el mas pequeno, siempre es "exclusivo")
                isExclusive = true;
            } else if (robot.getId().equals("robot_medium")) {
                // medium solo coge lo que light NO puede manejar
                isExclusive = !lightCan;
            } else {
                // heavy solo coge lo que ni light ni medium pueden
                isExclusive = !lightCan && !mediumCan;
            }

            if (isExclusive) {
                pendingContainers.remove(c);
                return c;
            }
        }

        // PASO 2: no hay exclusivo en toda la cola.
        // NINGUN robot coge trabajo que corresponde a un robot menor.
        // Heavy: espera hasta que haya contenedor que ni light ni medium puedan.
        // Medium: puede coger lo que light no puede si no hay nada exclusivo suyo
        //         (util cuando light esta ocupado o no hay contenedores pequenos).
        // Light: ya es el mas pequeno, su exclusivo abarca todo lo que puede.
        if (robot.getId().equals("robot_medium")) {
            // medium fallback: cualquiera que pueda y que light NO pueda
            for (Container c : queue) {
                boolean lCan = (light != null) && light.canCarry(c);
                if (robot.canCarry(c) && !lCan) {
                    pendingContainers.remove(c);
                    return c;
                }
            }
        }
        // heavy nunca coge trabajo de light o medium -> se queda idle
        return null;
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
     * Acción: get_free_shelf(ContainerId)
     * Busca una estantería libre para un contenedor
     */
    private boolean executeGetFreeShelf(String agName, Structure action) {
        try {
            String containerId = action.getTerm(0).toString().replace("\"", "");
            Container container = containers.get(containerId);
            
            if (container == null) {
                return false;
            }
            
            Shelf shelf = findBestShelf(container);
            if (shelf != null) {
                addPercept(agName, Literal.parseLiteral(
                    "free_shelf(\"" + containerId + "\",\"" + shelf.getId() + "\")"
                ));
                return true;
            }
            
            return false;
            
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }
    
    /**
     * Acción: scan_surroundings()
     * Escanea las celdas alrededor del robot
     */
    private boolean executeScanSurroundings(String agName, Structure action) {
        try {
            Robot robot = robots.get(agName);
            if (robot == null) return false;
            
            int x = robot.getX();
            int y = robot.getY();
            
            // Escanear celdas adyacentes
            for (int dx = -2; dx <= 2; dx++) {
                for (int dy = -2; dy <= 2; dy++) {
                    int nx = x + dx;
                    int ny = y + dy;
                    
                    if (nx >= 0 && nx < GRID_WIDTH && ny >= 0 && ny < GRID_HEIGHT) {
                        CellType type = grid[nx][ny];
                        addPercept(agName, Literal.parseLiteral(
                            "cell(" + nx + "," + ny + "," + type.name().toLowerCase() + ")"
                        ));
                        
                        if (type == CellType.BLOCKED) {
                            addPercept(agName, Literal.parseLiteral("blocked(" + nx + "," + ny + ")"));
                        }
                    }
                }
            }
            
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
