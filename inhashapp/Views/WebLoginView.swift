import SwiftUI
import WebKit

struct WebLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var crawler: LMSWebCrawler
    let onLoggedIn: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                        .padding(8)
                }
                Spacer()
                Text("LMS 로그인")
                    .font(.headline)
                Spacer()
                Spacer().frame(width: 36)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            WebViewContainer(webView: crawler.webView)
                .onAppear {
                    crawler.startManualLogin {
                        // 수동 로그인 성공 콜백 → 상위에서 로딩 화면으로 전환
                        onLoggedIn()
                    }
                }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}


