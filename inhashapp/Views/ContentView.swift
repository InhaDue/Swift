import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var store = ScheduleStore()
    @StateObject private var auth = AuthStore()
    
    var body: some View {
        Group {
            if !auth.isAuthenticated {
                AuthFlowView()
            } else if !auth.isLmsLinked {
                LmsLinkView()
            } else {
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
            SummaryView()
                .tabItem { Label("요약", systemImage: "chart.bar") }
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


