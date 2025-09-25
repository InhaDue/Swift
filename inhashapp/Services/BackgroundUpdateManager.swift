import Foundation
import BackgroundTasks
import UserNotifications
import Combine

/// 백그라운드 업데이트 관리자
/// Background App Refresh를 사용하여 주기적으로 LMS 데이터 업데이트
class BackgroundUpdateManager: ObservableObject {
    static let shared = BackgroundUpdateManager()
    
    private let backgroundTaskIdentifier = "com.inhash.app.refresh"
    private let crawler = LMSWebCrawler()
    
    @Published var lastUpdateDate: Date?
    @Published var isUpdating = false
    
    private init() {
        loadLastUpdateDate()
    }
    
    /// 백그라운드 업데이트 등록
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundTask(task: task as! BGAppRefreshTask)
        }
        
        scheduleNextBackgroundTask()
    }
    
    /// 다음 백그라운드 태스크 스케줄
    func scheduleNextBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 6) // 6시간 후
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background task scheduled")
        } catch {
            print("Failed to schedule background task: \(error)")
        }
    }
    
    /// 백그라운드 태스크 처리
    private func handleBackgroundTask(task: BGAppRefreshTask) {
        // 다음 태스크 스케줄
        scheduleNextBackgroundTask()
        
        // 만료 핸들러 설정
        task.expirationHandler = {
            // 태스크가 만료되면 정리
            self.isUpdating = false
        }
        
        // LMS 데이터 업데이트 수행
        Task {
            await performBackgroundUpdate()
            task.setTaskCompleted(success: true)
        }
    }
    
    /// 백그라운드 업데이트 수행
    @MainActor
    func performBackgroundUpdate() async {
        isUpdating = true
        
        // 저장된 LMS 계정 정보 가져오기
        guard let credentials = loadLMSCredentials() else {
            print("No LMS credentials found")
            isUpdating = false
            return
        }
        
        // 크롤링 수행
        crawler.startCrawling(
            username: credentials.username,
            password: credentials.password
        ) { [weak self] result in
            switch result {
            case .success(let data):
                // 서버로 데이터 전송
                Task {
                    await self?.sendDataToServer(data)
                    await MainActor.run {
                        self?.lastUpdateDate = Date()
                        self?.saveLastUpdateDate()
                        self?.isUpdating = false
                    }
                }
                
            case .failure(let error):
                print("Crawling failed: \(error)")
                self?.isUpdating = false
                
                // 실패가 반복되면 사용자에게 알림
                self?.checkAndNotifyUpdateFailure()
            }
        }
    }
    
    /// 서버로 크롤링 데이터 전송
    private func sendDataToServer(_ data: LMSWebCrawler.CrawlData) async {
        guard let studentId = UserDefaults.standard.object(forKey: "studentId") as? Int,
              let url = URL(string: "\(AppConfig.API.submitCrawlData)/\(studentId)") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 인증 토큰 추가
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(data)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                print("Data successfully sent to server")
            }
        } catch {
            print("Failed to send data to server: \(error)")
        }
    }
    
    /// 업데이트 실패 확인 및 알림
    private func checkAndNotifyUpdateFailure() {
        guard let lastUpdate = lastUpdateDate else { return }
        
        let daysSinceUpdate = Calendar.current.dateComponents([.day], from: lastUpdate, to: Date()).day ?? 0
        
        // 2일, 4일, 7일 경과 시 알림
        if [2, 4, 7].contains(daysSinceUpdate) {
            sendUpdateReminderNotification(days: daysSinceUpdate)
        }
    }
    
    /// 업데이트 알림 발송
    private func sendUpdateReminderNotification(days: Int) {
        let content = UNMutableNotificationContent()
        content.title = "INHASH 업데이트 필요"
        
        switch days {
        case 2:
            content.body = "LMS 데이터가 2일간 업데이트되지 않았습니다. 앱을 실행하여 최신 정보를 확인해주세요."
        case 4:
            content.body = "LMS 데이터가 4일간 업데이트되지 않았습니다. 과제를 놓치지 않으려면 앱을 실행해주세요!"
        case 7:
            content.body = "LMS 데이터가 일주일간 업데이트되지 않았습니다. 지금 바로 확인해보세요!"
        default:
            content.body = "LMS 데이터 업데이트가 필요합니다."
        }
        
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "update-reminder-\(days)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// 수동 업데이트 트리거
    @MainActor
    func triggerManualUpdate() async {
        await performBackgroundUpdate()
    }
    
    // MARK: - Credential Management
    
    private struct LMSCredentials {
        let username: String
        let password: String
    }
    
    /// LMS 자격 증명 저장 (Keychain 사용 권장)
    func saveLMSCredentials(username: String, password: String) {
        // 실제 구현에서는 Keychain을 사용해야 함
        UserDefaults.standard.set(username, forKey: "lms_username")
        
        // 비밀번호는 Keychain에 저장해야 하지만, 데모를 위해 UserDefaults 사용
        // WARNING: 실제 앱에서는 절대 UserDefaults에 비밀번호를 저장하지 마세요!
        if let data = password.data(using: .utf8) {
            UserDefaults.standard.set(data, forKey: "lms_password_encrypted")
        }
    }
    
    /// LMS 자격 증명 로드
    private func loadLMSCredentials() -> LMSCredentials? {
        guard let username = UserDefaults.standard.string(forKey: "lms_username"),
              let passwordData = UserDefaults.standard.data(forKey: "lms_password_encrypted"),
              let password = String(data: passwordData, encoding: .utf8) else {
            return nil
        }
        
        return LMSCredentials(username: username, password: password)
    }
    
    /// 마지막 업데이트 날짜 저장
    private func saveLastUpdateDate() {
        UserDefaults.standard.set(lastUpdateDate, forKey: "last_update_date")
    }
    
    /// 마지막 업데이트 날짜 로드
    private func loadLastUpdateDate() {
        lastUpdateDate = UserDefaults.standard.object(forKey: "last_update_date") as? Date
    }
}

