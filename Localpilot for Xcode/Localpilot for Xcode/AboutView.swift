//

import SwiftUI
import AppKit

struct RTFTextView: NSViewRepresentable {
    let rtfContent: NSAttributedString

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        textView.textStorage?.setAttributedString(rtfContent)
    }
}

public struct AboutView: View {
    public var body: some View {
        VStack {
            Text("Aknowledegments")
                .font(.headline)
                .padding(.vertical)
            ScrollView {
                RTFTextView(rtfContent: loadRTFText(filename: "Credits"))
            }
        }
        .padding()
    }

    private func loadRTFText(filename: String) -> NSAttributedString {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "rtf"),
              let data = try? Data(contentsOf: url),
              let attributedString = try? NSAttributedString(data: data,
                                                             options: [.documentType: NSAttributedString.DocumentType.rtf],
                                                             documentAttributes: nil) else {
            return NSAttributedString(string: "Failed to load RTF file.")
        }
        return attributedString
    }
}
