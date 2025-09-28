import SwiftUI
import WebKit

struct DataRefreshView: View {
    @EnvironmentObject var authStore: AuthStore
    @State private var isRefreshing = false
    @State private var showingRefreshAlert = false
    @State private var showingWebView = false
    @State private var refreshMessage = ""
    @State private var timer: Timer?
    @State private var timeUntilNextRefresh = ""
    
    // 유저별로 갱신 시간 저장
    private var userRefreshKey: String {
        "lastRefreshTime_\(authStore.studentId ?? 0)"
    }
    
    private var userRefreshCountKey: String {
        "refreshCount_\(authStore.studentId ?? 0)"
    }
    
    private var lastRefreshTime: Double {
        UserDefaults.standard.double(forKey: userRefreshKey)
    }
    
    private var refreshCount: Int {
        UserDefaults.standard.integer(forKey: userRefreshCountKey)
    }
    
    // TODO: 테스트 완료 후 3시간으로 변경
    private let refreshCooldown: TimeInterval = 0 // 3 * 60 * 60 // 테스트를 위해 제한 없음
    
    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    RefreshStatusCard(
                        lastRefreshTime: lastRefreshTime,
                        timeUntilNextRefresh: timeUntilNextRefresh
                    )
                    
                    RefreshActionCard(
                        isRefreshing: isRefreshing,
                        canRefresh: canRefresh,
                        isTestMode: refreshCooldown == 0,
                        onRefresh: performRefresh
                    )
                    
                    RefreshInfoCard()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("데이터 갱신")
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .alert("데이터 갱신", isPresented: $showingRefreshAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(refreshMessage)
        }
        .sheet(isPresented: $showingWebView) {
            if authStore.studentId != nil {
                RefreshWebView { success in
                    showingWebView = false
                    if success {
                        // 갱신 성공 (시간 기록은 DataLoadingView에서 처리)
                        isRefreshing = false
                        refreshMessage = "데이터가 성공적으로 갱신되었습니다!"
                        showingRefreshAlert = true
                        updateTimeUntilNextRefresh()
                    } else {
                        // 갱신 실패 또는 취소
                        isRefreshing = false
                        refreshMessage = "갱신이 취소되었습니다."
                        showingRefreshAlert = true
                    }
                }
            }
        }
    }
    
    private var canRefresh: Bool {
        let timeSinceLastRefresh = Date().timeIntervalSince1970 - lastRefreshTime
        return timeSinceLastRefresh >= refreshCooldown
    }
    
    private func startTimer() {
        updateTimeUntilNextRefresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateTimeUntilNextRefresh()
        }
    }
    
    private func updateTimeUntilNextRefresh() {
        // 테스트 모드에서는 항상 갱신 가능
        if refreshCooldown == 0 {
            timeUntilNextRefresh = "지금 갱신 가능 (테스트 모드)"
            return
        }
        
        let timeSinceLastRefresh = Date().timeIntervalSince1970 - lastRefreshTime
        let remainingTime = max(0, refreshCooldown - timeSinceLastRefresh)
        
        if remainingTime == 0 {
            timeUntilNextRefresh = "지금 갱신 가능"
        } else {
            let hours = Int(remainingTime) / 3600
            let minutes = (Int(remainingTime) % 3600) / 60
            let seconds = Int(remainingTime) % 60
            
            if hours > 0 {
                timeUntilNextRefresh = "\(hours)시간 \(minutes)분 \(seconds)초 후"
            } else if minutes > 0 {
                timeUntilNextRefresh = "\(minutes)분 \(seconds)초 후"
            } else {
                timeUntilNextRefresh = "\(seconds)초 후"
            }
        }
    }
    
    private func performRefresh() {
        guard canRefresh else {
            refreshMessage = "갱신은 3시간마다 한 번만 가능합니다.\n\(timeUntilNextRefresh) 갱신 가능합니다."
            showingRefreshAlert = true
            return
        }
        
        isRefreshing = true
        // WebView로 LMS 로그인 화면 표시
        showingWebView = true
    }
}

// 갱신용 WebView - WebLoginView 후 DataLoadingView로 전환
private struct RefreshWebView: View {
    @EnvironmentObject var authStore: AuthStore
    @StateObject private var crawler = LMSWebCrawler()
    @State private var showingDataLoadingView = false
    @State private var lmsUsername = ""
    @State private var lmsPassword = ""
    @State private var isCleaningSession = true
    let onComplete: (Bool) -> Void
    
    var body: some View {
        NavigationView {
            if isCleaningSession {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("세션 초기화 중...")
                        .font(.headline)
                    Text("잠시만 기다려주세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .onAppear {
                    cleanSessionAndProceed()
                }
            } else if showingDataLoadingView {
                // DataLoadingView를 갱신 모드로 표시
                DataLoadingView(
                    username: lmsUsername,
                    password: lmsPassword,
                    isRefreshMode: true,
                    onRefreshComplete: { success in
                        onComplete(success)
                    }
                )
                .environmentObject(authStore)
            } else {
                // WebLoginView 표시
                WebLoginView(crawler: crawler) {
                    // 로그인 성공 시 DataLoadingView로 전환
                    // LMS 자격 증명 저장 (갱신용)
                    if let savedUsername = UserDefaults.standard.string(forKey: "lmsUsername") {
                        lmsUsername = savedUsername
                        // 패스워드는 키체인에서 가져오거나 WebView에서 입력받은 것 사용
                        if let savedPassword = KeychainHelper.shared.readString(service: "com.inhash.app", 
                                                                                account: savedUsername) {
                            lmsPassword = savedPassword
                        } else {
                            // WebView에서 로그인한 정보를 사용 (실제로는 WebLoginView에서 처리)
                            lmsPassword = "temp_password" // 실제로는 WebLoginView에서 전달받아야 함
                        }
                    }
                    
                    withAnimation {
                        showingDataLoadingView = true
                    }
                }
            }
        }
    }
    
    private func cleanSessionAndProceed() {
        // WebView 쿠키와 캐시 초기화
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) { [self] in
            // 초기화 완료 후 진행
            isCleaningSession = false
        }
    }
}

// UI Components (동일하게 유지)
private struct RefreshStatusCard: View {
    let lastRefreshTime: Double
    let timeUntilNextRefresh: String
    
    private var lastRefreshText: String {
        if lastRefreshTime == 0 {
            return "아직 갱신 기록이 없습니다"
        }
        
        let date = Date(timeIntervalSince1970: lastRefreshTime)
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private var lastRefreshDetailText: String {
        if lastRefreshTime == 0 {
            return "첫 갱신을 시작해보세요"
        }
        
        let date = Date(timeIntervalSince1970: lastRefreshTime)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 MM월 dd일 HH:mm:ss"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("마지막 갱신")
                        .font(.headline)
                    Text(lastRefreshText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("갱신 시간")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(lastRefreshDetailText)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("다음 갱신 가능")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(timeUntilNextRefresh)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(timeUntilNextRefresh.contains("지금 갱신 가능") ? .green : .orange)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
        )
    }
}

private struct RefreshActionCard: View {
    let isRefreshing: Bool
    let canRefresh: Bool
    let isTestMode: Bool
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: onRefresh) {
                HStack {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(isRefreshing ? "갱신 중..." : "지금 갱신하기")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canRefresh && !isRefreshing ? Color.blue : Color.gray)
                )
            }
            .disabled(!canRefresh || isRefreshing)
            
            // 테스트 모드 안내
            if isTestMode {
                Label("테스트 모드: 갱신 제한 없음", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundColor(.green)
            } else if !canRefresh {
                Label("3시간마다 한 번씩 갱신 가능", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
        )
    }
}

private struct RefreshInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("갱신 안내", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(
                    icon: "clock.fill",
                    title: "자동 갱신",
                    description: "매일 자정에 시도되지만 실패할 수 있습니다",
                    color: .blue
                )
                
                InfoRow(
                    icon: "hand.tap.fill",
                    title: "수동 갱신",
                    description: "3시간마다 수동으로 갱신 가능합니다",
                    color: .orange
                )
                
                InfoRow(
                    icon: "calendar.badge.exclamationmark",
                    title: "권장 주기",
                    description: "주 2-3회 갱신을 권장합니다",
                    color: .green
                )
                
                InfoRow(
                    icon: "person.crop.circle.badge.exclamationmark",
                    title: "세션 충돌 시",
                    description: "LMS에서 로그아웃 후 다시 시도하세요",
                    color: .orange
                )
                
                InfoRow(
                    icon: "bell.badge",
                    title: "갱신 알림",
                    description: "3일, 7일 후 갱신 알림이 발송됩니다",
                    color: .purple
                )
            }
            
            Text("💡 Tip: 과제가 많이 올라오는 시기에는 자주 갱신하세요")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}



#Preview {
    NavigationView {
        DataRefreshView()
            .environmentObject(AuthStore())
    }
}