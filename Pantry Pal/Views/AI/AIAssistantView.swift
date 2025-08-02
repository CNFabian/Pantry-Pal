//
//  AIAssistantView.swift
//  Pantry Pal
//

import SwiftUI

struct RoundedLShape: Shape {
    var cornerRadius: CGFloat = 20
       
       func path(in rect: CGRect) -> Path {
           var path = Path()
           
           // Define the L shape dimensions - shorter ends
           let horizontalLength = rect.width * 0.6
           let verticalHeight = rect.height * 0.6
           let thickness = min(rect.width, rect.height) * 0.25
           
           // Limit corner radius to half the thickness
           let radius = min(cornerRadius, thickness / 2)
           
           // Start at top-left (with corner radius consideration)
           path.move(to: CGPoint(x: 0, y: radius))
           
           // Top-left outer corner
           path.addArc(
               center: CGPoint(x: radius, y: radius),
               radius: radius,
               startAngle: .degrees(180),
               endAngle: .degrees(270),
               clockwise: false
           )
           
           // Top edge
           path.addLine(to: CGPoint(x: thickness - radius, y: 0))
           
           // Top-right inner corner
           path.addArc(
               center: CGPoint(x: thickness - radius, y: radius),
               radius: radius,
               startAngle: .degrees(270),
               endAngle: .degrees(0),
               clockwise: false
           )
           
           // Inner vertical edge
           path.addLine(to: CGPoint(x: thickness, y: verticalHeight - thickness + radius))
           
           // Inner corner
           path.addArc(
               center: CGPoint(x: thickness + radius, y: verticalHeight - thickness + radius),
               radius: radius,
               startAngle: .degrees(180),
               endAngle: .degrees(90),
               clockwise: true
           )
           
           // Inner horizontal edge
           path.addLine(to: CGPoint(x: horizontalLength - radius, y: verticalHeight - thickness))
           
           // Bottom-right inner corner
           path.addArc(
               center: CGPoint(x: horizontalLength - radius, y: verticalHeight - thickness - radius),
               radius: radius,
               startAngle: .degrees(90),
               endAngle: .degrees(0),
               clockwise: true
           )
           
           // Right edge
           path.addLine(to: CGPoint(x: horizontalLength, y: verticalHeight - radius))
           
           // Bottom-right outer corner
           path.addArc(
               center: CGPoint(x: horizontalLength - radius, y: verticalHeight - radius),
               radius: radius,
               startAngle: .degrees(0),
               endAngle: .degrees(90),
               clockwise: false
           )
           
           // Bottom edge
           path.addLine(to: CGPoint(x: radius, y: verticalHeight))
           
           // Bottom-left outer corner
           path.addArc(
               center: CGPoint(x: radius, y: verticalHeight - radius),
               radius: radius,
               startAngle: .degrees(90),
               endAngle: .degrees(180),
               clockwise: false
           )
           
           // Close the path
           path.closeSubpath()
           
           return path
       }
}

struct AIAssistantView: View {
    @StateObject private var viewModel = AIAssistantViewModel()
    @State private var isAnimating = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Center container with AI Circle and surrounding icons
            ZStack {
                // Corner shapes as backgrounds for icons
                
                // Top-Right Corner Shape with Profile
                NavigationLink(destination: ProfileView()) {
                    ZStack {
                        RoundedLShape()
                                      .fill(Color.blue)
                                      .frame(width: 200, height: 200)
                                  
                        
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                            .offset(x: 20, y: -20)
                    }
                }
                .offset(x: 50, y: -50)
                
                // Bottom-Right Corner Shape with Pantry
                NavigationLink(destination: PantryView()) {
                    ZStack {
                        CornerShape(corner: .bottomRight)
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 100, height: 100)
                            .overlay(
                                CornerShape(corner: .bottomRight)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                        
                        Image(systemName: "basket.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                            .offset(x: 20, y: 20)
                    }
                }
                .offset(x: 50, y: 50)
                
                // Bottom-Left Corner Shape with Recipes
                NavigationLink(destination: RecipesView()) {
                    ZStack {
                        CornerShape(corner: .bottomLeft)
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 100, height: 100)
                            .overlay(
                                CornerShape(corner: .bottomLeft)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                        
                        Image(systemName: "book.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                            .offset(x: -20, y: 20)
                    }
                }
                .offset(x: -50, y: 50)
                
                // Top-Left Corner Shape with Settings
                NavigationLink(destination: SettingsView()) {
                    ZStack {
                        CornerShape(corner: .topLeft)
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 100, height: 100)
                            .overlay(
                                CornerShape(corner: .topLeft)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                        
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                            .offset(x: -20, y: -20)
                    }
                }
                .offset(x: -50, y: -50)
                
                // AI Circle in center
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)]),
                            center: .center,
                            startRadius: 50,
                            endRadius: 100
                        )
                    )
                    .frame(width: viewModel.isSpeaking ? 180 : 150,
                           height: viewModel.isSpeaking ? 180 : 150)
                    .shadow(color: Color.blue.opacity(0.5), radius: pulseAnimation ? 30 : 20)
                    .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                    .onTapGesture {
                        if viewModel.isListening {
                            viewModel.stopListening()
                        } else {
                            viewModel.startListening()
                        }
                    }
                
                // Microphone icon in center of circle
                Image(systemName: viewModel.isListening ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
            }
            
            // Status text at bottom
            VStack {
                Spacer()
                
                if viewModel.isListening {
                    Text("Listening...")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .padding(.bottom, 50)
                } else if viewModel.isSpeaking {
                    Text("Speaking...")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
            
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// Custom Corner Shape
struct CornerShape: Shape {
    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    let corner: Corner
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 25
        let innerCurve: CGFloat = 40
        
        switch corner {
        case .topLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
                             control: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                             control: CGPoint(x: rect.maxX - innerCurve, y: rect.maxY - innerCurve))
            path.closeSubpath()
            
        case .topRight:
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY),
                             control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY),
                             control: CGPoint(x: rect.minX + innerCurve, y: rect.maxY - innerCurve))
            path.closeSubpath()
            
        case .bottomLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY),
                             control: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                             control: CGPoint(x: rect.maxX - innerCurve, y: rect.minY + innerCurve))
            path.closeSubpath()
            
        case .bottomRight:
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY),
                             control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                             control: CGPoint(x: rect.minX + innerCurve, y: rect.minY + innerCurve))
            path.closeSubpath()
        }
        
        return path
    }
}

#Preview {
    AIAssistantView()
}
