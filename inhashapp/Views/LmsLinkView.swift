import SwiftUI

struct LmsLinkView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var crawler = LMSWebCrawler()
    @StateObject private var backgroundManager = BackgroundUpdateManager.shared
    @State private var username = ""
    @State private var password = ""
    @State private var loading = false
    @State private var showConsent = false
    @State private var consentAccepted = false
    @State private var showWebLogin = false
    @State private var showLoadingScreen = false
    
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                // 카드
                VStack(alignment: .leading, spacing: 16) {
                    // 헤더
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.white.opacity(0.7))
                            .overlay(Image(systemName: "chevron.left").foregroundColor(.secondary))
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LMS2 연결").font(.title3).fontWeight(.semibold)
                            Text("인하대 LMS 계정을 연결해주세요").font(.footnote).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 4)
                    
                    // 안내 박스
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle().fill(Color.black.opacity(0.06)).frame(width: 28, height: 28)
                            Image(systemName: "shield.fill").foregroundColor(.secondary).font(.footnote)
                        }
                        Text("계정 정보는 안전하게 암호화되어 저장되며, 과제 정보 수집 목적으로만 사용됩니다.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // 입력 필드
                    IconTextField(systemImage: "person", placeholder: "LMS 아이디", text: $username, isSecure: .constant(false), showSecure: .constant(false))
                        .frame(height: 44)
                    IconTextField(systemImage: "lock", placeholder: "LMS 비밀번호", text: $password, isSecure: .constant(true), showSecure: .constant(false))
                        .frame(height: 44)
                    
                    // LMS 연결 버튼: 동의 → 웹뷰 로그인 → 로딩 → 서버전송
                    Button(action: submit) {
                        PrimaryButtonLabel(title: loading ? "연결 중..." : "LMS 연결하기", loading: loading)
                            .frame(height: 48)
                    }
                    .buttonStyle(LightenOnPressStyle(cornerRadius: 12, overlayOpacity: 0.12))
                    .disabled(username.isEmpty || password.isEmpty || loading)
                    .opacity((username.isEmpty || password.isEmpty) ? 0.55 : 1.0)
                    .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                    
                    HStack(spacing: 6) {
                        Text("연결에 문제가 있나요?")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Button("도움말 보기") {}
                            .font(.footnote)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 10)
                )
                .frame(maxWidth: 360)
                
                if let err = auth.errorMessage { Text(err).foregroundColor(.red).font(.footnote) }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 0)
        }
        .sheet(isPresented: $showConsent) {
            ConsentView(accepted: $consentAccepted) {
                showConsent = false
                showWebLogin = true
            }
            .background(AppBackground())
        }
        .fullScreenCover(isPresented: $showWebLogin) {
            WebLoginView(crawler: crawler) {
                // 웹뷰 로그인 성공 → 웹뷰 닫고 로딩 화면으로 전환하고 백그라운드 크롤링 진행
                showWebLogin = false
                showLoadingScreen = true
            }
        }
        .fullScreenCover(isPresented: $showLoadingScreen) {
            // 동일한 crawler 인스턴스를 전달하여 세션 유지
            DataLoadingView(crawler: crawler, username: username, password: password)
                .environmentObject(auth)
        }
    }
    
    private func submit() {
        loading = true
        auth.errorMessage = nil
        
        // 자격증명은 기기에 저장(서버 무전송)
        backgroundManager.saveLMSCredentials(username: username, password: password)
        
        // 동의 페이지 → 웹뷰 로그인 → 로딩 화면 순으로 진행
        loading = false
        consentAccepted = false
        showConsent = true
    }
}


