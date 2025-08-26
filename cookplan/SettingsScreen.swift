//
//  SettingsScreen.swift
//  CookPlanRoar
//
//  Theme & language pickers, privacy policy WebView (with fallback), and About section.
//

import SwiftUI
import WebKit

struct SettingsScreen: View {
    @EnvironmentObject private var appState: AppState
    @State private var showPrivacy = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Theme
                Section(header: Text(LocalizedStringKey("theme"))) {
                    Picker(LocalizedStringKey("theme"), selection: $appState.store.settings.theme) {
                        Text(LocalizedStringKey("theme_system")).tag(ThemeMode.system)
                        Text(LocalizedStringKey("theme_light")).tag(ThemeMode.light)
                        Text(LocalizedStringKey("theme_dark")).tag(ThemeMode.dark)
                    }
                    .pickerStyle(.segmented)
                }
                
                // Language
                Section(header: Text(LocalizedStringKey("language"))) {
                    Picker(LocalizedStringKey("language"), selection: $appState.store.settings.language) {
                        Text(LocalizedStringKey("lang_en_name")).tag(Language.en)
                        Text(LocalizedStringKey("lang_es_name")).tag(Language.es)
                        Text(LocalizedStringKey("lang_fr_name")).tag(Language.fr)
                    }
                }
                
                // Privacy Policy
                Section(header: Text(LocalizedStringKey("privacy"))) {
                    Button {
                        showPrivacy = true
                    } label: {
                        HStack {
                            Text(LocalizedStringKey("privacy"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // About
                Section(header: Text(LocalizedStringKey("about"))) {
                    HStack {
                        Text(Bundle.main.displayName)
                        Spacer()
                        Text("v\(Bundle.main.shortVersion) (\(Bundle.main.buildVersion))")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(Text(LocalizedStringKey("tab_settings")))
            .onChange(of: appState.store.settings.language) { _ in
                // Force-publish so the app root rebuilds with the new locale
                appState.store = appState.store
            }
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyWebView(urlString: "https://www.termsfeed.com/live/437132bd-6788-4a24-8126-a4ebbd87296f")
                .ignoresSafeArea()
        }
    }
}

// MARK: - WebView Wrapper with Fallback
private struct PrivacyWebView: UIViewRepresentable {
    let urlString: String?
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        load(into: webView)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // no-op; keep current page
    }
    
    private func load(into webView: WKWebView) {
        if let s = urlString, let url = URL(string: s) {
            webView.load(URLRequest(url: url))
        } else {
            webView.loadHTMLString(Self.fallbackHTML, baseURL: nil)
        }
    }
    
    private static let fallbackHTML: String = {
        return """
        <!doctype html>
        <html lang=\"en\">
        <head>
        <meta charset=\"utf-8\" />
        <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
        <title>Privacy Policy</title>
        <style>
        body { font-family: -apple-system, Helvetica, Arial, sans-serif; padding: 20px; line-height: 1.5; }
        h1 { font-size: 22px; }
        h2 { font-size: 18px; margin-top: 1.25em; }
        p, li { font-size: 15px; }
        </style>
        </head>
        <body>
        <h1>Privacy Policy</h1>
        <p>Cook Plan Roar does not collect personal data. All content is stored locally on your device and remains under your control.</p>
        <h2>Data Storage</h2>
        <p>Your recipes, trips, groceries and preferences are stored locally to provide the app's core functionality.</p>
        <h2>Connectivity</h2>
        <p>The app works offline. If you open an external Privacy Policy link, your browser will connect to that site.</p>
        <h2>Contact</h2>
        <p>For questions, contact the developer via the store page.</p>
        </body>
        </html>
        """
    }()
}

// MARK: - Bundle helpers
private extension Bundle {
    var displayName: String { object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
        object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Cook Plan Roar" }
    var shortVersion: String { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }
    var buildVersion: String { object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "1" }
}
