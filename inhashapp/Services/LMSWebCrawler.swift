import Foundation
import WebKit
import SwiftUI
import Combine

/// 실제 인하대 LMS 크롤러
/// Python 크롤링 로직을 Swift/JavaScript로 구현
class LMSWebCrawler: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?
    
    private var webView: WKWebView?
    private var completion: ((Result<CrawlData, Error>) -> Void)?
    private var currentUsername: String?
    private var currentPassword: String?
    
    struct CrawlData: Codable {
        let clientVersion: String
        let clientPlatform: String
        let crawledAt: String
        let courses: [Course]
        let items: [Item]
        
        struct Course: Codable {
            let name: String
            let mainLink: String?
        }
        
        struct Item: Codable {
            let type: String // assignment, class
            let courseName: String
            let title: String
            let url: String?
            let due: String? // YYYY-MM-DD HH:MM:SS format
            let remainingSeconds: Int?
        }
    }
    
    override init() {
        super.init()
        setupWebView()
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
        
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView?.navigationDelegate = self
    }
    
    /// LMS 크롤링 시작
    func startCrawling(username: String, password: String, completion: @escaping (Result<CrawlData, Error>) -> Void) {
        self.completion = completion
        self.currentUsername = username
        self.currentPassword = password
        self.isLoading = true
        self.progress = 0
        self.errorMessage = nil
        self.statusMessage = "LMS 로그인 페이지 접속 중..."
        
        // LMS 로그인 페이지로 이동
        guard let url = URL(string: "https://learn.inha.ac.kr/login/index.php") else {
            completion(.failure(CrawlError.invalidURL))
            return
        }
        
        webView?.load(URLRequest(url: url))
    }
    
    private func performLogin() {
        guard let username = currentUsername, let password = currentPassword else { return }
        
        statusMessage = "로그인 시도 중..."
        progress = 0.2
        
        // 인하대 LMS 로그인 JavaScript
        let loginScript = """
        (function() {
            // 로그인 폼 찾기
            var usernameField = document.querySelector('input[name="username"], input#username');
            var passwordField = document.querySelector('input[name="password"], input#password');
            var loginButton = document.querySelector('button[type="submit"], input[type="submit"]');
            
            if (usernameField && passwordField) {
                usernameField.value = '\(username)';
                passwordField.value = '\(password)';
                
                // 로그인 버튼 클릭 또는 폼 제출
                if (loginButton) {
                    loginButton.click();
                } else {
                    var form = usernameField.closest('form');
                    if (form) {
                        form.submit();
                    }
                }
                return true;
            }
            return false;
        })();
        """
        
        webView?.evaluateJavaScript(loginScript) { [weak self] result, error in
            if let error = error {
                self?.completion?(.failure(error))
                return
            }
            
            // 로그인 후 대시보드로 이동 대기
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self?.checkLoginAndNavigate()
            }
        }
    }
    
    private func checkLoginAndNavigate() {
        statusMessage = "대시보드 로딩 중..."
        progress = 0.4
        
        // 로그인 성공 확인 후 대시보드로 이동
        guard let url = URL(string: "https://learn.inha.ac.kr/") else { return }
        webView?.load(URLRequest(url: url))
        
        // 대시보드 로딩 대기 후 데이터 추출
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.extractAllData()
        }
    }
    
    private func extractAllData() {
        statusMessage = "과제 및 수업 정보 수집 중..."
        progress = 0.6
        
        // Python 크롤링 로직을 JavaScript로 변환
        let extractScript = """
        (function() {
            var data = {
                courses: [],
                items: []
            };
            
            // 1. 과목 목록 추출 (왼쪽 사이드바 또는 메인 페이지)
            var courseElements = document.querySelectorAll('.course-item, .course_list_tree a, .coursebox');
            var courseMap = {};
            
            courseElements.forEach(function(elem) {
                var courseName = elem.textContent?.trim();
                var courseLink = elem.href || elem.querySelector('a')?.href;
                
                if (courseName && !courseName.includes('더보기')) {
                    // 과목명 정제
                    courseName = courseName.replace(/\\[.*?\\]/g, '').trim();
                    if (courseName && !courseMap[courseName]) {
                        courseMap[courseName] = true;
                        data.courses.push({
                            name: courseName,
                            mainLink: courseLink
                        });
                    }
                }
            });
            
            // 2. 할 일 목록 (과제, 퀴즈 등)
            var todoElements = document.querySelectorAll('.todo-item, .block_todo li, .event');
            
            todoElements.forEach(function(elem) {
                var title = elem.querySelector('.todo-name, .event-name, a')?.textContent?.trim();
                var courseName = elem.querySelector('.todo-course, .course-name')?.textContent?.trim();
                var dueText = elem.querySelector('.todo-due, .event-time')?.textContent?.trim();
                var link = elem.querySelector('a')?.href;
                
                // 타입 판별
                var type = 'assignment';
                if (title && (title.includes('동영상') || title.includes('강의'))) {
                    type = 'class';
                }
                
                if (title && courseName) {
                    // 날짜 파싱
                    var dueDate = null;
                    if (dueText) {
                        // "2024년 12월 31일 23:59" 형식을 "2024-12-31 23:59:00"으로 변환
                        var dateMatch = dueText.match(/(\\d{4})년\\s*(\\d{1,2})월\\s*(\\d{1,2})일\\s*(\\d{1,2}):(\\d{2})/);
                        if (dateMatch) {
                            var year = dateMatch[1];
                            var month = dateMatch[2].padStart(2, '0');
                            var day = dateMatch[3].padStart(2, '0');
                            var hour = dateMatch[4].padStart(2, '0');
                            var minute = dateMatch[5].padStart(2, '0');
                            dueDate = year + '-' + month + '-' + day + ' ' + hour + ':' + minute + ':00';
                        }
                    }
                    
                    data.items.push({
                        type: type,
                        courseName: courseName.replace(/\\[.*?\\]/g, '').trim(),
                        title: title,
                        url: link,
                        due: dueDate
                    });
                }
            });
            
            // 3. 캘린더 이벤트 (추가 과제/수업)
            var calendarEvents = document.querySelectorAll('.calendar-event, .event-item');
            
            calendarEvents.forEach(function(elem) {
                var title = elem.querySelector('.event-title, .name')?.textContent?.trim();
                var courseName = elem.querySelector('.course')?.textContent?.trim();
                var dateStr = elem.querySelector('.date')?.textContent?.trim();
                var link = elem.querySelector('a')?.href;
                
                if (title && courseName) {
                    var type = title.includes('과제') ? 'assignment' : 'class';
                    
                    data.items.push({
                        type: type,
                        courseName: courseName.replace(/\\[.*?\\]/g, '').trim(),
                        title: title,
                        url: link,
                        due: dateStr
                    });
                }
            });
            
            return JSON.stringify(data);
        })();
        """
        
        webView?.evaluateJavaScript(extractScript) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                // 첫 번째 시도 실패 시 다른 선택자로 재시도
                self.extractDataAlternative()
                return
            }
            
            self.processExtractedData(result)
        }
    }
    
    private func extractDataAlternative() {
        // 대체 선택자로 데이터 추출 시도
        let alternativeScript = """
        (function() {
            var data = {
                courses: [],
                items: []
            };
            
            // 대체 선택자들
            // 타임라인 형식
            var timelineItems = document.querySelectorAll('.timeline-item, .activity-item');
            timelineItems.forEach(function(item) {
                var title = item.querySelector('.activity-name, .item-title')?.textContent?.trim();
                var course = item.querySelector('.course-name')?.textContent?.trim();
                var due = item.querySelector('.activity-dates, .item-date')?.textContent?.trim();
                var link = item.querySelector('a')?.href;
                
                if (title && course) {
                    data.items.push({
                        type: title.includes('과제') ? 'assignment' : 'class',
                        courseName: course,
                        title: title,
                        url: link,
                        due: due
                    });
                }
            });
            
            // 블록 형식
            var blocks = document.querySelectorAll('[data-block="timeline"], [data-block="myoverview"]');
            blocks.forEach(function(block) {
                var items = block.querySelectorAll('.event, .activity');
                items.forEach(function(item) {
                    var title = item.textContent?.trim();
                    if (title) {
                        data.items.push({
                            type: 'assignment',
                            courseName: 'Unknown',
                            title: title,
                            url: null,
                            due: null
                        });
                    }
                });
            });
            
            return JSON.stringify(data);
        })();
        """
        
        webView?.evaluateJavaScript(alternativeScript) { [weak self] result, error in
            self?.processExtractedData(result)
        }
    }
    
    private func processExtractedData(_ result: Any?) {
        guard let jsonString = result as? String,
              let jsonData = jsonString.data(using: .utf8) else {
            self.completion?(.failure(CrawlError.dataExtractionFailed))
            return
        }
        
        do {
            let extractedData = try JSONDecoder().decode(ExtractedData.self, from: jsonData)
            
            statusMessage = "데이터 처리 중..."
            progress = 0.9
            
            // CrawlData 형식으로 변환
            let crawlData = CrawlData(
                clientVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                clientPlatform: "iOS",
                crawledAt: ISO8601DateFormatter().string(from: Date()),
                courses: extractedData.courses.map { CrawlData.Course(name: $0.name, mainLink: $0.mainLink) },
                items: extractedData.items.map { item in
                    CrawlData.Item(
                        type: item.type,
                        courseName: item.courseName,
                        title: item.title,
                        url: item.url,
                        due: item.due,
                        remainingSeconds: self.calculateRemainingSeconds(from: item.due)
                    )
                }
            )
            
            self.isLoading = false
            self.progress = 1.0
            self.statusMessage = "크롤링 완료!"
            self.completion?(.success(crawlData))
            
        } catch {
            self.completion?(.failure(error))
        }
    }
    
    private func calculateRemainingSeconds(from dateString: String?) -> Int? {
        guard let dateString = dateString else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        
        guard let dueDate = formatter.date(from: dateString) else { return nil }
        
        let remaining = Int(dueDate.timeIntervalSinceNow)
        return remaining > 0 ? remaining : nil
    }
    
    // 내부 데이터 구조
    private struct ExtractedData: Codable {
        let courses: [Course]
        let items: [Item]
        
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
        }
    }
}

// MARK: - WKNavigationDelegate
extension LMSWebCrawler: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let url = webView.url?.absoluteString ?? ""
        print("Page loaded: \(url)")
        
        // 로그인 페이지에서 자동 로그인 시도
        if url.contains("login/index.php") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.performLogin()
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.errorMessage = error.localizedDescription
        self.completion?(.failure(error))
    }
}

// MARK: - Error Types
enum CrawlError: LocalizedError {
    case invalidURL
    case loginFailed
    case dataExtractionFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .loginFailed:
            return "LMS 로그인에 실패했습니다."
        case .dataExtractionFailed:
            return "데이터 추출에 실패했습니다."
        case .networkError:
            return "네트워크 연결을 확인해주세요."
        }
    }
}
