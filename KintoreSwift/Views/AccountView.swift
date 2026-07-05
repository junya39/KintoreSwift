// AccountView.swift
// アカウントシート（ログイン・新規登録・ログアウト）。Home画面のゲーム風トンマナに合わせる。

import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    private enum Mode {
        case login
        case register
    }

    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirm = ""

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

            Text(mode == .login ? "ログインすると、今後データのバックアップや同期が使えるようになるよ" : "メールアドレスとパスワードで登録できるよ")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            authTextField("メールアドレス", text: $email, isSecure: false)
                .keyboardType(.emailAddress)
                .textContentType(.username)

            authTextField("パスワード", text: $password, isSecure: true)
                .textContentType(mode == .login ? .password : .newPassword)

            if mode == .register {
                authTextField("パスワード（確認）", text: $passwordConfirm, isSecure: true)
                    .textContentType(.newPassword)
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
                        Image(systemName: mode == .login ? "arrow.right.circle.fill" : "person.badge.plus")
                            .font(.headline.weight(.black))
                    }
                    Text(mode == .login ? "ログイン" : "登録する")
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

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    mode = mode == .login ? .register : .login
                    authVM.errorMessage = nil
                }
            } label: {
                Text(mode == .login ? "アカウントがない？ 新規登録へ" : "アカウントがある？ ログインへ戻る")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.gamePurpleLight)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    private var canSubmit: Bool {
        let hasBase = email.trimmingCharacters(in: .whitespaces).isEmpty == false && password.isEmpty == false
        if mode == .register {
            return hasBase && passwordConfirm.isEmpty == false
        }
        return hasBase
    }

    private func submit() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        Task {
            if mode == .login {
                _ = await authVM.login(email: trimmedEmail, password: password)
            } else {
                _ = await authVM.register(
                    email: trimmedEmail,
                    password: password,
                    passwordConfirm: passwordConfirm
                )
            }
        }
    }

    private func authTextField(_ placeholder: String, text: Binding<String>, isSecure: Bool) -> some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: text)
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
