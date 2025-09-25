import Foundation
import WebKit
import SwiftUI
import Combine

/// LMS WebView 크롤러
/// WebView를 통해 LMS에 로그인하고 JavaScript로 데이터를 추출
class LMSCrawler: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?
    
    private var webView: WKWebView?
    private var completion: ((Result<CrawlData, Error>) -> Void)?
    
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
            let due: String?
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
        
        // JavaScript 활성화 (iOS 14+ 방식)
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // User Agent 설정 (모바일 브라우저로 인식되지 않도록)
        configuration.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
        
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView?.navigationDelegate = self
    }
    
    /// LMS 크롤링 시작
    func startCrawling(username: String, password: String, completion: @escaping (Result<CrawlData, Error>) -> Void) {
        self.completion = completion
        self.isLoading = true
        self.progress = 0
        self.errorMessage = nil
        
        // LMS 로그인 페이지로 이동
        guard let url = URL(string: "https://lms.inha.ac.kr/login.php") else {
            completion(.failure(CrawlError.invalidURL))
            return
        }
        
        webView?.load(URLRequest(url: url))
        
        // 로그인 처리를 위한 자동화 스크립트 준비
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.performLogin(username: username, password: password)
        }
    }
    
    private func performLogin(username: String, password: String) {
        // 로그인 폼 자동 입력 JavaScript
        let loginScript = """
        (function() {
            var usernameField = document.querySelector('input[name="username"]');
            var passwordField = document.querySelector('input[name="password"]');
            var loginButton = document.querySelector('button[type="submit"]');
            
            if (usernameField && passwordField && loginButton) {
                usernameField.value = '\(username)';
                passwordField.value = '\(password)';
                loginButton.click();
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
                self?.navigateToDashboard()
            }
        }
    }
    
    private func navigateToDashboard() {
        guard let url = URL(string: "https://lms.inha.ac.kr/my/") else { return }
        webView?.load(URLRequest(url: url))
        
        // 대시보드 로딩 대기
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.extractData()
        }
    }
    
    private func extractData() {
        // 과제 및 수업 데이터 추출 JavaScript
        let extractScript = """
        (function() {
            var data = {
                courses: [],
                items: []
            };
            
            // 과목 목록 추출
            var courseElements = document.querySelectorAll('.course-item');
            courseElements.forEach(function(elem) {
                var courseName = elem.querySelector('.course-name')?.textContent?.trim();
                var courseLink = elem.querySelector('a')?.href;
                if (courseName) {
                    data.courses.push({
                        name: courseName,
                        mainLink: courseLink
                    });
                }
            });
            
            // 과제 추출
            var assignmentElements = document.querySelectorAll('.assignment-item');
            assignmentElements.forEach(function(elem) {
                var title = elem.querySelector('.title')?.textContent?.trim();
                var courseName = elem.querySelector('.course')?.textContent?.trim();
                var dueDate = elem.querySelector('.due-date')?.textContent?.trim();
                var link = elem.querySelector('a')?.href;
                
                if (title && courseName) {
                    data.items.push({
                        type: 'assignment',
                        title: title,
                        courseName: courseName,
                        due: dueDate,
                        url: link
                    });
                }
            });
            
            // 수업/강의 추출
            var lectureElements = document.querySelectorAll('.lecture-item');
            lectureElements.forEach(function(elem) {
                var title = elem.querySelector('.title')?.textContent?.trim();
                var courseName = elem.querySelector('.course')?.textContent?.trim();
                var dueDate = elem.querySelector('.due-date')?.textContent?.trim();
                var link = elem.querySelector('a')?.href;
                
                if (title && courseName) {
                    data.items.push({
                        type: 'class',
                        title: title,
                        courseName: courseName,
                        due: dueDate,
                        url: link
                    });
                }
            });
            
            return JSON.stringify(data);
        })();
        """
        
        webView?.evaluateJavaScript(extractScript) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.completion?(.failure(error))
                return
            }
            
            guard let jsonString = result as? String,
                  let jsonData = jsonString.data(using: .utf8) else {
                self.completion?(.failure(CrawlError.dataExtractionFailed))
                return
            }
            
            do {
                let extractedData = try JSONDecoder().decode(ExtractedData.self, from: jsonData)
                
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
                self.completion?(.success(crawlData))
                
            } catch {
                self.completion?(.failure(error))
            }
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
extension LMSCrawler: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 페이지 로딩 완료
        print("Page loaded: \(webView.url?.absoluteString ?? "")")
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

