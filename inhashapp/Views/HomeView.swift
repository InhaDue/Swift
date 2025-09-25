import SwiftUI

struct HomeView: View {
    @StateObject private var deadlineStore = DeadlineStore.shared
    @State private var selectedFilter: ScheduleFilter = .all
    
    private var filteredItems: [DeadlineItem] {
        switch selectedFilter {
        case .all:
            return deadlineStore.thisWeekDeadlines
        case .assignment:
            return deadlineStore.thisWeekDeadlines.filter { $0.isAssignment }
        case .lecture:
            return deadlineStore.thisWeekDeadlines.filter { !$0.isAssignment }
        }
    }
    
    var body: some View {
        ZStack {
            AppBackground()
            
            if deadlineStore.isLoading {
                ProgressView("데이터 로딩 중...")
                    .padding()
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(12)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        HomeHeader()
                        
                        // 오늘 마감
                        if !deadlineStore.todayDeadlines.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "오늘 마감 ⚠️")
                                ForEach(deadlineStore.todayDeadlines) { item in
                                    DeadlineCard(item: item, isUrgent: true)
                                }
                            }
                        }
                        
                        // 이번 주 일정
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "이번 주 일정")
                            FilterBar(selected: $selectedFilter)
                            
                            if filteredItems.isEmpty {
                                EmptyStateView()
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(filteredItems) { item in
                                        DeadlineCard(item: item)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .task {
            await deadlineStore.fetchDeadlines()
        }
        .refreshable {
            await deadlineStore.fetchDeadlines()
        }
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

private struct HomeHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("안녕하세요! 👋")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                Spacer(minLength: 0)
            }
            Text("다가오는 일정을 확인해보세요")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.primary)
    }
}

private struct FilterBar: View {
    @Binding var selected: ScheduleFilter
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(ScheduleFilter.allCases, id: \.self) { filter in
                FilterChip(
                    title: filter.title,
                    isSelected: selected == filter,
                    action: { selected = filter }
                )
            }
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
                )
        }
    }
}

private struct DeadlineCard: View {
    let item: DeadlineItem
    var isUrgent: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 아이콘
            Circle()
                .fill(item.isAssignment ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: item.isAssignment ? "doc.text" : "play.circle")
                        .foregroundColor(item.isAssignment ? .blue : .green)
                )
            
            // 내용
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(item.courseName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let _ = item.dueDate {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(item.formattedDueDate)
                            .font(.caption)
                            .foregroundColor(isUrgent ? .red : .secondary)
                    }
                }
            }
            
            Spacer()
            
            // 남은 시간
            if let dueDate = item.dueDate {
                let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                VStack(spacing: 2) {
                    if days == 0 {
                        Text("오늘")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    } else if days > 0 {
                        Text("D-\(days)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(days <= 3 ? .orange : .blue)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isUrgent ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("이번 주 일정이 없습니다")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("잠시 휴식을 취해보세요 ☕️")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

#Preview {
    HomeView()
}