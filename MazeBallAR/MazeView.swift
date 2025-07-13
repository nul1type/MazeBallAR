//MazeView.swift

import SwiftUI
import RealityKit
import ARKit
import Logging

struct MazeView: View {
    @Binding var tapTransform: simd_float4x4?
    @State var maze: Maze?
    @State var mazeScene: Entity?
    @State private var anchorEntity: AnchorEntity?
    @State private var pivotEntity: Entity?
    @State private var ballEntity: Entity?
    @State private var showFinishMessage = false
    @State private var deviceAnchor: AnchorEntity?
    
    private let maxTiltAngle: Float = .pi / 6 // 30 градусов
    private let referenceDistance: Float = 2.0
    private let smoothingFactor: Float = 0.2
    
    // Для управления жестами
    @State private var currentScale: Float = 1.0
    @State private var startScale: Float?
    @State private var offset: CGSize = .zero
    @State private var startOffset: CGSize = .zero

    @State private var translation: SIMD3<Float> = [0, 0, 0]
    @State private var startTranslation: SIMD3<Float>?
    
    @State private var collectedStars: Int = 0
    @State private var starsOnCurrentLevel: Int = 0
    @State private var rotationAngle: Float = 0
    
    let logger = Logger(label: "ru.MazeBallAR")

    var body: some View {
        RealityView { content in
            guard let transform = tapTransform else { return }
            
            // Сбрасываем сообщение при создании нового лабиринта
            showFinishMessage = false
            
            // Удаляем предыдущие сущности
            if let oldAnchor = anchorEntity {
                content.remove(oldAnchor)
            }
            
            // Создаем якорь в мировых координатах
            let anchor = AnchorEntity(.world(transform: transform))
            self.anchorEntity = anchor
            content.add(anchor)
            
            // Создаем pivot для вращения
            let pivot = Entity()
            pivot.name = "Pivot"
            self.pivotEntity = pivot
            anchor.addChild(pivot)
            
            // Создаем лабиринт
            createMaze(in: pivot)
            
            // Освещение
            let directionalLight = DirectionalLight()
            directionalLight.light.intensity = 1000
            directionalLight.light.color = .white
            directionalLight.orientation = simd_quatf(angle: -.pi/4, axis: [1, 0, 0])
            anchor.addChild(directionalLight)
            
            // Настраиваем камеру
            content.camera = .spatialTracking
            
            
            // Подписка на события столкновений
            content.subscribe(to: CollisionEvents.Began.self) { event in
                // Проверяем, что столкнулись шарик и финиш
                if (event.entityA.name == "ball" && event.entityB.name == "finish") ||
                   (event.entityA.name == "finish" && event.entityB.name == "ball") {
                    DispatchQueue.main.async {
                        showFinishMessage = true
                    }
                }
                
                // Проверка на столкновение шарика и звездочки
                if (event.entityA.name == "ball" && event.entityB.name == "starRoot") ||
                   (event.entityA.name == "starRoot" && event.entityB.name == "ball") {
                    
                    let star = event.entityA.name == "starRoot" ? event.entityA : event.entityB
                    
                    // Удаляем звезду со сцены
                    star.removeFromParent()
                    
                    // Обновляем счетчики
                    starsOnCurrentLevel += 1
                    collectedStars += 1
                    
                    // Сохраняем в Core Data
                    CoreDataManager.shared.updateTotalStars(collectedStars)
                }
            }
            
            // Создаем якорь для камеры
            let deviceAnchor = AnchorEntity(.camera)
            deviceAnchor.name = "DeviceAnchor"
            content.add(deviceAnchor)
            
            var smoothedRotation: simd_quatf = .init()

            content.subscribe(to: SceneEvents.Update.self) { event in
                guard let pivot = self.pivotEntity,
                      let anchor = self.anchorEntity else { return }
                
                // Позиции в мировых координатах
                let mazeCenter = anchor.position(relativeTo: nil)
                let cameraPosition = deviceAnchor.position(relativeTo: nil)
                
                // Вектор от центра лабиринта к камере
                var direction = cameraPosition - mazeCenter
                
                direction.y = 0
                
                // Расстояние до лабиринта
                let distance = simd_length(direction)
                
                if distance < 0.1 {
                    // Плавно возвращаем в исходное положение
                    smoothedRotation = simd_slerp(smoothedRotation, .init(), smoothingFactor)
                    pivot.transform.rotation = smoothedRotation
                    return
                }
                
                let normalizedDirection = direction / distance
                
                // Коэффициент наклона на основе расстояния
                let tiltFactor = min(distance / referenceDistance, 1.0)
                
                // Углы наклона
                let tiltX = -normalizedDirection.z * maxTiltAngle * tiltFactor
                let tiltZ = normalizedDirection.x * maxTiltAngle * tiltFactor
                
                // Вращение
                let rotationX = simd_quatf(angle: tiltX, axis: [1, 0, 0])
                let rotationZ = simd_quatf(angle: tiltZ, axis: [0, 0, 1])
                let targetRotation = rotationX * rotationZ
                
                // Сглаживание
                smoothedRotation = simd_slerp(smoothedRotation, targetRotation, smoothingFactor)
                
                pivot.transform.rotation = smoothedRotation
                
                logger.debug("""
                Направление: \(normalizedDirection)
                Расстояние: \(distance)
                Угол X: \(degrees(fromRadians: tiltX))°
                Угол Z: \(degrees(fromRadians: tiltZ))°
                """)
            }
            self.deviceAnchor = deviceAnchor
            
            collectedStars = CoreDataManager.shared.getTotalStars()
                        
        }
        .overlay(
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.title)
                    
                    Text("\(collectedStars)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        //.background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                }
                .padding()

                if showFinishMessage {
                    Text("лабиринт пройден")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.green)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .transition(.opacity)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .onAppear {
                            // Автоматическое пересоздание через 2 секунды
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                recreateMaze()
                            }
                        }
                }
                Spacer()
                HStack {
                    Button(NSLocalizedString("ball_reset", comment: "")) {
                        //resetBallPosition()
                        maze?.resetBallPosition()
                        showFinishMessage = false
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .shadow(radius: 10)
                    
                    Button(NSLocalizedString("recreate_maze", comment: "")) {
                        recreateMaze()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .shadow(radius: 10)
                }
                .padding()
            }
        )
        .onChange(of: tapTransform) { _ in
            showFinishMessage = false
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                self.rotateStars()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    guard let deviceAnchor = deviceAnchor,
                          let anchor = anchorEntity else { return }
                    
                    let cameraPosition = deviceAnchor.position(relativeTo: nil)
                    
                    let mazePosition = anchor.position(relativeTo: nil)
                    
                    let cameraToMaze = mazePosition - cameraPosition
                    
                    var direction = normalize(cameraToMaze)
                    direction.y = 0
                    
                    // Определяем нужное напрвление по позиционированию
                    if length(direction) < 0.001 {
                        direction = [0, 0, 1]
                    } else {
                        direction = normalize(direction)
                    }
                    
                    let rightVector = normalize(cross([0, 1, 0], direction))
                    
                    let sensitivity: Float = 0.0005
                    let dx = Float(value.translation.width) * sensitivity
                    let dz = Float(value.translation.height) * sensitivity
                    
                    let offsetX = rightVector * dx * -1
                    let offsetZ = direction * dz * -1
                    
                    if startTranslation == nil {
                        startTranslation = translation
                    }
                    
                    translation = startTranslation! + offsetX + offsetZ
                    
                    updateMazePosition()
                }
                .onEnded { _ in
                    startTranslation = translation
                }
        )
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    if startScale == nil {
                        startScale = currentScale
                    }
                    
                    let newScale = min(max(startScale! * Float(value), 0.5), 2.0)
                    currentScale = newScale
                    
                    updateMazeScale()
                }
                .onEnded { _ in
                    startScale = nil
                }
        )
    }
    
    private func rotateStars() {
        guard let scene = mazeScene else { return }
        
        // Находим все звезды
        let stars = scene.findAllEntities(named: "starVisual")
        
        // Обновляем угол вращения
        rotationAngle += 0.05
        if rotationAngle > .pi * 2 {
            rotationAngle = 0
        }
        
        for star in stars {
            // Устанавливаем новую ориентацию
            star.orientation = simd_quatf(angle: rotationAngle, axis: [0, 1, 0])
        }
    }
    
    // Функция для обновления позиции лабиринта
    private func updateMazePosition() {
        guard let anchor = anchorEntity else { return }
        
        anchor.position = translation
    }
    
    // Функция для обновления масштаба лабиринта
    private func updateMazeScale() {
        guard let anchor = anchorEntity else { return }
        
        anchor.children.forEach { entity in
            entity.transform.scale = SIMD3<Float>(repeating: currentScale)
        }
    }
    
    
    // Функция для создания лабиринта
    private func createMaze(in parent: Entity) {
        if let oldMaze = mazeScene {
            oldMaze.removeFromParent()
        }
        
        currentScale = 1.0
        translation = [0, 0, 0]
        startTranslation = nil
        startScale = nil
        
        
        let generator = MazeGenerator()
        let matrix = generator.generate(rows: 10, columns: 10)
        let maze = Maze(matrix: matrix)
        maze.scale(factor: 0.2)
        let mazeEntity = maze.getEntity()
        // Центрируем лабиринт в pivot
        let bounds = mazeEntity.visualBounds(relativeTo: nil)
        mazeEntity.position = -bounds.center
        mazeEntity.position.y = bounds.extents.y / 2
        
        parent.addChild(mazeEntity)
        mazeScene = mazeEntity
        self.maze = maze
        
        // Находим шарик для управления
        if let ball = mazeEntity.findEntity(named: "ball") {
            self.ballEntity = ball
            logger.info("Ball found for physics control")
        }
        
        //        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        //                    resetMazePosition()
        //                }
    }
    
    private func resetMazePosition() {
            guard let deviceAnchor = deviceAnchor,
                  let anchor = anchorEntity else { return }
            
            // Получаем позицию камеры
            let cameraPosition = deviceAnchor.position(relativeTo: nil)
            
            // Получаем ориентацию камеры
            let cameraOrientation = deviceAnchor.orientation(relativeTo: nil)
            
            // Вычисляем позицию перед камерой (2 метра вперед)
            let forwardVector = cameraOrientation.act([0, 0, -1])
            let targetPosition = cameraPosition + forwardVector * 2.0
            
            // Обновляем позицию лабиринта
            translation = targetPosition
            anchor.position = targetPosition
        }
    
    private func degrees(fromRadians radians: Float) -> Float {
        return radians * 180 / .pi
    }
    
    // Функция для пересоздания лабиринта
    private func recreateMaze() {
        guard let pivot = pivotEntity else { return }
        showFinishMessage = false
        createMaze(in: pivot)
        resetBallPosition()
    }
    
    private func resetBallPosition() {
        guard let ball = ballEntity else { return }
        
        ball.components.remove(PhysicsBodyComponent.self)
        
        ball.transform.translation = [0.25, 0.5, 0.85]
        ball.transform.rotation = .init()
        
        let newPhysics = PhysicsBodyComponent(
            shapes: [.generateSphere(radius: 0.1)],
            mass: 1.0,
            material: .generate(friction: 0.5, restitution: 0.5),
            mode: .dynamic
        )
        ball.components.set(newPhysics)
    }
}

extension Entity {
    func findAllEntities(named name: String) -> [Entity] {
        var result: [Entity] = []
        
        if self.name == name {
            result.append(self)
        }
        
        for child in children {
            result.append(contentsOf: child.findAllEntities(named: name))
        }
        
        return result
    }
}
