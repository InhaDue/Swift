import SwiftUI

struct LmsLinkView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var username = ""
    @State private var password = ""
    @State private var progress = 0
    @State private var loading = false
    @State private var testLoading = false
    @State private var testConnected = false
    @State private var showLoadingScreen = false
    
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                // 카드
                VStack(alignment: .leading, spacing: 16) {
                    // 헤더
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.white.opacity(0.7))
                            .overlay(Image(systemName: "chevron.left").foregroundColor(.secondary))
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LMS 연결").font(.title3).fontWeight(.semibold)
                            Text("인하대 LMS 계정을 연결해주세요").font(.footnote).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 4)
                    
                    // 안내 박스
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle().fill(Color.black.opacity(0.06)).frame(width: 28, height: 28)
                            Image(systemName: "shield.fill").foregroundColor(.secondary).font(.footnote)
                        }
                        Text("계정 정보는 안전하게 암호화되어 저장되며, 과제 정보 수집 목적으로만 사용됩니다.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // 입력 필드
                    IconTextField(systemImage: "person", placeholder: "LMS 아이디", text: $username, isSecure: .constant(false), showSecure: .constant(false))
                        .frame(height: 44)
                    IconTextField(systemImage: "lock", placeholder: "LMS 비밀번호", text: $password, isSecure: .constant(true), showSecure: .constant(false))
                        .frame(height: 44)
                    
                    // 버튼 / 진행
                    // 로컬 로딩바 제거 (로딩 화면으로 이동)
                    
                    // 테스트 연결하기 버튼 (동일 스타일)
                    Button(action: testSubmit) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                )
                            HStack(spacing: 8) {
                                if testLoading { ProgressView().tint(.primary).scaleEffect(0.9) }
                                Text(testLoading ? "테스트 중..." : (testConnected ? "테스트 연결 성공" : "테스트 연결하기"))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 8)
                        }
                        .frame(height: 48)
                        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                    }
                    .buttonStyle(LightenOnPressStyle(cornerRadius: 12, overlayOpacity: 0.12))
                    .disabled(testLoading || username.isEmpty || password.isEmpty)

                    Button(action: submit) {
                        PrimaryButtonLabel(title: "LMS 연결하기", loading: false)
                            .frame(height: 48)
                    }
                    .buttonStyle(LightenOnPressStyle(cornerRadius: 12, overlayOpacity: 0.12))
                    .disabled(isLmsDisabled)
                    .opacity(isLmsDisabled ? 0.55 : 1.0)
                    .saturation(isLmsDisabled ? 0.7 : 1.0)
                    .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                    
                    HStack(spacing: 6) {
                        Text("연결에 문제가 있나요?")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Button("도움말 보기") {}
                            .font(.footnote)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 10)
                )
                .frame(maxWidth: 360)
                
                if let err = auth.errorMessage { Text(err).foregroundColor(.red).font(.footnote) }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 0)
            .onChange(of: username) { testConnected = false }
            .onChange(of: password) { testConnected = false }
        }
        .fullScreenCover(isPresented: $showLoadingScreen) {
            DataLoadingView(username: username, password: password)
                .environmentObject(auth)
        }
        // 로딩 화면을 fullScreenCover로 표시
    }
    private var isLmsDisabled: Bool { username.isEmpty || password.isEmpty || !testConnected }
    private func submit() { showLoadingScreen = true }
    private func testSubmit() {
        testLoading = true
        auth.errorMessage = nil
        // 네트워크 체크를 가정한 짧은 지연
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            testLoading = false
            testConnected = true
        }
    }
}


