import Foundation

// 서버에서 받아온 과제/수업 데이터 모델
struct AssignmentResponse: Codable {
    let success: Bool
    let assignments: [Assignment]?
    let lectures: [Lecture]?
    let error: String?
}

struct Assignment: Codable, Identifiable {
    let id: String
    let title: String
    let courseName: String
    let dueAt: String?
    let url: String?
    let remainingDays: Int?
    
    var dueDate: Date? {
        guard let dueAt = dueAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.date(from: dueAt)
    }
    
    var formattedDueDate: String {
        guard let date = dueDate else { return "기한 없음" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
    
    var isOverdue: Bool {
        guard let date = dueDate else { return false }
        return date < Date()
    }
}

struct Lecture: Codable, Identifiable {
    let id: String
    let title: String
    let courseName: String
    let dueAt: String?
    let url: String?
    let remainingDays: Int?
    
    var dueDate: Date? {
        guard let dueAt = dueAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.date(from: dueAt)
    }
    
    var formattedDueDate: String {
        guard let date = dueDate else { return "기한 없음" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
    
    var isOverdue: Bool {
        guard let date = dueDate else { return false }
        return date < Date()
    }
}

// 통합 아이템 (과제 + 수업)
enum DeadlineItem: Identifiable {
    case assignment(Assignment)
    case lecture(Lecture)
    
    var id: String {
        switch self {
        case .assignment(let item):
            return "a_\(item.id)"
        case .lecture(let item):
            return "l_\(item.id)"
        }
    }
    
    var title: String {
        switch self {
        case .assignment(let item):
            return item.title
        case .lecture(let item):
            return item.title
        }
    }
    
    var courseName: String {
        switch self {
        case .assignment(let item):
            return item.courseName
        case .lecture(let item):
            return item.courseName
        }
    }
    
    var dueDate: Date? {
        switch self {
        case .assignment(let item):
            return item.dueDate
        case .lecture(let item):
            return item.dueDate
        }
    }
    
    var formattedDueDate: String {
        switch self {
        case .assignment(let item):
            return item.formattedDueDate
        case .lecture(let item):
            return item.formattedDueDate
        }
    }
    
    var isAssignment: Bool {
        switch self {
        case .assignment:
            return true
        case .lecture:
            return false
        }
    }
    
    var url: String? {
        switch self {
        case .assignment(let item):
            return item.url
        case .lecture(let item):
            return item.url
        }
    }
    
    var isOverdue: Bool {
        switch self {
        case .assignment(let item):
            return item.isOverdue
        case .lecture(let item):
            return item.isOverdue
        }
    }
}

