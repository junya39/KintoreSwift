# 🏋️‍♂️ KintoreSwift

**KintoreSwift** は、筋トレの記録と成長を可視化するためのiOSアプリです。  
シンプルなUIでトレーニング内容を記録し、グラフやカレンダーで進捗を確認できます。  

---

## 📱 スクリーンショット
| ホーム画面 | カレンダー | グラフ |
|-------------|-------------|--------|
| ![Workout](screenshots/workout.png) | ![Calendar](screenshots/calendar.png) | ![Chart](screenshots/chart.png) |

（※ スクショは `KintoreSwift/screenshots/` に保存してください）

---

## ✨ 主な機能

- 📆 **カレンダー表示**：トレーニングした日は青くハイライト  
- 🏋️‍♀️ **種目・部位別の記録**：ベンチプレスやスクワットなど自由に追加可能  
- 📊 **折れ線グラフ**：日・週・月ごとの進捗を可視化  
- ⏱ **前回比の自動表示**：重量・回数の増減を色で表示  
- 📖 **履歴画面**：種目ごとの過去データを一目で確認  
- 🗑 **削除機能**：不要なセットをスワイプで削除  

---

## 🧩 使用技術

| 分類 | 技術 |
|------|------|
| フレームワーク | SwiftUI |
| データベース | SQLite.swift |
| グラフ表示 | Swift Charts |
| カレンダー | FSCalendar |
| 言語 | Swift 5 |
| 開発環境 | Xcode 16 / iOS 18 |

---

## 🗂 ディレクトリ構成
KintoreSwift/
├── Assets.xcassets/ # アプリアイコン・画像管理
├── CalendarView.swift # カレンダー表示
├── ChartView.swift # グラフ表示
├── ContentView.swift # メイン画面
├── DatabaseManager.swift # SQLite管理
├── HistoryView.swift # 履歴画面
├── LaunchScreen.storyboard # 起動画面
└── screenshots/ # スクリーンショット画像


---

## 🚀 今後のアップデート予定

- 🔔 通知機能：トレーニングリマインダー
- 💾 iCloudバックアップ対応
- 🧍 キャラクター育成要素（成長に応じて変化）
- 🌐 多言語対応（日本語 / 英語）


---

## 🧠 コンセプト

> 筋トレの成長を「データ」と「キャラクター」で楽しむ。

ただの記録ではなく、**自分の成長を見てモチベーションを上げる**アプリです。

---



