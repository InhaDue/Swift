import Foundation
import WebKit
import SwiftUI
import Combine

/// LMS WebView 크롤러 - 실제 크롤링 구현
class LMSWebCrawler: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    
    let webView: WKWebView
    private var completion: ((Result<CrawlData, Error>) -> Void)?
    private var currentUsername: String?
    private var currentPassword: String?
    private var manualLoginMode: Bool = false
    private var onManualLoginSuccess: (() -> Void)?
    
    // 크롤링된 데이터 저장
    private var courses: [CrawlData.Course] = []
    private var items: [CrawlData.Item] = []
    private var currentCourseIndex = 0
    
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
        // 웹뷰 구성 생성
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        self.webView.navigationDelegate = self
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
        self.courses = []
        self.items = []
        self.currentCourseIndex = 0
        
        // LMS 로그인 페이지로 이동
        guard let url = URL(string: "https://learn.inha.ac.kr/login/index.php") else {
            completion(.failure(CrawlError.invalidURL))
            return
        }
        manualLoginMode = false
        webView.load(URLRequest(url: url))
    }
    
    /// 수동 로그인 UI 플로우 시작
    func startManualLogin(onSuccess: @escaping () -> Void) {
        self.onManualLoginSuccess = onSuccess
        self.manualLoginMode = true
        self.isLoading = false
        self.progress = 0
        self.errorMessage = nil
        self.statusMessage = "로그인 준비 중..."
        guard let url = URL(string: "https://learn.inha.ac.kr/login/index.php") else { return }
        webView.load(URLRequest(url: url))
    }
    
    /// 수동 로그인 후 크롤링 계속
    func startAfterManualLogin(completion: @escaping (Result<CrawlData, Error>) -> Void) {
        self.completion = completion
        self.isLoading = true
        self.progress = 0.4
        self.statusMessage = "대시보드 로딩 중..."
        self.courses = []
        self.items = []
        self.currentCourseIndex = 0
        navigateToDashboardAndExtract()
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
        
        webView.evaluateJavaScript(loginScript) { [weak self] result, error in
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
        webView.load(URLRequest(url: url))
        
        // 대시보드 로딩 대기 후 과목 추출
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.extractCourses()
        }
    }
    
    private func navigateToDashboardAndExtract() {
        guard let url = URL(string: "https://learn.inha.ac.kr/") else { return }
        webView.load(URLRequest(url: url))
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.extractCourses()
        }
    }
    
    /// 과목 목록 추출
    private func extractCourses() {
        statusMessage = "과목 정보 수집 중..."
        progress = 0.5
        
        let courseScript = """
        (function() {
            var courses = [];
            
            // 다양한 선택자로 과목 찾기
            var selectors = [
                'div.course_lists ul.my-course-lists > li a.course_link',
                'div.coursebox a[href*="/course/view.php"]',
                'a.coursename[href*="/course/view.php"]',
                'a[href*="/course/view.php?id="]'
            ];
            
            var courseLinks = [];
            for (var i = 0; i < selectors.length; i++) {
                var links = document.querySelectorAll(selectors[i]);
                if (links.length > 0) {
                    courseLinks = links;
                    break;
                }
            }
            
            var seen = {};
            for (var j = 0; j < courseLinks.length; j++) {
                var link = courseLinks[j];
                var href = link.href;
                var text = link.textContent.trim();
                
                // 과목 ID 추출
                var idMatch = href.match(/id=(\\d+)/);
                if (idMatch && !seen[idMatch[1]]) {
                    seen[idMatch[1]] = true;
                    courses.push({
                        id: idMatch[1],
                        name: text,
                        mainLink: href
                    });
                }
            }
            
            return JSON.stringify(courses);
        })();
        """
        
        webView.evaluateJavaScript(courseScript) { [weak self] result, error in
            guard let self = self else { return }
            
            if let json = result as? String,
               let data = json.data(using: .utf8),
               let coursesArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                
                self.courses = coursesArray.compactMap { dict in
                    guard let name = dict["name"] as? String,
                          let mainLink = dict["mainLink"] as? String else { return nil }
                    return CrawlData.Course(name: name, mainLink: mainLink)
                }
                
                print("Found \(self.courses.count) courses")
                
                if self.courses.isEmpty {
                    // 과목이 없으면 대시보드 데이터만 추출
                    self.extractDashboardData()
                } else {
                    // 각 과목별로 크롤링 시작
                    self.currentCourseIndex = 0
                    self.crawlNextCourse()
                }
            } else {
                // 추출 실패 시 대시보드 데이터만
                self.extractDashboardData()
            }
        }
    }
    
    /// 다음 과목 크롤링
    private func crawlNextCourse() {
        guard currentCourseIndex < courses.count else {
            // 모든 과목 크롤링 완료
            finishCrawling()
            return
        }
        
        let course = courses[currentCourseIndex]
        let courseId = course.mainLink?.components(separatedBy: "id=").last ?? ""
        
        statusMessage = "과목 데이터 수집 중... (\(currentCourseIndex + 1)/\(courses.count))"
        progress = 0.6 + Double(currentCourseIndex) / Double(courses.count) * 0.3
        
        // 먼저 과제 페이지 크롤링
        crawlAssignments(courseId: courseId, courseName: course.name)
    }
    
    /// 과제 페이지 크롤링
    private func crawlAssignments(courseId: String, courseName: String) {
        let assignUrl = "https://learn.inha.ac.kr/mod/assign/index.php?id=\(courseId)"
        guard let url = URL(string: assignUrl) else {
            crawlVODs(courseId: courseId, courseName: courseName)
            return
        }
        
        webView.load(URLRequest(url: url))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            let assignScript = """
            (function() {
                var assignments = [];
                var tables = document.querySelectorAll('table');
                
                for (var t = 0; t < tables.length; t++) {
                    var table = tables[t];
                    var headers = [];
                    var headerCells = table.querySelectorAll('thead th, tr:first-child th, tr:first-child td');
                    
                    for (var h = 0; h < headerCells.length; h++) {
                        headers.push(headerCells[h].textContent.toLowerCase().trim());
                    }
                    
                    var titleCol = -1, dueCol = -1;
                    for (var i = 0; i < headers.length; i++) {
                        if (headers[i].includes('과제') || headers[i].includes('assignment') || 
                            headers[i].includes('활동') || headers[i].includes('activity')) {
                            titleCol = i;
                        }
                        if (headers[i].includes('종료') || headers[i].includes('마감') || 
                            headers[i].includes('due') || headers[i].includes('마감일')) {
                            dueCol = i;
                        }
                    }
                    
                    if (titleCol >= 0 && dueCol >= 0) {
                        var rows = table.querySelectorAll('tbody tr');
                        if (rows.length === 0) {
                            rows = table.querySelectorAll('tr');
                        }
                        
                        for (var r = 0; r < rows.length; r++) {
                            var cells = rows[r].querySelectorAll('td');
                            if (cells.length > Math.max(titleCol, dueCol)) {
                                var link = cells[titleCol].querySelector('a[href]');
                                if (link) {
                                    var title = link.textContent.trim();
                                    var url = link.href;
                                    var due = cells[dueCol].textContent.trim();
                                    
                                    assignments.push({
                                        title: title,
                                        url: url,
                                        due: due
                                    });
                                }
                            }
                        }
                        break; // 첫 번째 유효한 테이블만 처리
                    }
                }
                
                return JSON.stringify(assignments);
            })();
            """
            
            self?.webView.evaluateJavaScript(assignScript) { result, error in
                if let json = result as? String,
                   let data = json.data(using: .utf8),
                   let assignments = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    
                    for assign in assignments {
                        if let title = assign["title"] as? String,
                           let url = assign["url"] as? String,
                           let due = assign["due"] as? String {
                            
                            let item = CrawlData.Item(
                                type: "assignment",
                                courseName: courseName,
                                title: title,
                                url: url,
                                due: self?.normalizeDueDate(due),
                                remainingSeconds: nil
                            )
                            self?.items.append(item)
                        }
                    }
                }
                
                // VOD 크롤링으로 이동
                self?.crawlVODs(courseId: courseId, courseName: courseName)
            }
        }
    }
    
    /// VOD 페이지 크롤링
    private func crawlVODs(courseId: String, courseName: String) {
        let courseUrl = "https://learn.inha.ac.kr/course/view.php?id=\(courseId)"
        guard let url = URL(string: courseUrl) else {
            currentCourseIndex += 1
            crawlNextCourse()
            return
        }
        
        webView.load(URLRequest(url: url))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            let vodScript = """
            (function() {
                var vods = [];
                var vodItems = document.querySelectorAll('li.activity.vod.modtype_vod');
                
                vodItems.forEach(function(item) {
                    var link = item.querySelector('.activityinstance a[href]');
                    var titleEl = item.querySelector('.activityinstance .instancename');
                    var periodEl = item.querySelector('.displayoptions .text-ubstrap');
                    
                    if (titleEl) {
                        var title = titleEl.textContent.trim();
                        // 접근성 텍스트 제거
                        title = title.replace(/동영상$/, '').trim();
                        
                        var url = link ? link.href : null;
                        var due = null;
                        
                        if (periodEl) {
                            var text = periodEl.textContent.trim();
                            if (text.includes('~')) {
                                var parts = text.split('~');
                                if (parts.length > 1) {
                                    due = parts[1].trim();
                                }
                            }
                        }
                        
                        vods.push({
                            title: title,
                            url: url,
                            due: due
                        });
                    }
                });
                
                return JSON.stringify(vods);
            })();
            """
            
            self?.webView.evaluateJavaScript(vodScript) { result, error in
                if let json = result as? String,
                   let data = json.data(using: .utf8),
                   let vods = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    
                    for vod in vods {
                        if let title = vod["title"] as? String {
                            let url = vod["url"] as? String
                            let due = vod["due"] as? String
                            
                            let item = CrawlData.Item(
                                type: "class",
                                courseName: courseName,
                                title: title,
                                url: url,
                                due: self?.normalizeDueDate(due),
                                remainingSeconds: nil
                            )
                            self?.items.append(item)
                        }
                    }
                }
                
                // 다음 과목으로
                self?.currentCourseIndex += 1
                self?.crawlNextCourse()
            }
        }
    }
    
    /// 대시보드 데이터 추출 (폴백)
    private func extractDashboardData() {
        statusMessage = "대시보드 데이터 수집 중..."
        progress = 0.7
        
        let dashboardScript = """
        (function() {
            var items = [];
            
            // 타임라인 블록
            var timelineItems = document.querySelectorAll('.block_timeline .timeline-event-list li');
            timelineItems.forEach(function(item) {
                var link = item.querySelector('a[href]');
                var title = item.querySelector('.event-name') || item.querySelector('.timeline-event-title');
                var time = item.querySelector('.event-time') || item.querySelector('.timeline-event-time');
                
                if (link && title) {
                    var type = link.href.includes('/mod/assign/') ? 'assignment' : 'class';
                    items.push({
                        type: type,
                        courseName: 'Unknown',
                        title: title.textContent.trim(),
                        url: link.href,
                        due: time ? time.textContent.trim() : null
                    });
                }
            });
            
            // 할 일 블록
            var todoItems = document.querySelectorAll('.block_todo li.todo-item');
            todoItems.forEach(function(item) {
                var link = item.querySelector('a[href]');
                var title = item.querySelector('.todo-name');
                
                if (link && title) {
                    var type = link.href.includes('/mod/assign/') ? 'assignment' : 'class';
                    items.push({
                        type: type,
                        courseName: 'Unknown',
                        title: title.textContent.trim(),
                        url: link.href,
                        due: null
                    });
                }
            });
            
            return JSON.stringify(items);
        })();
        """
        
        webView.evaluateJavaScript(dashboardScript) { [weak self] result, error in
            if let json = result as? String,
               let data = json.data(using: .utf8),
               let dashItems = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                
                for item in dashItems {
                    if let type = item["type"] as? String,
                       let title = item["title"] as? String {
                        
                        let crawlItem = CrawlData.Item(
                            type: type,
                            courseName: item["courseName"] as? String ?? "Unknown",
                            title: title,
                            url: item["url"] as? String,
                            due: self?.normalizeDueDate(item["due"] as? String),
                            remainingSeconds: nil
                        )
                        self?.items.append(crawlItem)
                    }
                }
            }
            
            self?.finishCrawling()
        }
    }
    
    /// 크롤링 완료 처리
    private func finishCrawling() {
        statusMessage = "크롤링 완료"
        progress = 1.0
        isLoading = false
        
        let formatter = ISO8601DateFormatter()
        let crawlData = CrawlData(
            clientVersion: "1.0",
            clientPlatform: "iOS",
            crawledAt: formatter.string(from: Date()),
            courses: courses,
            items: items
        )
        
        print("Crawling completed: \(courses.count) courses, \(items.count) items")
        
        completion?(.success(crawlData))
    }
    
    /// 날짜 정규화
    private func normalizeDueDate(_ dateStr: String?) -> String? {
        guard let dateStr = dateStr, !dateStr.isEmpty else { return nil }
        
        let trimmed = dateStr.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 이미 올바른 형식인 경우
        if trimmed.range(of: #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?$"#, options: .regularExpression) != nil {
            return trimmed.count == 16 ? trimmed + ":00" : trimmed
        }
        
        // 한국어 날짜 형식 처리
        let patterns: [(String, String)] = [
            (#"(\d{4})년\s*(\d{1,2})월\s*(\d{1,2})일\s*(\d{1,2})시\s*(\d{1,2})분"#, "$1-$2-$3 $4:$5:00"),
            (#"(\d{4})\.(\d{1,2})\.(\d{1,2})\s*(\d{1,2}):(\d{1,2})"#, "$1-$2-$3 $4:$5:00"),
            (#"(\d{1,2})월\s*(\d{1,2})일.*?(\d{1,2}):(\d{2})"#, "2025-$1-$2 $3:$4:00"),
            (#"(\d{4})-(\d{1,2})-(\d{1,2})\s+오[전후]\s*(\d{1,2}):(\d{2})"#, "") // 오전/오후 처리 필요
        ]
        
        for (pattern, replacement) in patterns {
            if replacement.isEmpty { continue } // 복잡한 처리가 필요한 경우 스킵
            
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                
                var result = regex.stringByReplacingMatches(
                    in: trimmed,
                    range: match.range,
                    withTemplate: replacement
                )
                
                // 월/일을 2자리로 패딩
                if let dashRange = result.range(of: "-") {
                    let components = result.components(separatedBy: " ")
                    if components.count == 2 {
                        let dateParts = components[0].components(separatedBy: "-")
                        if dateParts.count == 3 {
                            let year = dateParts[0]
                            let month = String(format: "%02d", Int(dateParts[1]) ?? 1)
                            let day = String(format: "%02d", Int(dateParts[2]) ?? 1)
                            result = "\(year)-\(month)-\(day) \(components[1])"
                        }
                    }
                }
                
                return result
            }
        }
        
        // 기본값: 현재 날짜+시간
        return nil
    }
    
    enum CrawlError: Error {
        case invalidURL
        case loginFailed
        case extractionFailed
    }
}

// MARK: - WKNavigationDelegate
extension LMSWebCrawler: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        
        print("Page loaded: \(url.absoluteString)")
        
        // 수동 로그인 모드인 경우
        if manualLoginMode {
            // 로그인 성공 확인 (대시보드로 리디렉션됨)
            if url.absoluteString.contains("learn.inha.ac.kr") && 
               !url.absoluteString.contains("login") {
                manualLoginMode = false
                onManualLoginSuccess?()
            }
            return
        }
        
        // 자동 로그인 모드
        if url.absoluteString.contains("login/index.php") {
            // 로그인 페이지 로드 완료 - 자동 로그인 시도
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.performLogin()
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.errorMessage = error.localizedDescription
        self.isLoading = false
        self.completion?(.failure(error))
    }
}

// String extension for regex matching
extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression) != nil
    }
}