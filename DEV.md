# CopyUp 调试

CopyUp 是只在菜单栏运行的 macOS 应用，没有 Dock 图标。只支持 Apple Silicon，不构建 Intel 或 Universal 包。

## 用 Xcode 运行

1. 打开 `CopyUp.xcodeproj`。
2. Scheme 选 `CopyUp`，运行目标选这台 Mac。
3. 按 Run。
4. 到屏幕顶部菜单栏找剪贴板图标。点开后，齿轮按钮是偏好设置。
5. 默认快捷键是历史 `Control + V`，收藏 `Control + B`。

Debug 的 Bundle ID 是 `tech.beisi.copyup.debug`。它和正式版不是同一个应用，辅助功能权限要单独允许。

## 断点

在 Xcode 里点行号加断点，然后 Run。常用入口：

- `ClipService`：剪贴板变化和历史保存。
- `PasteService`：选中一项后的写回剪贴板和模拟粘贴。
- `MenuManager`：菜单栏图标和主菜单。
- `AppDelegate`：启动、偏好设置窗口、清空历史。

Debug 运行时，SQLite 语句会打到 Xcode 底部的控制台。Debug 下如果数据库结构和代码不一致，启动时会清掉本地库并重建。正式包不会这样做。

## 命令行测试

在仓库根目录执行：

```bash
xcodebuild \
  -project CopyUp.xcodeproj \
  -scheme CopyUp \
  -destination 'platform=macOS,arch=arm64' \
  ARCHS=arm64 \
  EXCLUDED_ARCHS=x86_64 \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  test
```

只跑一组测试时，把最后的 `test` 换成：

```bash
-only-testing:CopyUpTests/PasteboardHistoryRepositoryTests test
```

测试覆盖剪贴板历史、收藏、数据库迁移和部分模型。菜单栏点击、辅助功能粘贴没有自动化测试，需要自己运行 App 看。

## 确认没有打进 Intel

命令行构建时加上 `-derivedDataPath .build/DerivedData`，然后检查产物：

```bash
lipo -info .build/DerivedData/Build/Products/Debug/CopyUp.app/Contents/MacOS/CopyUp
```

结果里只能有 `arm64`。出现 `x86_64` 就是构建配置错了。

## 数据位置

- Debug 数据库：`~/Library/Application Support/tech.beisi.copyup.debug/sqlite.db`
- Release 数据库：`~/Library/Application Support/tech.beisi.copyup/sqlite.db`

可以直接删掉对应目录，下次启动会重新创建。不要把剪贴板内容提交到仓库。

## 常见问题

- 菜单栏没有图标：确认没有另一个 CopyUp 正在运行。旧进程会占着快捷键。用 `pkill CopyUp` 关掉后再 Run。
- 能复制，但不能自动粘贴到其他应用：到系统设置的辅助功能里允许当前这个 Bundle ID。签名一变，系统会把它当成新应用，需要重新允许。
- 快捷键没反应：看是不是和别的应用冲突，或者辅助功能权限还没给。
- 改完代码历史没了：Debug 遇到数据库结构变化会重建库，这是当前的调试行为。
