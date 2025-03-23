import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("General")
                }
            AboutView()
                .tabItem {
                    Image(systemName: "info.circle")
                    Text("About")
                }
        }
    }
}

#Preview {
    ContentView()
}
