import SwiftUI

struct DataRefreshView: View {
    @EnvironmentObject var auth: AuthStore
    @State private var isRefreshing = false
    @State private var lastRefreshTime: Date?
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // 상태 아이콘
                Image(systemName: isRefreshing ? "arrow.clockwise.circle.fill" : "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(isRefreshing ? .blue : .green)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                
                // 상태 텍스트
                Text(isRefreshing ? "데이터 갱신 중..." : "데이터가 최신 상태입니다")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                // 마지막 갱신 시간
                if let lastRefreshTime = lastRefreshTime {
                    Text("마지막 갱신: \(lastRefreshTime, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 갱신 버튼
                Button(action: refreshData) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("지금 갱신하기")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(isRefreshing ? Color.gray : Color.blue)
                    .cornerRadius(10)
                }
                .disabled(isRefreshing)
                
                // 에러 메시지
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("데이터 갱신")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("갱신 완료", isPresented: $showSuccess) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("LMS 데이터가 성공적으로 갱신되었습니다.")
        }
    }
    
    private func refreshData() {
        isRefreshing = true
        errorMessage = nil
        
        // 실제 데이터 갱신 로직은 DataSyncService를 통해 구현
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isRefreshing = false
            lastRefreshTime = Date()
            showSuccess = true
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }
}

#Preview {
    DataRefreshView()
        .environmentObject(AuthStore())
}
