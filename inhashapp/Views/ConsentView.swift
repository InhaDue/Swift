import SwiftUI

struct ConsentView: View {
    @Binding var accepted: Bool
    var onContinue: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.white.opacity(0.7))
                    .overlay(Image(systemName: "hand.raised.fill").foregroundColor(.secondary))
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("개인정보 처리 동의")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("LMS 계정 정보는 서버에 저장되지 않으며, 기기 내에서만 사용됩니다.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("동의 내용")
                    .font(.headline)
                Text("- 앱은 WebView를 통해 사용자가 직접 LMS에 로그인합니다.\n- 서버는 LMS 아이디/비밀번호를 저장하지 않습니다.\n- 크롤링으로 수집된 과제/수업 데이터만 서버로 전송됩니다.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.white.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Toggle(isOn: $accepted) {
                Text("위 내용을 확인했고 동의합니다.")
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            Button(action: onContinue) {
                PrimaryButtonLabel(title: "웹뷰로 진행", loading: false)
                    .frame(height: 48)
            }
            .buttonStyle(LightenOnPressStyle(cornerRadius: 12, overlayOpacity: 0.12))
            .disabled(!accepted)
            .opacity(accepted ? 1.0 : 0.55)
            .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 10)
        )
        .frame(maxWidth: 360)
    }
}



