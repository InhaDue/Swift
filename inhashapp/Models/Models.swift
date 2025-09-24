import Foundation

enum ScheduleType: String, CaseIterable, Identifiable {
    case assignment
    case lecture
    
    var id: String { rawValue }
    var title: String {
        switch self {
        case .assignment: return "과제"
        case .lecture: return "수업"
        }
    }
    var icon: String {
        switch self {
        case .assignment: return "doc.text"
        case .lecture: return "play.rectangle"
        }
    }
}

struct ScheduleItem: Identifiable {
    let id = UUID()
    let type: ScheduleType
    let course: String
    let title: String
    let due: Date
}


