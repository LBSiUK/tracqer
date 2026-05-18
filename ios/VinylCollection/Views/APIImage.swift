import SwiftUI

/// Loads an image from our API (which uses self-signed TLS + token auth via query param).
/// Falls back to a placeholder while loading or on error.
struct APIImage: View {
    let url: URL
    let api: APIClient

    @State private var image: UIImage? = nil
    @State private var loading = true

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else if loading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray5))
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray5))
            }
        }
        .task(id: url) {
            loading = true
            image = try? await api.fetchImage(url: url)
            loading = false
        }
    }
}
