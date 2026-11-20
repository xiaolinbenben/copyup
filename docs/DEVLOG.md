# CopyUp Devlog：二开启动与发行验证全流程记录

记录日期：2026-06-19

仓库路径：

```text
/Users/xiaolinbenben/Documents/GitHub/copyup
```

本文记录从开始评估 Clipy 二开，到完成 CopyUp Developer ID 签名、公证、打包的完整流程。后续复盘和教程素材统一追加到本文件。

## 1. 项目初步认知

一开始先确认这个项目的性质：

- 这是一个 macOS 原生剪贴板管理工具。
- 主体是 Swift / AppKit 项目。
- 使用 Xcode 工程 `Clipy.xcodeproj`。
- 运行方式是菜单栏 App。
- 核心功能是监听剪贴板、保存历史记录、通过菜单选择历史内容并粘贴。

重点源码模块：

```text
Clipy/Sources/AppDelegate.swift
Clipy/Sources/Services/ClipService.swift
Clipy/Sources/Services/PasteService.swift
Clipy/Sources/Managers/MenuManager.swift
Clipy/Sources/Repositories/PasteboardHistoryRepository.swift
Clipy/Sources/Repositories/SnippetRepository.swift
Clipy/Sources/Database/SQLiteDataSchema.swift
Clipy/Sources/Snippets/CPYSnippetsEditorWindowController.swift
Clipy/Sources/Utility/CPYUtilities.swift
```

核心理解：

- `ClipService` 负责轮询剪贴板并保存历史。
- `PasteService` 负责把选中内容写回剪贴板并模拟粘贴。
- `MenuManager` 负责构建菜单栏菜单、历史菜单、片段菜单。
- `SnippetRepository` 和 `SnippetFolder` / `Snippet` 是片段功能的数据模型。
- SQLiteData 是当前主要数据存储层。

## 2. 版权与二开风险判断

项目许可证：

```text
LICENSE
LICENSE_CLIPMENU
```

两者都是 MIT 许可证。

结论：

- 可以 fork、修改、二开、商业化。
- 可以改名为 CopyUp。
- 可以做 Pro 版本收费。
- 必须保留 MIT 许可证和版权声明。
- 派生作品不建议继续使用 `Clipy` / `ClipMenu` 作为产品名。

对后续商业化的提醒：

- 代码许可允许商业化，不等于商标、图标、品牌资产都可直接复用。
- 正式发行前要替换产品名、图标、官网、隐私政策、更新地址。
- 如果上架 Mac App Store，还要单独评估审核和沙盒权限。

## 3. Firebase 的作用

项目中引入了 Firebase 相关依赖，主要用于：

- Crashlytics 崩溃上报。
- Analytics 或相关事件统计。

本地构建不强制需要 `GoogleService-Info.plist`。

构建时看到的提示：

```text
Skipping Crashlytics: GoogleService-Info.plist is missing.
```

这不是构建错误，只表示没有配置 Firebase，Crashlytics 脚本跳过。

决策：

- 当前核心功能改造阶段暂时不处理 Firebase。
- 后续要决定是否保留。
- 如果保留，需要使用 CopyUp 自己的 Firebase 项目和 `GoogleService-Info.plist`。
- 如果不保留，可以后续清理 Firebase 依赖，减少包体和隐私解释成本。

## 4. Sparkle 的作用

项目中引入 Sparkle：

```text
https://github.com/sparkle-project/Sparkle
```

作用：

- 非 Mac App Store 渠道的自动更新。
- 用户从官网下载安装后，App 可以通过 Sparkle 检查并下载新版本。

结论：

- 如果未来走官网分发，Sparkle 是有用的。
- 如果只走 Mac App Store，Sparkle 通常不需要。
- CopyUp 后续需要把 Sparkle 的更新 feed、签名、公钥等改成自己的。

## 5. 启动与 Rosetta 问题

用户机器环境：

- macOS 已升级到 27.0。
- 当前 GUI 只能使用 Xcode 27 beta。
- 稳定 Xcode GUI 在系统上无法正常打开。
- CLI 环境里仍能使用 Xcode 26.5。

确认过的 CLI 信息：

```bash
xcode-select -p
xcodebuild -version
```

当时命令行 Xcode 是：

```text
/Applications/Xcode.app/Contents/Developer
Xcode 26.5
```

官方安装版 `/Applications/Clipy.app` 出现 Rosetta 提示。检查结果是官方包只有 Intel 架构：

```bash
file /Applications/Clipy.app/Contents/MacOS/Clipy
lipo -info /Applications/Clipy.app/Contents/MacOS/Clipy
```

结论：

- 官方发行版是纯 `x86_64`。
- Apple Silicon 机器运行会要求 Rosetta。
- CopyUp 后续发行必须至少提供 `arm64`，最好提供 Universal：`arm64 x86_64`。

## 6. 初始启动策略

一开始目标不是马上改名，而是先把项目跑起来。

最早采用过 ad-hoc 方式构建 Debug，命令类似：

```bash
xcodebuild \
  -project Clipy.xcodeproj \
  -scheme Clipy \
  -configuration Debug \
  -derivedDataPath .build/DerivedData \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  PROVISIONING_PROFILE_SPECIFIER= \
  build
```

产物路径：

```text
.build/DerivedData/Build/Products/Debug/Clipy.app
```

验证结果：

- Debug 版本可构建。
- 产物是 `arm64`。
- 可以启动，避免官方 x86_64 发行版的 Rosetta 问题。

## 7. 核心功能改造方向

用户暂时决定：

- 不急着把 App 从 Clipy 改成 CopyUp。
- 先做核心功能体验优化。
- 自己先用起来，再考虑正式发行。

当前主要痛点：

- 复制历史藏在文件夹里，经常需要点两次。
- 菜单里的文字、图片、文件预览太小。
- 缺少类似快捷短语、收藏夹、Pin 的能力。

讨论后确定产品概念：

```text
收藏
```

而不是：

```text
Pin
快捷短语
```

实现策略：

- 直接复用现有 snippets 模型。
- 底层继续使用 `SnippetFolder` 和 `Snippet`。
- 第一版不新增 favorites 表。
- 产品文案逐步从 “Snippet / 片断” 改成 “Favorite / 收藏”。

## 8. TODO.md

创建了中文 TODO 文档：

```text
TODO.md
```

主要内容：

- 把粘贴选择从“两次点击”优化成“一次点击”。
- 把现有片段功能改造成“收藏”。
- 底层继续复用 `SnippetFolder` 和 `Snippet`。
- 放大历史记录和收藏项菜单文字。
- 放大图片、文件预览尺寸。
- 确保 Apple Silicon 原生运行。
- 规划签名、公证、Universal App 发行流程。
- 后续决定是否保留 Firebase、Sparkle、Pro 版本边界、正式改名。

当前文档路径：

```text
/Users/xiaolinbenben/Documents/GitHub/copyup/TODO.md
```

## 9. Apple Developer 与证书准备

用户已有 Apple Developer 账号，并准备长期自用和后续分发。

Team 信息：

```text
Team ID: LQ97GA8LY8
Company: Fuzhou Beisi Network Technology Co., Ltd.
```

注册 App ID 时采用：

```text
Release Bundle ID: tech.beisi.copyup
Debug Bundle ID:   tech.beisi.copyup.debug
```

App ID Description 建议：

```text
CopyUp macOS Clipboard Manager
CopyUp macOS Debug
```

已确认的证书：

```text
Apple Development: ZhiQing Lin
Developer ID Application: Fuzhou Beisi Network Technology Co., Ltd. (LQ97GA8LY8)
```

说明：

- `Apple Development` 用于本机调试。
- `Developer ID Application` 用于官网分发。
- Mac App Store 上架是另一套链路，不走 Developer ID 公证。

## 10. 项目签名配置调整

配置文件：

```text
Configurations/CodeSigning.xcconfig
```

当前关键配置：

```xcconfig
CODE_SIGN_IDENTITY[config=Debug] = Apple Development
CODE_SIGN_IDENTITY[config=Release] = Developer ID Application
CODE_SIGN_INJECT_BASE_ENTITLEMENTS[config=Release] = NO
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM = LQ97GA8LY8
PROVISIONING_PROFILE_SPECIFIER[config=Debug] =
PROVISIONING_PROFILE_SPECIFIER[config=Release] =

// #include "Configurations/CodeSigning-AdHoc.xcconfig"
```

`CODE_SIGN_INJECT_BASE_ENTITLEMENTS[config=Release] = NO` 是后来发现并修正的关键点。

没有这行时，Release 包会带：

```text
com.apple.security.get-task-allow = true
```

这是调试权限，不适合正式分发。

Bundle ID 配置在：

```text
Clipy.xcodeproj/project.pbxproj
```

当前值：

```text
Debug:   tech.beisi.copyup.debug
Release: tech.beisi.copyup
```

## 11. Debug 签名构建与启动验证

Debug 构建命令：

```bash
xcodebuild \
  -project Clipy.xcodeproj \
  -scheme Clipy \
  -configuration Debug \
  -derivedDataPath .build/DerivedData \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  build
```

验证命令：

```bash
APP=/Users/xiaolinbenben/Documents/GitHub/copyup/.build/DerivedData/Build/Products/Debug/Clipy.app

defaults read "$APP/Contents/Info.plist" CFBundleIdentifier
lipo -info "$APP/Contents/MacOS/Clipy"
codesign -dv --verbose=2 "$APP" 2>&1 | sed -n '1,28p'
```

本次结果：

```text
Bundle ID: tech.beisi.copyup.debug
Arch: arm64
Authority: Apple Development: ZhiQing Lin
TeamIdentifier: LQ97GA8LY8
```

启动命令：

```bash
open /Users/xiaolinbenben/Documents/GitHub/copyup/.build/DerivedData/Build/Products/Debug/Clipy.app
```

当时看到的进程：

```text
40721 /Users/xiaolinbenben/Documents/GitHub/copyup/.build/DerivedData/Build/Products/Debug/Clipy.app/Contents/MacOS/Clipy
```

## 12. Release 构建与发行验证

Release 构建设置检查：

```bash
xcodebuild \
  -project Clipy.xcodeproj \
  -scheme Clipy \
  -showBuildSettings \
  -configuration Release \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  | rg "PRODUCT_BUNDLE_IDENTIFIER|DEVELOPMENT_TEAM|CODE_SIGN_IDENTITY|PROVISIONING_PROFILE_SPECIFIER|ARCHS|ONLY_ACTIVE_ARCH|ENABLE_HARDENED_RUNTIME|CODE_SIGN_STYLE"
```

确认结果：

```text
ARCHS = arm64 x86_64
CODE_SIGN_IDENTITY = Developer ID Application
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM = LQ97GA8LY8
ENABLE_HARDENED_RUNTIME = YES
ONLY_ACTIVE_ARCH = NO
PRODUCT_BUNDLE_IDENTIFIER = tech.beisi.copyup
```

Release 构建命令：

```bash
xcodebuild \
  -project Clipy.xcodeproj \
  -scheme Clipy \
  -configuration Release \
  -derivedDataPath .build/DerivedData \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  build
```

构建结果：

```text
** BUILD SUCCEEDED **
```

产物：

```text
.build/DerivedData/Build/Products/Release/Clipy.app
```

验证结果：

```text
Bundle ID: tech.beisi.copyup
Version: 1.3.0
Arch: x86_64 arm64
Authority: Developer ID Application: Fuzhou Beisi Network Technology Co., Ltd. (LQ97GA8LY8)
TeamIdentifier: LQ97GA8LY8
```

## 13. Developer ID 重签

发现命令行 Release 构建默认签名里出现过：

```text
--timestamp=none
```

为了满足公证和正式发行要求，对 `.app` 进行了带 timestamp 的 Developer ID 重签：

```bash
APP=/Users/xiaolinbenben/Documents/GitHub/copyup/.build/DerivedData/Build/Products/Release/Clipy.app

codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --sign "Developer ID Application: Fuzhou Beisi Network Technology Co., Ltd. (LQ97GA8LY8)" \
  "$APP"
```

重签后确认：

```text
Timestamp=Jun 19, 2026 at 17:16:33
```

## 14. 打 zip 包

公证提交包：

```bash
mkdir -p /Users/xiaolinbenben/Documents/GitHub/copyup/.build/dist

ditto \
  -c \
  -k \
  --keepParent \
  /Users/xiaolinbenben/Documents/GitHub/copyup/.build/DerivedData/Build/Products/Release/Clipy.app \
  /Users/xiaolinbenben/Documents/GitHub/copyup/.build/dist/CopyUp-1.3.0.zip
```

产物：

```text
/Users/xiaolinbenben/Documents/GitHub/copyup/.build/dist/CopyUp-1.3.0.zip
```

大小约：

```text
20M
```

解压后验证过签名仍然有效。

## 15. 公证准备

一开始检查到还没有 `notarytool` profile：

```bash
xcrun notarytool history --keychain-profile copyup
```

输出：

```text
Error: No Keychain password item found for profile: copyup
```

随后用户在本机配置：

```bash
xcrun notarytool store-credentials "copyup" \
  --apple-id "Apple Developer 账号邮箱" \
  --team-id "LQ97GA8LY8" \
  --password "App 专用密码"
```

成功结果：

```text
Validating your credentials...
Success. Credentials validated.
Credentials saved to Keychain.
To use them, specify --keychain-profile "copyup"
```

## 16. Apple 公证

提交命令：

```bash
xcrun notarytool submit \
  /Users/xiaolinbenben/Documents/GitHub/copyup/.build/dist/CopyUp-1.3.0.zip \
  --keychain-profile copyup \
  --wait
```

Submission ID：

```text
0be1df80-1ab0-45de-a728-e1fe8e4b9524
```

最终结果：

```text
Current status: Accepted
Processing complete
status: Accepted
```

查看日志：

```bash
xcrun notarytool log \
  0be1df80-1ab0-45de-a728-e1fe8e4b9524 \
  --keychain-profile copyup
```

关键日志：

```json
{
  "status": "Accepted",
  "statusSummary": "Ready for distribution",
  "statusCode": 0,
  "archiveFilename": "CopyUp-1.3.0.zip"
}
```

## 17. Staple 公证票据

命令：

```bash
APP=/Users/xiaolinbenben/Documents/GitHub/copyup/.build/DerivedData/Build/Products/Release/Clipy.app

xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
```

结果：

```text
The staple and validate action worked!
The validate action worked!
```

## 18. Gatekeeper 验证

验证命令：

```bash
APP=/Users/xiaolinbenben/Documents/GitHub/copyup/.build/DerivedData/Build/Products/Release/Clipy.app

spctl -a -vvv -t exec "$APP"
```

结果：

```text
/Users/xiaolinbenben/Documents/GitHub/copyup/.build/DerivedData/Build/Products/Release/Clipy.app: accepted
source=Notarized Developer ID
origin=Developer ID Application: Fuzhou Beisi Network Technology Co., Ltd. (LQ97GA8LY8)
```

说明：

- `spctl -t exec` 已确认 Notarized Developer ID。
- `stapler validate` 已确认票据有效。
- 本地对未隔离文件执行 `spctl -t open` 可能出现 `Insufficient Context`，不作为本次失败判断。

## 19. 最终公证包

Staple 后重新打包：

```bash
ditto \
  -c \
  -k \
  --keepParent \
  /Users/xiaolinbenben/Documents/GitHub/copyup/.build/DerivedData/Build/Products/Release/Clipy.app \
  /Users/xiaolinbenben/Documents/GitHub/copyup/.build/dist/CopyUp-1.3.0-notarized.zip
```

最终产物：

```text
/Users/xiaolinbenben/Documents/GitHub/copyup/.build/dist/CopyUp-1.3.0-notarized.zip
```

状态：

```text
Ready for distribution
```

## 20. 当前仓库文件变化

本阶段新增或修改的关键文件：

```text
TODO.md
Configurations/CodeSigning.xcconfig
Clipy.xcodeproj/project.pbxproj
docs/DEVLOG.md
```

说明：

- `TODO.md` 记录核心功能改造计划。
- `CodeSigning.xcconfig` 记录签名配置。
- `project.pbxproj` 记录 Debug / Release Bundle ID。
- `DEVLOG.md` 记录从二开评估到公证成功的完整流程。

## 21. 后续建议

短期优先级：

1. 不急着正式改名，继续做核心功能改造。
2. 先优化菜单层级，让最近历史记录可以一级菜单选择。
3. 把 snippets 产品概念改造成“收藏”。
4. 放大文字、图片、文件预览。
5. 自用验证稳定后，再统一处理 App 名称、图标、菜单文案、Sparkle 更新地址。

发行侧建议：

1. 把 Release build、重签、zip、公证、staple、验证固化成脚本。
2. 官网分发走 Developer ID + notarization。
3. Mac App Store 单独评估，不要让早期版本被 MAS 审核流程卡住。
4. 如果保留 Sparkle，后续要配置 CopyUp 自己的更新 feed 和签名。
5. 如果保留 Firebase，后续要接入 CopyUp 自己的 Firebase 项目和隐私说明。

## 22. 当前最重要的结论

这次已经证明：

- 仓库可以在当前机器上正常构建。
- Debug 可以用 Apple Development 签名启动。
- Release 可以用 Developer ID 签名。
- Release 可以构建 Universal App，解决官方包触发 Rosetta 的问题。
- Developer ID 公证链路已经跑通。
- 最终 zip 已达到官网分发的技术状态。

下一步真正要做的是产品体验改造，而不是继续卡在构建和签名链路上。

## 23. 正式将 Clipy 重命名为 CopyUp

执行时间：2026-06-19

本阶段目标：

- 将 App、工程、target、scheme、module、测试 target 从 `Clipy` 改为 `CopyUp`。
- 将源码目录从 `Clipy` 改为 `CopyUp`。
- 将测试目录从 `ClipyTests` 改为 `CopyUpTests`。
- 将工程文件从 `Clipy.xcodeproj` 改为 `CopyUp.xcodeproj`。
- 将 `Configurations/Clipy.xcconfig` 改为 `Configurations/CopyUp.xcconfig`。
- 将 `NSLock+Clipy.swift` 改为 `NSLock+CopyUp.swift`。
- 将 `clipy.colorset`、`clipy_logo.png` 改为 `copyup.colorset`、`copyup_logo.png`。
- 将 Sparkle 更新地址改为 `https://copyup.beisi.tech/appcast.xml`。
- 保留 `CPY` 类名前缀和持久化 key。
- 保留原 Clipy Project copyright、第三方依赖 URL 和历史记录。

验证命令：

```bash
xcodebuild -list -project CopyUp.xcodeproj
```

结果：

```text
Targets:
    CopyUp
    CopyUpTests

Schemes:
    CopyUp
```

Debug 构建：

```bash
xcodebuild \
  -project CopyUp.xcodeproj \
  -scheme CopyUp \
  -configuration Debug \
  -derivedDataPath .build/DerivedData-CopyUp \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  build
```

结果：

```text
** BUILD SUCCEEDED **
```

测试：

```bash
xcodebuild \
  -project CopyUp.xcodeproj \
  -scheme CopyUp \
  -configuration Debug \
  -derivedDataPath .build/DerivedData-CopyUp \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  test
```

结果：

```text
Test run with 62 tests in 10 suites passed
** TEST SUCCEEDED **
```

产物检查：

```bash
plutil -p .build/DerivedData-CopyUp/Build/Products/Debug/CopyUp.app/Contents/Info.plist
file .build/DerivedData-CopyUp/Build/Products/Debug/CopyUp.app/Contents/MacOS/CopyUp
lipo -info .build/DerivedData-CopyUp/Build/Products/Debug/CopyUp.app/Contents/MacOS/CopyUp
```

关键结果：

```text
CFBundleExecutable = CopyUp
CFBundleIdentifier = tech.beisi.copyup.debug
CFBundleName = CopyUp
SUFeedURL = https://copyup.beisi.tech/appcast.xml
architecture = arm64
```

启动验证：

```bash
open /Users/xiaolinbenben/Documents/GitHub/copyup/.build/DerivedData-CopyUp/Build/Products/Debug/CopyUp.app
pgrep -fl 'Clipy|CopyUp'
```

结果：

```text
/Users/xiaolinbenben/Documents/GitHub/copyup/.build/DerivedData-CopyUp/Build/Products/Debug/CopyUp.app/Contents/MacOS/CopyUp
```
