import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
            AboutView()
        }
    }
}

#Preview {
    ContentView()
}
