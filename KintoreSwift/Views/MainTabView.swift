//
//  MainTabView.swift


import SwiftUI

/// 下部タブは廃止し、Homeを唯一のルート画面として表示する。
/// DexとLevelはHome内のショートカット（シート表示）から利用する。
struct MainTabView: View {
    var body: some View {
        HomeView()
            .background(Color.black)
    }
}
