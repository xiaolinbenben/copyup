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
            return max(360, min(screenWidth - 80, 520))
        }

        static let headerHeight: CGFloat = 52
        static let inset: CGFloat = 18
        static let rowGap: CGFloat = 10
        static let contentTopInset: CGFloat = 0
        static let contentBottomInset: CGFloat = 18

        static var maxListHeight: CGFloat {
            guard let visibleFrame = screen?.visibleFrame else { return 628 }
            return max(220, min(760, visibleFrame.height - headerHeight - 72))
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
    private var hoverTrackingArea: NSTrackingArea?
    private weak var hoveredRow: CopyUpMenuRowView?

    private var tab: CopyUpMenuTab
    private var historyEntries: [CopyUpMenuEntry]
    private var favoriteEntries: [CopyUpMenuEntry]
    private let showsClearHistoryButton: Bool
    private let usesNumericShortcuts: Bool
    private let numericShortcutsStartAtZero: Bool
    private let callbacks: CopyUpMenuCallbacks
    private let listViewportHeight: CGFloat
    private var contentHeight: CGFloat = 0
    private var scrollsToTopOnNextLayout = false

    init(
        tab: CopyUpMenuTab,
        historyEntries: [CopyUpMenuEntry],
        favoriteEntries: [CopyUpMenuEntry],
        showsClearHistoryButton: Bool,
        usesNumericShortcuts: Bool,
        numericShortcutsStartAtZero: Bool,
        callbacks: CopyUpMenuCallbacks
    ) {
        self.tab = tab
        self.historyEntries = historyEntries
        self.favoriteEntries = favoriteEntries
        self.showsClearHistoryButton = showsClearHistoryButton
        self.usesNumericShortcuts = usesNumericShortcuts
        self.numericShortcutsStartAtZero = numericShortcutsStartAtZero
        self.callbacks = callbacks
        self.listViewportHeight = Metrics.maxListHeight
        super.init(frame: NSRect(x: 0, y: 0, width: Metrics.width, height: Metrics.headerHeight + listViewportHeight))
        setup()
        reloadRows()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            setHoveredRow(nil)
        } else {
            window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard !handleNumericShortcut(event) else { return }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        handleNumericShortcut(event) || super.performKeyEquivalent(with: event)
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

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let next = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(next)
        hoverTrackingArea = next
    }

    override func mouseMoved(with event: NSEvent) {
        updateHoveredRow(at: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard !bounds.contains(point) else {
            updateHoveredRow(at: event.locationInWindow)
            return
        }
        setHoveredRow(nil)
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
            button("square.and.pencil", String(localized: "Edit Snippets"), #selector(editFavorites)),
            button("gearshape", String(localized: "Preferences"), #selector(showPreferences)),
            button("power", String(localized: "Quit CopyUp"), #selector(quit))
        ]
        if showsClearHistoryButton {
            headerButtons.insert(button("trash", String(localized: "Clear History"), #selector(clearHistory)), at: 0)
        }
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
        setHoveredRow(nil)
        rows.forEach { $0.removeFromSuperview() }
        rows.removeAll()
        emptyLabel.removeFromSuperview()

        let rowWidth = frame.width - Metrics.inset * 2
        rows = activeEntries.enumerated().map { index, entry in
            CopyUpMenuRowView(
                width: rowWidth,
                entry: entry,
                numericShortcut: numericShortcutLabel(for: index),
                callbacks: callbacks
            )
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

        frame.size = NSSize(width: Metrics.width, height: Metrics.headerHeight + listViewportHeight)
        contentView.frame = NSRect(x: 0, y: 0, width: Metrics.width, height: documentHeight)
        scrollsToTopOnNextLayout = true
        needsLayout = true
        needsDisplay = true
        contentView.needsDisplay = true
        layoutSubtreeIfNeeded()
    }

    var documentHeight: CGFloat {
        max(contentHeight, listViewportHeight)
    }

    func layoutRows() {
        contentView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: documentHeight)
        guard !rows.isEmpty else {
            emptyLabel.frame = NSRect(x: Metrics.inset, y: documentHeight - 86, width: bounds.width - Metrics.inset * 2, height: 36)
            return
        }

        var rowY = documentHeight - Metrics.contentTopInset
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
        let topY = max(0, documentHeight - visibleHeight)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: topY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func handleNumericShortcut(_ event: NSEvent) -> Bool {
        guard usesNumericShortcuts,
              let index = numericShortcutIndex(for: event),
              activeEntries.indices.contains(index) else {
            return false
        }
        callbacks.selectEntry(activeEntries[index].kind)
        return true
    }

    func numericShortcutLabel(for index: Int) -> String? {
        guard let key = numericShortcutKey(for: index) else { return nil }
        return "⌘\(key)"
    }

    func numericShortcutKey(for index: Int) -> String? {
        guard usesNumericShortcuts && index >= 0 && index < 10 else { return nil }
        let key = numericShortcutsStartAtZero ? index : index + 1
        return "\(key == 10 ? 0 : key)"
    }

    func numericShortcutIndex(for event: NSEvent) -> Int? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command),
              !flags.contains(.shift),
              !flags.contains(.control),
              !flags.contains(.option),
              let character = event.charactersIgnoringModifiers?.first,
              let number = Int(String(character)),
              number >= 0 && number <= 9 else {
            return nil
        }
        return numericShortcutsStartAtZero ? number : (number == 0 ? 9 : number - 1)
    }

    func updateHoveredRow(at windowLocation: NSPoint) {
        let point = contentView.convert(windowLocation, from: nil)
        setHoveredRow(rows.first { $0.frame.contains(point) })
    }

    func setHoveredRow(_ row: CopyUpMenuRowView?) {
        guard hoveredRow !== row else { return }
        hoveredRow?.setHover(false)
        hoveredRow = row
        hoveredRow?.setHover(true)
    }

    @objc func clearHistory() { callbacks.clearHistory() }
    @objc func editFavorites() { callbacks.editFavorites() }
    @objc func showPreferences() { callbacks.showPreferences() }
    @objc func quit() { callbacks.quit() }
}

final class CopyUpMenuTabControl: NSView {
    var selectedTab: CopyUpMenuTab = .history {
        didSet { needsDisplay = true }
    }
    var onSelect: ((CopyUpMenuTab) -> Void)?

    private let historyTitle = String(localized: "History")
    private let favoritesTitle = String(localized: "Snippet")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return }
        select(point.x < bounds.midX ? .history : .favorites)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let segmentWidth = bounds.width / 2
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]

        let labelHeight = bounds.height - 4
        historyTitle.draw(in: NSRect(x: 0, y: 4, width: segmentWidth, height: labelHeight), withAttributes: attributes)
        favoritesTitle.draw(
            in: NSRect(x: segmentWidth, y: 4, width: segmentWidth, height: labelHeight),
            withAttributes: attributes
        )

        let selectedMidX = selectedTab == .history ? segmentWidth / 2 : segmentWidth + segmentWidth / 2
        let underlineRect = NSRect(x: selectedMidX - 10, y: 0, width: 20, height: 2)
        NSColor.labelColor.setFill()
        NSBezierPath(roundedRect: underlineRect, xRadius: 1, yRadius: 1).fill()
    }
}

private extension CopyUpMenuTabControl {
    func select(_ tab: CopyUpMenuTab) {
        guard selectedTab != tab else { return }
        selectedTab = tab
        onSelect?(tab)
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
        static let pasteButtonSize = NSSize(width: 78, height: 30)
    }

    let preferredHeight: CGFloat

    private let entry: CopyUpMenuEntry
    private let callbacks: CopyUpMenuCallbacks
    private let numericShortcut: String?
    private let textField = NSTextField(labelWithString: "")
    private let imageView = CopyUpAspectFillImageView()
    private let pasteButton = NSButton()
    private let favoriteButton = NSButton()
    private let deleteButton = NSButton()
    private var isHovering: Bool?
    private var favorited: Bool

    init(width: CGFloat, entry: CopyUpMenuEntry, numericShortcut: String?, callbacks: CopyUpMenuCallbacks) {
        self.entry = entry
        self.callbacks = callbacks
        self.numericShortcut = numericShortcut
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

        let buttonY = bounds.height - Metrics.buttonSize.height - 12
        var buttonRight = bounds.width - 14

        deleteButton.frame = NSRect(
            x: buttonRight - Metrics.buttonSize.width,
            y: buttonY,
            width: Metrics.buttonSize.width,
            height: Metrics.buttonSize.height
        )
        buttonRight = deleteButton.frame.minX - 8

        if entry.canFavorite {
            favoriteButton.frame = NSRect(
                x: buttonRight - Metrics.buttonSize.width,
                y: buttonY,
                width: Metrics.buttonSize.width,
                height: Metrics.buttonSize.height
            )
            buttonRight = favoriteButton.frame.minX - 8
        }

        if numericShortcut != nil {
            pasteButton.frame = NSRect(
                x: buttonRight - Metrics.pasteButtonSize.width,
                y: buttonY,
                width: Metrics.pasteButtonSize.width,
                height: Metrics.pasteButtonSize.height
            )
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { setHover(false) }
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
        configurePasteButton()
        addSubview(pasteButton)
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

    func configurePasteButton() {
        let shortcut = numericShortcut ?? ""
        pasteButton.title = "\(String(localized: "Paste")) \(shortcut)"
        pasteButton.isBordered = false
        pasteButton.font = .systemFont(ofSize: 13, weight: .semibold)
        pasteButton.alignment = .center
        pasteButton.target = self
        pasteButton.action = #selector(pasteEntry)
        pasteButton.wantsLayer = true
        pasteButton.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor
        pasteButton.layer?.cornerRadius = 8
        pasteButton.toolTip = "\(String(localized: "Paste")) \(shortcut)"
    }

    func setHover(_ hovering: Bool) {
        guard isHovering != hovering else { return }
        isHovering = hovering
        layer?.backgroundColor = entry.image == nil && hovering
            ? NSColor.controlAccentColor.withAlphaComponent(0.14).cgColor
            : NSColor.clear.cgColor
        pasteButton.isHidden = !hovering || numericShortcut == nil
        deleteButton.isHidden = !hovering
        favoriteButton.isHidden = !hovering || !entry.canFavorite
    }

    @objc func pasteEntry() {
        callbacks.selectEntry(entry.kind)
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
