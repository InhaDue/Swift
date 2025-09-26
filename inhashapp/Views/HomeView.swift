import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var deadlineStore = DeadlineStore()
    @State private var selectedFilter: ScheduleFilter = .all
    @State private var showCompleted: Bool = true
    @State private var sortOrder: SortOrder = .dueDate
    
    enum SortOrder: String, CaseIterable {
        case dueDate = "마감일순"
        case courseName = "과목명순"
        case title = "제목순"
    }

    private var filteredItems: [AssignmentItem] {
        var base = deadlineStore.filteredDeadlines
        
        // 완료 필터
        if !showCompleted {
            base = base.filter { !$0.completed }
        }
        
        // 타입 필터
        switch selectedFilter {
        case .all: break
        case .assignment: base = base.filter { $0.type == "assignment" }
        case .lecture: base = base.filter { $0.type == "lecture" || $0.type == "class" }
        }
        
        // 정렬
        switch sortOrder {
        case .dueDate: return base.sorted { $0.dueAt < $1.dueAt }
        case .courseName: return base.sorted { $0.courseName < $1.courseName }
        case .title: return base.sorted { $0.title < $1.title }
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    
                    // 날짜 필터 (중앙 정렬)
                    HStack {
                        Picker("", selection: $deadlineStore.dateFilter) {
                            ForEach(DeadlineStore.DateFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(maxWidth: 280)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    
                    // 섹션 헤더와 필터들
                    HStack(spacing: 8) {
                        SectionHeader(title: "다가오는 일정")
                        
                        Spacer()
                        
                        // 정렬 선택
                        Menu {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Button(action: { sortOrder = order }) {
                                    Label(order.rawValue, systemImage: sortOrder == order ? "checkmark" : "")
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 11))
                                Text(sortOrder.rawValue)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                        }
                        
                        // 완료 필터
                        Button(action: { showCompleted.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: showCompleted ? "eye" : "eye.slash")
                                    .font(.system(size: 11))
                                Text(showCompleted ? "전체" : "미완료")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(showCompleted ? Color(.systemGray6) : Color.blue.opacity(0.1))
                            .foregroundColor(showCompleted ? .primary : .blue)
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
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
                                ScheduleCard(item: item, deadlineStore: deadlineStore, studentId: auth.studentId ?? 0)
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
    let deadlineStore: DeadlineStore
    let studentId: Int
    
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
            // 완료 체크박스
            Button(action: {
                Task {
                    await deadlineStore.toggleCompletion(for: item, studentId: studentId)
                }
            }) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.completed ? .green : .gray)
                    .font(.system(size: 22))
            }
            
            Circle()
                .fill(item.type == "assignment" ? Color.orange : Color.blue)
                .frame(width: 10, height: 10)
                .opacity(item.completed ? 0.5 : 1.0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(item.completed ? .gray : .primary)
                    .lineLimit(1)
                    .strikethrough(item.completed)
                
                Text(item.courseName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .opacity(item.completed ? 0.6 : 1.0)
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