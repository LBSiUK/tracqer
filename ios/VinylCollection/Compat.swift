// Compatibility shims so the SwiftUI codebase compiles for iOS 15+ while
// still using iOS 16/17/18/26 APIs where they are available.

import SwiftUI

// MARK: - Bundle build-date helper

extension Bundle {
    /// Build timestamp formatted as "HH:mm, d MMM yyyy 'UTC'", derived from
    /// the executable's modification date. The mtime is set at link time, so
    /// this reflects when the binary was built, in UTC.
    var buildDateString: String {
        guard let url = executableURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date  = attrs[.modificationDate] as? Date
        else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.dateFormat = "HH:mm, d MMM yyyy 'UTC'"
        return fmt.string(from: date)
    }

    /// Marketing version like "1.1" pulled from CFBundleShortVersionString.
    var shortVersionString: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }
}

// MARK: - NavigationStack (iOS 16+) / NavigationView fallback (iOS 15)

/// Wraps `NavigationStack` on iOS 16+ and falls back to `NavigationView` with
/// `.stack` style on iOS 15 so the code uses the same call site everywhere.
struct CompatNavigation<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack { content() }
        } else {
            NavigationView { content() }
                .navigationViewStyle(.stack)
        }
    }
}

// MARK: - ContentUnavailableView (iOS 17+) fallback

/// Mirrors `ContentUnavailableView(title, systemImage:, description:)` on iOS 17+,
/// renders a centered VStack with icon + title + description on iOS 15-16.
struct CompatContentUnavailable: View {
    let title: String
    let systemImage: String
    let description: Text?

    init(_ title: String, systemImage: String, description: Text? = nil) {
        self.title       = title
        self.systemImage = systemImage
        self.description = description
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            if let description {
                ContentUnavailableView(title, systemImage: systemImage, description: description)
            } else {
                ContentUnavailableView(title, systemImage: systemImage)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.title2.weight(.semibold))
                if let description {
                    description
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
}

// MARK: - View extension: fontWeight() backport

extension View {
    /// Calls `.fontWeight(_:)` on iOS 16+, no-op on iOS 15 (weight is ignored).
    @ViewBuilder
    func compatFontWeight(_ weight: Font.Weight) -> some View {
        if #available(iOS 16.0, *) {
            self.fontWeight(weight)
        } else {
            self
        }
    }
}

// MARK: - "No matching search results" variant of CompatContentUnavailable

/// Equivalent of `ContentUnavailableView.search(text:)` for iOS 15-16.
struct CompatSearchUnavailable: View {
    let searchText: String

    var body: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView.search(text: searchText)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No Results")
                    .font(.title2.weight(.semibold))
                Text("No results found for \"\(searchText)\".")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
}
