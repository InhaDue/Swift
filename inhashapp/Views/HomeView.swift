import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var deadlineStore = DeadlineStore()
    @State private var selectedFilter: ScheduleFilter = .all

    private var filteredItems: [AssignmentItem] {
        let base = deadlineStore.allDeadlines.sorted { $0.dueAt < $1.dueAt }
        switch selectedFilter {
        case .all: return base
        case .assignment: return base.filter { $0.type == "assignment" }
        case .lecture: return base.filter { $0.type == "lecture" || $0.type == "class" }
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    
                    SectionHeader(title: "다가오는 일정")
                    FilterBar(selected: $selectedFilter)
                    if deadlineStore.isLoading {
                        ProgressView("로딩 중...")
                            .padding()
                    } else if let errorMessage = deadlineStore.errorMessage {
                        Text("오류: \(errorMessage)")
                            .foregroundColor(.red)
                            .padding()
                    } else if filteredItems.isEmpty {
                        Text("다가오는 일정이 없습니다.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredItems) { item in
                                ScheduleCard(item: item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .refreshable {
                await fetchData()
            }
        }
        .onAppear {
            Task {
                await fetchData()
            }
        }
    }

    private func fetchData() async {
        guard let studentId = auth.studentId, let token = auth.token else {
            deadlineStore.errorMessage = "로그인 정보가 없습니다."
            return
        }
        await deadlineStore.fetchAllDeadlines(studentId: studentId, token: token)
    }
}

private enum ScheduleFilter: CaseIterable { 
    case all, assignment, lecture
    
    var title: String {
        switch self {
        case .all: return "전체"
        case .assignment: return "과제"
        case .lecture: return "수업"
        }
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 10)
    }
}

private struct FilterBar: View {
    @Binding var selected: ScheduleFilter
    var body: some View {
        HStack(spacing: 8) {
            ForEach(ScheduleFilter.allCases, id: \.self) { filter in
                FilterChip(title: filter.title, isSelected: selected == filter) {
                    selected = filter
                }
            }
            Spacer()
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
        }
    }
}

private struct ScheduleCard: View {
    let item: AssignmentItem
    
    private var timeRemaining: String {
        let now = Date()
        let diff = item.dueAt.timeIntervalSince(now)
        
        if diff < 0 {
            return "지남"
        } else if diff < 3600 {
            return "\(Int(diff/60))분 남음"
        } else if diff < 86400 {
            return "\(Int(diff/3600))시간 남음"
        } else {
            return "\(Int(diff/86400))일 남음"
        }
    }
    
    private var isUrgent: Bool {
        item.dueAt.timeIntervalSince(Date()) < 86400
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(item.type == "assignment" ? Color.orange : Color.blue)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(item.courseName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeRemaining)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isUrgent ? .red : .secondary)
                
                Text(formatDate(item.dueAt))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}