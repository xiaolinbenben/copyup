//
//  CopyUpMenuViews.swift
//
//  CopyUp
//  GitHub: https://github.com/xiaolinbenben/copyup
//  HP: https://copyup.beisi.tech
//
//  Created by Codex on 2026/06/19.
//
//  Copyright © 2015-2026 Clipy Project.
//

import Cocoa

enum CopyUpMenuTab: Int {
    case history
    case favorites
}

struct CopyUpMenuEntry {
    enum Kind {
        case history(PasteboardHistory.ID)
        case favorite(Snippet.ID)
    }

    let kind: Kind
    let title: String
    let image: NSImage?
    let listNumber: Int
    let showsNumber: Bool
    let canFavorite: Bool
    let isFavorited: Bool
}

struct CopyUpMenuCallbacks {
    let selectTab: (CopyUpMenuTab) -> Void
    let selectEntry: (CopyUpMenuEntry.Kind) -> Void
    let deleteEntry: (CopyUpMenuEntry.Kind) -> Void
    let favoriteEntry: (CopyUpMenuEntry.Kind) -> Bool
    let clearHistory: () -> Void
    let editFavorites: () -> Void
    let showPreferences: () -> Void
    let quit: () -> Void
}

final class CopyUpMenuPanelView: NSView {
    private enum Metrics {
        static var width: CGFloat {
            let screenWidth = screen?.visibleFrame.width ?? 640
            return max(360, min(screenWidth - 80, 560))
        }

        static let headerHeight: CGFloat = 52
        static let inset: CGFloat = 18
        static let rowGap: CGFloat = 10
        static let contentTopInset: CGFloat = 0
        static let contentBottomInset: CGFloat = 18

        static var maxListHeight: CGFloat {
            max(220, min(760, maxPanelHeight - headerHeight))
        }

        private static var maxPanelHeight: CGFloat {
            guard let visibleFrame = screen?.visibleFrame else { return 680 }
            let mouseY = NSEvent.mouseLocation.y
            let verticalPadding: CGFloat = 36
            let spaceBelow = mouseY - visibleFrame.minY - verticalPadding
            let spaceAbove = visibleFrame.maxY - mouseY - verticalPadding
            return max(360, min(max(spaceAbove, spaceBelow), visibleFrame.height - verticalPadding * 2))
        }

        private static var screen: NSScreen? {
            NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        }
    }

    private let tabControl = CopyUpMenuTabControl()
    private let scrollView = NSScrollView()
    private let contentView = NSView()
    private let emptyLabel = NSTextField(labelWithString: "")
    private var headerButtons = [NSButton]()
    private var rows = [CopyUpMenuRowView]()

    private var tab: CopyUpMenuTab
    private var historyEntries: [CopyUpMenuEntry]
    private var favoriteEntries: [CopyUpMenuEntry]
    private let callbacks: CopyUpMenuCallbacks
    private var contentHeight: CGFloat = 0
    private var scrollsToTopOnNextLayout = false

    init(
        tab: CopyUpMenuTab,
        historyEntries: [CopyUpMenuEntry],
        favoriteEntries: [CopyUpMenuEntry],
        callbacks: CopyUpMenuCallbacks
    ) {
        self.tab = tab
        self.historyEntries = historyEntries
        self.favoriteEntries = favoriteEntries
        self.callbacks = callbacks
        super.init(frame: NSRect(x: 0, y: 0, width: Metrics.width, height: Metrics.headerHeight + 160))
        setup()
        reloadRows()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let headerY = bounds.height - Metrics.headerHeight
        tabControl.frame = NSRect(x: Metrics.inset, y: headerY + 14, width: 108, height: 24)

        let buttonSize = NSSize(width: 28, height: 28)
        var buttonX = bounds.width - Metrics.inset - buttonSize.width
        headerButtons.reversed().forEach { button in
            button.frame = NSRect(x: buttonX, y: headerY + 12, width: buttonSize.width, height: buttonSize.height)
            buttonX -= 40
        }

        scrollView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: headerY)
        layoutRows()
        scrollToTopIfNeeded()
    }

    func update(tab: CopyUpMenuTab, historyEntries: [CopyUpMenuEntry], favoriteEntries: [CopyUpMenuEntry]) {
        self.tab = tab
        self.historyEntries = historyEntries
        self.favoriteEntries = favoriteEntries
        tabControl.selectedTab = tab
        reloadRows()
    }
}

private extension CopyUpMenuPanelView {
    var activeEntries: [CopyUpMenuEntry] {
        tab == .history ? historyEntries : favoriteEntries
    }

    func setup() {
        tabControl.selectedTab = tab
        tabControl.onSelect = { [weak self] tab in
            self?.callbacks.selectTab(tab)
        }
        addSubview(tabControl)

        headerButtons = [
            button("trash", String(localized: "Clear History"), #selector(clearHistory)),
            button("square.and.pencil", String(localized: "Edit Snippets"), #selector(editFavorites)),
            button("gearshape", String(localized: "Preferences"), #selector(showPreferences)),
            button("power", String(localized: "Quit CopyUp"), #selector(quit))
        ]
        headerButtons.forEach(addSubview)

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = contentView
        addSubview(scrollView)

        emptyLabel.font = .systemFont(ofSize: 24)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
    }

    func button(_ symbolName: String, _ tooltip: String, _ action: Selector) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltip)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .labelColor
        button.toolTip = tooltip
        button.target = self
        button.action = action
        return button
    }

    func reloadRows() {
        rows.forEach { $0.removeFromSuperview() }
        rows.removeAll()
        emptyLabel.removeFromSuperview()

        let rowWidth = frame.width - Metrics.inset * 2
        rows = activeEntries.map { entry in
            CopyUpMenuRowView(width: rowWidth, entry: entry, callbacks: callbacks)
        }

        if rows.isEmpty {
            emptyLabel.stringValue = tab == .history ? String(localized: "History") : String(localized: "Snippet")
            contentView.addSubview(emptyLabel)
            contentHeight = 132
        } else {
            rows.forEach(contentView.addSubview)
            contentHeight = Metrics.contentTopInset
                + rows.reduce(0) { $0 + $1.preferredHeight }
                + CGFloat(max(rows.count - 1, 0)) * Metrics.rowGap
                + Metrics.contentBottomInset
        }

        frame.size = NSSize(width: Metrics.width, height: Metrics.headerHeight + min(contentHeight, Metrics.maxListHeight))
        contentView.frame = NSRect(x: 0, y: 0, width: Metrics.width, height: contentHeight)
        scrollsToTopOnNextLayout = true
        needsLayout = true
    }

    func layoutRows() {
        contentView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: contentHeight)
        guard !rows.isEmpty else {
            emptyLabel.frame = NSRect(x: Metrics.inset, y: contentHeight - 86, width: bounds.width - Metrics.inset * 2, height: 36)
            return
        }

        var rowY = contentHeight - Metrics.contentTopInset
        let rowWidth = bounds.width - Metrics.inset * 2
        rows.forEach { row in
            rowY -= row.preferredHeight
            row.frame = NSRect(x: Metrics.inset, y: rowY, width: rowWidth, height: row.preferredHeight)
            rowY -= Metrics.rowGap
        }
    }

    func scrollToTopIfNeeded() {
        guard scrollsToTopOnNextLayout else { return }
        scrollsToTopOnNextLayout = false
        let visibleHeight = scrollView.contentView.bounds.height
        let topY = max(0, contentHeight - visibleHeight)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: topY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    @objc func clearHistory() { callbacks.clearHistory() }
    @objc func editFavorites() { callbacks.editFavorites() }
    @objc func showPreferences() { callbacks.showPreferences() }
    @objc func quit() { callbacks.quit() }
}

final class CopyUpMenuTabControl: NSView {
    var selectedTab: CopyUpMenuTab = .history {
        didSet { updateSelection() }
    }
    var onSelect: ((CopyUpMenuTab) -> Void)?

    private let historyButton = NSButton(title: String(localized: "History"), target: nil, action: nil)
    private let favoritesButton = NSButton(title: String(localized: "Snippet"), target: nil, action: nil)
    private let underlineView = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let segmentWidth = bounds.width / 2
        let buttonHeight = bounds.height - 4
        historyButton.frame = NSRect(x: 0, y: 4, width: segmentWidth, height: buttonHeight)
        favoritesButton.frame = NSRect(x: segmentWidth, y: 4, width: segmentWidth, height: buttonHeight)

        let selectedFrame = selectedTab == .history ? historyButton.frame : favoritesButton.frame
        let underlineWidth: CGFloat = 20
        underlineView.frame = NSRect(
            x: selectedFrame.midX - underlineWidth / 2,
            y: 0,
            width: underlineWidth,
            height: 2
        )
    }
}

private extension CopyUpMenuTabControl {
    func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        configure(historyButton, action: #selector(selectHistory))
        configure(favoritesButton, action: #selector(selectFavorites))
        underlineView.wantsLayer = true
        underlineView.layer?.backgroundColor = NSColor.labelColor.cgColor
        underlineView.layer?.cornerRadius = 1

        addSubview(historyButton)
        addSubview(favoritesButton)
        addSubview(underlineView)
        updateSelection()
    }

    func configure(_ button: NSButton, action: Selector) {
        button.isBordered = false
        button.font = .systemFont(ofSize: 14, weight: .medium)
        button.contentTintColor = .labelColor
        button.target = self
        button.action = action
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
    }

    func updateSelection() {
        update(historyButton, isSelected: selectedTab == .history)
        update(favoritesButton, isSelected: selectedTab == .favorites)
        needsLayout = true
    }

    func update(_ button: NSButton, isSelected: Bool) {
        button.contentTintColor = .labelColor
        button.layer?.backgroundColor = NSColor.clear.cgColor
    }

    @objc func selectHistory() {
        selectedTab = .history
        onSelect?(.history)
    }

    @objc func selectFavorites() {
        selectedTab = .favorites
        onSelect?(.favorites)
    }
}

final class CopyUpMenuRowView: NSView {
    private enum Metrics {
        static let textFont = NSFont.systemFont(ofSize: 30)
        static let textInset = NSSize(width: 18, height: 14)
        static let minTextHeight: CGFloat = 72
        static let maxTextHeight: CGFloat = 178
        static let maxImageHeightRatio: CGFloat = 0.75
        static let buttonSize = NSSize(width: 34, height: 30)
    }

    let preferredHeight: CGFloat

    private let entry: CopyUpMenuEntry
    private let callbacks: CopyUpMenuCallbacks
    private let textField = NSTextField(labelWithString: "")
    private let imageView = CopyUpAspectFillImageView()
    private let favoriteButton = NSButton()
    private let deleteButton = NSButton()
    private var trackingArea: NSTrackingArea?
    private var favorited: Bool

    init(width: CGFloat, entry: CopyUpMenuEntry, callbacks: CopyUpMenuCallbacks) {
        self.entry = entry
        self.callbacks = callbacks
        self.favorited = entry.isFavorited
        self.preferredHeight = Self.height(for: entry, width: width)
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: preferredHeight))
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        if entry.image == nil {
            textField.frame = bounds.insetBy(dx: Metrics.textInset.width, dy: Metrics.textInset.height)
        } else {
            imageView.frame = bounds
        }

        deleteButton.frame = NSRect(
            x: bounds.width - Metrics.buttonSize.width - 14,
            y: bounds.height - Metrics.buttonSize.height - 12,
            width: Metrics.buttonSize.width,
            height: Metrics.buttonSize.height
        )
        favoriteButton.frame = NSRect(
            x: deleteButton.frame.minX - Metrics.buttonSize.width - 8,
            y: deleteButton.frame.minY,
            width: Metrics.buttonSize.width,
            height: Metrics.buttonSize.height
        )
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let next = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(next)
        trackingArea = next
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { setHover(false) }
    }

    override func mouseEntered(with event: NSEvent) {
        setHover(true)
    }

    override func mouseMoved(with event: NSEvent) {
        setHover(true)
    }

    override func mouseExited(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard !bounds.contains(point) else {
            setHover(true)
            return
        }
        setHover(false)
    }

    override func mouseDown(with event: NSEvent) {
        callbacks.selectEntry(entry.kind)
    }
}

private extension CopyUpMenuRowView {
    func setup() {
        wantsLayer = true
        layer?.cornerRadius = 8

        if let image = entry.image {
            imageView.image = image
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = 8
            imageView.layer?.masksToBounds = true
            addSubview(imageView)
        } else {
            textField.stringValue = displayTitle
            textField.font = Metrics.textFont
            textField.lineBreakMode = .byWordWrapping
            textField.maximumNumberOfLines = 4
            textField.cell?.wraps = true
            textField.cell?.usesSingleLineMode = false
            addSubview(textField)
        }

        configure(deleteButton, symbol: "trash", action: #selector(deleteEntry))
        configure(favoriteButton, symbol: favorited ? "star.fill" : "star", action: #selector(favoriteEntry))
        addSubview(favoriteButton)
        addSubview(deleteButton)
        setHover(false)
    }

    var displayTitle: String {
        let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = title.isEmpty ? "File" : title
        return entry.showsNumber ? "\(entry.listNumber). \(value)" : value
    }

    func configure(_ button: NSButton, symbol: String, action: Selector) {
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = symbol == "star.fill" ? .systemYellow : .labelColor
        button.target = self
        button.action = action
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor
        button.layer?.cornerRadius = 8
    }

    func setHover(_ hovering: Bool) {
        layer?.backgroundColor = entry.image == nil && hovering
            ? NSColor.controlAccentColor.withAlphaComponent(0.14).cgColor
            : NSColor.clear.cgColor
        deleteButton.isHidden = !hovering
        favoriteButton.isHidden = !hovering || !entry.canFavorite
    }

    @objc func deleteEntry() {
        callbacks.deleteEntry(entry.kind)
    }

    @objc func favoriteEntry() {
        guard callbacks.favoriteEntry(entry.kind) else { return }
        favorited = true
        configure(favoriteButton, symbol: "star.fill", action: #selector(favoriteEntry))
    }

    static func height(for entry: CopyUpMenuEntry, width: CGFloat) -> CGFloat {
        if let image = entry.image {
            let aspectHeight = image.size.width > 0 ? width * image.size.height / image.size.width : width * 0.56
            return max(80, min(width * Metrics.maxImageHeightRatio, aspectHeight))
        }

        let textWidth = width - Metrics.textInset.width * 2
        let rect = ((entry.title.isEmpty ? "File" : entry.title) as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: Metrics.textFont]
        )
        return max(Metrics.minTextHeight, min(Metrics.maxTextHeight, ceil(rect.height) + Metrics.textInset.height * 2))
    }
}

final class CopyUpAspectFillImageView: NSView {
    var image: NSImage? {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let image, image.size.width > 0, image.size.height > 0 else { return }

        let imageHeight = bounds.width * image.size.height / image.size.width
        let drawRect = NSRect(
            x: 0,
            y: (bounds.height - imageHeight) / 2,
            width: bounds.width,
            height: imageHeight
        )
        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
    }
}
