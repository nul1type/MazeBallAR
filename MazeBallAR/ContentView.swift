//
//  ContentView.swift
//  MazeBallAR
//
//  Created by Анатолий Александрович on 09.07.2025.
//

import SwiftUI
import RealityKit
import ARKit

// MARK: - Model
struct ARState {
    var tapTransform: simd_float4x4?
    var isPlaneDetected = false
}

// MARK: - ViewModel
enum AppState {
    case menu
    case arDetection
    case maze
    case instruction
}

// MARK: - App Settings
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var showInstruction: Bool {
        didSet {
            UserDefaults.standard.set(showInstruction, forKey: "showInstruction")
        }
    }
    
    @Published var starCount: Int {
        didSet {
            CoreDataManager.shared.updateTotalStars(starCount)
        }
    }
    
    private init() {
        self.showInstruction = UserDefaults.standard.object(forKey: "showInstruction") as? Bool ?? true
        self.starCount = CoreDataManager.shared.getTotalStars()
    }
    
    func resetStars() {
        starCount = 0
    }
}

final class ContentViewModel: ObservableObject {
    @Published private(set) var appState: AppState = .menu
    @Published var arState = ARState()
    
    func showARView() {
        appState = .arDetection
    }
    
    func showInstructionScreen() {
        appState = .instruction
    }
    
    func startMaze() {
        appState = .maze
    }
    
    func returnToMenu() {
        appState = .menu
        resetARState()
    }
    
    func returnToARDetection() {
        appState = .arDetection
    }
    
    private func resetARState() {
        arState = ARState()
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var settings = AppSettings.shared
    @State private var showingSettings = false
    
    var body: some View {
        ZStack {
            switch viewModel.appState {
            case .menu:
                MenuView(viewModel: viewModel, showingSettings: $showingSettings)
                
            case .arDetection:
                ARDetectionView(viewModel: viewModel)
                    .overlay(backButton(viewModel: viewModel), alignment: .topLeading)
                
            case .instruction:
                InstructionView(viewModel: viewModel)
                
            case .maze:
                MazeView(tapTransform: $viewModel.arState.tapTransform)
                    .overlay(backButton(viewModel: viewModel), alignment: .topLeading)
            }
            
            if showingSettings {
                SettingsView(isPresented: $showingSettings)
                    .transition(.opacity)
            }
        }
    }
    
    private func backButton(viewModel: ContentViewModel) -> some View {
        Button(action: {
            if viewModel.appState == .maze {
                viewModel.returnToARDetection()
            } else {
                viewModel.returnToMenu()
            }
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.white)
                .padding(20)
                //.background(Circle().fill(Color.black.opacity(0.3)))
        }
    }
}

struct MenuView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var showingSettings: Bool
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                // Настройки
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 30))
                        //.padding(20)
                        .foregroundColor(.white)
                }
                .padding(10)
            }
            Spacer()
            Text("Maze Ball AR")
                .font(.system(size: 48, weight: .bold))
                .padding(.bottom, 40)
            
            Button(action: viewModel.showInstructionScreen) {
                Text(NSLocalizedString("game_start", comment: ""))
                    .font(.title)
                    .padding()
                    .frame(width: 250)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .shadow(radius: 10)
            }
            Spacer()
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct ARDetectionView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(
                tapTransform: $viewModel.arState.tapTransform,
                isPlaneDetected: $viewModel.arState.isPlaneDetected,
                onPlaneTap: viewModel.startMaze
            )
            .edgesIgnoringSafeArea(.all)
            
            if !viewModel.arState.isPlaneDetected {
                detectionMessage(NSLocalizedString("ar_detection_search", comment: ""))
            } else {
                detectionMessage(NSLocalizedString("ar_tap", comment: ""))
            }
        }
    }
    
    private func detectionMessage(_ text: String) -> some View {
        Text(text)
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
            .padding()
            .padding(.bottom, 40)
            .transition(.opacity)
            .animation(.easeInOut, value: viewModel.arState.isPlaneDetected)
    }
}

struct InstructionView: View {
    @ObservedObject var viewModel: ContentViewModel
    @StateObject private var settings = AppSettings.shared
    @State private var dontShowAgain = false
    
    @State private var personPosition: CGPoint = .zero
    @State private var tiltX: Double = 0
    @State private var tiltY: Double = 0
    @State private var ballPosition: CGPoint = .zero
    @State private var currentStep = 0
    @State private var isAnimating = false
    
    private let circleRadius: CGFloat = 120
    private let mazeSize: CGFloat = 180
    private let positions = [
        CGPoint(x: 1, y: 0),   // справа
        CGPoint(x: 0, y: 1),   // снизу
        CGPoint(x: -1, y: 0),  // слева
        CGPoint(x: 0, y: -1)   // сверху
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.9).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 15) {
                Text(NSLocalizedString("instruction_title", comment: ""))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 10)
                
                VStack(spacing: 12) {
                    Text(NSLocalizedString("instruction_type1", comment: ""))
                        .font(.title2)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(NSLocalizedString("instruction_type2", comment: ""))
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    Text(NSLocalizedString("instruction_type3", comment: ""))
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                
                // Анимационная сцена
                ZStack {
                    // Лабиринт
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.gray, .black]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: mazeSize, height: mazeSize)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .rotation3DEffect(
                            .degrees(tiltX),
                            axis: (1, 0, 0)
                        )
                        .rotation3DEffect(
                            .degrees(tiltY),
                            axis: (0, 1, 0)
                        )
                    
                    // Шарик
                    Circle()
                        .fill(LinearGradient(gradient: Gradient(colors: [.white, .red]), startPoint: .top, endPoint: .bottom))
                        .frame(width: 28, height: 28)
                        .offset(x: ballPosition.x, y: ballPosition.y)
                        .shadow(color: .red, radius: 8)
                    
                    // Человечек
                    Image(systemName: "figure.walk")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                        .offset(x: personPosition.x * circleRadius, y: personPosition.y * circleRadius)
                        .shadow(color: .blue, radius: 5)
                }
                .frame(width: circleRadius * 2 + 40, height: circleRadius * 2 + 40)
                .padding(.vertical, 15)
                
                HStack {
                    Toggle(isOn: $dontShowAgain) {
                        Text(NSLocalizedString("instruction_check_box", comment: ""))
                            .foregroundColor(.white)
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    .onChange(of: dontShowAgain) { newValue in
                        settings.showInstruction = !newValue
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 10)
                
                Button(action: viewModel.showARView) {
                    Text(NSLocalizedString("instruction_close", comment: ""))
                        .font(.title2)
                        .bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                        .shadow(radius: 5)
                }
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            isAnimating = false
        }
    }
    
    private func startAnimation() {
        isAnimating = true
        animateStep()
    }
    
    private func animateStep() {
        guard isAnimating else { return }
        
        // Определяем положение человека
        let position = positions[currentStep]
        
        withAnimation(.easeInOut(duration: 1.5)) {
            personPosition = position
            
            // Лабиринт наклоняется в противоположную сторону
            tiltX = 15 * position.y
            tiltY = -15 * position.x
            
            // Шарик катится в направлении наклона
            ballPosition = CGPoint(
                x: -40 * position.x,
                y: -40 * position.y
            )
        }
        
        // Переход к следующему шагу
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.currentStep = (self.currentStep + 1) % 4
            self.animateStep()
        }
    }
}

// Settings View
struct SettingsView: View {
    @Binding var isPresented: Bool
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 20) {
                Text(NSLocalizedString("settings", comment: ""))
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                Toggle(isOn: $settings.showInstruction) {
                    Text(NSLocalizedString("instruction_toggle", comment: ""))
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 10)
                
                Button(action: {
                    settings.resetStars()
                }) {
                    Text(NSLocalizedString("clear_stars", comment: ""))
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 30)
                
                Button(action: { isPresented = false }) {
                    Text(NSLocalizedString("settings_close", comment: ""))
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.systemGray6))
                    .shadow(radius: 20)
            )
            .padding(40)
        }
        .zIndex(1)
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            Spacer()
            
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(configuration.isOn ? .blue : .gray)
                .onTapGesture { configuration.isOn.toggle() }
        }
    }
}
