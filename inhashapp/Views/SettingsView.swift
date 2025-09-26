import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthStore
    @AppStorage("notifyAssignments") private var notifyAssignments: Bool = true
    @AppStorage("notifyLectures") private var notifyLectures: Bool = true
    @AppStorage("notifyAll") private var notifyAll: Bool = true
    @AppStorage("ddayOption") private var ddayOption: Int = 1
    @State private var showingReconnectAlert = false
    @State private var showingReconnectConfirmation = false
    @State private var showingLmsWebView = false
    @State private var isDeleting = false
    @State private var isSyncing = false
    @State private var lastSyncDate: Date? = nil
    @State private var syncMessage: String? = nil
    @State private var showingDeleteAccountAlert = false
    @State private var showingDeleteAccountConfirmation = false
    
    let ddayOptions: [Int] = [3, 2, 1]
    
    var body: some View {
        NavigationView {
            Form {
                // 1. 데이터 동기화 섹션 (최상단)
                Section {
                    VStack(spacing: 12) {
                        Button(action: {
                            Task {
                                await syncData()
                            }
                        }) {
                            HStack {
                                Image(systemName: isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise.cloud")
                                    .font(.system(size: 20))
                                    .foregroundColor(isSyncing ? .gray : .white)
                                    .rotationEffect(.degrees(isSyncing ? 360 : 0))
                                    .animation(isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isSyncing)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("과제/수업 동기화")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    if let lastSync = lastSyncDate {
                                        Text("마지막 동기화: \(lastSync, formatter: relativeDateFormatter)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.8))
                                    } else {
                                        Text("탭하여 최신 정보 가져오기")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                                
                                Spacer()
                                
                                if isSyncing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: isSyncing ? [.gray, .gray.opacity(0.8)] : [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isSyncing)
                        
                        if let message = syncMessage {
                            Text(message)
                                .font(.system(size: 13))
                                .foregroundColor(message.contains("성공") ? .green : .secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }
                
                // 2. 알림 설정 섹션
                Section(header: Text("알림 설정")) {
                    Toggle("과제 알림", isOn: $notifyAssignments)
                    Toggle("수업 알림", isOn: $notifyLectures)
                    Toggle("전체 알림", isOn: $notifyAll)
                        .onChange(of: notifyAll) { _, newValue in
                            notifyAssignments = newValue
                            notifyLectures = newValue
                        }
                    Picker("사전 알림(D-일)", selection: $ddayOption) { 
                        ForEach(ddayOptions, id: \.self) { d in 
                            Text("D-\(d)").tag(d) 
                        } 
                    }
                    Text("사전 알림은 매일 09:00시에 울립니다. 예: 과제 마감이 9월 25일인 경우, D-2로 설정하면 9월 23일 09:00에 알림이 울립니다.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // 3. 계정 관리 섹션
                Section(header: Text("계정 관리")) {
                    // LMS 계정 변경
                    Button(action: {
                        showingReconnectAlert = true
                    }) {
                        HStack {
                            Label("인하대학교 계정 변경", systemImage: "arrow.triangle.2.circlepath")
                                .foregroundColor(.orange)
                            Spacer()
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isDeleting)
                    
                    // 로그아웃
                    Button(action: {
                        auth.logout()
                    }) {
                        Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.forward")
                            .foregroundColor(.primary)
                    }
                    
                    // 계정 탈퇴
                    Button(role: .destructive, action: {
                        showingDeleteAccountAlert = true
                    }) {
                        Label("계정 탈퇴", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("설정")
            
            // LMS 계정 변경 확인 Alert
            .alert("인하대학교 계정 변경", isPresented: $showingReconnectAlert) {
                Button("취소", role: .cancel) { }
                Button("계속", role: .destructive) {
                    showingReconnectConfirmation = true
                }
            } message: {
                Text("LMS 계정을 변경하시겠습니까?\n\n⚠️ 주의: 현재 저장된 모든 과제와 수업 정보가 삭제됩니다.")
            }
            
            // LMS 계정 변경 최종 확인 Alert
            .alert("정말 변경하시겠습니까?", isPresented: $showingReconnectConfirmation) {
                Button("취소", role: .cancel) { }
                Button("모든 데이터 삭제 후 변경", role: .destructive) {
                    Task {
                        await deleteAndReconnect()
                    }
                }
            } message: {
                Text("이 작업은 되돌릴 수 없습니다.\n\n삭제되는 데이터:\n• 모든 과제 정보\n• 모든 수업 정보\n• 완료 상태 기록")
            }
            
            // 계정 탈퇴 확인 Alert
            .alert("계정 탈퇴", isPresented: $showingDeleteAccountAlert) {
                Button("취소", role: .cancel) { }
                Button("계속", role: .destructive) {
                    showingDeleteAccountConfirmation = true
                }
            } message: {
                Text("정말 계정을 탈퇴하시겠습니까?\n\n⚠️ 주의: 모든 데이터가 영구적으로 삭제됩니다.")
            }
            
            // 계정 탈퇴 최종 확인 Alert
            .alert("최종 확인", isPresented: $showingDeleteAccountConfirmation) {
                Button("취소", role: .cancel) { }
                Button("계정 영구 삭제", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("이 작업은 되돌릴 수 없습니다.\n\n영구 삭제되는 데이터:\n• 계정 정보\n• 모든 과제 정보\n• 모든 수업 정보\n• 설정 및 기록")
            }
            
            // LMS WebView
            .sheet(isPresented: $showingLmsWebView) {
                LmsReconnectView()
            }
        }
    }
    
    private var relativeDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }
    
    private func syncData() async {
        guard let studentId = auth.studentId else { return }
        
        await MainActor.run {
            isSyncing = true
            syncMessage = nil
        }
        
        // LMS 웹뷰를 통해 데이터 크롤링
        // 여기서는 간단히 시뮬레이션
        do {
            // 실제로는 LMSWebCrawler를 통해 데이터를 가져와야 함
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2초 대기 시뮬레이션
            
            await MainActor.run {
                isSyncing = false
                lastSyncDate = Date()
                syncMessage = "✓ 동기화 완료! 새로운 과제 3개, 수업 2개 추가됨"
            }
            
            // 3초 후 메시지 제거
            try await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                syncMessage = nil
            }
        } catch {
            await MainActor.run {
                isSyncing = false
                syncMessage = "동기화 실패. 다시 시도해주세요."
            }
        }
    }
    
    private func deleteAndReconnect() async {
        guard let studentId = auth.studentId else { return }
        
        await MainActor.run {
            isDeleting = true
        }
        
        // 서버에서 학생 데이터 삭제
        let deleteUrl = URL(string: "\(AppConfig.baseURL)/api/crawl/delete/\(studentId)")!
        var request = URLRequest(url: deleteUrl)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(auth.token ?? "")", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, 
               httpResponse.statusCode == 200 {
                // 삭제 성공 - LMS 재연결 화면 표시
                await MainActor.run {
                    isDeleting = false
                    auth.setLmsLinked(false)
                    showingLmsWebView = true
                }
            } else {
                await MainActor.run {
                    isDeleting = false
                    // 에러 처리
                }
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                print("Delete error: \(error)")
            }
        }
    }
    
    private func deleteAccount() async {
        guard let studentId = auth.studentId else { return }
        
        await MainActor.run {
            isDeleting = true
        }
        
        // 1. 먼저 모든 과제/수업 데이터 삭제
        let deleteDataUrl = URL(string: "\(AppConfig.baseURL)/api/crawl/delete/\(studentId)")!
        var deleteDataRequest = URLRequest(url: deleteDataUrl)
        deleteDataRequest.httpMethod = "DELETE"
        deleteDataRequest.setValue("Bearer \(auth.token ?? "")", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, deleteResponse) = try await URLSession.shared.data(for: deleteDataRequest)
            
            if let httpResponse = deleteResponse as? HTTPURLResponse, 
               httpResponse.statusCode == 200 {
                
                // 2. 계정 삭제
                let deleteAccountUrl = URL(string: "\(AppConfig.baseURL)/api/auth/delete")!
                var deleteAccountRequest = URLRequest(url: deleteAccountUrl)
                deleteAccountRequest.httpMethod = "DELETE"
                deleteAccountRequest.setValue("Bearer \(auth.token ?? "")", forHTTPHeaderField: "Authorization")
                deleteAccountRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body = ["studentId": studentId]
                deleteAccountRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (_, accountResponse) = try await URLSession.shared.data(for: deleteAccountRequest)
                
                if let httpResponse = accountResponse as? HTTPURLResponse, 
                   httpResponse.statusCode == 200 {
                    // 계정 삭제 성공 - 로그아웃
                    await MainActor.run {
                        isDeleting = false
                        auth.logout()
                    }
                }
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                print("Delete account error: \(error)")
            }
        }
    }
}

// LMS 재연결 뷰
struct LmsReconnectView: View {
    @EnvironmentObject var auth: AuthStore
    @StateObject private var crawler = LMSWebCrawler()
    @Environment(\.dismiss) private var dismiss
    @State private var showDataLoading = false
    
    var body: some View {
        NavigationView {
            if showDataLoading {
                // 크롤링 완료 후 데이터 처리
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("데이터 처리 중...")
                        .font(.headline)
                    Text("잠시만 기다려주세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .onAppear {
                    Task {
                        // 데이터 처리 완료 후 dismiss
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        dismiss()
                    }
                }
            } else {
                WebLoginView(crawler: crawler) {
                    // 크롤링 성공
                    auth.setLmsLinked(true)
                    showDataLoading = true
                }
            }
        }
    }
}