//Maze.swift

import RealityKit
import Combine

struct MazeConfiguration {
    var cellSize: Float = 0.5
    var wallHeight: Float = 0.3
    var wallThickness: Float = 0.1
    var ballRadius: Float = 0.08
    var floorHeight: Float = 0.05
    var startPosition: [Float] = [0.25, 0.5, 0.85]
}

//    Лабиринт
//
//    ## Использование:
//    1) Создайте MazeGenerator для получения
//    схемы лабиринта
//    1) Создайте экземпляр с использованием схемы
//    3) Получите лабиринт через getEntity

class Maze {
    
    private var _scene: Entity
    var matrix: [[Int]]
    var columns: Int
    var rows: Int
    var ball: Entity?
    var config: MazeConfiguration
    
    public func getEntity() -> Entity {
        return self._scene
    }
    
    init(matrix: [[Int]], config: MazeConfiguration = MazeConfiguration()) {
        self.matrix = matrix
        self.rows = matrix.count
        self.columns = matrix.first?.count ?? 0
        self.config = config
        
        self._scene = Maze.createMazeScene(matrix: matrix, config: config)
        self.ball = _scene.findEntity(named: "ball")
    }
    
    public func resetBallPosition() {
        guard let ball = ball else { return }
        
        ball.components.remove(PhysicsBodyComponent.self)
        
        ball.transform.translation = SIMD3<Float>(
            config.startPosition[0],
            config.startPosition[1],
            config.startPosition[2]
        )
        ball.transform.rotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        
        let shape = ShapeResource.generateSphere(radius: config.ballRadius)
        
        var physicsBody = PhysicsBodyComponent(
            shapes: [shape],
            mass: 10.0, // Оптимальная масса для стабильности
            material: .generate(friction: 0.01, restitution: 0.05), // Минимальные значения
            mode: .dynamic
        )
        
        physicsBody.linearDamping = 0 // затухание скорости
        physicsBody.angularDamping = 0  // гашение вращения
        physicsBody.isContinuousCollisionDetectionEnabled = true
        
        ball.components.set(physicsBody)
    }
    
    public func scale(factor: Float) {
        scaleMaze(self._scene, factor: factor)
    }
    
    private func scaleMaze(_ entity: Entity, factor: Float) {
        let originalPosition = entity.position
        entity.scale = [1, 1, 1]
        entity.position = [0, 0, 0]
        
        var transform = entity.transform
        transform.scale *= factor
        entity.transform = transform
        
        entity.position = originalPosition
    }
    
    private static func createMazeScene(matrix: [[Int]], config: MazeConfiguration) -> Entity {
        let scene = Entity()
        scene.name = "mazeScene"
        
        let rows = matrix.count
        let columns = matrix.first?.count ?? 0
        
        let (floor, holes) = createBaseFloor(
            rows: rows,
            columns: columns,
            config: config,
            matrix: matrix
        )
        scene.addChild(floor)
        holes.forEach { scene.addChild($0) }
        
        for (rowIndex, row) in matrix.enumerated() {
            for (colIndex, cellValue) in row.enumerated() {
                let position = SIMD3<Float>(
                    Float(colIndex) * config.cellSize + config.cellSize/2,
                    0,
                    Float(rowIndex) * config.cellSize + config.cellSize/2
                )
                
                switch cellValue {
                case 1:
                    let wall = createWall(
                        position: SIMD3<Float>(position.x, config.wallHeight/2, position.z),
                        size: SIMD3<Float>(config.cellSize, config.wallHeight, config.wallThickness),
                        config: config
                    )
                    scene.addChild(wall)
                    
                case 2:
                    let wall = createWall(
                        position: SIMD3<Float>(position.x, config.wallHeight/2, position.z),
                        size: SIMD3<Float>(config.wallThickness, config.wallHeight, config.cellSize),
                        config: config
                    )
                    scene.addChild(wall)
                    
                case 3:
                    createCorner(
                        at: position,
                        type: .topLeft,
                        scene: scene,
                        config: config
                    )
                    
                case 4:
                    createCorner(
                        at: position,
                        type: .topRight,
                        scene: scene,
                        config: config
                    )
                    
                case 5:
                    createCorner(
                        at: position,
                        type: .bottomLeft,
                        scene: scene,
                        config: config
                    )
                    
                case 6:
                    createCorner(
                        at: position,
                        type: .bottomRight,
                        scene: scene,
                        config: config
                    )
                    
                default:
                    break
                }
            }
        }
        
        let outerWalls = createOuterWalls(
            rows: rows,
            columns: columns,
            config: config
        )
        scene.addChild(outerWalls)
        
        let ball = createBall(
            position: [
                config.startPosition[0],
                config.startPosition[1],
                config.startPosition[2]
            ],
            config: config
        )
        scene.addChild(ball)
        
        let finish = createFinish(position: [
            Float(columns-1) * config.cellSize + config.cellSize/2,
            0.005,
            Float(rows-2) * config.cellSize + config.cellSize/2
        ])
        scene.addChild(finish)
        
        placeStars(in: scene, matrix: matrix, config: config)
        
//        // Рассчитываем центр лабиринта
//        let width = Float(columns) * config.cellSize
//        let depth = Float(rows) * config.cellSize
//        scene.position = [-width / 2, 0, -depth / 2]
        
        return scene
    }
    
    // MARK: - Element Creation
    
    private static func createBaseFloor(
        rows: Int,
        columns: Int,
        config: MazeConfiguration,
        matrix: [[Int]]
    ) -> (Entity, [Entity]) {
        let container = Entity()
        let material = SimpleMaterial(color: .lightGray, isMetallic: false)
        
        let physicsMaterial = PhysicsMaterialResource.generate(friction: 0.01, restitution: 0.01)
        
        var holes: [Entity] = []
        
        for row in 0..<rows {
            for col in 0..<columns {
                let position = SIMD3<Float>(
                    Float(col) * config.cellSize + config.cellSize/2,
                    -0.02,
                    Float(row) * config.cellSize + config.cellSize/2
                )
                
                if matrix[row][col] == 0 &&
                   !(row == 1 && col == 0) &&
                   !(row == rows-2 && col == columns-1) &&
                   Float.random(in: 0..<1) < 0.1 {
                    
                    let hole = createHole(position: position)
                    holes.append(hole)
                } else {
                    let tile = ModelEntity(
                        mesh: .generateBox(size: [config.cellSize, config.floorHeight, config.cellSize]),
                        materials: [material]
                    )
                    tile.position = position
                        
                    let shape = ShapeResource.generateBox(size: [config.cellSize, config.floorHeight, config.cellSize])
                    
                    tile.components.set(PhysicsBodyComponent(
                        shapes: [shape],
                        mass: 0,
                        material: physicsMaterial,
                        mode: .static
                    ))
                    
                    tile.components.set(CollisionComponent(
                        shapes: [shape],
                        mode: .default
                    ))
                    
                    container.addChild(tile)
                }
            }
        }
        
        return (container, holes)
    }
    
    private static func createHole(position: SIMD3<Float>) -> Entity {
        let hole = Entity()
        hole.position = position
        hole.name = "hole_\(position.x)_\(position.z)"
        
        let triggerSize: Float = 0.2
        let trigger = ModelEntity(
            mesh: .generateBox(size: [triggerSize, 0.1, triggerSize]),
            materials: [SimpleMaterial(color: .clear, isMetallic: false)]
        )
        trigger.components.set(CollisionComponent(
            shapes: [.generateBox(size: [triggerSize, 0.1, triggerSize])],
            mode: .trigger
        ))
        hole.addChild(trigger)
        
        return hole
    }
    
    private static func createWall(
        position: SIMD3<Float>,
        size: SIMD3<Float>,
        config: MazeConfiguration
    ) -> ModelEntity {
        let wall = ModelEntity(
            mesh: .generateBox(size: size),
            materials: [SimpleMaterial(color: .brown, isMetallic: false)]
        )
        wall.position = position
        
        let collisionSize = size - [0.05, 0.05, 0.05]
        let shape = ShapeResource.generateBox(size: collisionSize)
        
        let physicsMaterial = PhysicsMaterialResource.generate(friction: 0.01, restitution: 0.01)
        
        wall.components.set(PhysicsBodyComponent(
            shapes: [shape],
            mass: 0,
            material: physicsMaterial,
            mode: .static
        ))
        
        wall.components.set(CollisionComponent(
            shapes: [shape],
            mode: .default
        ))
        
        return wall
    }
    
    private enum CornerType {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    private static func createCorner(
        at position: SIMD3<Float>,
        type: CornerType,
        scene: Entity,
        config: MazeConfiguration
    ) {
        let halfCell = config.cellSize / 2
        let quarterCell = config.cellSize / 4
        
        switch type {
        case .topLeft:
            scene.addChild(createWall(
                position: SIMD3<Float>(position.x - quarterCell, config.wallHeight/2, position.z - halfCell),
                size: SIMD3<Float>(halfCell, config.wallHeight, config.wallThickness),
                config: config
            ))
            
            scene.addChild(createWall(
                position: SIMD3<Float>(position.x - halfCell, config.wallHeight/2, position.z - quarterCell),
                size: SIMD3<Float>(config.wallThickness, config.wallHeight, halfCell),
                config: config
            ))
            
        case .topRight:
            scene.addChild(createWall(
                position: SIMD3<Float>(position.x + quarterCell, config.wallHeight/2, position.z - halfCell),
                size: SIMD3<Float>(halfCell, config.wallHeight, config.wallThickness),
                config: config
            ))
            
            scene.addChild(createWall(
                position: SIMD3<Float>(position.x + halfCell, config.wallHeight/2, position.z - quarterCell),
                size: SIMD3<Float>(config.wallThickness, config.wallHeight, halfCell),
                config: config
            ))
            
        case .bottomLeft:
            scene.addChild(createWall(
                position: SIMD3<Float>(position.x - quarterCell, config.wallHeight/2, position.z + halfCell),
                size: SIMD3<Float>(halfCell, config.wallHeight, config.wallThickness),
                config: config
            ))
            
            scene.addChild(createWall(
                position: SIMD3<Float>(position.x - halfCell, config.wallHeight/2, position.z + quarterCell),
                size: SIMD3<Float>(config.wallThickness, config.wallHeight, halfCell),
                config: config
            ))
            
        case .bottomRight:
            scene.addChild(createWall(
                position: SIMD3<Float>(position.x + quarterCell, config.wallHeight/2, position.z + halfCell),
                size: SIMD3<Float>(halfCell, config.wallHeight, config.wallThickness),
                config: config
            ))
            
            scene.addChild(createWall(
                position: SIMD3<Float>(position.x + halfCell, config.wallHeight/2, position.z + quarterCell),
                size: SIMD3<Float>(config.wallThickness, config.wallHeight, halfCell),
                config: config
            ))
        }
    }
    
    private static func createOuterWalls(
        rows: Int,
        columns: Int,
        config: MazeConfiguration
    ) -> Entity {
        let container = Entity()
        let width = Float(columns) * config.cellSize
        let depth = Float(rows) * config.cellSize
        
        container.addChild(createWall(
            position: [width/2, config.wallHeight/2, 0],
            size: [width, config.wallHeight, config.wallThickness],
            config: config
        ))
        
        container.addChild(createWall(
            position: [width/2, config.wallHeight/2, depth],
            size: [width, config.wallHeight, config.wallThickness],
            config: config
        ))
        
        container.addChild(createWall(
            position: [0, config.wallHeight/2, depth/2],
            size: [config.wallThickness, config.wallHeight, depth],
            config: config
        ))
        
        container.addChild(createWall(
            position: [width, config.wallHeight/2, depth/2],
            size: [config.wallThickness, config.wallHeight, depth],
            config: config
        ))
        
        return container
    }
    
    private static func createBall(
        position: SIMD3<Float>,
        config: MazeConfiguration
    ) -> ModelEntity {
        let ball = ModelEntity(
            mesh: .generateSphere(radius: config.ballRadius),
            materials: [SimpleMaterial(color: .blue, roughness: 0.5, isMetallic: false)]
        )
        ball.position = position
        ball.name = "ball"
        
        let shape = ShapeResource.generateSphere(radius: config.ballRadius)
        
        var physicsBody = PhysicsBodyComponent(
            shapes: [shape],
            mass: 10.0,
            material: .generate(friction: 0.01, restitution: 0.05),
            mode: .dynamic
        )
        
        // Настройки для стабильного движения
        physicsBody.linearDamping = 0
        physicsBody.angularDamping = 0
        physicsBody.isContinuousCollisionDetectionEnabled = true
        
        ball.components.set(physicsBody)
        ball.components.set(CollisionComponent(
            shapes: [shape],
            mode: .default
        ))
        
        return ball
    }
    
    private static func createFinish(position: SIMD3<Float>) -> ModelEntity {
        let finishSize: Float = 0.3
        let finishHeight: Float = 0.01

        let finish = ModelEntity(
            mesh: .generateBox(size: [finishSize, finishHeight, finishSize]),
            materials: [SimpleMaterial(color: .green, isMetallic: false)]
        )
        finish.position = position
        finish.name = "finish"
        
        finish.components.set(PhysicsBodyComponent(
            shapes: [.generateBox(size: [finishSize, finishHeight, finishSize])],
            mass: 0,
            mode: .static
        ))
        
        finish.components.set(CollisionComponent(
            shapes: [.generateBox(size: [finishSize, finishHeight, finishSize])]
        ))
        
        return finish
    }
    
    // MARK: - Star Creation
    private static func createStar(position: SIMD3<Float>) -> Entity {
        let starRoot = Entity()
        starRoot.name = "starRoot"
        starRoot.position = position
        
        let starVisual = Entity()
        starVisual.name = "starVisual"
        starVisual.position = [0, 0, 0]
        
        let starModel = createStarModel()
        starVisual.addChild(starModel)
        
        starRoot.addChild(starVisual)
        
        let colliderSize: Float = 0.3
        let shape = ShapeResource.generateBox(size: [colliderSize, colliderSize, colliderSize])
        
        var collisionComponent = CollisionComponent(
            shapes: [shape],
            mode: .trigger
        )
        
        starRoot.components.set(collisionComponent)
        
        return starRoot
    }
    
    private static func createStarModel() -> ModelEntity {
        let starMesh = MeshResource.generateStar(radius: 0.12, depth: 0.01)
        let starMaterial = SimpleMaterial(color: .yellow, isMetallic: true)
        let model = ModelEntity(mesh: starMesh, materials: [starMaterial])
        
        let bounds = model.visualBounds(relativeTo: nil)
        model.position.y = bounds.extents.y / 2
        
        return model
    }

    private static func placeStars(in scene: Entity, matrix: [[Int]], config: MazeConfiguration) {
        var availablePositions: [SIMD3<Float>] = []
        let rows = matrix.count
        let columns = matrix.first?.count ?? 0
        
        for row in 0..<rows {
            for col in 0..<columns {
                if matrix[row][col] == 0 &&
                   !(row == 1 && col == 0) && // Не стартовая позиция
                   !(row == rows-2 && col == columns-1) { // Не финиш
                    
                    let position = SIMD3<Float>(
                        Float(col) * config.cellSize + config.cellSize/2,
                        0.15,
                        Float(row) * config.cellSize + config.cellSize/2
                    )
                    availablePositions.append(position)
                }
            }
        }
        
        let starPositions = availablePositions.shuffled().prefix(3)
        
        for position in starPositions {
            let star = createStar(position: position)
            scene.addChild(star)
        }
    }
}

extension MeshResource {
    static func generateStar(radius: Float, depth: Float) -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        
        let points: Int = 5
        let innerRadius = radius * 0.4
        
        positions.append(SIMD3<Float>(0, depth/2, 0))
        
        for i in 0..<points * 2 {
            let angle = Float(i) * .pi / Float(points)
            let r = i % 2 == 0 ? radius : innerRadius
            
            positions.append(SIMD3<Float>(
                r * cos(angle),
                depth/2,
                r * sin(angle)
            ))
        }

        for i in 1...points * 2 {
            let next = i % (points * 2) + 1
            indices.append(0)
            indices.append(UInt32(i))
            indices.append(UInt32(next))
        }
        
        let startIndex = UInt32(positions.count)
        positions.append(SIMD3<Float>(0, -depth/2, 0))
        
        for i in 1...points * 2 {
            let index = startIndex + UInt32(i)
            positions.append(SIMD3<Float>(
                positions[i].x,
                -depth/2,
                positions[i].z
            ))
        }
        
        for i in 1...points * 2 {
            let next = i % (points * 2) + 1
            indices.append(startIndex)
            indices.append(startIndex + UInt32(next))
            indices.append(startIndex + UInt32(i))
        }
        
        for i in 1...points * 2 {
            let next = i % (points * 2) + 1
            let i2 = startIndex + UInt32(i)
            let next2 = startIndex + UInt32(next)
            
            // Первый треугольник
            indices.append(UInt32(i))
            indices.append(UInt32(next))
            indices.append(next2)
            
            indices.append(UInt32(i))
            indices.append(next2)
            indices.append(i2)
        }
        
        var meshDescriptor = MeshDescriptor()
        meshDescriptor.positions = MeshBuffers.Positions(positions)
        meshDescriptor.primitives = .triangles(indices)
        
        return try! MeshResource.generate(from: [meshDescriptor])
    }
}
