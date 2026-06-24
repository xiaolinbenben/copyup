---
name: copyup-release
description: CopyUp 项目专用的 macOS 发布打包流程。用于用户要求“打包 DMG”“签名”“公证”“发布测试包”“给朋友分享 Apple Silicon 版本”“验证 Gatekeeper”时，指导 Codex 使用 xcodebuild、Developer ID、notarytool、stapler 和 hdiutil 生成已签名、已公证、可分发的 CopyUp DMG。
---

# CopyUp 发布打包

## 基本判断

先确认用户要的渠道：

- **朋友测试 DMG**：使用 Developer ID Application 签名、公证、生成 DMG。这是本 skill 的主路径。
- **Mac App Store 正式上架**：不要用本 skill 生成 DMG 上架；应走 App Store Connect、Apple Distribution、App Sandbox 和 Xcode 上传流程。
- **官网正式分发**：当前 CopyUp 决策是暂不做官网分发；DMG 仅作为本地或朋友测试构建。

默认假设：

- 仓库路径是 `/Users/xiaolinbenben/Documents/GitHub/copyup`，但脚本也支持 `--repo` 指定。
- Team ID 是 `LQ97GA8LY8`。
- Developer ID 证书名称是 `Developer ID Application: Fuzhou Beisi Network Technology Co., Ltd. (LQ97GA8LY8)`。
- notarytool keychain profile 是 `copyup`。
- 默认只打 Apple Silicon：`arm64`。

## 快速执行

完整发布流程必须执行默认命令，不要加 `--skip-notarization`：

从任意目录执行：

```bash
/Users/xiaolinbenben/Documents/GitHub/copyup/.agents/skills/copyup-release/scripts/package_dmg.sh
```

常用参数：

```bash
# Apple Silicon，默认行为
scripts/package_dmg.sh --arch arm64

# 通用包，只有用户明确要求时使用
scripts/package_dmg.sh --arch universal

# 只打包不公证，仅用于本机快速冒烟；完整发布流程禁止使用
scripts/package_dmg.sh --skip-notarization
```

脚本完成后会打印 DMG 路径。最终文件通常位于：

```text
.build/dist/CopyUp-<version>-<timestamp>-<arch>.dmg
```

## 发布流程

1. 检查工作区是否干净。打包测试包通常应该基于当前代码；如果有未提交改动，先明确这是预期。
2. 确认证书存在：

```bash
security find-identity -v -p codesigning | rg "Developer ID Application"
```

3. 确认公证 profile 可用：

```bash
xcrun notarytool history --keychain-profile copyup | head
```

4. 执行脚本打包。完整流程必须看到 `提交公证`、`Staple DMG`、`Gatekeeper 验证 DMG` 三个阶段成功完成。
5. 检查输出：
   - `lipo -archs` 应为 `arm64`，除非用户明确要求 universal。
   - `codesign --verify --deep --strict` 应通过。
   - `spctl -a -vvv -t open --context context:primary-signature <dmg>` 应显示 `accepted`。
   - 挂载 DMG 后，对 `CopyUp.app` 执行 `spctl -a -vvv -t exec` 应显示 `accepted`。

## 结果汇报

完成后用中文简短汇报：

- DMG 的绝对路径，使用可点击文件链接。
- 架构：`arm64` 或 `universal`。
- 签名、公证、staple、Gatekeeper 验证结果。
- 是否改动源码工作区。
- 明确说明：这是朋友测试用 Developer ID 公证 DMG，不是 Mac App Store 正式上传包。

## 注意事项

- 不要为了打包修改版本号，除非用户明确要求。
- 不要自动提交打包产物。
- 不要删除 `.build` 之外的文件。
- 如果用户要求 App Store 上架包，先指出这不是 DMG 流程，应切换到 App Store Connect 流程。
- 当前项目后续正式分发只走 App Store；DMG 仅用于朋友测试。
- 如果用户要求“完整流程”，必须亲自运行一次不带 `--skip-notarization` 的脚本，并汇报完整验证结果。
