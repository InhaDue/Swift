import SwiftUI

struct DataLoadingView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    // WebLoginView에서 사용한 동일 세션을 이어받기 위해 외부 주입 허용
    @StateObject var crawler = LMSWebCrawler()
    @StateObject private var backgroundManager = BackgroundUpdateManager.shared
    
    let username: String
    let password: String
    
    @State private var progress: Int = 0
    @State private var isLoading: Bool = true
    @State private var accountDone: Bool = false
    @State private var assignmentDone: Bool = false
    @State private var scheduleDone: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.white.opacity(0.7))
                            .overlay(Image(systemName: "bolt.horizontal.circle.fill").foregroundColor(.secondary))
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("데이터 수집 중")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("LMS에서 정보를 가져오고 있습니다")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 4)
                    
                    ProgressView(value: Double(progress), total: 100)
                        .tint(.accentColor)
                        .animation(.easeInOut(duration: 0.35), value: progress)
                    Text("\(progress)% 완료")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // 단계 표시
                    VStack(spacing: 12) {
                        StageRow(
                            systemImage: accountDone ? "checkmark.circle.fill" : "person.crop.circle",
                            text: accountDone ? "계정 생성 및 등록 완료" : "계정 생성 및 등록중...",
                            isDone: accountDone,
                            isActive: !accountDone && !assignmentDone && !scheduleDone
                        )
                        StageRow(
                            systemImage: assignmentDone ? "checkmark.circle.fill" : "doc.text.fill",
                            text: assignmentDone ? "과제 정보 수집 완료" : "과제 정보 수집중...",
                            isDone: assignmentDone,
                            isActive: !assignmentDone && accountDone && !scheduleDone
                        )
                        VStack(alignment: .leading, spacing: 8) {
                            StageRow(
                                systemImage: scheduleDone ? "checkmark.circle.fill" : "calendar",
                                text: scheduleDone ? "수업 정보 수집 완료" : "수업 일정 수집중...",
                                isDone: scheduleDone,
                                isActive: !scheduleDone && assignmentDone
                            )
                            HStack {
                                Spacer(minLength: 0)
                                DotsLoadingIndicator(color: .blue.opacity(0.6), dotSize: 6, spacing: 8)
                                Spacer(minLength: 0)
                            }
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 10)
                )
                .frame(maxWidth: 360)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .ignoresSafeArea()
        .task {
            isLoading = true
            
            // 수동 로그인 이후 내부 크롤링 수행
            await performCrawling()
        }
    }
    
    private func performCrawling() async {
        // 단계 1: 계정 확인
        progress = 10
        withAnimation(.easeInOut(duration: 0.28)) {
            accountDone = true
        }
        
                // 단계 2: 수동 로그인 이후 실제 크롤링
                progress = 30
                
                // 실제 WebView 크롤링 시작
                crawler.startAfterManualLogin { result in
                    Task { @MainActor in
                        switch result {
                        case .success(let crawlData):
                            // 크롤링 성공
                            progress = 60
                            withAnimation(.easeInOut(duration: 0.28)) {
                                assignmentDone = true
                            }
                            
                            // 서버로 데이터 전송
                            do {
                                let studentId = UserDefaults.standard.object(forKey: "studentId") as? Int ?? 1
                                try await sendCrawlDataToServer(crawlData, studentId: studentId)
                                
                                progress = 90
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    scheduleDone = true
                                }
                                
                                // 백그라운드 업데이트 매니저에 자격 증명 저장
                                backgroundManager.saveLMSCredentials(username: username, password: password)
                                
                                // LMS 연결 상태 업데이트
                                await auth.linkLms(username: username, password: password) { _ in }
                                
                                progress = 100
                                isLoading = false
                                
                                // 완료 후 화면 닫기
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                dismiss()
                                
                            } catch {
                                errorMessage = "서버 전송 실패: \(error.localizedDescription)"
                                isLoading = false
                            }
                            
                        case .failure(let error):
                            errorMessage = "크롤링 실패: \(error.localizedDescription)"
                            isLoading = false
                        }
                    }
                }
    }
    
    private func sendCrawlDataToServer(_ data: LMSWebCrawler.CrawlData, studentId: Int) async throws {
        // 서버로 크롤링 데이터 전송
        guard let url = URL(string: "\(AppConfig.API.submitCrawlData)/\(studentId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 인증 토큰 추가
        if let token = auth.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(data)
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    // 서버 오류 응답 본문 출력
                    if let errorBody = String(data: responseData, encoding: .utf8) {
                        print("Server error response: \(errorBody)")
                        errorMessage = "서버 오류 \(httpResponse.statusCode): \(errorBody)"
                    } else {
                        errorMessage = "서버 오류: \(httpResponse.statusCode)"
                    }
                } else {
                    // 성공 시 응답 확인
                    if let successBody = String(data: responseData, encoding: .utf8) {
                        print("Server success response: \(successBody)")
                    }
                }
            }
        } catch {
            errorMessage = "데이터 전송 실패: \(error.localizedDescription)"
        }
    }
}


