import SwiftUI
import AppKit

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var container: AppDependencyContainer
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @State private var statusMessage: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 60)).foregroundStyle(.blue)
            Text("Add Gmail Account").font(.title2.bold())
            Text("Sign in with your Canva Google Workspace account.\nRequires WARP/VPN connection.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let error = errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(isSigningIn ? "Signing in..." : "Sign in with Google") {
                Task { await signIn() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSigningIn)

            if isSigningIn { ProgressView() }

            Button("Cancel") { dismiss() }.buttonStyle(.plain)
        }
        .padding(40)
        .frame(width: 380)
    }

    private func signIn() async {
        isSigningIn = true
        errorMessage = nil
        statusMessage = "Opening browser for Google sign-in..."

        do {
            let authService = await GmailAuthService.shared
            let account = try await authService.signIn()
            statusMessage = "Getting access token..."
            let token = try await authService.getOtterToken()
            let client = GmailAPIClient(accessToken: token)
            container.registerAPIClient(client, for: account.id)
            statusMessage = "Syncing mailbox..."
            let syncUseCase = container.makeSyncAccountUseCase()
            try await syncUseCase.execute(accountId: account.id)
            dismiss()
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)\n\nMake sure WARP/VPN is connected and try again."
        }
        isSigningIn = false
        statusMessage = ""
    }
}
