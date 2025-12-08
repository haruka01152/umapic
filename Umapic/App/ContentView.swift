import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showCreateSheet = false
    @State private var previousTab: Tab = .home

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            Color.clear
                .tabItem {
                    Label(Tab.create.rawValue, systemImage: Tab.create.icon)
                }
                .tag(Tab.create)

            MapTabView()
                .tabItem {
                    Label(Tab.map.rawValue, systemImage: Tab.map.icon)
                }
                .tag(Tab.map)
        }
        .tint(Color.pompomBrown)
        .onChange(of: appState.selectedTab) { oldValue, newValue in
            if newValue == .create {
                previousTab = oldValue
                showCreateSheet = true
                // 前のタブに戻す
                DispatchQueue.main.async {
                    appState.selectedTab = previousTab
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            RecordCreateView { _ in
                // 保存後はホームタブに遷移
                appState.selectedTab = .home
            }
        }
        .overlay(alignment: .top) {
            if appState.showToast, let message = appState.toastMessage {
                ToastView(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 50)
            }
        }
    }
}

// MARK: - Toast View
struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.pompomBrown)

            Text(message)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.pompomText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.pompomYellow)
        .clipShape(Capsule())
        .shadow(color: Color.pompomBrown.opacity(0.2), radius: 8, y: 4)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
