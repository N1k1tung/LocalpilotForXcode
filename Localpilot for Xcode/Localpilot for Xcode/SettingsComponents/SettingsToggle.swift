import SwiftUI

struct SettingsToggle: View {
    let title: String
    let isOn: Binding<Bool>

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
            Spacer()
            Toggle(isOn: isOn) {}
                .toggleStyle(.switch)
        }
        .padding(10)
    }
}

#Preview {
    SettingsToggle(title: "Test", isOn: .constant(true))
}
