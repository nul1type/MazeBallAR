import SwiftUI
import RealityKit
import ARKit

// MARK: - AR View Container
struct ARViewContainer: UIViewRepresentable {
    @Binding var tapTransform: simd_float4x4?
    @Binding var isPlaneDetected: Bool
    var onPlaneTap: (() -> Void)?
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.arView = arView
        
        // Настройка AR
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config)
        
        // Жесты
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap))
        arView.addGestureRecognizer(tapGesture)
        
        // Делегат для отслеживания плоскостей
        arView.session.delegate = context.coordinator
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, onPlaneTap: onPlaneTap)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        var parent: ARViewContainer
        weak var arView: ARView?
        private var planeAnchors = [UUID: AnchorEntity]()
        var onPlaneTap: (() -> Void)?
        
        init(_ parent: ARViewContainer, onPlaneTap: (() -> Void)?) {
            self.parent = parent
            self.onPlaneTap = onPlaneTap
        }
        
        // MARK: - Plane Detection
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let arView = arView else { return }
            
            for anchor in anchors {
                guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }
                
                // Визуализация плоскости
                let planeEntity = createPlaneEntity(for: planeAnchor)
                let anchorEntity = AnchorEntity(anchor: planeAnchor)
                anchorEntity.addChild(planeEntity)
                
                planeAnchors[planeAnchor.identifier] = anchorEntity
                arView.scene.addAnchor(anchorEntity)
                
                if !parent.isPlaneDetected {
                    DispatchQueue.main.async {
                        self.parent.isPlaneDetected = true
                    }
                }
            }
        }
        
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let arView = arView else { return }
            
            for anchor in anchors {
                guard let planeAnchor = anchor as? ARPlaneAnchor,
                      let anchorEntity = planeAnchors[planeAnchor.identifier] else { continue }
                
                // Обновляем геометрию плоскости
                if let planeEntity = anchorEntity.children.first as? ModelEntity {
                    let mesh = MeshResource.generatePlane(
                        width: planeAnchor.extent.x,
                        depth: planeAnchor.extent.z
                    )
                    planeEntity.model?.mesh = mesh
                    
                    anchorEntity.transform = Transform(matrix: planeAnchor.transform)
                }
            }
        }
        
        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            guard let arView = arView else { return }
            
            for anchor in anchors {
                guard let planeAnchor = anchor as? ARPlaneAnchor,
                      let anchorEntity = planeAnchors.removeValue(forKey: planeAnchor.identifier) else { continue }
                
                // Удаляем плоскость
                arView.scene.removeAnchor(anchorEntity)
            }
            
            // Проверяем остались ли плоскости
            if planeAnchors.isEmpty {
                DispatchQueue.main.async {
                    self.parent.isPlaneDetected = false
                }
            }
        }
        
        // MARK: - Plane Visualization
        private func createPlaneEntity(for planeAnchor: ARPlaneAnchor) -> ModelEntity {
            let planeMesh = MeshResource.generatePlane(
                width: planeAnchor.extent.x,
                depth: planeAnchor.extent.z
            )
            
            let material = SimpleMaterial(
                color: UIColor.systemBlue.withAlphaComponent(0.4),
                isMetallic: false
            )
            
            return ModelEntity(mesh: planeMesh, materials: [material])
        }
        
        // MARK: - Tap Handling
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            let location = gesture.location(in: arView)
            
            // Raycast для обнаружения плоскостей
            guard let raycastQuery = arView.makeRaycastQuery(
                from: location,
                allowing: .existingPlaneGeometry,
                alignment: .horizontal
            ) else { return }
            
            guard let result = arView.session.raycast(raycastQuery).first else { return }
            
            parent.tapTransform = result.worldTransform
            onPlaneTap?()
        }
    }
}
