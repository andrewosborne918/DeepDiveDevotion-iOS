import SwiftUI

struct TranscriptView: View {
    let text: String
    @State private var searchQuery: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.dddGold)
                TextField("Search transcript...", text: $searchQuery)
                    .font(.subheadline)
                    .foregroundStyle(Color.dddIvory)
                if !searchQuery.isEmpty {
                    Button { searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.dddGold.opacity(0.8))
                    }
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.24))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.dddGold.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Share button
            HStack {
                Spacer()
                Button {
                    UIPasteboard.general.string = text
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.dddGoldLight)
                }
                Button {
                    let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let vc = scene.windows.first?.rootViewController {
                        vc.present(av, animated: true)
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(.dddGoldLight)
                }
            }

            Divider()

            // Transcript text
            if searchQuery.isEmpty {
                Text(text)
                    .font(.body)
                    .foregroundColor(.dddIvory)
                    .lineSpacing(8)
                    .textSelection(.enabled)
            } else {
                filteredTranscript
            }
        }
    }

    private var filteredTranscript: some View {
        let paragraphs = text.components(separatedBy: "\n\n")
        let matching = paragraphs.filter { $0.localizedCaseInsensitiveContains(searchQuery) }

        return Group {
            if matching.isEmpty {
                Text("No results for \"\(searchQuery)\"")
                    .font(.body)
                    .foregroundColor(.dddGoldLight.opacity(0.8))
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("\(matching.count) matches")
                        .font(.caption)
                        .foregroundColor(.dddGoldLight.opacity(0.8))

                    ForEach(Array(matching.enumerated()), id: \.offset) { _, paragraph in
                        Text(highlightedText(paragraph, query: searchQuery))
                            .font(.body)
                            .lineSpacing(6)
                            .textSelection(.enabled)
                            .padding(12)
                            .background(Color.dddGold.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func highlightedText(_ text: String, query: String) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = .init(.dddIvory)

        var searchRange = attributed.startIndex..<attributed.endIndex
        let queryLower = query.lowercased()

        while let range = attributed[searchRange].range(of: queryLower, options: .caseInsensitive) {
            attributed[range].backgroundColor = .init(.dddGold.opacity(0.4))
            attributed[range].foregroundColor = .init(.dddSurfaceBlack)
            searchRange = range.upperBound..<attributed.endIndex
        }
        return attributed
    }
}
