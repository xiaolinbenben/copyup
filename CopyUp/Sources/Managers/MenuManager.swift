//
//  MenuManager.swift
//
//  CopyUp
//  GitHub: https://github.com/xiaolinbenben/copyup
//  HP: https://copyup.beisi.tech
//
//  Created by Econa77 on 2016/03/08.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import Combine
import Dependencies
import RxCocoa
import RxSwift

final class MenuManager: NSObject {

    // MARK: - Properties
    // Menus
    private var clipMenu: NSMenu?
    private var historyMenu: NSMenu?
    private var snippetMenu: NSMenu?
    private weak var menuPanelView: CopyUpMenuPanelView?
    // StatusMenu
    private lazy var statusBarItem: NSStatusItem = {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.toolTip = "\(Constants.Application.name)\(Bundle.main.appVersion ?? "")"
        item.menu = clipMenu
        return item
    }()
    // Icon Cache
    private let folderIcon = NSImage(resource: .iconFolder)
    private let snippetIcon = NSImage(resource: .iconText)
    // Other
    private let disposeBag = DisposeBag()
    private let notificationCenter = NotificationCenter.default
    private let kMaxKeyEquivalents = 10
    private let shortenSymbol = "..."

    @Dependency(\.pasteboardHistoryRepository)
    private var pasteboardHistoryRepository
    @Dependency(\.snippetRepository)
    private var snippetRepository
    @Dependency(\.mainQueue)
    private var mainQueue
    private var cancellables: Set<AnyCancellable> = []
    private var snippetFolderDetails = [SnippetFolderDetail]()
    private var selectedTab: CopyUpMenuTab = .history

    // MARK: - Enum Values
    enum StatusType: Int {
        case none, black, white
    }

    // MARK: - Initialize
    override init() {
        super.init()
        folderIcon.isTemplate = true
        folderIcon.size = NSSize(width: 15, height: 13)
        snippetIcon.isTemplate = true
        snippetIcon.size = NSSize(width: 12, height: 13)
    }

    func setup() {
        bind()
    }

}

// MARK: - Popup Menu
extension MenuManager {
    func popUpMenu(_ type: MenuType) {
        switch type {
        case .main:
            selectedTab = .history
        case .history:
            selectedTab = .history
        case .snippet:
            selectedTab = .favorites
        }
        let panelView = createCopyUpMenu()
        clipMenu?.popUp(positioning: nil, at: popupLocation(for: panelView.frame.size), in: nil)
    }

    func popUpSnippetFolder(_ folderDetail: SnippetFolderDetail) {
        let folderMenu = NSMenu(title: folderDetail.folder.title)
        // Folder title
        let labelItem = NSMenuItem(title: folderDetail.folder.title, action: nil)
        labelItem.isEnabled = false
        folderMenu.addItem(labelItem)
        // Snippets
        var index = firstIndexOfMenuItems()
        folderDetail.snippets
            .filter { $0.isEnabled }
            .forEach { snippet in
                let subMenuItem = makeSnippetMenuItem(snippet, listNumber: index)
                folderMenu.addItem(subMenuItem)
                index += 1
            }
        folderMenu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}

// MARK: - Binding
private extension MenuManager {
    func bind() {
        pasteboardHistoryRepository.observeHistories()
            .receive(on: mainQueue)
            .sink { [weak self] _ in self?.createCopyUpMenu() }
            .store(in: &cancellables)
        snippetRepository.observeFolderDetails()
            .receive(on: mainQueue)
            .sink { [weak self] folderDetails in
                self?.snippetFolderDetails = folderDetails
                self?.createCopyUpMenu()
            }
            .store(in: &cancellables)
        // Menu icon
        AppEnvironment.current.defaults.rx.observe(Int.self, Constants.UserDefaults.showStatusItem, retainSelf: false)
            .compactMap { $0 }
            .asDriver(onErrorDriveWith: .empty())
            .drive(onNext: { [weak self] key in
                self?.changeStatusItem(StatusType(rawValue: key) ?? .black)
            })
            .disposed(by: disposeBag)
        // Sort clips
        AppEnvironment.current.defaults.rx.observe(Bool.self, Constants.UserDefaults.reorderClipsAfterPasting, options: [.new], retainSelf: false)
            .compactMap { $0 }
            .asDriver(onErrorDriveWith: .empty())
            .drive(onNext: { [weak self] _ in
                guard let wSelf = self else { return }
                wSelf.createCopyUpMenu()
            })
            .disposed(by: disposeBag)
        // Edit snippets
        notificationCenter.rx.notification(Notification.Name(rawValue: Constants.Notification.closeSnippetEditor))
            .asDriver(onErrorDriveWith: .empty())
            .drive(onNext: { [weak self] _ in
                self?.createCopyUpMenu()
            })
            .disposed(by: disposeBag)
        // Observe change preference settings
        let defaults = AppEnvironment.current.defaults
        var menuChangedObservables = [Observable<Void>]()
        menuChangedObservables.append(defaults.rx.observe(Bool.self, Constants.UserDefaults.addClearHistoryMenuItem, options: [.new], retainSelf: false)
                                        .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(defaults.rx.observe(Int.self, Constants.UserDefaults.maxHistorySize, options: [.new], retainSelf: false)
                                        .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(defaults.rx.observe(Bool.self, Constants.UserDefaults.showIconInTheMenu, options: [.new], retainSelf: false)
                                        .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(defaults.rx.observe(Int.self, Constants.UserDefaults.numberOfItemsPlaceInline, options: [.new], retainSelf: false)
                                        .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(defaults.rx.observe(Int.self, Constants.UserDefaults.numberOfItemsPlaceInsideFolder, options: [.new], retainSelf: false)
                                        .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(defaults.rx.observe(Int.self, Constants.UserDefaults.maxMenuItemTitleLength, options: [.new], retainSelf: false)
                                        .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(defaults.rx.observe(Bool.self, Constants.UserDefaults.menuItemsTitleStartWithZero, options: [.new], retainSelf: false)
                                        .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(defaults.rx.observe(Bool.self, Constants.UserDefaults.menuItemsAreMarkedWithNumbers, options: [.new], retainSelf: false)
                                        .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(defaults.rx.observe(Bool.self, Constants.UserDefaults.showToolTipOnMenuItem, options: [.new], retainSelf: false)
                                        .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(defaults.rx.observe(Bool.self, Constants.UserDefaults.showImageInTheMenu, options: [.new], retainSelf: false)
                                        .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(defaults.rx.observe(Bool.self, Constants.UserDefaults.addNumericKeyEquivalents, options: [.new], retainSelf: false)
                                        .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(defaults.rx.observe(Int.self, Constants.UserDefaults.maxLengthOfToolTip, options: [.new], retainSelf: false)
                                        .compactMap { $0 }.distinctUntilChanged().map { _ in })
        menuChangedObservables.append(defaults.rx.observe(Bool.self, Constants.UserDefaults.showColorPreviewInTheMenu, options: [.new], retainSelf: false)
                                        .compactMap { $0 }.distinctUntilChanged().map { _ in })
        Observable.merge(menuChangedObservables)
            .throttle(.seconds(1), scheduler: MainScheduler.instance)
            .asDriver(onErrorDriveWith: .empty())
            .drive(onNext: { [weak self] in
                self?.createCopyUpMenu()
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - Menus
private extension MenuManager {
    @discardableResult
    func createCopyUpMenu() -> CopyUpMenuPanelView {
        clipMenu = NSMenu(title: Constants.Application.name)
        clipMenu?.delegate = self
        historyMenu = clipMenu
        snippetMenu = clipMenu

        let panelView = CopyUpMenuPanelView(
            tab: selectedTab,
            historyEntries: historyEntries(),
            favoriteEntries: favoriteEntries(),
            callbacks: menuCallbacks()
        )
        let menuItem = NSMenuItem()
        menuItem.view = panelView
        clipMenu?.addItem(menuItem)
        menuPanelView = panelView

        statusBarItem.menu = clipMenu
        return panelView
    }

    func popupLocation(for panelSize: NSSize) -> NSPoint {
        let mouseLocation = NSEvent.mouseLocation
        guard let visibleFrame = NSScreen.screens
            .first(where: { $0.frame.contains(mouseLocation) })?
            .visibleFrame ?? NSScreen.main?.visibleFrame else {
            return mouseLocation
        }

        let padding: CGFloat = 12
        let spaceAbove = visibleFrame.maxY - mouseLocation.y
        let spaceBelow = mouseLocation.y - visibleFrame.minY
        let popupX = min(max(mouseLocation.x, visibleFrame.minX + padding), visibleFrame.maxX - panelSize.width - padding)
        let popupY: CGFloat
        if spaceAbove >= spaceBelow {
            popupY = min(mouseLocation.y + panelSize.height, visibleFrame.maxY - padding)
        } else {
            popupY = max(mouseLocation.y, visibleFrame.minY + panelSize.height + padding)
        }
        return NSPoint(x: popupX, y: popupY)
    }

    func refreshMenuPanel() {
        menuPanelView?.update(
            tab: selectedTab,
            historyEntries: historyEntries(),
            favoriteEntries: favoriteEntries()
        )
    }

    func menuCallbacks() -> CopyUpMenuCallbacks {
        CopyUpMenuCallbacks(
            selectTab: { [weak self] tab in
                self?.selectedTab = tab
                self?.refreshMenuPanel()
            },
            selectEntry: { [weak self] kind in
                self?.selectEntry(kind)
            },
            deleteEntry: { [weak self] kind in
                self?.deleteEntry(kind)
            },
            favoriteEntry: { [weak self] kind in
                self?.favoriteEntry(kind) ?? false
            },
            clearHistory: { [weak self] in
                self?.clipMenu?.cancelTracking()
                (NSApp.delegate as? AppDelegate)?.clearAllHistory()
            },
            editFavorites: { [weak self] in
                self?.clipMenu?.cancelTracking()
                (NSApp.delegate as? AppDelegate)?.showSnippetEditorWindow()
            },
            showPreferences: { [weak self] in
                self?.clipMenu?.cancelTracking()
                (NSApp.delegate as? AppDelegate)?.showPreferenceWindow()
            },
            quit: { [weak self] in
                self?.clipMenu?.cancelTracking()
                (NSApp.delegate as? AppDelegate)?.terminate()
            }
        )
    }

    func historyEntries() -> [CopyUpMenuEntry] {
        let maxHistory = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.maxHistorySize)
        let ascending = !AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.reorderClipsAfterPasting)
        let showsNumber = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.menuItemsAreMarkedWithNumbers)
        let firstIndex = firstIndexOfMenuItems()
        let favoriteContents = Set(snippetFolderDetails.flatMap(\.snippets).map(\.content))

        return pasteboardHistoryRepository.fetchHistoryDetails(
            ascending: ascending,
            includesThumbnailAsset: false,
            limit: maxHistory
        )
        .enumerated()
        .map { index, detail in
            let content = pasteboardHistoryRepository.fetchContent(id: detail.history.id)
            let image: NSImage?
            if let content {
                image = self.image(from: content)
            } else {
                image = nil
            }
            let stringValue = content?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return CopyUpMenuEntry(
                kind: .history(detail.history.id),
                title: image == nil ? title(for: detail.history, content: content) : "",
                image: image,
                listNumber: firstIndex + index,
                showsNumber: showsNumber,
                canFavorite: image == nil && !stringValue.isEmpty,
                isFavorited: favoriteContents.contains(stringValue)
            )
        }
    }

    func favoriteEntries() -> [CopyUpMenuEntry] {
        let showsNumber = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.menuItemsAreMarkedWithNumbers)
        let firstIndex = firstIndexOfMenuItems()
        return snippetFolderDetails
            .filter { $0.folder.isEnabled }
            .flatMap { $0.snippets.filter(\.isEnabled) }
            .enumerated()
            .map { index, snippet in
                CopyUpMenuEntry(
                    kind: .favorite(snippet.id),
                    title: trimTitle(snippet.title),
                    image: nil,
                    listNumber: firstIndex + index,
                    showsNumber: showsNumber,
                    canFavorite: false,
                    isFavorited: true
                )
            }
    }

    func selectEntry(_ kind: CopyUpMenuEntry.Kind) {
        clipMenu?.cancelTracking()
        switch kind {
        case .history(let id):
            guard let content = pasteboardHistoryRepository.fetchContent(id: id) else {
                NSSound.beep()
                return
            }
            AppEnvironment.current.pasteService.paste(id: id, content: content)
        case .favorite(let id):
            guard let snippet = snippetRepository.fetchSnippet(id: id) else {
                NSSound.beep()
                return
            }
            AppEnvironment.current.pasteService.copyToPasteboard(with: snippet.content)
            AppEnvironment.current.pasteService.paste()
        }
    }

    func deleteEntry(_ kind: CopyUpMenuEntry.Kind) {
        switch kind {
        case .history(let id):
            pasteboardHistoryRepository.deleteHistory(id: id)
        case .favorite(let id):
            snippetRepository.deleteSnippet(id)
        }
        refreshMenuPanel()
    }

    func favoriteEntry(_ kind: CopyUpMenuEntry.Kind) -> Bool {
        guard case .history(let id) = kind,
              let content = pasteboardHistoryRepository.fetchContent(id: id) else {
            NSSound.beep()
            return false
        }
        let favoriteContent = content.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !favoriteContent.isEmpty, image(from: content) == nil else {
            NSSound.beep()
            return false
        }
        if snippetFolderDetails.flatMap(\.snippets).contains(where: { $0.content == favoriteContent }) {
            return true
        }
        guard let folder = favoriteFolder(),
              let snippet = snippetRepository.insertSnippet(to: folder.id) else {
            NSSound.beep()
            return false
        }
        snippetRepository.updateSnippetTitle(snippet.id, title: favoriteTitle(from: favoriteContent))
        snippetRepository.updateSnippetContent(snippet.id, content: favoriteContent)
        snippetFolderDetails = snippetRepository.fetchFolderDetails()
        refreshMenuPanel()
        return true
    }

    func favoriteFolder() -> SnippetFolder? {
        if let folder = snippetFolderDetails.first(where: { $0.folder.isEnabled })?.folder {
            return folder
        }
        guard let folder = snippetRepository.insertFolder() else { return nil }
        snippetRepository.updateFolderTitle(folder.id, title: String(localized: "Snippet"))
        return folder
    }

    func favoriteTitle(from content: String) -> String {
        let title = content
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return String(localized: "Snippet") }
        if title.utf16.count <= 50 { return title }
        return (title as NSString).substring(to: 47) + shortenSymbol
    }

    func title(for history: PasteboardHistory, content: PasteboardContent?) -> String {
        let title = history.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return trimTitle(title) }
        if let content,
           let fileName = content.assets
            .first(where: { $0.type == .fileURL })
            .flatMap({ URL(dataRepresentation: $0.data, relativeTo: nil)?.lastPathComponent }),
           !fileName.isEmpty {
            return trimTitle(fileName)
        }
        return "File"
    }

    func image(from content: PasteboardContent) -> NSImage? {
        let imageURL = content.assets
            .filter { $0.type == .fileURL }
            .compactMap { URL(dataRepresentation: $0.data, relativeTo: nil) }
            .first(where: { ["jpg", "jpeg", "png", "bmp", "tiff"].contains($0.pathExtension.lowercased()) })
        if let imageURL {
            return NSImage(contentsOf: imageURL)
        }
        if let data = content.assets.first(where: { [.png, .tiff, .deprecatedTIFF].contains($0.type) })?.data {
            return NSImage(data: data)
        }
        return nil
    }

    func menuItemTitle(_ title: String, listNumber: NSInteger, isMarkWithNumber: Bool) -> String {
        return (isMarkWithNumber) ? "\(listNumber). \(title)" : title
    }

    func makeSubmenuItem(_ count: Int, start: Int, end: Int, numberOfItems: Int) -> NSMenuItem {
        var count = count
        if start == 0 {
            count -= 1
        }
        var lastNumber = count + numberOfItems
        if end < lastNumber {
            lastNumber = end
        }
        let menuItemTitle = "\(count + 1) - \(lastNumber)"
        return makeSubmenuItem(menuItemTitle)
    }

    func makeSubmenuItem(_ title: String) -> NSMenuItem {
        let subMenu = NSMenu(title: "")
        let subMenuItem = NSMenuItem(title: title, action: nil)
        subMenuItem.submenu = subMenu
        subMenuItem.image = (AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showIconInTheMenu)) ? folderIcon : nil
        return subMenuItem
    }

    func trimTitle(_ title: String?) -> String {
        if title == nil { return "" }
        let theString = title!.trimmingCharacters(in: .whitespacesAndNewlines) as NSString

        let aRange = NSRange(location: 0, length: 0)
        var lineStart = 0, lineEnd = 0, contentsEnd = 0
        theString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: aRange)

        var titleString = (lineEnd == theString.length) ? theString as String : theString.substring(to: contentsEnd)

        var maxMenuItemTitleLength = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.maxMenuItemTitleLength)
        if maxMenuItemTitleLength < shortenSymbol.count {
            maxMenuItemTitleLength = shortenSymbol.count
        }

        if titleString.utf16.count > maxMenuItemTitleLength {
            titleString = (titleString as NSString).substring(to: maxMenuItemTitleLength - shortenSymbol.count) + shortenSymbol
        }

        return titleString as String
    }
}

// MARK: - Clips
private extension MenuManager {
    func addHistoryItems(_ menu: NSMenu) {
        let placeInLine = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.numberOfItemsPlaceInline)
        let placeInsideFolder = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.numberOfItemsPlaceInsideFolder)
        let maxHistory = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.maxHistorySize)

        // History title
        let labelItem = NSMenuItem(title: String(localized: "History"), action: nil)
        labelItem.isEnabled = false
        menu.addItem(labelItem)

        // History
        let firstIndex = firstIndexOfMenuItems()
        var listNumber = firstIndex
        var subMenuCount = placeInLine
        var subMenuIndex = 1 + placeInLine

        let ascending = !AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.reorderClipsAfterPasting)
        let isShowImage = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showImageInTheMenu)
        let isShowColorCode = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showColorPreviewInTheMenu)
        let historyDetails = pasteboardHistoryRepository.fetchHistoryDetails(
            ascending: ascending,
            includesThumbnailAsset: isShowImage || isShowColorCode,
            limit: maxHistory
        )
        let currentSize = historyDetails.count
        var i = 0
        historyDetails.forEach { historyDetail in
            if placeInLine < 1 || placeInLine - 1 < i {
                // Folder
                if i == subMenuCount {
                    let subMenuItem = makeSubmenuItem(subMenuCount, start: firstIndex, end: currentSize, numberOfItems: placeInsideFolder)
                    menu.addItem(subMenuItem)
                    listNumber = firstIndex
                }

                // Clip
                if let subMenu = menu.item(at: subMenuIndex)?.submenu {
                    let menuItem = makeCopyUpMenuItem(historyDetail, index: i, listNumber: listNumber)
                    subMenu.addItem(menuItem)
                    listNumber += 1
                }
            } else {
                // Clip
                let menuItem = makeCopyUpMenuItem(historyDetail, index: i, listNumber: listNumber)
                menu.addItem(menuItem)
                listNumber += 1
            }

            i += 1
            if i == subMenuCount + placeInsideFolder {
                subMenuCount += placeInsideFolder
                subMenuIndex += 1
            }
        }
    }

    func makeCopyUpMenuItem(_ historyDetail: PasteboardHistoryDetail, index: Int, listNumber: Int) -> NSMenuItem {
        let history = historyDetail.history
        let isMarkWithNumber = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.menuItemsAreMarkedWithNumbers)
        let isShowToolTip = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showToolTipOnMenuItem)
        let isShowImage = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showImageInTheMenu)
        let isShowColorCode = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showColorPreviewInTheMenu)
        let addNumbericKeyEquivalents = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.addNumericKeyEquivalents)

        var keyEquivalent = ""
        if addNumbericKeyEquivalents && (index < kMaxKeyEquivalents) {
            let isStartFromZero = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.menuItemsTitleStartWithZero)

            var shortCutNumber = (isStartFromZero) ? index : index + 1
            if shortCutNumber == kMaxKeyEquivalents {
                shortCutNumber = 0
            }
            keyEquivalent = "\(shortCutNumber)"
        }

        let primaryPboardType = history.primaryType
        let clipString = history.title
        let title = trimTitle(clipString)
        let titleWithMark = menuItemTitle(title, listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)

        let menuItem = NSMenuItem(title: titleWithMark, action: #selector(AppDelegate.selectCopyUpMenuItem(_:)), keyEquivalent: keyEquivalent)
        menuItem.representedObject = history.id

        if isShowToolTip {
            let maxLengthOfToolTip = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.maxLengthOfToolTip)
            let toIndex = (clipString.count < maxLengthOfToolTip) ? clipString.count : maxLengthOfToolTip
            menuItem.toolTip = (clipString as NSString).substring(to: toIndex)
        }

        if primaryPboardType == .png || primaryPboardType == .tiff || primaryPboardType == .deprecatedTIFF {
            menuItem.title = menuItemTitle("(Image)", listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)
        } else if primaryPboardType == .pdf || primaryPboardType == .deprecatedPDF {
            menuItem.title = menuItemTitle("(PDF)", listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)
        } else if primaryPboardType == .fileURL || primaryPboardType == .deprecatedFilenames {
            menuItem.title = menuItemTitle("(Files)", listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)
        }

        if isShowImage || isShowColorCode,
           let thumbnailAsset = historyDetail.thumbnailAsset,
           let image = NSImage(data: thumbnailAsset.data),
           (thumbnailAsset.kind == .image && isShowImage) || (thumbnailAsset.kind == .colorCode && isShowColorCode) {
            let width = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.thumbnailWidth)
            let height = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.thumbnailHeight)
            menuItem.image = image.aspectFitImage(CGFloat(width), CGFloat(height))
        }

        return menuItem
    }
}

// MARK: - Snippets
private extension MenuManager {
    func addSnippetItems(_ menu: NSMenu, separateMenu: Bool, details: [SnippetFolderDetail]) {
        guard !details.isEmpty else { return }

        if separateMenu {
            menu.addItem(NSMenuItem.separator())
        }

        // Snippet title
        let labelItem = NSMenuItem(title: String(localized: "Snippet"), action: nil)
        labelItem.isEnabled = false
        menu.addItem(labelItem)

        var subMenuIndex = menu.numberOfItems - 1
        let firstIndex = firstIndexOfMenuItems()
        details
            .filter { $0.folder.isEnabled }
            .forEach { detail in
                let folderTitle = detail.folder.title
                let subMenuItem = makeSubmenuItem(folderTitle)
                menu.addItem(subMenuItem)
                subMenuIndex += 1

                var i = firstIndex
                detail.snippets
                    .filter { $0.isEnabled }
                    .forEach { snippet in
                        let subMenuItem = makeSnippetMenuItem(snippet, listNumber: i)
                        if let subMenu = menu.item(at: subMenuIndex)?.submenu {
                            subMenu.addItem(subMenuItem)
                            i += 1
                        }
                    }
            }
    }

    func makeSnippetMenuItem(_ snippet: Snippet, listNumber: Int) -> NSMenuItem {
        let isMarkWithNumber = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.menuItemsAreMarkedWithNumbers)
        let isShowIcon = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.showIconInTheMenu)

        let title = trimTitle(snippet.title)
        let titleWithMark = menuItemTitle(title, listNumber: listNumber, isMarkWithNumber: isMarkWithNumber)

        let menuItem = NSMenuItem(title: titleWithMark, action: #selector(AppDelegate.selectSnippetMenuItem(_:)), keyEquivalent: "")
        menuItem.representedObject = snippet.id
        menuItem.toolTip = snippet.content
        menuItem.image = (isShowIcon) ? snippetIcon : nil

        return menuItem
    }
}

// MARK: - Status Item
private extension MenuManager {
    func changeStatusItem(_ type: StatusType) {
        switch type {
        case .black:
            let image = NSImage(resource: .statusbarMenuBlack)
            image.isTemplate = true
            statusBarItem.button?.image = image
            statusBarItem.isVisible = true
        case .white:
            let image = NSImage(resource: .statusbarMenuWhite)
            image.isTemplate = true
            statusBarItem.button?.image = image
            statusBarItem.isVisible = true
        case .none:
            statusBarItem.isVisible = false
        }
    }
}

// MARK: - Settings
private extension MenuManager {
    func firstIndexOfMenuItems() -> NSInteger {
        return AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.menuItemsTitleStartWithZero) ? 0 : 1
    }
}

extension MenuManager: NSMenuDelegate {
    func menuDidClose(_ menu: NSMenu) {
        if menu === clipMenu {
            selectedTab = .history
        }
    }
}
