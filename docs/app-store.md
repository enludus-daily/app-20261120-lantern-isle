# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.015 |
| アプリ名 | 灯り島：昼は島づくり、夜は生きのびる / Lantern Isle: Craft & Survive（AI が決めた。本人の許可 2026-11-04） |
| サポート URL | https://github.com/enludus-daily/app-20261120-lantern-isle/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261120-lantern-isle/blob/main/PRIVACY.md |
| 年齢区分の答え（下書き） | アニメ・ファンタジーの暴力：まれ／軽度（丸いおばけのような「もや」を光で払う。血・死体の表現なし）。ほかはすべて「なし」（ギャンブル・Web・生成 AI・ユーザー間の交流なし）。9+ 相当の見込み。入力は本人 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：ゲーム（サバイバー × 島づくり）。懐中電灯・効果音・壁紙・タイマー・占いなどではない。前日までの毎日のアプリと遊び・見た目・コードの部品が違う（Theme・部品は新しく作った）
- 既存のアプリとの意味のある違い：昼に作った物が、夜の武器・明かり・仲間になる因果（灯台＝見える範囲と回る光、柵＝もやを押し返す、住人＝夜の仲間）
- 長く使える価値（4.2）：毎日の潮（拾い物 10 か所）、住人 8 × 頼みごと 3、作り物 18 × レベル 3、夜ごとに手強くなる第 N 夜と記録
- 他社の名前・商標・見た目を使っていないか：使っていない。キャラ（ハサミ・ポポ・ゴロ・モチ・ソラ・コン・ホウ・ヤド）・絵・名前はオリジナル。絵は自作の Canvas
- Apple Intelligence：使わない
- 課金の審査：Pro（com.enludus.daily.015.pro）は初めてなので、このバージョンと一緒に審査に出す（提出は本人）

## 収益の道筋（本人が選ぶ）

- 選んだ形：買い切りの Pro ¥480（非消耗型・家族共有）。広告なし
- 理由と比べた表・勝算の表：README の「課金」

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない、解析・広告 SDK なし、保存は端末の UserDefaults だけ）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。足りない画面は本人と相談。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
