import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var auth: AuthStore
    @StateObject private var deadlineStore = DeadlineStore()
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var mode: CalendarMode = .month
    @State private var showingAddSheet: Bool = false
    
    private var monthItems: [AssignmentItem] {
        deadlineStore.allDeadlines.filter {
            Calendar.current.isDate($0.dueAt, equalTo: currentMonth, toGranularity: .month)
        }
    }
    
    private var weekItems: [AssignmentItem] {
        let calendar = Calendar.current
        let now = Date()
        
        // 이번 주의 시작과 끝 계산 (한국 시간 기준)
        var startOfWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        startOfWeek.weekday = 2 // Monday
        startOfWeek.timeZone = TimeZone(identifier: "Asia/Seoul")
        
        guard let monday = calendar.date(from: startOfWeek) else { return [] }
        guard let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else { return [] }
        
        // 일요일 23:59:59까지 포함
        let endOfWeek = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: sunday) ?? sunday
        
        return deadlineStore.allDeadlines.filter { item in
            item.dueAt >= monday && item.dueAt <= endOfWeek
        }.sorted { $0.dueAt < $1.dueAt }
    }
    
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                // 상단 바는 고정
                topBar
                    .padding(.bottom, 8)
                
                // 스크롤 가능한 콘텐츠
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if mode == .month {
                            MonthCalendarCard(month: currentMonth,
                                              selectedDate: $selectedDate,
                                              dots: monthDots())
                                .padding(.horizontal, 16)
                        } else {
                            WeekSummaryCard(weekItems: weekItems)
                                .padding(.horizontal, 16)
                        }
                        
                        MonthlySummaryCard(monthItems: monthItems)
                            .padding(.horizontal, 16)
                        
                        DayDueListCard(date: selectedDate, items: dayItems(), deadlineStore: deadlineStore, studentId: auth.studentId ?? 0)
                            .padding(.horizontal, 16)
                        
                        // 하단 여백
                        Color.clear.frame(height: 20)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .onAppear {
            Task {
                await fetchData()
            }
        }
        .refreshable {
            await fetchData()
        }
    }
    
    private func fetchData() async {
        guard let studentId = auth.studentId, let token = auth.token else {
            deadlineStore.errorMessage = "로그인 정보가 없습니다."
            return
        }
        await deadlineStore.fetchAllDeadlines(studentId: studentId, token: token)
    }
    
    private var topBar: some View {
        HStack(spacing: 12) {
            CircleIconButton(systemName: "chevron.left") { shiftMonth(-1) }
            Text(monthTitle(currentMonth))
                .font(.system(size: 18, weight: .semibold))
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                )
            CircleIconButton(systemName: "chevron.right") { shiftMonth(1) }
            Spacer()
            SegmentedMode(mode: $mode)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private func shiftMonth(_ delta: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: delta, to: currentMonth) {
            currentMonth = newDate
            if let day = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate).day {
                let comps = Calendar.current.dateComponents([.year, .month], from: newDate)
                if let newSelected = Calendar.current.date(from: DateComponents(year: comps.year, month: comps.month, day: min(day, lastDay(of: newDate)))) {
                    selectedDate = newSelected
                }
            }
        }
    }
    private func lastDay(of date: Date) -> Int { Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 28 }
    private func monthDots() -> Set<Int> { 
        var days = Set<Int>()
        let cal = Calendar.current
        for item in monthItems {
            days.insert(cal.component(.day, from: item.dueAt))
        }
        return days
    }
    private func monthTitle(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "YYYY년 M월"; return f.string(from: date) }
    private func dayItems() -> [AssignmentItem] {
        deadlineStore.allDeadlines
            .filter { Calendar.current.isDate($0.dueAt, inSameDayAs: selectedDate) }
            .sorted { $0.dueAt < $1.dueAt }
    }
}

private enum CalendarMode { case month, week }

private struct SegmentedMode: View {
    @Binding var mode: CalendarMode
    var body: some View {
        HStack(spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { mode = .month } }) {
                Text("월")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 44, height: 28)
                    .background(mode == .month ? Color(.systemGray3) : .clear)
                    .foregroundColor(mode == .month ? .white : Color(.label))
                    .clipShape(Capsule())
            }.buttonStyle(.plain)
            Button(action: { withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { mode = .week } }) {
                Text("주")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 44, height: 28)
                    .background(mode == .week ? Color(.systemGray3) : .clear)
                    .foregroundColor(mode == .week ? .white : Color(.label))
                    .clipShape(Capsule())
            }.buttonStyle(.plain)
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color(.systemGray5))
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
    }
}

private struct CircleIconButton: View {
    let systemName: String
    let action: () -> Void
    
    init(systemName: String, action: @escaping () -> Void) {
        self.systemName = systemName
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white)
                Image(systemName: systemName)
                    .foregroundColor(.primary)
            }
            .frame(width: 32, height: 32)
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct MonthCalendarCard: View {
    let month: Date
    @Binding var selectedDate: Date
    let dots: Set<Int>
    
    private var days: [Int?] {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: month)!
        let first = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let firstWeekday = cal.component(.weekday, from: first)
        let leadingBlanks = (firstWeekday + 6) % 7
        let total = leadingBlanks + range.count
        var cells: [Int?] = Array(repeating: nil, count: leadingBlanks)
        cells += range.map { Optional($0) }
        let remainder = total % 7
        if remainder != 0 { cells += Array(repeating: nil, count: 7 - remainder) }
        return cells
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                ForEach(["일","월","화","수","목","금","토"], id: \.self) { d in
                    Text(d)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7), spacing: 12) {
                ForEach(0..<days.count, id: \.self) { idx in
                    let day = days[idx]
                    ZStack {
                        if let day = day {
                            let comps = Calendar.current.dateComponents([.year, .month], from: month)
                            let cellDate = Calendar.current.date(from: DateComponents(year: comps.year, month: comps.month, day: day))!
                            let isSelected = Calendar.current.isDate(cellDate, inSameDayAs: selectedDate)
                            let isToday = Calendar.current.isDateInToday(cellDate)
                            Circle()
                                .fill(isSelected ? Color.blue : (isToday ? Color.purple.opacity(0.2) : Color.clear))
                                .frame(width: 38, height: 38)
                            Text("\(day)")
                                .font(.system(size: 14, weight: isSelected || isToday ? .semibold : .regular))
                                .foregroundColor(isSelected ? .white : (isToday ? .purple : .primary))
                            if dots.contains(day) {
                                Circle()
                                    .fill(isSelected ? Color.white : Color.orange)
                                    .frame(width: 5, height: 5)
                                    .offset(y: 14)
                            }
                        }
                    }
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let day = day {
                            let comps = Calendar.current.dateComponents([.year, .month], from: month)
                            if let newDate = Calendar.current.date(from: DateComponents(year: comps.year, month: comps.month, day: day)) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                    selectedDate = newDate
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
        )
    }
}

private struct WeekSummaryCard: View {
    let weekItems: [AssignmentItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("이번 주 일정")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            if weekItems.isEmpty {
                Text("이번 주 일정이 없습니다.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: 8) {
                    ForEach(weekItems.prefix(5)) { item in
                        HStack {
                            Circle()
                                .fill(item.type == "assignment" ? Color.orange : Color.blue)
                                .frame(width: 8, height: 8)
                            
                            Text(item.title)
                                .font(.system(size: 14))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(formatDate(item.dueAt))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if weekItems.count > 5 {
                        Text("외 \(weekItems.count - 5)개...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d(E)"
        return formatter.string(from: date)
    }
}

private struct MonthlySummaryCard: View {
    let monthItems: [AssignmentItem]
    
    private var assignmentCount: Int { monthItems.filter { $0.type == "assignment" }.count }
    private var lectureCount: Int { monthItems.filter { $0.type == "lecture" || $0.type == "class" }.count }
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("이번 달 요약")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                HStack(spacing: 16) {
                    Label("\(assignmentCount)", systemImage: "doc.text")
                        .font(.system(size: 15, weight: .semibold))
                    Label("\(lectureCount)", systemImage: "video")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

private struct DayDueListCard: View {
    let date: Date
    let items: [AssignmentItem]
    let deadlineStore: DeadlineStore
    let studentId: Int
    
    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 EEEE"
        return f.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dateString)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            if items.isEmpty {
                Text("일정 없음")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        HStack {
                            // 완료 체크박스
                            Button(action: {
                                Task {
                                    await deadlineStore.toggleCompletion(for: item, studentId: studentId)
                                }
                            }) {
                                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.completed ? .green : .gray)
                                    .font(.system(size: 20))
                            }
                            
                            Image(systemName: item.type == "assignment" ? "doc.text" : "video")
                                .foregroundColor(item.type == "assignment" ? .orange : .blue)
                                .font(.system(size: 14))
                                .frame(width: 20)
                                .opacity(item.completed ? 0.5 : 1.0)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                    .foregroundColor(item.completed ? .gray : .primary)
                                    .strikethrough(item.completed)
                                Text(item.courseName)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .opacity(item.completed ? 0.6 : 1.0)
                            }
                            
                            Spacer()
                            
                            Text(formatTime(item.dueAt))
                                .font(.system(size: 12))
                                .foregroundColor(item.completed ? .gray : .secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}