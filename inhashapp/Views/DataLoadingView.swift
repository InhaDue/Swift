import SwiftUI

struct DataLoadingView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    
    let username: String
    let password: String
    
    @State private var progress: Int = 0
    @State private var isLoading: Bool = true
    @State private var accountDone: Bool = false
    @State private var assignmentDone: Bool = false
    @State private var scheduleDone: Bool = false
    
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
            }
        }
        .ignoresSafeArea()
        .task {
            isLoading = true
            // 단계 1: 계정 생성 및 등록중
            for p in stride(from: 1, through: 33, by: 2) {
                try? await Task.sleep(nanoseconds: 90_000_000)
                progress = p
            }
            withAnimation(.easeInOut(duration: 0.28)) {
                accountDone = true
            }

            // 단계 2: 과제 정보 수집중
            for p in stride(from: 34, through: 66, by: 2) {
                try? await Task.sleep(nanoseconds: 90_000_000)
                progress = p
            }
            withAnimation(.easeInOut(duration: 0.28)) {
                assignmentDone = true
            }

            // 단계 3: 수업 일정 수집중
            for p in stride(from: 67, through: 100, by: 2) {
                try? await Task.sleep(nanoseconds: 90_000_000)
                progress = min(p, 100)
            }
            withAnimation(.easeInOut(duration: 0.28)) {
                scheduleDone = true
            }

            // 실제 연동 트리거 (백엔드 연동시 교체)
            await auth.linkLms(username: username, password: password) { _ in }

            isLoading = false
            dismiss()
        }
    }
}


