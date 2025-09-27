import SwiftUI

// 개별 화면 단독 미리보기 세트

#Preview("LoginView") {
    let auth = AuthStore()
    return LoginView()
        .environmentObject(auth)
        .preferredColorScheme(.light)
}

// SignupView는 로그인 탭 내부로 통합되어 제거되었습니다.

#Preview("LmsLinkView") {
    let auth = AuthStore()
    auth.isAuthenticated = true // 콘텐츠 플로우 무시하고 화면 구성만 미리보기
    return LmsLinkView()
        .environmentObject(auth)
}

#Preview("DataLoadingView") {
    let auth = AuthStore()
    return DataLoadingView(username: "20190000", password: "password")
        .environmentObject(auth)
}

#Preview("HomeView") {
    let store = ScheduleStore()
    return HomeView()
        .environmentObject(store)
}

#Preview("CalendarView") {
    let store = ScheduleStore()
    return CalendarView()
        .environmentObject(store)
}

#Preview("DataRefreshView") {
    let auth = AuthStore()
    return DataRefreshView()
        .environmentObject(auth)
}

#Preview("SettingsView") {
    SettingsView()
}

// 하단 탭(TabView) 미리보기
#Preview("MainTabs") {
    let store = ScheduleStore()
    return MainTabs()
        .environmentObject(store)
        .preferredColorScheme(.light)
}
