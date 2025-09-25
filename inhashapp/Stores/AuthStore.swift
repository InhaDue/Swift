import Foundation
import Combine
import SwiftUI

final class AuthStore: ObservableObject {
    @AppStorage("authToken") private var storedToken: String?
    @AppStorage("studentId") private var storedStudentId: Int?
    @AppStorage("userEmail") private var storedEmail: String?
    @AppStorage("userName") private var storedName: String?
    @AppStorage("lmsLinked") private var storedLmsLinked: Bool = false
    
    @Published var isAuthenticated: Bool = false
    @Published var isLinkingLMS: Bool = false
    @Published var errorMessage: String?
    
    var token: String? { storedToken }
    var studentId: Int? { storedStudentId }
    var email: String? { storedEmail }
    var name: String? { storedName }
    var isLmsLinked: Bool { storedLmsLinked }
    
    init() {
        isAuthenticated = storedToken?.isEmpty == false
    }
    
    func login(email: String, password: String) async {
        await MainActor.run { self.errorMessage = nil }
        
        guard let url = URL(string: AppConfig.API.login) else {
            await MainActor.run { self.errorMessage = "잘못된 URL" }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool {
                
                if success {
                    await MainActor.run {
                        self.storedToken = json["token"] as? String
                        self.storedStudentId = json["studentId"] as? Int
                        self.storedEmail = json["email"] as? String
                        self.storedName = json["name"] as? String
                        self.storedLmsLinked = json["lmsLinked"] as? Bool ?? false
                        self.isAuthenticated = true
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = json["error"] as? String ?? "로그인 실패"
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "네트워크 오류: \(error.localizedDescription)"
            }
        }
    }
    
    func signup(email: String, password: String, name: String) async {
        await MainActor.run { self.errorMessage = nil }
        
        guard let url = URL(string: AppConfig.API.signup) else {
            await MainActor.run { self.errorMessage = "잘못된 URL" }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password, "name": name]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool {
                
                if success {
                    await MainActor.run {
                        self.storedToken = json["token"] as? String
                        self.storedStudentId = json["studentId"] as? Int
                        self.storedEmail = json["email"] as? String
                        self.storedName = json["name"] as? String
                        self.storedLmsLinked = false // 회원가입 시 LMS 연결 필요
                        self.isAuthenticated = true
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = json["error"] as? String ?? "회원가입 실패"
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "네트워크 오류: \(error.localizedDescription)"
            }
        }
    }
    
    func logout() {
        storedToken = nil
        storedStudentId = nil
        storedEmail = nil
        storedName = nil
        storedLmsLinked = false
        isAuthenticated = false
    }
    
    func linkLms(username: String, password: String, progress: @escaping (Int)->Void) async {
        await MainActor.run { 
            self.isLinkingLMS = true
            self.errorMessage = nil
        }
        
        // LMS 연결 완료 후
        await MainActor.run {
            self.storedLmsLinked = true
            self.isLinkingLMS = false
        }
    }
    
    // LMS 연결 상태 업데이트
    func setLmsLinked(_ linked: Bool) {
        storedLmsLinked = linked
    }
}