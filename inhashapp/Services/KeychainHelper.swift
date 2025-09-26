import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    
    private init() {}
    
    private let service = "com.inhash.app"
    private let lmsUsernameKey = "lms_username"
    private let lmsPasswordKey = "lms_password"
    
    struct LMSCredentials {
        let username: String
        let password: String
    }
    
    // LMS 계정 정보 저장
    func saveLMSCredentials(username: String, password: String) -> Bool {
        let usernameData = username.data(using: .utf8)!
        let passwordData = password.data(using: .utf8)!
        
        // Username 저장
        let usernameQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: lmsUsernameKey,
            kSecValueData as String: usernameData
        ]
        
        SecItemDelete(usernameQuery as CFDictionary) // 기존 항목 삭제
        let usernameStatus = SecItemAdd(usernameQuery as CFDictionary, nil)
        
        // Password 저장
        let passwordQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: lmsPasswordKey,
            kSecValueData as String: passwordData
        ]
        
        SecItemDelete(passwordQuery as CFDictionary) // 기존 항목 삭제
        let passwordStatus = SecItemAdd(passwordQuery as CFDictionary, nil)
        
        return usernameStatus == errSecSuccess && passwordStatus == errSecSuccess
    }
    
    // LMS 계정 정보 가져오기
    func getLMSCredentials() -> LMSCredentials? {
        // Username 가져오기
        let usernameQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: lmsUsernameKey,
            kSecReturnData as String: true
        ]
        
        var usernameItem: CFTypeRef?
        let usernameStatus = SecItemCopyMatching(usernameQuery as CFDictionary, &usernameItem)
        
        guard usernameStatus == errSecSuccess,
              let usernameData = usernameItem as? Data,
              let username = String(data: usernameData, encoding: .utf8) else {
            return nil
        }
        
        // Password 가져오기
        let passwordQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: lmsPasswordKey,
            kSecReturnData as String: true
        ]
        
        var passwordItem: CFTypeRef?
        let passwordStatus = SecItemCopyMatching(passwordQuery as CFDictionary, &passwordItem)
        
        guard passwordStatus == errSecSuccess,
              let passwordData = passwordItem as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            return nil
        }
        
        return LMSCredentials(username: username, password: password)
    }
    
    // LMS 계정 정보 삭제
    func deleteLMSCredentials() {
        let usernameQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: lmsUsernameKey
        ]
        SecItemDelete(usernameQuery as CFDictionary)
        
        let passwordQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: lmsPasswordKey
        ]
        SecItemDelete(passwordQuery as CFDictionary)
    }
}
