//
//  CPYShortcutsPreferenceViewController.swift
//
//  CopyUp
//  GitHub: https://github.com/xiaolinbenben/copyup
//  HP: https://copyup.beisi.tech
//
//  Created by Econa77 on 2016/02/26.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import KeyHolder
import Magnet

class CPYShortcutsPreferenceViewController: NSViewController {

    // MARK: - Properties
    @IBOutlet private weak var historyShortcutRecordView: RecordView!
    @IBOutlet private weak var snippetShortcutRecordView: RecordView!
    @IBOutlet private weak var clearHistoryShortcutRecordView: RecordView!

    // MARK: - Initialize
    override func loadView() {
        super.loadView()
        historyShortcutRecordView.delegate = self
        snippetShortcutRecordView.delegate = self
        clearHistoryShortcutRecordView.delegate = self
        prepareHotKeys()
    }

}

// MARK: - Shortcut
private extension CPYShortcutsPreferenceViewController {
    func prepareHotKeys() {
        historyShortcutRecordView.keyCombo = AppEnvironment.current.hotKeyService.historyKeyCombo
        snippetShortcutRecordView.keyCombo = AppEnvironment.current.hotKeyService.snippetKeyCombo
        clearHistoryShortcutRecordView.keyCombo = AppEnvironment.current.hotKeyService.clearHistoryKeyCombo
    }
}

// MARK: - RecordView Delegate
extension CPYShortcutsPreferenceViewController: RecordViewDelegate {
    func recordViewShouldBeginRecording(_ recordView: RecordView) -> Bool {
        return true
    }

    func recordView(_ recordView: RecordView, canRecordKeyCombo keyCombo: KeyCombo) -> Bool {
        return true
    }

    func recordView(_ recordView: RecordView, didChangeKeyCombo keyCombo: KeyCombo?) {
        switch recordView {
        case historyShortcutRecordView:
            AppEnvironment.current.hotKeyService.change(with: .history, keyCombo: keyCombo)
        case snippetShortcutRecordView:
            AppEnvironment.current.hotKeyService.change(with: .snippet, keyCombo: keyCombo)
        case clearHistoryShortcutRecordView:
            AppEnvironment.current.hotKeyService.changeClearHistoryKeyCombo(keyCombo)
        default: break
        }
    }

    func recordViewDidEndRecording(_ recordView: RecordView) {}
}
