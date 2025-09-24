import SwiftUI

struct IconTextField: View {
    let systemImage: String
    let placeholder: String
    @Binding var text: String
    @Binding var isSecure: Bool
    @Binding var showSecure: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                if isSecure && !showSecure {
                    SecureField(placeholder, text: $text)
                        .textContentType(.password)
                        .font(.system(size: 15))
                } else {
                    TextField(placeholder, text: $text)
                        .textContentType(isSecure ? .password : .username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(isSecure ? .default : .emailAddress)
                        .font(.system(size: 15))
                }
                if isSecure {
                    Button(action: { showSecure.toggle() }) {
                        Image(systemName: showSecure ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}

struct KakaoButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 1.0, green: 0.898, blue: 0.0))
                Text("카카오로 계속하기")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
            .frame(height: 48)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(LightenOnPressStyle(cornerRadius: 12, overlayOpacity: 0.1))
    }
}

struct LightenOnPressStyle: ButtonStyle {
    let cornerRadius: CGFloat
    let overlayOpacity: Double
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white)
                    .opacity(configuration.isPressed ? overlayOpacity : 0)
            )
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PrimaryButtonLabel: View {
    let title: String
    let loading: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.35), lineWidth: 1))
            HStack(spacing: 8) {
                if loading { ProgressView().tint(.white).scaleEffect(0.9) }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
        }
    }
}

struct SecondaryButtonLabel: View {
    let title: String
    let loading: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemGray5),
                            Color(.systemGray3)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
            HStack(spacing: 8) {
                if loading { ProgressView().tint(.primary).scaleEffect(0.9) }
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 8)
        }
    }
}

struct StageRow: View {
    let systemImage: String
    let text: String
    let isDone: Bool
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((isDone ? Color.green.opacity(0.15) : Color.blue.opacity(0.12)))
                    .frame(width: 28, height: 28)
                Image(systemName: systemImage)
                    .foregroundColor(isDone ? .green : .blue)
                    .font(.footnote)
            }
            Text(text)
                .font(.footnote)
                .foregroundColor(isDone ? Color.green : (isActive ? Color.primary : Color.secondary))
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDone ? Color.green.opacity(0.12) : Color.blue.opacity(0.08))
        )
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.28), value: isDone)
        .animation(.easeInOut(duration: 0.22), value: isActive)
    }
}

struct DotsLoadingIndicator: View {
    let color: Color
    let dotSize: CGFloat
    let spacing: CGFloat
    
    @State private var animate: Bool = false
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3) { idx in
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(animate ? 1.0 : 0.55)
                    .animation(
                        .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(idx) * 0.18),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}


