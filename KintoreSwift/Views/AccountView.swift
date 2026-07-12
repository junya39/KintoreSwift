// AccountView.swift
// アカウントシート（ログイン・新規登録・ログアウト）。Home画面のゲーム風トンマナに合わせる。

import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    private enum Mode {
        case login
        case register
        /// パスワードリセット: メールアドレスを入力して確認コードを送る
        case resetRequest
        /// パスワードリセット: 届いたコードと新しいパスワードを入力する
        case resetConfirm
    }

    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var resetCode = ""
    @State private var infoMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if authVM.isAuthenticated {
                            loggedInContent
                        } else {
                            authFormContent
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("アカウント")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .fontDesign(.rounded)
        .onChange(of: authVM.isAuthenticated) { _, isAuthenticated in
            // ログイン・登録成功でHomeへ戻る
            if isAuthenticated {
                dismiss()
            }
        }
    }

    // MARK: - ログイン済み

    private var loggedInContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill.badge.checkmark")
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(.gameGold)
                .frame(width: 84, height: 84)
                .background(Color.gameGold.opacity(0.14))
                .clipShape(Circle())

            VStack(spacing: 4) {
                Text("ログイン中")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.white.opacity(0.6))

                Text(authVM.currentUser?.email ?? "")
                    .font(.headline.weight(.heavy))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.gameGold.opacity(0.3), lineWidth: 1)
            )

            Button {
                Task {
                    await authVM.logout()
                }
            } label: {
                HStack(spacing: 8) {
                    if authVM.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.subheadline.weight(.heavy))
                    }
                    Text("ログアウト")
                        .font(.subheadline.weight(.heavy))
                }
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(authVM.isLoading)
        }
    }

    // MARK: - ログイン / 新規登録フォーム

    private var authFormContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(.gamePurpleLight)
                .frame(width: 76, height: 76)
                .background(Color.gamePurple.opacity(0.16))
                .clipShape(Circle())

            Text(caption)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            if mode == .resetConfirm {
                authTextField("確認コード（6桁）", text: $resetCode, isSecure: false)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)

                authTextField("新しいパスワード", text: $password, isSecure: true)
                    .textContentType(.newPassword)

                authTextField("新しいパスワード（確認）", text: $passwordConfirm, isSecure: true)
                    .textContentType(.newPassword)
            } else {
                authTextField("メールアドレス", text: $email, isSecure: false)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)

                if mode != .resetRequest {
                    authTextField("パスワード", text: $password, isSecure: true)
                        .textContentType(mode == .login ? .password : .newPassword)
                }

                if mode == .register {
                    authTextField("パスワード（確認）", text: $passwordConfirm, isSecure: true)
                        .textContentType(.newPassword)
                }
            }

            if let infoMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.gameGold)

                    Text(infoMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let errorMessage = authVM.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.orange)

                    Text(errorMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                submit()
            } label: {
                HStack(spacing: 8) {
                    if authVM.isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: submitIcon)
                            .font(.headline.weight(.black))
                    }
                    Text(submitLabel)
                        .font(.headline.weight(.heavy))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: canSubmit ? [.gameGold, .gameGoldDeep] : [Color.white.opacity(0.18), Color.white.opacity(0.18)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(canSubmit == false || authVM.isLoading)

            bottomLinks
        }
    }

    /// モード別の補助リンク（モード切り替え・コード再送）
    private var bottomLinks: some View {
        VStack(spacing: 10) {
            switch mode {
            case .login:
                linkButton("パスワードを忘れた？") { switchMode(to: .resetRequest) }
                linkButton("アカウントがない？ 新規登録へ") { switchMode(to: .register) }
            case .register:
                linkButton("アカウントがある？ ログインへ戻る") { switchMode(to: .login) }
            case .resetRequest:
                linkButton("ログインへ戻る") { switchMode(to: .login) }
            case .resetConfirm:
                linkButton("コードが届かない？ 再送する") { resendCode() }
                linkButton("ログインへ戻る") { switchMode(to: .login) }
            }
        }
        .padding(.top, 2)
    }

    private func linkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.bold))
                .foregroundColor(.gamePurpleLight)
        }
        .buttonStyle(.plain)
    }

    private var caption: String {
        switch mode {
        case .login:
            return "ログインすると、今後データのバックアップや同期が使えるようになるよ"
        case .register:
            return "メールアドレスとパスワードで登録できるよ"
        case .resetRequest:
            return "登録したメールアドレスに、パスワード再設定用の6桁コードを送るよ"
        case .resetConfirm:
            return "メールに届いた6桁コードと、新しいパスワードを入力してね"
        }
    }

    private var submitLabel: String {
        switch mode {
        case .login: return "ログイン"
        case .register: return "登録する"
        case .resetRequest: return "確認コードを送る"
        case .resetConfirm: return "パスワードを再設定"
        }
    }

    private var submitIcon: String {
        switch mode {
        case .login: return "arrow.right.circle.fill"
        case .register: return "person.badge.plus"
        case .resetRequest: return "paperplane.fill"
        case .resetConfirm: return "key.fill"
        }
    }

    private var canSubmit: Bool {
        let hasEmail = email.trimmingCharacters(in: .whitespaces).isEmpty == false
        switch mode {
        case .login:
            return hasEmail && password.isEmpty == false
        case .register:
            return hasEmail && password.isEmpty == false && passwordConfirm.isEmpty == false
        case .resetRequest:
            return hasEmail
        case .resetConfirm:
            return resetCode.count == 6 && password.isEmpty == false && passwordConfirm.isEmpty == false
        }
    }

    private func switchMode(to newMode: Mode) {
        withAnimation(.easeInOut(duration: 0.2)) {
            mode = newMode
            authVM.errorMessage = nil
            infoMessage = nil
            // パスワード欄はモードをまたいで引き継がない
            password = ""
            passwordConfirm = ""
            resetCode = ""
        }
    }

    private func submit() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        infoMessage = nil
        Task {
            switch mode {
            case .login:
                _ = await authVM.login(email: trimmedEmail, password: password)
            case .register:
                _ = await authVM.register(
                    email: trimmedEmail,
                    password: password,
                    passwordConfirm: passwordConfirm
                )
            case .resetRequest:
                if await authVM.requestPasswordReset(email: trimmedEmail) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .resetConfirm
                        infoMessage = "確認コードを送ったよ。メールをチェックしてね"
                    }
                }
            case .resetConfirm:
                if await authVM.confirmPasswordReset(
                    email: trimmedEmail,
                    code: resetCode,
                    newPassword: password,
                    newPasswordConfirm: passwordConfirm
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .login
                        password = ""
                        passwordConfirm = ""
                        resetCode = ""
                        infoMessage = "パスワードを再設定したよ。新しいパスワードでログインしてね"
                    }
                }
            }
        }
    }

    /// 確認コードの再送（サーバー側で60秒のクールダウンあり）
    private func resendCode() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        infoMessage = nil
        Task {
            if await authVM.requestPasswordReset(email: trimmedEmail) {
                infoMessage = "確認コードの再送を受け付けたよ"
            }
        }
    }

    private func authTextField(_ placeholder: String, text: Binding<String>, isSecure: Bool) -> some View {
        Group {
            if isSecure {
                RevealableSecureField(placeholder: placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .textInputAutocapitalization(.never)
        .disableAutocorrection(true)
        .foregroundColor(.white)
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

/// 目のアイコンで表示・非表示を切り替えられるパスワード入力欄。
/// 切り替えても入力済みの文字は保持される（フィールドごとに独立して切り替わる）。
private struct RevealableSecureField: View {
    let placeholder: String
    @Binding var text: String

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if isRevealed {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.45))
                    // タップ領域を広げる（アイコン自体は小さいため）
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "パスワードを隠す" : "パスワードを表示")
        }
    }
}
