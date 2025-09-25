import SwiftUI

struct OnboardingFlow: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var crawler = LMSWebCrawler()
    @StateObject private var backgroundManager = BackgroundUpdateManager.shared
    
    @State private var showConsent = true
    @State private var consentAccepted = false
    @State private var showWebLogin = false
    @State private var showLoadingScreen = false
    
    var body: some View {
        ZStack {
            AppBackground()
            
            if showConsent {
                ConsentView(accepted: $consentAccepted) {
                    showConsent = false
                    showWebLogin = true
                }
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showWebLogin) {
            WebLoginView(crawler: crawler) {
                // 웹뷰 로그인 성공 → 웹뷰 닫고 로딩 화면으로
                showWebLogin = false
                showLoadingScreen = true
            }
        }
        .fullScreenCover(isPresented: $showLoadingScreen) {
            DataLoadingView(crawler: crawler, username: "", password: "")
                .environmentObject(auth)
        }
    }
}
