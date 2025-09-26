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
    private var currentCrawlInfo: (courseId: String, courseName: String, type: String)?
    private var isCrawling = false
    
    /// 과목명 정리 (불필요한 접두사 제거)
    private func cleanCourseName(_ name: String) -> String {
        let prefixesToRemove = [
            "비러닝학부",
            "오프라인학부",
            "원격활용학부",
            "블렌디드러닝학부",
            "온라인학부",
            "비대면학부",
            "대면학부"
        ]
        
        var cleaned = name
        for prefix in prefixesToRemove {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        return cleaned
    }
    
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
    
    /// 백그라운드에서 크롤링 수행 (UI 없이)
    func performBackgroundCrawl(username: String, password: String) async -> Result<CrawlData, Error> {
        return await withCheckedContinuation { continuation in
            // 메인 스레드에서 WebView 크롤링 수행
            Task { @MainActor in
                // 크롤링 시작
                self.startCrawling(username: username, password: password) { result in
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    /// 크롤링 데이터를 서버로 전송
    func submitCrawlData(_ crawlData: CrawlData, studentId: Int) async -> Result<Void, Error> {
        guard let url = URL(string: "\(AppConfig.baseURL)/api/crawl/submit/\(studentId)") else {
            return .failure(NSError(domain: "LMSCrawler", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // AuthStore에서 토큰 가져오기
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(crawlData)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return .success(())
                } else {
                    // 에러 응답 파싱
                    if let errorData = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                        return .failure(NSError(domain: "LMSCrawler", code: httpResponse.statusCode, 
                                              userInfo: [NSLocalizedDescriptionKey: errorData.error]))
                    }
                    return .failure(NSError(domain: "LMSCrawler", code: httpResponse.statusCode, 
                                          userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"]))
                }
            }
            
            return .failure(NSError(domain: "LMSCrawler", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
            
        } catch {
            return .failure(error)
        }
    }
    
    struct ErrorResponse: Codable {
        let success: Bool
        let error: String
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
    
    /// 로그인 성공 처리
    private func handleLoginSuccess() {
        guard !isCrawling else { return }
        isCrawling = true
        
        // 로그인 성공 시 계정 정보를 Keychain에 저장
        if let username = currentUsername, let password = currentPassword {
            _ = KeychainHelper.shared.saveLMSCredentials(username: username, password: password)
        }
        
        extractCourses()
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
                    return CrawlData.Course(name: self.cleanCourseName(name), mainLink: mainLink)
                }
                
                print("Found \(self.courses.count) courses")
                
                if self.courses.isEmpty {
                    // 과목이 없으면 에러 - 대시보드 데이터는 과목 정보가 없어 사용 안함
                    print("ERROR: No courses found! Cannot proceed without course information")
                    self.errorMessage = "과목 정보를 찾을 수 없습니다"
                    self.finishCrawling()
                } else {
                    // 각 과목별로 크롤링 시작
                    print("Starting course-by-course crawling with \(self.courses.count) courses")
                    self.currentCourseIndex = 0
                    self.crawlNextCourse()
                }
            } else {
                // 추출 실패 시 에러
                print("ERROR: Failed to extract courses from JavaScript")
                self.errorMessage = "과목 정보 추출 실패"
                self.finishCrawling()
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
        let cleanedCourseName = cleanCourseName(courseName)
        print("=== Crawling assignments for course: \(cleanedCourseName) (ID: \(courseId))")
        
        let assignUrl = "https://learn.inha.ac.kr/mod/assign/index.php?id=\(courseId)"
        guard let url = URL(string: assignUrl) else {
            print("Invalid assignment URL for course: \(cleanedCourseName)")
            crawlVODs(courseId: courseId, courseName: courseName)
            return
        }
        
        // 현재 크롤링 정보 저장 (페이지 로드 완료 후 사용)
        self.currentCrawlInfo = (courseId: courseId, courseName: courseName, type: "assignment")
        
        // 페이지 로드
        webView.stopLoading()
        webView.load(URLRequest(url: url))
        // webView:didFinishNavigation:에서 계속됨
    }
    
    /// 과제 데이터 추출 (페이지 로드 완료 후 호출)
    private func extractAssignmentData(courseId: String, courseName: String) {
        let cleanedCourseName = cleanCourseName(courseName)
        print("Extracting assignment data for: \(cleanedCourseName)")
        
        let assignScript = """
            (function() {
                var assignments = [];
                
                // 방법 1: 일반 테이블에서 찾기
                var tables = document.querySelectorAll('table.generaltable, table.flexible, table');
                
                console.log('Found ' + tables.length + ' tables');
                
                for (var t = 0; t < tables.length; t++) {
                    var table = tables[t];
                    var headers = [];
                    var headerCells = table.querySelectorAll('thead th, thead td, tr:first-child th, tr:first-child td');
                    
                    for (var h = 0; h < headerCells.length; h++) {
                        headers.push(headerCells[h].textContent.toLowerCase().trim());
                    }
                    
                    console.log('Table ' + t + ' headers: ' + headers.join(', '));
                    
                    // 헤더가 없거나 너무 적으면 스킵
                    if (headers.length < 2) continue;
                    
                    var titleCol = -1, dueCol = -1;
                    
                    // 과제 컬럼 찾기 (보통 두 번째 컬럼)
                    for (var i = 0; i < headers.length; i++) {
                        if (headers[i].includes('과제') || headers[i].includes('assignment') || 
                            headers[i].includes('활동') || headers[i] === '과제') {
                            titleCol = i;
                            break;
                        }
                    }
                    
                    // 못 찾으면 두 번째 컬럼 시도 (0번은 주차, 1번이 과제명인 경우가 많음)
                    if (titleCol === -1 && headers.length > 1) {
                        if (headers[0].includes('주') || headers[0].includes('week')) {
                            titleCol = 1;
                        } else {
                            titleCol = 0;
                        }
                    }
                    
                    // 종료 일시 컬럼 찾기
                    for (var i = 0; i < headers.length; i++) {
                        if (headers[i].includes('종료') || headers[i].includes('마감') || 
                            headers[i].includes('due') || headers[i].includes('끝')) {
                            dueCol = i;
                            break;
                        }
                    }
                    
                    // 시작 일시 다음이 종료 일시일 가능성
                    if (dueCol === -1) {
                        for (var i = 0; i < headers.length - 1; i++) {
                            if (headers[i].includes('시작')) {
                                dueCol = i + 1;
                                break;
                            }
                        }
                    }
                    
                    // 그래도 없으면 2번째 또는 3번째 컬럼 시도
                    if (dueCol === -1 && headers.length >= 3) {
                        dueCol = 2; // 보통 3번째 컬럼이 종료일시
                    }
                    
                    console.log('Using title column: ' + titleCol + ', due column: ' + dueCol);
                    
                    if (titleCol >= 0) {
                        var rows = table.querySelectorAll('tbody tr');
                        if (rows.length === 0) {
                            rows = table.querySelectorAll('tr').length > 1 ? 
                                   Array.from(table.querySelectorAll('tr')).slice(1) : [];
                        }
                        
                        console.log('Processing ' + rows.length + ' rows');
                        
                        for (var r = 0; r < rows.length; r++) {
                            var cells = rows[r].querySelectorAll('td');
                            if (cells.length > titleCol) {
                                var titleCell = cells[titleCol];
                                var link = titleCell.querySelector('a[href*="/mod/assign/"]');
                                
                                if (link) {
                                    var title = link.textContent.trim();
                                    var url = link.href;
                                    var due = (dueCol >= 0 && cells[dueCol]) ? 
                                             cells[dueCol].textContent.trim() : '';
                                    
                                    if (title && title !== '-' && due && due !== '-' && due !== '') {
                                        console.log('Found assignment: ' + title + ' (due: ' + due + ')');
                                        assignments.push({
                                            title: title,
                                            url: url,
                                            due: due
                                        });
                                    } else if (title) {
                                        console.log('Skipping assignment without due date: ' + title);
                                    }
                                }
                            }
                        }
                    }
                }
                
                // 방법 2: 과제 리스트 div에서 찾기 (마감일 없으면 스킵)
                // 이 방법은 백업용이므로 주석 처리
                /*
                var assignDivs = document.querySelectorAll('.assign-name a, .activity.assign a');
                assignDivs.forEach(function(link) {
                    var title = link.textContent.trim();
                    var url = link.href;
                    
                    // 중복 체크
                    var exists = assignments.some(function(a) {
                        return a.title === title;
                    });
                    
                    if (!exists && title) {
                        console.log('Found assignment from div (no due date): ' + title);
                    }
                });
                */
                
                console.log('Total assignments found: ' + assignments.length);
                return JSON.stringify(assignments);
            })();
            """
            
        // 현재 페이지 URL 확인
        webView.evaluateJavaScript("window.location.href") { [weak self] currentUrl, _ in
            print("Current page URL when extracting assignments: \(currentUrl ?? "unknown")")
            
            self?.webView.evaluateJavaScript(assignScript) { result, error in
                    if let json = result as? String,
                       let data = json.data(using: .utf8),
                       let assignments = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        
                        print("📋 Assignment table found \(assignments.count) items for \(cleanedCourseName)")
                        
                        for assign in assignments {
                            if let title = assign["title"] as? String,
                               let url = assign["url"] as? String,
                               let due = assign["due"] as? String {
                                
                                // vivado 관련 항목 디버깅
                                if title.lowercased().contains("vivado") {
                                    print("🔍 Found vivado assignment: '\(title)' in course: '\(cleanedCourseName)' from page: \(currentUrl ?? "unknown")")
                                }
                                
                                let item = CrawlData.Item(
                                    type: "assignment",
                                    courseName: cleanedCourseName,
                                    title: title,
                                    url: nil,  // URL 전송하지 않음 (개인정보 보호)
                                    due: self?.normalizeDueDate(due),
                                    remainingSeconds: nil
                                )
                                self?.items.append(item)
                            }
                        }
                    }
                
                // VOD 크롤링으로 이동
                self?.currentCrawlInfo = nil  // 현재 작업 초기화
                self?.crawlVODs(courseId: courseId, courseName: courseName)
            }
        }
    }
    
    /// VOD 페이지 크롤링
    private func crawlVODs(courseId: String, courseName: String) {
        let cleanedCourseName = cleanCourseName(courseName)
        print("=== Crawling VODs for course: \(cleanedCourseName) (ID: \(courseId))")
        
        let courseUrl = "https://learn.inha.ac.kr/course/view.php?id=\(courseId)"
        guard let url = URL(string: courseUrl) else {
            currentCourseIndex += 1
            crawlNextCourse()
            return
        }
        
        // 현재 크롤링 정보 저장 (페이지 로드 완료 후 사용)
        self.currentCrawlInfo = (courseId: courseId, courseName: courseName, type: "vod")
        
        // 페이지 로드
        webView.stopLoading()
        webView.load(URLRequest(url: url))
        // webView:didFinishNavigation:에서 계속됨
    }
    
    /// VOD 데이터 추출 (페이지 로드 완료 후 호출)
    private func extractVODData(courseId: String, courseName: String) {
        let cleanedCourseName = cleanCourseName(courseName)
        print("Extracting VOD data for: \(cleanedCourseName)")
        
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
                
                // 과제도 찾기 (과목 페이지에서)
                var assignItems = document.querySelectorAll('li.activity.assign.modtype_assign');
                console.log('Found ' + assignItems.length + ' assignments in course page');
                
                assignItems.forEach(function(item) {
                    var link = item.querySelector('.activityinstance a[href]');
                    var titleEl = item.querySelector('.activityinstance .instancename');
                    var availabilityEl = item.querySelector('.availability-info');
                    
                    if (titleEl && link) {
                        var title = titleEl.textContent.trim();
                        title = title.replace(/과제$/, '').trim();
                        
                        // 마감일 추출 시도
                        var due = null;
                        if (availabilityEl) {
                            var availText = availabilityEl.textContent;
                            // "~까지" 패턴 찾기
                            var dueMatch = availText.match(/(\\d{4}년 \\d{1,2}월 \\d{1,2}일.*?까지)/);
                            if (dueMatch) {
                                due = dueMatch[1];
                                console.log('Found due date for ' + title + ': ' + due);
                            }
                        }
                        
                        vods.push({
                            title: title,
                            url: link.href,
                            due: due,
                            isAssignment: true
                        });
                        
                        console.log('Found assignment in course page: ' + title);
                    }
                });
                
                return JSON.stringify(vods);
            })();
            """
            
        webView.evaluateJavaScript(vodScript) { [weak self] result, error in
                if let json = result as? String,
                   let data = json.data(using: .utf8),
                   let vods = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    
                    for vod in vods {
                        if let title = vod["title"] as? String {
                            let url = vod["url"] as? String
                            let due = vod["due"] as? String
                            let isAssignment = vod["isAssignment"] as? Bool ?? false
                            
                            // vivado 관련 항목 디버깅
                            if title.lowercased().contains("vivado") {
                                print("🔍 Found vivado \(isAssignment ? "assignment" : "VOD"): '\(title)' in course: '\(cleanedCourseName)'")
                            }
                            
                            // 객체지향프로그래밍기초 과제 디버깅
                            if cleanedCourseName.contains("객체지향프로그래밍기초") && isAssignment {
                                print("✅ Found 객체지향프로그래밍기초 assignment: '\(title)' with due: \(due ?? "no due date")")
                            }
                            
                            // 마감일 정규화
                            var normalizedDue: String? = nil
                            if due != nil && due != "" {
                                normalizedDue = self?.normalizeDueDate(due)
                            }
                            
                            // 과제인데 마감일이 없으면 건너뛰기
                            if isAssignment && normalizedDue == nil {
                                print("⚠️ Skipping assignment '\(title)' - no valid due date")
                                continue
                            }
                            
                            let item = CrawlData.Item(
                                type: isAssignment ? "assignment" : "class",
                                courseName: cleanedCourseName,
                                title: title,
                                url: nil,  // URL 전송하지 않음 (개인정보 보호)
                                due: normalizedDue,
                                remainingSeconds: nil
                            )
                            self?.items.append(item)
                        }
                    }
                }
                
            // 다음 과목으로
            self?.currentCrawlInfo = nil  // 현재 작업 초기화
            self?.currentCourseIndex += 1
            self?.crawlNextCourse()
        }
    }
    
    /// 대시보드 데이터 추출 (폴백)
    private func extractDashboardData() {
        statusMessage = "대시보드 데이터 수집 중..."
        
        // 대시보드에서 upcoming assignments 가져오기
        let dashboardScript = """
            (function() {
                var assignments = [];
                
                // 방법 1: 타임라인 블록에서 과제 찾기
                var timelineItems = document.querySelectorAll('.block_timeline .timeline-event-list li');
                timelineItems.forEach(function(item) {
                    var link = item.querySelector('a[href*="/mod/assign/"]');
                    if (link) {
                        var title = link.textContent.trim();
                        var url = link.href;
                        
                        // 마감일과 과목명 추출
                        var text = item.textContent;
                        var courseMatch = text.match(/\\[([^\\]]+)\\]/);
                        var courseName = courseMatch ? courseMatch[1] : 'Unknown';
                        
                        // 날짜 패턴 찾기
                        var dateMatch = text.match(/(\\d{4}년 \\d{1,2}월 \\d{1,2}일[^,]*)/);
                        var due = dateMatch ? dateMatch[1] : null;
                        
                        assignments.push({
                            title: title,
                            url: url,
                            due: due,
                            courseName: courseName
                        });
                        
                        console.log('Timeline assignment: ' + title + ' (' + courseName + ') due: ' + due);
                    }
                });
                
                // 방법 2: myoverview 블록에서 과제 찾기
                var overviewItems = document.querySelectorAll('.block_myoverview .event-list-item');
                overviewItems.forEach(function(item) {
                    var link = item.querySelector('a[href*="/mod/assign/"]');
                    if (link) {
                        var title = link.textContent.trim();
                        var url = link.href;
                        
                        var courseEl = item.querySelector('.text-muted');
                        var courseName = courseEl ? courseEl.textContent.trim() : 'Unknown';
                        
                        var dueEl = item.querySelector('.text-right, .event-time');
                        var due = dueEl ? dueEl.textContent.trim() : null;
                        
                        // 중복 체크
                        var exists = assignments.some(function(a) {
                            return a.title === title && a.courseName === courseName;
                        });
                        
                        if (!exists) {
                            assignments.push({
                                title: title,
                                url: url,
                                due: due,
                                courseName: courseName
                            });
                            
                            console.log('Overview assignment: ' + title + ' (' + courseName + ') due: ' + due);
                        }
                    }
                });
                
                return JSON.stringify(assignments);
            })();
            """
        
        webView.evaluateJavaScript(dashboardScript) { [weak self] result, error in
            if let json = result as? String,
               let data = json.data(using: .utf8),
               let assignments = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                
                for assign in assignments {
                    if let title = assign["title"] as? String,
                       let courseName = assign["courseName"] as? String {
                        let due = assign["due"] as? String
                        
                        let cleanedCourseName = self?.cleanCourseName(courseName) ?? courseName
                        
                        // 대시보드에서 찾은 모든 과제 추가
                        print("🎯 Found assignment in dashboard: '\(title)' for '\(cleanedCourseName)'")
                        
                        if let normalizedDue = self?.normalizeDueDate(due) {
                            let item = CrawlData.Item(
                                type: "assignment",
                                courseName: cleanedCourseName,
                                title: title,
                                url: nil,
                                due: normalizedDue,
                                remainingSeconds: nil
                            )
                            self?.items.append(item)
                        } else {
                            print("⚠️ Dashboard assignment '\(title)' has no valid due date")
                        }
                    }
                }
            }
            
            // 기존 로직 계속...
            self?.extractCoursesFromDashboard()
        }
    }
    
    /// 대시보드에서 과목 목록 추출 (기존 로직)
    private func extractCoursesFromDashboard() {
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
                            url: nil,  // URL 전송하지 않음 (개인정보 보호)
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
        
        // 현재 크롤링 정보가 있으면 해당 작업 수행 (동기적 처리)
        if let crawlInfo = currentCrawlInfo {
            if crawlInfo.type == "assignment" && url.absoluteString.contains("mod/assign/index.php") {
                // 과제 페이지 로드 완료 - 1초 후 데이터 추출
                print("Assignment page loaded for \(crawlInfo.courseName), extracting data...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.extractAssignmentData(courseId: crawlInfo.courseId, courseName: crawlInfo.courseName)
                }
                return
            } else if crawlInfo.type == "vod" && url.absoluteString.contains("course/view.php") {
                // VOD 페이지 로드 완료 - 1초 후 데이터 추출
                print("VOD page loaded for \(crawlInfo.courseName), extracting data...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.extractVODData(courseId: crawlInfo.courseId, courseName: crawlInfo.courseName)
                }
                return
            }
        }
        
        // 자동 로그인 모드
        if url.absoluteString.contains("login/index.php") {
            // 로그인 페이지 로드 완료 - 자동 로그인 시도
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.performLogin()
            }
        } else if url.absoluteString.contains("learn.inha.ac.kr") && 
                  (url.absoluteString.contains("/my") || url.absoluteString.contains("/course")) &&
                  !isCrawling {
            // 로그인 성공 후 대시보드 또는 과목 페이지
            handleLoginSuccess()
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