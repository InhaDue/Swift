import Foundation
import Combine

class DeadlineStore: ObservableObject {
    static let shared = DeadlineStore()
    
    @Published var assignments: [Assignment] = []
    @Published var lectures: [Lecture] = []
    @Published var allItems: [DeadlineItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 초기화 시 데이터 로드
        Task {
            await fetchDeadlines()
        }
    }
    
    /// 서버에서 과제/수업 데이터 가져오기
    @MainActor
    func fetchDeadlines() async {
        isLoading = true
        errorMessage = nil
        
        guard let studentId = UserDefaults.standard.object(forKey: "studentId") as? Int else {
            errorMessage = "학생 ID를 찾을 수 없습니다"
            isLoading = false
            return
        }
        
        // API 엔드포인트 (백엔드에 추가 필요)
        guard let url = URL(string: "\(AppConfig.API.deadlines)/\(studentId)") else {
            errorMessage = "잘못된 URL"
            isLoading = false
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                // 데이터가 없는 경우 빈 배열 유지
                isLoading = false
                return
            }
            
            let decoder = JSONDecoder()
            let deadlineResponse = try decoder.decode(AssignmentResponse.self, from: data)
            
            if deadlineResponse.success {
                self.assignments = deadlineResponse.assignments ?? []
                self.lectures = deadlineResponse.lectures ?? []
                updateAllItems()
            } else {
                errorMessage = deadlineResponse.error ?? "데이터 로드 실패"
            }
            
        } catch {
            print("Fetch deadlines error: \(error)")
            // 에러가 나도 빈 배열 유지 (앱이 크래시하지 않도록)
            errorMessage = nil
        }
        
        isLoading = false
    }
    
    /// 모든 아이템 업데이트 (과제 + 수업)
    private func updateAllItems() {
        var items: [DeadlineItem] = []
        
        // 과제 추가
        items.append(contentsOf: assignments.map { .assignment($0) })
        
        // 수업 추가
        items.append(contentsOf: lectures.map { .lecture($0) })
        
        // 날짜순 정렬 (가장 가까운 마감일이 먼저)
        items.sort { item1, item2 in
            guard let date1 = item1.dueDate else { return false }
            guard let date2 = item2.dueDate else { return true }
            return date1 < date2
        }
        
        allItems = items
    }
    
    /// 오늘 마감인 아이템들
    var todayDeadlines: [DeadlineItem] {
        let calendar = Calendar.current
        let today = Date()
        
        return allItems.filter { item in
            guard let dueDate = item.dueDate else { return false }
            return calendar.isDateInToday(dueDate)
        }
    }
    
    /// 이번 주 마감인 아이템들
    var thisWeekDeadlines: [DeadlineItem] {
        let calendar = Calendar.current
        let today = Date()
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: today) else { return [] }
        
        return allItems.filter { item in
            guard let dueDate = item.dueDate else { return false }
            return dueDate >= today && dueDate <= weekEnd && !item.isOverdue
        }
    }
    
    /// 다가오는 마감 (7일 이내)
    var upcomingDeadlines: [DeadlineItem] {
        let calendar = Calendar.current
        let today = Date()
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: today) else { return [] }
        
        return allItems.filter { item in
            guard let dueDate = item.dueDate else { return false }
            return dueDate >= today && dueDate <= weekEnd
        }.prefix(5).map { $0 } // 최대 5개만
    }
    
    /// 특정 날짜의 아이템들
    func deadlines(for date: Date) -> [DeadlineItem] {
        let calendar = Calendar.current
        
        return allItems.filter { item in
            guard let dueDate = item.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }
    }
    
    /// 과제만 필터링
    var assignmentsOnly: [Assignment] {
        return assignments.filter { !$0.isOverdue }
            .sorted { item1, item2 in
                guard let date1 = item1.dueDate else { return false }
                guard let date2 = item2.dueDate else { return true }
                return date1 < date2
            }
    }
    
    /// 수업만 필터링
    var lecturesOnly: [Lecture] {
        return lectures.filter { !$0.isOverdue }
            .sorted { item1, item2 in
                guard let date1 = item1.dueDate else { return false }
                guard let date2 = item2.dueDate else { return true }
                return date1 < date2
            }
    }
}
