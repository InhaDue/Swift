import SwiftUI
import WebKit

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthStore
    @AppStorage("notifyAssignments") private var notifyAssignments: Bool = true
    @AppStorage("notifyLectures") private var notifyLectures: Bool = true
    @AppStorage("notifyAll") private var notifyAll: Bool = true
    @AppStorage("notifyRefreshReminder") private var notifyRefreshReminder: Bool = true
    @AppStorage("ddayOption") private var ddayOption: Int = 1
    @State private var showingReconnectAlert = false
    @State private var showingLmsWebView = false
    @State private var showingDeleteAccountAlert = false
    @State private var isDeleting = false
    
    let ddayOptions: [Int] = [3, 2, 1]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("알림 설정")) {
                    Toggle("전체 알림", isOn: $notifyAll)
                        .onChange(of: notifyAll) { _, newValue in
                            notifyAssignments = newValue
                            notifyLectures = newValue
                            notifyRefreshReminder = newValue
                        }
                    
                    Toggle("과제 알림", isOn: $notifyAssignments)
                        .disabled(!notifyAll)
                    
                    Toggle("수업 알림", isOn: $notifyLectures)
                        .disabled(!notifyAll)
                    
                    Toggle("갱신 경고 알림", isOn: $notifyRefreshReminder)
                        .disabled(!notifyAll)
                    Picker("사전 알림(D-일)", selection: $ddayOption) { 
                        ForEach(ddayOptions, id: \.self) { d in 
                            Text("D-\(d)").tag(d) 
                        } 
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("사전 알림은 매일 09:00시에 울립니다. 예: 과제 마감이 9월 25일인 경우, D-2로 설정하면 9월 23일 09:00에 알림이 울립니다.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("갱신 경고 알림은 마지막 갱신일로부터 3일, 7일 후에 발송됩니다.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Section(header: Text("계정")) {
                    Button(action: {
                        showingReconnectAlert = true
                    }) {
                        HStack {
                            Label("LMS 계정 변경", systemImage: "arrow.triangle.2.circlepath")
                                .foregroundColor(.primary)
                            Spacer()
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isDeleting)
                    
                    Button(role: .destructive) { 
                        auth.logout() 
                    } label: { 
                        Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.forward") 
                    }
                    
                    Button(role: .destructive) { 
                        showingDeleteAccountAlert = true
                    } label: { 
                        Label("계정 탈퇴", systemImage: "trash") 
                    }
                }
            }
            .navigationTitle("설정")
            .alert("LMS 계정 변경", isPresented: $showingReconnectAlert) {
                Button("취소", role: .cancel) { }
                Button("계속", role: .destructive) {
                    Task {
                        await deleteAndReconnect()
                    }
                }
            } message: {
                Text("기존 LMS 계정에서 로그아웃되며, 현재 저장된 모든 강의, 과제, 수업 정보가 삭제됩니다. 계속하시겠습니까?")
            }
            .sheet(isPresented: $showingLmsWebView) {
                LmsReconnectView()
            }
            .alert("계정 탈퇴", isPresented: $showingDeleteAccountAlert) {
                Button("취소", role: .cancel) { }
                Button("탈퇴", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("정말로 계정을 탈퇴하시겠습니까? 모든 데이터가 삭제되며 복구할 수 없습니다.")
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
        request.setValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, 
               httpResponse.statusCode == 200 {
                // 삭제 성공 - LMS 재연결 화면 표시
                await MainActor.run {
                    isDeleting = false
                    // LMS 연결 상태 초기화
                    auth.setLmsLinked(false)
                    // WebView 표시
                    showingLmsWebView = true
                }
            } else {
                await MainActor.run {
                    isDeleting = false
                }
            }
        } catch {
            print("Failed to delete data: \(error)")
            await MainActor.run {
                isDeleting = false
            }
        }
    }
    
    private func deleteAccount() async {
        guard let studentId = auth.studentId else { return }
        
        await MainActor.run {
            isDeleting = true
        }
        
        // 1. 서버에서 학생 데이터 삭제
        let deleteDataUrl = URL(string: "\(AppConfig.baseURL)/api/crawl/delete/\(studentId)")!
        var deleteDataRequest = URLRequest(url: deleteDataUrl)
        deleteDataRequest.httpMethod = "DELETE"
        deleteDataRequest.setValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
        
        // 2. 계정 삭제 API 호출 (서버에 구현 필요)
        let deleteAccountUrl = URL(string: "\(AppConfig.baseURL)/api/auth/delete/\(studentId)")!
        var deleteAccountRequest = URLRequest(url: deleteAccountUrl)
        deleteAccountRequest.httpMethod = "DELETE"
        deleteAccountRequest.setValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
        
        do {
            // 데이터 삭제
            _ = try await URLSession.shared.data(for: deleteDataRequest)
            
            // 계정 삭제
            _ = try await URLSession.shared.data(for: deleteAccountRequest)
            
            // 성공 시 WebView 세션 초기화 후 로그아웃
            await MainActor.run {
                isDeleting = false
                
                // WebView 세션 초기화
                WKWebsiteDataStore.default().removeData(
                    ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                    modifiedSince: Date(timeIntervalSince1970: 0)
                ) { [weak auth] in
                    // 로컬 데이터 삭제
                    UserDefaults.standard.removeObject(forKey: "studentId")
                    UserDefaults.standard.removeObject(forKey: "lmsUsername")
                    // 키체인에서 비밀번호 삭제
                    if let username = UserDefaults.standard.string(forKey: "lmsUsername") {
                        KeychainHelper.shared.delete(service: "com.inhash.app", account: username)
                    }
                    // 로그아웃
                    auth?.logout()
                }
            }
        } catch {
            print("Failed to delete account: \(error)")
            await MainActor.run {
                isDeleting = false
            }
        }
    }
}

// LMS 재연결을 위한 래퍼 뷰  
struct LmsReconnectView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var crawler = LMSWebCrawler()
    @State private var showingWebLogin = false
    @State private var showingDataLoading = false
    @State private var lmsUsername = ""
    @State private var lmsPassword = ""
    
    var body: some View {
        NavigationView {
            if showingDataLoading {
                // DataLoadingView 표시 (갱신 모드)
                DataLoadingView(
                    username: lmsUsername,
                    password: lmsPassword,
                    isRefreshMode: true,
                    onRefreshComplete: { success in
                        if success {
                            // 재연결 성공 시 LMS 연결 상태 업데이트
                            auth.setLmsLinked(true)
                            dismiss()
                        }
                    }
                )
                .environmentObject(auth)
            } else if showingWebLogin {
                // WebLoginView 표시
                WebLoginView(crawler: crawler) {
                    // 로그인 성공 시 DataLoadingView로 전환
                    // LMS 자격 증명 저장
                    if let savedUsername = UserDefaults.standard.string(forKey: "lmsUsername") {
                        lmsUsername = savedUsername
                        if let savedPassword = KeychainHelper.shared.read(service: "com.inhash.app", 
                                                                         account: savedUsername) {
                            lmsPassword = savedPassword
                        } else {
                            lmsPassword = "temp_password"
                        }
                    }
                    
                    withAnimation {
                        showingDataLoading = true
                    }
                }
            } else {
                // 초기 화면
                VStack(spacing: 30) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .padding(.top, 50)
                    
                    VStack(spacing: 16) {
                        Text("LMS 계정 재연결")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("새로운 LMS 계정으로 로그인하여\n강의 정보를 다시 불러옵니다.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showingWebLogin = true
                    }) {
                        HStack {
                            Image(systemName: "safari")
                            Text("LMS 로그인")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .navigationBarItems(
                    trailing: Button("취소") { dismiss() }
                )
            }
        }
    }
}

// KeychainHelper extension for delete
extension KeychainHelper {
    func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}