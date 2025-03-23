import SwiftUI

struct SettingsSection<Content: View, Footer: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer

    
    init(title: String, @ViewBuilder content: @escaping () -> Content, @ViewBuilder footer: @escaping () -> Footer) {
        self.title = title
        self.content = content
        self.footer = footer
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .bold()
                .padding(.horizontal, 10)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            footer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension SettingsSection where Footer == EmptyView {
    init(title: String, showWarning: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, content: content, footer: { EmptyView() })
    }
}

#Preview {
    VStack(spacing: 20) {
        SettingsSection(title: "General") {
            SettingsLink(
                url: "https://github.com", title: "GitHub", subtitle: "footnote")
            Divider()
            SettingsToggle(title: "Example", isOn: .constant(true))
            Divider()
            SettingsLink(url: "https://example.com", title: "Example")
        }
        SettingsSection(title: "Advanced") {
            SettingsLink(url: "https://example.com", title: "Example")
        } footer: {
            Text("Footer")
        }
    }
    .padding()
    .frame(width: 300)
}
