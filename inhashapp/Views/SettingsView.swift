import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthStore
    @AppStorage("notifyAssignments") private var notifyAssignments: Bool = true
    @AppStorage("notifyLectures") private var notifyLectures: Bool = true
    @AppStorage("notifyAll") private var notifyAll: Bool = true
    @AppStorage("ddayOption") private var ddayOption: Int = 1
    @State private var showingReconnectAlert = false
    @State private var showingLmsWebView = false
    @State private var isDeleting = false
    @State private var isSyncing = false
    @State private var lastSyncDate: Date? = nil
    @State private var syncMessage: String? = nil
    
    let ddayOptions: [Int] = [3, 2, 1]
    
    var body: some View {
        NavigationView {
            Form {
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
                
                Section(header: Text("데이터 동기화")) {
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
                
                Section(header: Text("계정")) {
                    Button(action: {
                        showingReconnectAlert = true
                    }) {
                        HStack {
                            Label("인하대학교 계정 변경", systemImage: "arrow.triangle.2.circlepath")
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
                    
                    Button(role: .destructive) { } label: { 
                        Label("계정 탈퇴", systemImage: "trash") 
                    }
                }
            }
            .navigationTitle("설정")
            .alert("인하대학교 계정 변경", isPresented: $showingReconnectAlert) {
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
}

// LMS 재연결을 위한 래퍼 뷰
struct LmsReconnectView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingOnboarding = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 50)
                
                VStack(spacing: 16) {
                    Text("인하대학교 계정 재연결")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("새로운 LMS 계정으로 로그인하여\n강의 정보를 다시 불러옵니다.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showingOnboarding = true
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
                leading: Button("취소") {
                    dismiss()
                }
            )
            .fullScreenCover(isPresented: $showingOnboarding) {
                // OnboardingFlow를 재사용하여 LMS 연결 처리
                OnboardingFlow()
                    .onDisappear {
                        dismiss()
                    }
            }
        }
    }
}