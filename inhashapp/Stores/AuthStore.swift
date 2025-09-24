import Foundation
import Combine
import SwiftUI

final class AuthStore: ObservableObject {
    @AppStorage("authToken") private var storedToken: String?
    @AppStorage("lmsLinked") private var storedLmsLinked: Bool = false
    
    @Published var isAuthenticated: Bool = false
    @Published var isLinkingLMS: Bool = false
    @Published var errorMessage: String?
    
    var token: String? { storedToken }
    var isLmsLinked: Bool { storedLmsLinked }
    
    init() {
        isAuthenticated = storedToken?.isEmpty == false
    }
    
    func login(email: String, password: String) async {
        await MainActor.run { self.errorMessage = nil }
        // TODO: 실제 API 연동. 여기서는 성공 가정
        try? await Task.sleep(nanoseconds: 600_000_000)
        await MainActor.run {
            self.storedToken = UUID().uuidString
            self.isAuthenticated = true
        }
    }
    
    func signup(email: String, password: String) async {
        await MainActor.run { self.errorMessage = nil }
        // TODO: 실제 API 연동. 여기서는 성공 가정
        try? await Task.sleep(nanoseconds: 800_000_000)
        await MainActor.run {
            self.storedToken = UUID().uuidString
            self.isAuthenticated = true
        }
    }
    
    func logout() {
        storedToken = nil
        isAuthenticated = false
        storedLmsLinked = false
    }
    
    func linkLms(username: String, password: String, progress: @escaping (Int)->Void) async {
        await MainActor.run { self.isLinkingLMS = true; self.errorMessage = nil }
        // TODO: 서버에 LMS 계정 등록 및 초기 수집 트리거. 여기서는 진행률 시뮬레이션
        for p in stride(from: 5, through: 100, by: 7) {
            try? await Task.sleep(nanoseconds: 150_000_000)
            await MainActor.run { progress(min(p,100)) }
        }
        await MainActor.run {
            self.storedLmsLinked = true
            self.isLinkingLMS = false
        }
    }
}
