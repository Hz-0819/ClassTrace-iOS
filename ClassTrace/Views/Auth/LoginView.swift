import SwiftUI
import AuthenticationServices
import CryptoKit

struct LoginView: View {
    @Environment(AppSession.self) private var session
    @Environment(AppDependencies.self) private var dependencies
    @State private var phone = ""
    @State private var code = ""
    @State private var displayName = ""
    @State private var role = "GUARDIAN"
    @State private var codeRequested = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var developmentCode: String?
    @State private var appleNonce = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CTSpacing.xl) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 54)).foregroundStyle(Color.ctBrand)
                    VStack(spacing: CTSpacing.xs) {
                        Text("课迹").font(.largeTitle.bold())
                        Text("让每节课都有迹可循").foregroundStyle(Color.ctTextSecondary)
                    }
                    Picker("使用身份", selection: $role) {
                        Text("家长").tag("GUARDIAN"); Text("教师").tag("TEACHER")
                    }.pickerStyle(.segmented)
                    VStack(spacing: CTSpacing.sm) {
                        TextField("手机号", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
                        if codeRequested {
                            TextField("6 位验证码", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode)
                            TextField("昵称（首次登录）", text: $displayName).textContentType(.name)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    if let developmentCode { Text("开发环境验证码：\(developmentCode)").font(.footnote).foregroundStyle(Color.ctWarning) }
                    if let errorMessage { Text(errorMessage).foregroundStyle(Color.ctDanger).frame(maxWidth: .infinity, alignment: .leading) }
                    Button(codeRequested ? "登录 / 注册" : "获取验证码") { Task { await submit() } }
                        .buttonStyle(CTPrimaryButtonStyle()).disabled(isWorking || phone.count < 11 || (codeRequested && code.count != 6))
                    SignInWithAppleButton(.signIn) { request in
                        let raw = UUID().uuidString
                        appleNonce = SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
                        request.nonce = appleNonce
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task { await handleApple(result) }
                    }
                    .signInWithAppleButtonStyle(.black).frame(height: 48).clipShape(RoundedRectangle(cornerRadius: CTRadius.medium))
                }
                .padding(CTSpacing.xl).frame(maxWidth: 520)
            }
            .background(Color.ctPage)
        }
    }

    @MainActor private func submit() async {
        isWorking = true; defer { isWorking = false }
        let repository = AuthRepository(client: dependencies.client, vault: dependencies.sessionVault)
        do {
            if !codeRequested {
                let result = try await repository.requestCode(phone: phone)
                developmentCode = result.developmentCode; codeRequested = true
            } else {
                let result = try await repository.verify(phone: phone, code: code, displayName: displayName.isEmpty ? nil : displayName, role: role)
                session.signIn(result)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    @MainActor private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else { throw LoginError.missingCredential }
            let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            let name = credential.fullName.map { [$0.givenName, $0.familyName].compactMap { $0 }.joined() }
            let repository = AuthRepository(client: dependencies.client, vault: dependencies.sessionVault)
            session.signIn(try await repository.signInWithApple(identityToken: token, authorizationCode: code, nonce: appleNonce, fullName: name, role: role))
        } catch { errorMessage = error.localizedDescription }
    }
}

private enum LoginError: LocalizedError { case missingCredential; var errorDescription: String? { "无法读取 Apple 登录凭据" } }
