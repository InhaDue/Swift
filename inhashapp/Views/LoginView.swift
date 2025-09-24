import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var loading = false
    @State private var selectedAuthTab: Int = 0 // 0: 로그인, 1: 회원가입
    @State private var signupEmail = ""
    @State private var signupPassword = ""
    @State private var signupLoading = false
    @State private var showSignupPassword = false
    @State private var signupPasswordConfirm = ""
    @State private var showSignupPasswordConfirm = false
    @State private var emailCheckLoading = false
    @State private var emailCheckResult: Bool? = nil
    
    private let fieldHeight: CGFloat = 44
    private let buttonHeight: CGFloat = 48
    private var loginContentHeight: CGFloat { fieldHeight * 2 + buttonHeight * 2 + 14 * 3 + 20 + 20 }
    private var signupContentHeight: CGFloat { fieldHeight * 3 + buttonHeight * 2 + 14 * 4 + 20 + 20 }
    
    private var animatedTabBinding: Binding<Int> {
        Binding(
            get: { selectedAuthTab },
            set: { newValue in
                withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.88, blendDuration: 0.2)) {
                    selectedAuthTab = newValue
                }
                auth.errorMessage = nil
            }
        )
    }
    
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.purple.opacity(0.9), .blue.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 84, height: 84)
                            .shadow(color: .purple.opacity(0.25), radius: 18, x: 0, y: 10)
                        Text("IH")
                            .foregroundColor(.white)
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .kerning(2)
                    }
                    Text("INHASH")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                    Text("인하대 스마트 과제 관리")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 0) {
                    // Custom Segmented Control for consistent appearance
                    HStack(spacing: 0) {
                        Button(action: { animatedTabBinding.wrappedValue = 0 }) {
                            Text("로그인")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(selectedAuthTab == 0 ? .white : Color(.label))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    selectedAuthTab == 0 ?
                                    AnyView(RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray2))) :
                                    AnyView(Color.clear)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
                        .scaleEffect(selectedAuthTab == 0 ? 1.0 : 0.98)
                        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: selectedAuthTab)
                        
                        Button(action: { animatedTabBinding.wrappedValue = 1 }) {
                            Text("회원가입")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(selectedAuthTab == 1 ? .white : Color(.label))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    selectedAuthTab == 1 ?
                                    AnyView(RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray2))) :
                                    AnyView(Color.clear)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
                        .scaleEffect(selectedAuthTab == 1 ? 1.0 : 0.98)
                        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: selectedAuthTab)
                    }
                    .padding(2)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray5))
                    )
                
                    ZStack {
                        if selectedAuthTab == 0 {
                            VStack(spacing: 14) {
                                IconTextField(systemImage: "envelope", placeholder: "이메일", text: $email, isSecure: .constant(false), showSecure: .constant(false))
                                    .frame(height: 44)
                                IconTextField(systemImage: "lock", placeholder: "비밀번호", text: $password, isSecure: .constant(true), showSecure: $showPassword)
                                    .frame(height: 44)
                                Button(action: submit) { PrimaryButtonLabel(title: loading ? "로그인 중..." : "로그인", loading: loading) }
                                    .frame(height: 48)
                                    .buttonStyle(LightenOnPressStyle(cornerRadius: 12, overlayOpacity: 0.12))
                                    .disabled(loading || email.isEmpty || password.isEmpty)
                                    .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                                KakaoButton { }
                                    .frame(height: 48)
                                    .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                                HStack {
                                    Button("비밀번호 찾기") {}
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .transition(.opacity)
                        } else {
                            VStack(spacing: 14) {
                                ZStack(alignment: .trailing) {
                                    IconTextField(systemImage: "envelope", placeholder: "이메일", text: $signupEmail, isSecure: .constant(false), showSecure: .constant(false))
                                        .frame(height: 44)
                                    HStack { Spacer()
                                        Button(action: checkEmailDuplicate) {
                                            HStack(spacing: 6) { if emailCheckLoading { ProgressView().scaleEffect(0.6) }; Text("중복확인").font(.footnote) }
                                                .padding(.vertical, 6).padding(.horizontal, 10)
                                        .background(Color.black.opacity(0.06)).foregroundColor(.primary).clipShape(Capsule())
                                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                                        }.disabled(signupEmail.isEmpty || emailCheckLoading)
                                    }.padding(.trailing, 8)
                                }
                                IconTextField(systemImage: "lock", placeholder: "비밀번호", text: $signupPassword, isSecure: .constant(true), showSecure: $showSignupPassword)
                                    .frame(height: 44)
                                IconTextField(systemImage: "lock", placeholder: "비밀번호 확인", text: $signupPasswordConfirm, isSecure: .constant(true), showSecure: $showSignupPasswordConfirm)
                                    .frame(height: 44)
                                Button(action: submitSignup) { PrimaryButtonLabel(title: signupLoading ? "가입 중..." : "회원가입", loading: signupLoading) }
                                    .frame(height: 48)
                                    .buttonStyle(LightenOnPressStyle(cornerRadius: 12, overlayOpacity: 0.12))
                                    .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                                    .disabled(signupLoading || signupEmail.isEmpty || signupPassword.isEmpty || signupPasswordConfirm.isEmpty || signupPassword != signupPasswordConfirm)
                                KakaoButton { }
                                    .frame(height: 48)
                                    .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                                HStack { Button("비밀번호 찾기"){}.font(.footnote).foregroundColor(.secondary); Spacer() }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .transition(.opacity)
                        }
                    }
                    .frame(height: selectedAuthTab == 0 ? loginContentHeight : signupContentHeight)
                    .padding(.top, 14)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
                )
                .colorScheme(.light) // Force light mode for this card
                .frame(maxWidth: 360)
                .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.88, blendDuration: 0.2), value: selectedAuthTab)
                
                if let err = auth.errorMessage { Text(err).foregroundColor(.red).font(.footnote) }
            }
            .offset(y: -48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
    
    private func submit() { loading = true; Task { await auth.login(email: email, password: password); loading = false } }
    private func submitSignup() { signupLoading = true; Task { await auth.signup(email: signupEmail, password: signupPassword); signupLoading = false } }
    private func checkEmailDuplicate() { emailCheckLoading = true; emailCheckResult = nil; DispatchQueue.main.asyncAfter(deadline: .now()+0.8){ self.emailCheckLoading=false; self.emailCheckResult=Bool.random() } }
}


