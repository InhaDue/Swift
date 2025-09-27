import SwiftUI
import UserNotifications

struct ConsentView: View {
    @Binding var accepted: Bool
    var onContinue: () -> Void
    
    @State private var showingDetails = false
    @State private var showingTechnicalDetails = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 헤더
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                        .padding(.top, 8)
                    
                    Text("개인정보 처리 동의")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("귀하의 개인정보는 안전하게 보호됩니다")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
                
                // 핵심 원칙
                VStack(alignment: .leading, spacing: 16) {
                    PrivacyPrincipleRow(
                        icon: "icloud.slash",
                        title: "서버 미저장",
                        description: "LMS 계정정보는 서버에 전송되지 않습니다"
                    )
                    
                    PrivacyPrincipleRow(
                        icon: "iphone.badge.play",
                        title: "기기 내 처리",
                        description: "모든 크롤링은 사용자 기기에서만 수행됩니다"
                    )
                    
                    PrivacyPrincipleRow(
                        icon: "doc.text.magnifyingglass",
                        title: "최소 정보 수집",
                        description: "과제명, 마감일 등 필수 정보만 수집합니다"
                    )
                    
                    PrivacyPrincipleRow(
                        icon: "bell.badge",
                        title: "알림 발송",
                        description: "과제 마감일 및 갱신 알림을 보냅니다"
                    )
                }
                .padding(16)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
                
                // 상세 정보 (펼치기/접기)
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingDetails.toggle()
                        }
                    }) {
                        HStack {
                            Text("수집하는 정보")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                    }
                    
                    if showingDetails {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoSection(
                                title: "수집 항목",
                                items: [
                                    "• 과목명 (예: 디지털논리회로)",
                                    "• 과제 제목 및 마감일",
                                    "• 수업/강의 제목 및 수강 기한"
                                ]
                            )
                            
                            InfoSection(
                                title: "수집하지 않는 항목",
                                items: [
                                    "• LMS 로그인 ID/비밀번호",
                                    "• 성적 및 평가 정보",
                                    "• 개인 신상 정보",
                                    "• 제출한 과제 내용",
                                    "• 과제/수업 URL 링크"
                                ],
                                isNegative: true
                            )
                        }
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                // 기술적 보안 조치 (펼치기/접기)
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showingTechnicalDetails.toggle()
                        }
                    }) {
                        HStack {
                            Text("기술적 보호 조치")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: showingTechnicalDetails ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                    }
                    
                    if showingTechnicalDetails {
                        VStack(alignment: .leading, spacing: 16) {
                            TechnicalDetailRow(
                                icon: "lock.circle.fill",
                                title: "클라이언트 사이드 크롤링",
                                description: "WebView를 통한 직접 로그인으로 서버에 계정정보 미전송"
                            )
                            
                            TechnicalDetailRow(
                                icon: "key.icloud.fill",
                                title: "iOS Keychain 암호화",
                                description: "자동 업데이트용 자격증명은 iOS 보안 저장소에 암호화 저장"
                            )
                            
                            TechnicalDetailRow(
                                icon: "network",
                                title: "최소 권한 원칙",
                                description: "서버는 크롤링된 결과 데이터만 수신, 로그인 정보 접근 불가"
                            )
                            
                            TechnicalDetailRow(
                                icon: "trash.circle.fill",
                                title: "데이터 삭제 권한",
                                description: "언제든지 계정 변경 또는 탈퇴로 모든 데이터 즉시 삭제 가능"
                            )
                        }
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                // 동의 체크박스
                HStack(spacing: 12) {
                    Image(systemName: accepted ? "checkmark.square.fill" : "square")
                        .font(.title2)
                        .foregroundColor(accepted ? .blue : .gray)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                accepted.toggle()
                            }
                        }
                    
                    Text("위 내용을 모두 확인했으며, 개인정보 처리에 동의합니다")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(accepted ? Color.blue.opacity(0.05) : Color.gray.opacity(0.05))
                .cornerRadius(12)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        accepted.toggle()
                    }
                }
                
                // 계속 버튼
                Button(action: {
                    // iOS 알림 권한 요청
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        print("알림 권한: \(granted)")
                        if let error = error {
                            print("알림 권한 오류: \(error)")
                        }
                    }
                    onContinue()
                }) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("LMS 로그인 진행")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accepted ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!accepted)
                .opacity(accepted ? 1.0 : 0.6)
                .animation(.easeInOut(duration: 0.2), value: accepted)
                
                // 하단 안내
                Text("본 서비스는 인하대학교와 무관한 개인 프로젝트입니다")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.03), Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// 개인정보 보호 원칙 행
struct PrivacyPrincipleRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// 정보 섹션
struct InfoSection: View {
    let title: String
    let items: [String]
    var isNegative: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isNegative ? .red : .primary)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// 기술적 상세 정보 행
struct TechnicalDetailRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// Preview
struct ConsentView_Previews: PreviewProvider {
    static var previews: some View {
        ConsentView(accepted: .constant(false), onContinue: {})
            .previewDevice("iPhone 14 Pro")
    }
}