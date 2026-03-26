import SwiftUI

struct LoginView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isBiometricLoading = false
    @State private var errorMessage: String? = nil
    @State private var infoMessage: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Text("Glow")
                .font(.largeTitle)
                .fontWeight(.light)

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.username)
                    #if os(iOS)
                    .autocapitalization(.none)
                    #endif
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: appState.cardCornerRadius)
                            .fill(appState.surfaceFillStyle)
                    )

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: appState.cardCornerRadius)
                            .fill(appState.surfaceFillStyle)
                    )
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if let info = infoMessage {
                Text(info)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Button {
                Task {
                    await signIn()
                }
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            .clipShape(RoundedRectangle(cornerRadius: appState.buttonCornerRadius))

            if BiometricCredentialsStore.shared.isBiometricsAvailable {
                Button {
                    Task {
                        await signInWithBiometrics()
                    }
                } label: {
                    if isBiometricLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign In with \(BiometricCredentialsStore.shared.biometryLabel)")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading || isBiometricLoading)
                .clipShape(RoundedRectangle(cornerRadius: appState.buttonCornerRadius))
            }
        }
        .padding(32)
        .frame(maxWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: appState.cardCornerRadius)
                .fill(appState.surfaceFillStyle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: appState.cardCornerRadius)
                .stroke(appState.surfaceStrokeColor.opacity(0.35), lineWidth: 0.5)
        )
        .padding(20)
    }

    private func signIn() async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        do {
            try await supabaseManager.signIn(email: email, password: password)
            do {
                try BiometricCredentialsStore.shared.saveCredentials(email: email, password: password)
                infoMessage = "Credentials saved for \(BiometricCredentialsStore.shared.biometryLabel)."
            } catch {
                errorMessage = "Signed in, but couldn't save credentials for biometrics."
                print("Biometric save error: \(error)")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func signInWithBiometrics() async {
        isBiometricLoading = true
        errorMessage = nil
        infoMessage = nil
        do {
            let creds = try await BiometricCredentialsStore.shared.loadCredentials(
                reason: "Unlock saved credentials to sign in to Phoebe."
            )
            email = creds.email
            password = creds.password
            try await supabaseManager.signIn(email: creds.email, password: creds.password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isBiometricLoading = false
    }
}
