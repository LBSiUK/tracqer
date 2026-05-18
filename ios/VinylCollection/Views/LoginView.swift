import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState

    @State private var serverURL = ""
    @State private var password  = ""
    @State private var isLoading = false
    @State private var errorMsg: String? = nil

    var body: some View {
        CompatNavigation {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 72))
                        .foregroundColor(.orange)
                    Text("Tracqer")
                        .font(.largeTitle.bold())
                    Text("Enter your server details to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 40)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Server URL").font(.caption).foregroundColor(.secondary)
                        TextField("https://...", text: $serverURL)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password").font(.caption).foregroundColor(.secondary)
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }

                    if let err = errorMsg {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: login) {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Connect").fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(isLoading || serverURL.isEmpty || password.isEmpty)
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private func login() {
        errorMsg  = nil
        isLoading = true
        Task {
            do {
                try await appState.login(serverURL: serverURL, password: password)
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}
