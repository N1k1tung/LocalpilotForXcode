import SwiftUI

struct SettingsTextField: View {
    let title: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        Form {
            TextField(text: $text, prompt: Text(prompt)) {
                Text(title)
            }
            .textFieldStyle(PlainTextFieldStyle())
            .multilineTextAlignment(.trailing)
        }
        .padding(10)
    }
}

struct SettingsSecureField: View {
    let title: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        Form {
            SecureField(text: $text, prompt: Text(prompt)) {
                Text(title)
            }
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
        }
        .padding(10)
    }
}

#Preview {
    VStack(spacing: 10) {
        SettingsTextField(
            title: "Username",
            prompt: "user",
            text: .constant("")
        )
        Divider()
        SettingsSecureField(
            title: "Password",
            prompt: "pass",
            text: .constant("")
        )
    }
    .padding(.vertical, 10)
}
