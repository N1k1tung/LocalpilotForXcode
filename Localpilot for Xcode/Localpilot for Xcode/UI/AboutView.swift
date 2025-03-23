//

import SwiftUI
import AppKit

struct RTFTextView: NSViewRepresentable {
    let content: NSAttributedString

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()

        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        textView.textStorage?.setAttributedString(content)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        if let textView = scrollView.documentView as? NSTextView {
            textView.textStorage?.setAttributedString(content)
        }
    }
}

public struct AboutView: View {
    public var body: some View {
        VStack {
            Text("Aknowledegments")
                .font(.headline)
                .padding(.vertical)
            RTFTextView(content: loadRTFText(filename: "Credits"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
    }

    private func loadRTFText(filename: String) -> NSAttributedString {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "rtf"),
              let data = try? Data(contentsOf: url),
              let attributedString = try? NSAttributedString(data: data,
                                                             options: [.documentType: NSAttributedString.DocumentType.rtf],
                                                             documentAttributes: nil) else {
            return NSAttributedString(string: "Failed to load file.")
        }
        return attributedString
    }
}

#Preview {
    AboutView()
}
