## 現在地（完了済み）
- View から DatabaseManager 直呼びを ViewModel 経由に移行
- history を ContentViewModel に集約

## 状態管理の方針
- UI は View に限定し、データ取得・保存・削除は ViewModel に集約
- history の単一所有者を ContentViewModel とし、他の ViewModel は参照側に徹する

## 未完・注意点
- KintoreSwift.xcodeproj/project.pbxproj に差分がある
- Xcode 側のビルド確認は未実施

## 次にやるべき作業（優先順）
1. Xcode でビルド確認（シミュレータ）
2. project.pbxproj の差分を今回の変更に含めるか判断
3. 必要なら差分整理（コミット単位の調整）

## 設計上の判断メモ（なぜそうしたか）
- history を ContentViewModel に集約した理由
  - 履歴の持ち主を一つにすることで、状態管理の重複を避けるため
  - ViewModel 間の責務を明確にし、データ取得の入口を集約するため
