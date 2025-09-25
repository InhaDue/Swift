import Foundation
import Combine

/// Python 크롤링 결과를 서버로 전송하는 서비스
/// 실제 WebView 크롤링 대신 Python final.py의 결과를 사용
class DataSyncService: ObservableObject {
    static let shared = DataSyncService()
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    private init() {}
    
    /// 실제 크롤링 데이터 (final.py 실행 결과 기반)
    func syncRealData(studentId: Int) async throws {
        isSyncing = true
        defer { isSyncing = false }
        
        // 실제 크롤링 데이터 (final.py 결과 기반)
        let crawlData = CrawlData(
            clientVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            clientPlatform: "iOS",
            crawledAt: ISO8601DateFormatter().string(from: Date()),
            courses: getRealCourses(),
            items: getRealItems()
        )
        
        // 서버로 전송
        guard let url = URL(string: "\(AppConfig.API.submitCrawlData)/\(studentId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(crawlData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw NSError(domain: "DataSync", code: 0, userInfo: [NSLocalizedDescriptionKey: errorData.error])
            }
            throw URLError(.badServerResponse)
        }
        
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
    }
    
    private func getRealCourses() -> [Course] {
        // 실제 과목 데이터 (final.py 결과 기반)
        return [
            Course(name: "생명과학[202502-ACE1904-001]", mainLink: "https://learn.inha.ac.kr/course/view.php?id=63435"),
            Course(name: "객체지향프로그래밍기초[202502-EEC1104-001]", mainLink: "https://learn.inha.ac.kr/course/view.php?id=64609"),
            Course(name: "디지털논리회로[202502-EEC2106-001]NEW", mainLink: "https://learn.inha.ac.kr/course/view.php?id=64640"),
            Course(name: "컴퓨터네트워크[202502-EEC3412-002]", mainLink: "https://learn.inha.ac.kr/course/view.php?id=64695"),
            Course(name: "객체지향프로그래밍[202502-EEC2200-002~003]", mainLink: "https://learn.inha.ac.kr/course/view.php?id=68016"),
            Course(name: "자료구조론[202502-EEC2208-002]NEW", mainLink: "https://learn.inha.ac.kr/course/view.php?id=64667"),
            Course(name: "[2025년도 법정의무교육] 학부, 대학원생 대상 폭력예방교육", mainLink: "https://learn.inha.ac.kr/course/view.php?id=62607")
        ]
    }
    
    private func getRealItems() -> [Item] {
        // 실제 과제/수업 데이터 (final.py 결과에서 주요 항목만)
        return [
            // 과제
            Item(type: "assignment", courseName: "객체지향프로그래밍기초[202502-EEC1104-001]", 
                 title: "3주차 과제", url: "https://learn.inha.ac.kr/mod/assign/view.php?id=1439124",
                 due: "2025-09-25 00:00:00", remainingSeconds: nil),
            Item(type: "assignment", courseName: "객체지향프로그래밍기초[202502-EEC1104-001]",
                 title: "3주차 실습", url: "https://learn.inha.ac.kr/mod/assign/view.php?id=1439123",
                 due: "2025-09-19 00:00:00", remainingSeconds: nil),
            Item(type: "assignment", courseName: "디지털논리회로[202502-EEC2106-001]NEW",
                 title: "vivado 설치 및 시뮬레이션", url: "https://learn.inha.ac.kr/mod/assign/view.php?id=1443408",
                 due: "2025-09-30 00:00:00", remainingSeconds: nil),
            Item(type: "assignment", courseName: "객체지향프로그래밍[202502-EEC2200-002~003]",
                 title: "3주차 과제", url: "https://learn.inha.ac.kr/mod/assign/view.php?id=1438387",
                 due: "2025-09-24 00:00:00", remainingSeconds: nil),
            
            // 동영상 수업
            Item(type: "class", courseName: "생명과학[202502-ACE1904-001]",
                 title: "생명과학-4주차 1교시동영상", url: "https://learn.inha.ac.kr/mod/vod/view.php?id=1388074",
                 due: "2025-09-28 23:59:59", remainingSeconds: nil),
            Item(type: "class", courseName: "생명과학[202502-ACE1904-001]",
                 title: "생명과학-4주차 2교시동영상", url: "https://learn.inha.ac.kr/mod/vod/view.php?id=1388075",
                 due: "2025-09-28 23:59:59", remainingSeconds: nil),
            Item(type: "class", courseName: "생명과학[202502-ACE1904-001]",
                 title: "생명과학-5주차 1교시동영상", url: nil,
                 due: "2025-10-05 23:59:59", remainingSeconds: nil),
            Item(type: "class", courseName: "컴퓨터네트워크[202502-EEC3412-002]",
                 title: "Chap3-3동영상", url: "https://learn.inha.ac.kr/mod/vod/view.php?id=1396026",
                 due: "2025-09-28 23:59:59", remainingSeconds: nil),
            Item(type: "class", courseName: "디지털논리회로[202502-EEC2106-001]NEW",
                 title: "vivado-first동영상", url: "https://learn.inha.ac.kr/mod/vod/view.php?id=1443336",
                 due: "2025-09-28 23:59:59", remainingSeconds: nil)
        ]
    }
    
    // Data structures
    struct CrawlData: Codable {
        let clientVersion: String
        let clientPlatform: String
        let crawledAt: String
        let courses: [Course]
        let items: [Item]
    }
    
    struct Course: Codable {
        let name: String
        let mainLink: String?
    }
    
    struct Item: Codable {
        let type: String
        let courseName: String
        let title: String
        let url: String?
        let due: String?
        let remainingSeconds: Int?
    }
    
    struct ErrorResponse: Codable {
        let success: Bool
        let error: String
    }
}
