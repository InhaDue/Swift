import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var mode: CalendarMode = .month
    @State private var showingAddSheet: Bool = false
    
    private var monthItems: [ScheduleItem] { store.items.filter { Calendar.current.isDate($0.due, equalTo: currentMonth, toGranularity: .month) } }
    private var weekItems: [ScheduleItem] {
        let cal = Calendar.current
        let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let endOfWeek = cal.date(byAdding: .day, value: 7, to: startOfWeek)!
        return store.items.filter { $0.due >= startOfWeek && $0.due < endOfWeek }
    }
    
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 16) {
                topBar
                
                if mode == .month {
                    MonthCalendarCard(month: currentMonth,
                                      selectedDate: $selectedDate,
                                      dots: monthDots())
                        .padding(.horizontal, 16)
                } else {
                    WeekPlaceholder()
                        .padding(.horizontal, 16)
                }
                
                MonthlySummaryCard(monthItems: monthItems)
                    .padding(.horizontal, 16)
                
                DayDueListCard(date: selectedDate, items: dayItems())
                    .padding(.horizontal, 16)
                
                Spacer(minLength: 0)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: { showingAddSheet = true }) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .font(.system(size: 22, weight: .bold))
                }
                .frame(width: 54, height: 54)
                .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
                .padding(20)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddReminderSheet(initialDate: selectedDate) { newItem in
                store.items.append(newItem)
            }
        }
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
    private func monthDots() -> Set<Int> { var days = Set<Int>(); let cal = Calendar.current; for it in monthItems { days.insert(cal.component(.day, from: it.due)) }; return days }
    private func monthTitle(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "YYYY년 M월"; return f.string(from: date) }
    private func dayItems() -> [ScheduleItem] {
        store.items
            .filter { Calendar.current.isDate($0.due, inSameDayAs: selectedDate) }
            .sorted { $0.due < $1.due }
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
                                .fill(
                                    isSelected ? Color.blue : Color.white.opacity(0.9)
                                )
                                .frame(width: 36, height: 36)
                                .shadow(color: .black.opacity(isSelected ? 0.2 : 0.06), radius: isSelected ? 8 : 6, x: 0, y: 4)
                            Text("\(day)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(isSelected ? .white : .primary)
                            if dots.contains(day) {
                                Circle().fill(isSelected ? Color.white : Color.blue)
                                    .frame(width: 4, height: 4)
                                    .offset(y: 13)
                            }
                            if isToday && !isSelected {
                                Circle().stroke(Color.blue.opacity(0.35), lineWidth: 1)
                                    .frame(width: 36, height: 36)
                            }
                        } else {
                            Color.clear.frame(height: 36)
                        }
                    }
                    .frame(height: 40)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let day = day {
                            let comps = Calendar.current.dateComponents([.year, .month], from: month)
                            if let d = Calendar.current.date(from: DateComponents(year: comps.year, month: comps.month, day: day)) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { selectedDate = d }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
        )
    }
}

private struct MonthlySummaryCard: View {
    let monthItems: [ScheduleItem]
    
    private var countAssignments: Int { monthItems.filter { $0.type == .assignment }.count }
    private var countLectures: Int { monthItems.filter { $0.type == .lecture }.count }
    private var countUrgent: Int {
        let now = Date()
        return monthItems.filter { $0.due <= Calendar.current.date(byAdding: .day, value: 2, to: now)! }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("이번 달 요약")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            HStack {
                SummaryStat(value: countAssignments, label: "총 과제", color: .blue)
                Spacer()
                SummaryStat(value: countLectures, label: "수업", color: .green)
                Spacer()
                SummaryStat(value: countUrgent, label: "긴급", color: .red)
            }
            .padding(.horizontal, 6)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
        )
    }
}

private struct SummaryStat: View {
    let value: Int
    let label: String
    let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WeekPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(0.9))
            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
            .overlay(
                Text("주간 보기 준비중")
                    .foregroundColor(.secondary)
            )
            .frame(height: 120)
    }
}

private struct DayDueListCard: View {
    let date: Date
    let items: [ScheduleItem]
    
    private var dateTitle: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 마감"
        return f.string(from: date)
    }
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dateTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            if items.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.secondary)
                    Text("마감 항목이 없습니다")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                    Spacer()
                }
                .padding(.vertical, 6)
            } else {
                ForEach(items.prefix(4)) { item in
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(color(for: item.type).opacity(0.15))
                            Image(systemName: item.type.icon)
                                .foregroundColor(color(for: item.type))
                                .font(.footnote)
                        }
                        .frame(width: 26, height: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.footnote.weight(.semibold))
                                .lineLimit(1)
                            Text(item.course)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(timeFormatter.string(from: item.due))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
        )
    }
    
    private func color(for type: ScheduleType) -> Color {
        switch type {
        case .assignment: return .blue
        case .lecture: return .green
        }
    }
}

private struct AddReminderSheet: View {
    @Environment(\..dismiss) private var dismiss
    let onAdd: (ScheduleItem) -> Void
    @State private var title: String = ""
    @State private var course: String = ""
    @State private var type: ScheduleType = .assignment
    @State private var due: Date
    
    init(initialDate: Date, onAdd: @escaping (ScheduleItem) -> Void) {
        self._due = State(initialValue: initialDate)
        self.onAdd = onAdd
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("유형")) {
                    Picker("유형", selection: $type) {
                        ForEach(ScheduleType.allCases) { t in
                            Text(t.title).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section(header: Text("제목")) {
                    TextField("예: 과제 제출 알림", text: $title)
                }
                Section(header: Text("과목")) {
                    TextField("예: 객체지향프로그래밍", text: $course)
                }
                Section(header: Text("마감일시")) {
                    DatePicker("마감", selection: $due, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("알림 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        let item = ScheduleItem(type: type, course: course.isEmpty ? "기타" : course, title: title.isEmpty ? "새 알림" : title, due: due)
                        onAdd(item)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
private extension DateComponents { func setting(day: Int) -> DateComponents { var c = self; c.day = day; return c } }


