# StretchBreak

每小時提醒你起身，播一支不重複的 3–5 分鐘 YouTube 伸展影片（或內建計時伸展組），
做完一鍵評分，前後記錄坐骨神經 / 下背不適度並畫成趨勢圖。

- iOS 17+ / Xcode 15+
- SwiftUI + SwiftData，無後端、無第三方套件
- 提醒為本機通知，不需要網路、不上傳任何資料

---

## 建置方式

### 方法 A — XcodeGen（推薦）

```bash
brew install xcodegen
cd ~/Documents/StretchBreak
xcodegen generate
open StretchBreak.xcodeproj
```

在 Xcode 裡：
1. 選 target `StretchBreak` → Signing & Capabilities → 選你的 Team（個人 Apple ID 也可）。
2. 接上 iPhone，選為執行裝置，按 ▶︎。
3. 首次在手機上開啟：設定 → 一般 → VPN 與裝置管理 → 信任你的開發者憑證。
4. App 內完成引導頁、允許通知。

> 免費 Apple ID 的側載憑證 7 天到期，需重新用 Xcode 執行一次；同時最多 3 個側載 App。
> 想長期用可上傳到 TestFlight（需付費開發者帳號）。

### 方法 B — 手動建立專案（不裝 XcodeGen）

1. Xcode → File → New → Project → iOS → App。
   - Product Name: `StretchBreak`
   - Interface: SwiftUI，Language: Swift，Storage: None
   - 最低版本設 iOS 17.0
2. 刪掉範本產生的 `ContentView.swift` 和 `StretchBreakApp.swift`。
3. 把本資料夾 `Sources/` 裡的檔案全部拖進專案（勾 Copy items if needed、加入 target）：
   `App.swift` `Models.swift` `Services.swift` `Views.swift` `YouTubePlayerView.swift` `routine.json`
4. Target → Info → 新增一個 String 鍵 `YTAPIKey`（值留空或填金鑰，見下）。
5. 接手機執行。

---

## YouTube 影片來源

三種模式，App 會自動判斷：

| 設定 | 行為 |
|---|---|
| **填了 `YTAPIKey`** | 依身體部位（梨狀肌 / 髖屈肌 / 大腿後側 / 胸椎…）輪流呼叫 YouTube 搜尋，抓可嵌入的 4–20 分鐘影片，最近播過的自動排除 → 幾乎不重複、內容無限 |
| **在 App「設定」貼 YouTube 連結** | 自建影片清單，與上面來源合併 |
| **兩者都沒有** | 使用內建計時伸展組（`routine.json`，8 組 ~4.5 分鐘，離線可用）|

**取得金鑰**：Google Cloud Console → 建專案 → 啟用 *YouTube Data API v3* → 建立 API 金鑰。
填入位置：`project.yml` 裡 `YTAPIKey: "你的金鑰"`，重跑 `xcodegen generate`；
或方法 B 直接在 Target Info 的 `YTAPIKey` 欄位。免費額度每天 10,000 units，本 App 一天用不到 1%。

**預抓（兩層）**：
- `VideoStore`：App 啟動 / 回前景時背景搜尋 + 驗證影片清單，存記憶體與磁碟
  （`video_cache.json`，TTL 6 小時）。
- `PlayerWarmer`：拿一個隱藏的 WKWebView，在 App 開啟 / 每次 session 結束 / 清單更新後，
  預先把「下一支可能的影片」的 YouTube player（iframe API + player 物件）建好。點
  「Stretch now」時若命中，session 直接接手這個 webview → 幾乎瞬間開始，不用再等
  ~2–3 秒的 player 初始化。reroll 或沒命中就正常重新載入。

**iOS 模擬器只有聲音、畫面不動**：這是模擬器的 WKWebView 媒體解碼限制（log 會看到
`WebKit Media Playback` assertion 失敗），不是 App 的問題。**實機 iPhone 正常**。

**穩定性**：
- 播放器直接載入 `youtube.com/embed/<id>` 真實網址（不是 `loadHTMLString`＋baseURL —
  那樣 WKWebView 拿不到正確 origin，iframe API 交握失敗會讓每支影片都報錯）。
- 搜尋後多打一次 `videos.list` 只留 `status.embeddable=true` + `public` 的影片
  （search 的 `videoEmbeddable` 過濾不可靠），把 150/152 從源頭清掉。
- 直接載入沒有 JS 事件，改用影片實際長度的計時器到時自動進評分（上限 7 分鐘）；
  網路層失敗會透過 navigation delegate 回報 → 換下一支，連續 4 支失敗退回內建伸展組。
- 播放畫面有「Next video」手動換片。

**不適度提問**：每次 session 輪流問不同部位（下背 → 左髖 → 右髖 → 大腿後側 → 頸肩 →
深層臀肌），連續兩次不會重複；記錄在 `SessionLog.focusArea`。

**接續痠痛**：上一次某部位不適 ≥ 7（且該次 stretch 沒被評為 😖、距今 < 24 小時）時，
下次開場會問「上次你的 X 是 7/10，要用同一組 stretch 繼續嗎？」→ Repeat it / Try something new。
選 Repeat 時，check-in 也會鎖定在該痠痛部位而非輪替部位。

---

## 排程細節

- iOS 一次最多 64 個待觸發本機通知。App 每次進入前景時，重新排未來 8 天、封頂 60 個。
- 通知動作：`開始伸展`（開 App 直接進入伸展流程）/ `延後 5 分鐘` / `今天不用了`（取消今天剩餘）。
- 時段跨午夜、改間隔、日光節約 → 下次開 App 會自動重排。

## 檔案

```
project.yml                 XcodeGen 設定
Sources/
  App.swift                 App 進入點、通知 delegate
  Models.swift              SwiftData model + enum
  Services.swift            通知排程、YouTube 搜尋、推薦演算法、統計
  YouTubePlayerView.swift   WKWebView + iframe API 播放器
  Views.swift               所有畫面（首頁 / 伸展流程 / 評分 / 痛感 / 紀錄 / 設定 / 引導）
  routine.json              離線伸展組
  Info.plist                含 YTAPIKey 欄位
```

## 測試

`Tests/` 有一個 `StretchBreakTests` target（`@testable import`，host = App）。

```bash
xcodebuild test -scheme StretchBreak -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```
或在 Xcode 按 `⌘U`。

- **純單元測試**（快、免網路）：`ParsingTests`（YouTube URL 解析、ISO8601 長度、API JSON
  解碼）、`RecommenderTests`（不重播最近視窗、排除壞片/不喜歡、偏好沒看過的）、
  `StatsTests`（連續天數含免死、當日次數、本週分鐘）、`PolicyTests`（部位輪替不連續重複、
  痛感 ≥ 7 的接續條件）。
- **`YouTubeLiveTests`**（要網路 + `YTAPIKey`，沒設會自動 skip）：實際打 YouTube API 跑
  `YouTubeProvider.pool()`，斷言回傳 ≥ 3 支、都可嵌入、長度合理、id 不重複；再用 WKWebView
  實際載入第一支 `embed` 頁確認會載入成功。這是真正「YouTube 有沒有成功」的檢查。

## App 圖示

`Sources/Assets.xcassets/AppIcon.appiconset/icon-1024.png`（1024×1024，Xcode 15+ 單尺寸）。
設計：白色「起身伸展」人形 + 湖綠漸層，對應 App 內的 teal 主色。
要改：編輯 `tools/make_icon.py`（純 Pillow，`pip3 install Pillow`）後執行
`python3 tools/make_icon.py` 重新產生，再 build。

## 尚未做（v2）

Apple Watch、HealthKit 寫入、跨裝置同步、深色 / tinted 圖示變體、社群。
