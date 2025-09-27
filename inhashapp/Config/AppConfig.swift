import Foundation

struct AppConfig {
    // ⚠️ 환경 전환: 아래 세 줄 중 하나만 주석 해제하세요
    // ================================================
    
    // 1. 시뮬레이터 테스트용
    static let baseURL = "http://localhost:8080"
    
    // 2. 실제 기기 테스트용 (Mac의 IP 주소로 변경 필요)
    // static let baseURL = "http://192.168.1.100:8080"
    
    // 3. 프로덕션 서버
    // static let baseURL = "https://api.inhash.com"
    
    // ================================================
    
    // API Endpoints
    struct API {
        static let submitCrawlData = "\(baseURL)/api/crawl/submit"
        static let updateStatus = "\(baseURL)/api/crawl/status"
        static let registerFCM = "\(baseURL)/api/fcm/register"
        static let login = "\(baseURL)/api/auth/login"
        static let signup = "\(baseURL)/api/auth/signup"
        static let deadlines = "\(baseURL)/api/deadlines"
    }
    
    // 기타 설정
    static let backgroundTaskIdentifier = "com.inhash.app.refresh"
    static let backgroundUpdateInterval: TimeInterval = 60 * 60 * 6 // 6시간
}

