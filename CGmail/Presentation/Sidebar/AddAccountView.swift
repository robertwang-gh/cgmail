import SwiftUI
import AppKit

struct AddAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var container: AppDependencyContainer
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 60)).foregroundStyle(.blue)
            Text("Add Gmail Account").font(.title2.bold())
            Text("Sign in with your Google account to add it to CGmail.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            if let error = errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Button("Sign in with Google") {
                Task { await signIn() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSigningIn)
            if isSigningIn { ProgressView() }
            Button("Cancel") { dismiss() }.buttonStyle(.plain)
        }
        .padding(40)
        .frame(width: 360)
    }

    private func signIn() async {
        guard let window = NSApp.keyWindow else { return }
        isSigningIn = true
        errorMessage = nil
        do {
            let authService = await GmailAuthService.shared
            let account = try await authService.signIn(presentingWindow: window)
            let token = try await authService.refreshTokenIfNeeded(accountId: account.id)
            let client = GmailAPIClient(accessToken: token)
            container.registerAPIClient(client, for: account.id)
            let syncUseCase = container.makeSyncAccountUseCase()
            try await syncUseCase.execute(accountId: account.id)
            dismiss()
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
        }
        isSigningIn = false
    }
}
