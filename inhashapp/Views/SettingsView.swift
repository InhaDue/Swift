import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthStore
    @AppStorage("notifyAssignments") private var notifyAssignments: Bool = true
    @AppStorage("notifyLectures") private var notifyLectures: Bool = true
    @AppStorage("notifyAll") private var notifyAll: Bool = true
    @AppStorage("ddayOption") private var ddayOption: Int = 1
    let ddayOptions: [Int] = [3, 2, 1]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("알림 설정")) {
                    Toggle("과제 알림", isOn: $notifyAssignments)
                    Toggle("수업 알림", isOn: $notifyLectures)
                    Toggle("전체 알림", isOn: $notifyAll)
                        .onChange(of: notifyAll) { newValue in
                            if newValue == false { notifyAssignments = false; notifyLectures = false }
                        }
                    Picker("사전 알림(D-일)", selection: $ddayOption) { ForEach(ddayOptions, id: \.self) { d in Text("D-\(d)").tag(d) } }
                    Text("사전 알림은 매일 09:00시에 울립니다. 예: 과제 마감이 9월 25일인 경우, D-2로 설정하면 9월 23일 09:00에 알림이 울립니다.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Section(header: Text("계정")) {
                    Button(role: .none) { } label: { Label("LMS 계정 재연결", systemImage: "arrow.triangle.2.circlepath") }
                    Button(role: .destructive) { auth.logout() } label: { Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.forward") }
                    Button(role: .destructive) { } label: { Label("계정 탈퇴", systemImage: "trash") }
                }
            }.navigationTitle("설정")
        }
    }
}


