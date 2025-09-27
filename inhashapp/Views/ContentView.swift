import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var store = ScheduleStore()
    @StateObject private var auth = AuthStore()
    
    var body: some View {
        Group {
            if !auth.isAuthenticated {
                // 로그인/회원가입 화면
                AuthFlowView()
            } else if !auth.isLmsLinked {
                // 회원가입 후에만 LMS 연결 필요 (로그인 시에는 이미 연결되어 있음)
                OnboardingFlow()
            } else {
                // 메인 화면
                MainTabs()
            }
        }
        .environmentObject(store)
        .environmentObject(auth)
    }
}

struct MainTabs: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("홈", systemImage: "house") }
            CalendarView()
                .tabItem { Label("캘린더", systemImage: "calendar") }
            DataRefreshView()
                .tabItem { Label("갱신", systemImage: "arrow.clockwise") }
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
        }
    }
}

struct AuthFlowView: View {
    var body: some View {
        LoginView()
    }
}


