import SwiftUI

struct SummaryView: View {
    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    HeaderCard()
                    SettingsCard()
                    ProgressInfoCard()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("수업 내용 요약")
    }
}

private struct HeaderCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("수업 내용 요약")
                        .font(.headline)
                    Text("강의실 자료를 바탕으로 핵심을 자동 요약합니다")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "gearshape")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 8)
                    VStack(spacing: 14) {
                        Image(systemName: "book")
                            .font(.system(size: 32, weight: .regular))
                            .foregroundColor(.secondary)
                            .padding(14)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        Text("Coming Soon")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1)
                            )
                        Text("곧 출시됩니다!")
                            .font(.headline.weight(.semibold))
                        Text("강의실에 올라온 강의자료·공지·과제 설명을 기반으로 중요한 포인트를 간략히 정리해 드립니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("예정 기능:")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("• 강의 자료/공지 자동 요약")
                                Text("• 핵심 키워드 추출")
                                Text("• 학습 체크리스트 생성")
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
        )
    }
}

private struct SettingsCard: View {
    @State private var enabled: Bool = false
    @State private var notify: Bool = false
    @State private var depth: Int = 2 // 1:짧게 2:중간 3:길게
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.secondary)
                Text("요약 설정 (비활성)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 6)
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("자동 요약 활성화")
                            .font(.footnote.weight(.semibold))
                        Text("새로운 강의 영상을 자동으로 요약합니다")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $enabled).labelsHidden().disabled(true)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("요약 길이")
                            .font(.footnote.weight(.semibold))
                        Text("요약문의 상세 정도를 설정합니다")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(depth == 1 ? "짧게" : (depth == 2 ? "중간" : "길게"))
                        .font(.caption)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
                        .foregroundColor(.secondary)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("알림 받기")
                            .font(.footnote.weight(.semibold))
                        Text("요약 완료 시 알림을 받습니다")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $notify).labelsHidden().disabled(true)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.6))
            )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.5))
                .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
        )
    }
}

private struct ProgressInfoCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            VStack(alignment: .leading, spacing: 6) {
                Text("개발 진행 상황")
                    .font(.subheadline.weight(.semibold))
                Text("현재 AI 모델 학습 및 최적화 작업을 진행하고 있습니다. 더 나은 서비스를 위해 열심히 개발 중이니 조금만 기다려주세요!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
        )
    }
}

