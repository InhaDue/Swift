import Foundation
import Combine

// AssignmentItem 정의
struct AssignmentItem: Identifiable, Codable, Hashable {
    let id: String
    let type: String // "assignment" or "lecture"
    let courseName: String
    let title: String
    let url: String?
    let dueAt: Date
}

class DeadlineStore: ObservableObject {
    @Published var allDeadlines: [AssignmentItem] = []
    @Published var todayDeadlines: [AssignmentItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var cancellables = Set<AnyCancellable>()

    init() {
        // 초기화 시 데이터 로드는 View에서 처리
    }
    
    private func parseItem(_ item: [String: Any], type: String) -> AssignmentItem? {
        guard let id = item["id"] as? String,
              let courseName = item["courseName"] as? String,
              let title = item["title"] as? String else { return nil }
        
        let url = item["url"] as? String
        
        // Date 파싱 - 다양한 형식 지원
        var dueAt: Date?
        if let dueAtString = item["dueAt"] as? String {
            // ISO 8601 형식 시도
            let isoFormatter = ISO8601DateFormatter()
            dueAt = isoFormatter.date(from: dueAtString)
            
            // ISO 8601 실패 시 커스텀 형식 시도
            if dueAt == nil {
                let customFormatter = DateFormatter()
                customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                customFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")
                dueAt = customFormatter.date(from: dueAtString)
            }
        } else if let dueAtTimeInterval = item["dueAt"] as? Double {
            dueAt = Date(timeIntervalSince1970: dueAtTimeInterval / 1000)
        }
        
        guard let finalDueAt = dueAt else { return nil }
        
        return AssignmentItem(
            id: id,
            type: type,
            courseName: courseName,
            title: title,
            url: url,
            dueAt: finalDueAt
        )
    }

    func fetchAllDeadlines(studentId: Int, token: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        guard let url = URL(string: "\(AppConfig.API.deadlines)/\(studentId)") else {
            await MainActor.run {
                self.errorMessage = "Invalid URL for all deadlines."
                self.isLoading = false
            }
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                await MainActor.run {
                    self.errorMessage = "Failed to fetch all deadlines: \(statusCode) - \(errorBody)"
                    self.isLoading = false
                }
                return
            }

            // JSON 파싱 - assignments와 lectures 배열 처리
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var items: [AssignmentItem] = []
                
                // assignments 처리
                if let assignmentsArray = json["assignments"] as? [[String: Any]] {
                    items.append(contentsOf: assignmentsArray.compactMap { parseItem($0, type: "assignment") })
                }
                
                // lectures 처리
                if let lecturesArray = json["lectures"] as? [[String: Any]] {
                    items.append(contentsOf: lecturesArray.compactMap { parseItem($0, type: "lecture") })
                }
                
                await MainActor.run {
                    self.allDeadlines = items.sorted { $0.dueAt < $1.dueAt }
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Failed to parse deadlines data"
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Network error fetching all deadlines: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func fetchTodayDeadlines(studentId: Int, token: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        guard let url = URL(string: "\(AppConfig.API.deadlines)/\(studentId)/today") else {
            await MainActor.run {
                self.errorMessage = "Invalid URL for today's deadlines."
                self.isLoading = false
            }
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                await MainActor.run {
                    self.errorMessage = "Failed to fetch today's deadlines: \(statusCode) - \(errorBody)"
                    self.isLoading = false
                }
                return
            }

            // JSON 파싱 - assignments와 lectures 배열 처리
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var items: [AssignmentItem] = []
                
                // assignments 처리
                if let assignmentsArray = json["assignments"] as? [[String: Any]] {
                    items.append(contentsOf: assignmentsArray.compactMap { parseItem($0, type: "assignment") })
                }
                
                // lectures 처리
                if let lecturesArray = json["lectures"] as? [[String: Any]] {
                    items.append(contentsOf: lecturesArray.compactMap { parseItem($0, type: "lecture") })
                }
                
                await MainActor.run {
                    self.todayDeadlines = items.sorted { $0.dueAt < $1.dueAt }
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Failed to parse today's deadlines data"
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Network error fetching today's deadlines: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}