////
////  Menu.swift
////  MazeBallAR
////
////  Created by Анатолий Александрович on 09.07.2025.
////
//
//import SwiftUI
//
//struct MenuView: View {
//    @Binding var showARView: Bool
//    
//    var body: some View {
//        VStack(spacing: 30) {
//            Text("MazeBallAR")
//                .font(.largeTitle)
//            
//            // Кнопка запуска AR
//            Button(action: { showARView = true }) {
//                MenuItem(icon: "arkit", title: "Start")
//            }
//            
//            // Другие пункты меню
//            NavigationLink(destination: SettingsView()) {
//                MenuItem(icon: "gear", title: "Settings")
//            }
//            
//            Spacer()
//        }
//        .padding()
//    }
//}
//
//// Компонент пункта меню
//struct MenuItem: View {
//    let icon: String
//    let title: String
//    
//    var body: some View {
//        HStack {
//            Image(systemName: icon)
//                .font(.title)
//            Text(title)
//                .font(.title2)
//            Spacer()
//            Image(systemName: "chevron.right")
//        }
//        .padding()
//        .background(Color.blue.opacity(0.1))
//        .cornerRadius(12)
//        .foregroundColor(.blue)
//    }
//}
//
//// Пример экрана настроек
//struct SettingsView: View {
//    var body: some View {
//        Text("Settings Screen")
//            .navigationTitle("Settings")
//    }
//}
