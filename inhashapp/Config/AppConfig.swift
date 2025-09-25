import Foundation

struct AppConfig {
    // 로컬 테스트용 서버 주소
    // 실제 기기 테스트 시: Mac의 IP 주소로 변경 (예: "http://192.168.1.100:8080")
    // 프로덕션: 실제 서버 주소로 변경
    #if DEBUG
    static let baseURL = "http://localhost:8080"
    #else
    static let baseURL = "https://api.inhash.com" // 프로덕션 서버 주소
    #endif
    
    // API Endpoints
    struct API {
        static let submitCrawlData = "\(baseURL)/api/crawl/submit"
        static let updateStatus = "\(baseURL)/api/crawl/status"
        static let registerFCM = "\(baseURL)/api/fcm/register"
        static let login = "\(baseURL)/api/auth/login"
        static let signup = "\(baseURL)/api/auth/signup"
    }
    
    // 기타 설정
    static let backgroundTaskIdentifier = "com.inhash.app.refresh"
    static let backgroundUpdateInterval: TimeInterval = 60 * 60 * 6 // 6시간
}

