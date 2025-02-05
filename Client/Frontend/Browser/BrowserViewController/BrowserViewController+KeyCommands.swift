// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Shared
import UIKit

// Naming functions: use the suffix 'KeyCommand' for an additional level of namespacing (bug 1415830)
extension BrowserViewController {
    fileprivate typealias shortcuts = String.KeyboardShortcuts

    @objc private func openSettingsKeyCommand() {
        openSettings()
    }

    @objc private func showHistoryKeyCommand() {
        showPanel(.history)
    }

    @objc private func showDownloadsKeyCommand() {
        showPanel(.downloads)
    }

    @objc private func showBookmarksKeyCommand() {
        showPanel(.bookmarks)
    }

    private func showPanel(_ panel: LibraryPanelType) {
        guard let libraryViewController = self.libraryViewController else {
            showLibrary(panel: panel)
            return
        }

        libraryViewController.selectedPanel = panel
    }

    @objc private func openClearHistoryPanelKeyCommand() {
        guard let libraryViewController = self.libraryViewController else {
            let clearHistoryHelper = ClearHistoryHelper(profile: profile)
            clearHistoryHelper.showClearRecentHistory(onViewController: self, didComplete: {})
            return
        }

        libraryViewController.selectedPanel = .history
        NotificationCenter.default.post(name: .OpenClearRecentHistory, object: nil)
    }

    @objc private func addBookmarkKeyCommand() {
        if let tab = tabManager.selectedTab, firefoxHomeViewController == nil {
            guard let url = tab.canonicalURL?.displayURL else { return }
            addBookmark(url: url.absoluteString, title: tab.title, favicon: tab.displayFavicon)
        }
    }

    @objc private func reloadTabKeyCommand() {
        TelemetryWrapper.recordEvent(category: .action, method: .press, object: .keyCommand, extras: ["action": "reload"])
        if let tab = tabManager.selectedTab, firefoxHomeViewController == nil {
            tab.reload()
        }
    }

    @objc private func goBackKeyCommand() {
        TelemetryWrapper.recordEvent(category: .action, method: .press, object: .keyCommand, extras: ["action": "go-back"])
        if let tab = tabManager.selectedTab, tab.canGoBack, firefoxHomeViewController == nil {
            tab.goBack()
        }
    }

    @objc private func goForwardKeyCommand() {
        TelemetryWrapper.recordEvent(category: .action, method: .press, object: .keyCommand, extras: ["action": "go-forward"])
        if let tab = tabManager.selectedTab, tab.canGoForward {
            tab.goForward()
        }
    }

    @objc private func findInPageKeyCommand() {
        TelemetryWrapper.recordEvent(category: .action, method: .press, object: .keyCommand, extras: ["action": "find-in-page"])
        findInPage(withText: "")
    }

    @objc private func findInPageAgainKeyCommand() {
        findInPage(withText: FindInPageBar.retrieveSavedText ?? "")
    }

    private func findInPage(withText text: String) {
        if let tab = tabManager.selectedTab, firefoxHomeViewController == nil {
            self.tab(tab, didSelectFindInPageForSelection: text)
        }
    }

    @objc private func selectLocationBarKeyCommand() {
        TelemetryWrapper.recordEvent(category: .action, method: .press, object: .keyCommand, extras: ["action": "select-location-bar"])
        scrollController.showToolbars(animated: true)
        urlBar.tabLocationViewDidTapLocation(urlBar.locationView)
    }

    @objc private func newTabKeyCommand() {
        TelemetryWrapper.recordEvent(category: .action, method: .press, object: .keyCommand, extras: ["action": "new-tab"])
        let isPrivate = tabManager.selectedTab?.isPrivate ?? false
        openBlankNewTab(focusLocationField: true, isPrivate: isPrivate)
    }

    @objc private func newPrivateTabKeyCommand() {
        // NOTE: We cannot and should not distinguish between "new-tab" and "new-private-tab"
        // when recording telemetry for key commands.
        TelemetryWrapper.recordEvent(category: .action, method: .press, object: .keyCommand, extras: ["action": "new-tab"])
        openBlankNewTab(focusLocationField: true, isPrivate: true)
    }

    @objc private func closeTabKeyCommand() {
        TelemetryWrapper.recordEvent(category: .action, method: .press, object: .keyCommand, extras: ["action": "close-tab"])
        guard let currentTab = tabManager.selectedTab else {
            return
        }
        tabManager.removeTab(currentTab)
    }

    @objc private func nextTabKeyCommand() {
        TelemetryWrapper.recordEvent(category: .action, method: .press, object: .keyCommand, extras: ["action": "next-tab"])
        guard let currentTab = tabManager.selectedTab else {
            return
        }

        let tabs = currentTab.isPrivate ? tabManager.privateTabs : tabManager.normalTabs
        if let index = tabs.firstIndex(of: currentTab), index + 1 < tabs.count {
            tabManager.selectTab(tabs[index + 1])
        } else if let firstTab = tabs.first {
            tabManager.selectTab(firstTab)
        }
    }

    @objc private func previousTabKeyCommand() {
        TelemetryWrapper.recordEvent(category: .action, method: .press, object: .keyCommand, extras: ["action": "previous-tab"])
        guard let currentTab = tabManager.selectedTab else {
            return
        }

        let tabs = currentTab.isPrivate ? tabManager.privateTabs : tabManager.normalTabs
        if let index = tabs.firstIndex(of: currentTab), index - 1 < tabs.count && index != 0 {
            tabManager.selectTab(tabs[index - 1])
        } else if let lastTab = tabs.last {
            tabManager.selectTab(lastTab)
        }
    }

    @objc private func showTabTrayKeyCommand() {
        TelemetryWrapper.recordEvent(category: .action, method: .press, object: .keyCommand, extras: ["action": "show-tab-tray"])
        showTabTray()
    }

    @objc private func moveURLCompletionKeyCommand(sender: UIKeyCommand) {
        guard let searchController = self.searchController else {
            return
        }

        searchController.handleKeyCommands(sender: sender)
    }

    override var keyCommands: [UIKeyCommand]? {
        let searchLocationCommands = [
            // Navigate the suggestions
            UIKeyCommand(action: #selector(moveURLCompletionKeyCommand(sender:)), input: UIKeyCommand.inputDownArrow),
            UIKeyCommand(action: #selector(moveURLCompletionKeyCommand(sender:)), input: UIKeyCommand.inputUpArrow),
        ]

        let overridesTextEditing = [
            UIKeyCommand(action: #selector(nextTabKeyCommand), input: UIKeyCommand.inputRightArrow, modifierFlags: [.command, .shift]),
            UIKeyCommand(action: #selector(previousTabKeyCommand), input: UIKeyCommand.inputLeftArrow, modifierFlags: [.command, .shift]),
            UIKeyCommand(action: #selector(goBackKeyCommand), input: UIKeyCommand.inputLeftArrow, modifierFlags: .command),
            UIKeyCommand(action: #selector(goForwardKeyCommand), input: UIKeyCommand.inputRightArrow, modifierFlags: .command),
        ]

        // In iOS 15+, certain keys events are delivered to the text input or focus systems first, unless specified otherwise
        if #available(iOS 15, *) {
            searchLocationCommands.forEach { $0.wantsPriorityOverSystemBehavior = true }
            overridesTextEditing.forEach { $0.wantsPriorityOverSystemBehavior = true }
        }

        let commands = [
            // Settings
            UIKeyCommand(action: #selector(openSettingsKeyCommand), input: ",", modifierFlags: .command, discoverabilityTitle: shortcuts.Settings),

            // File
            UIKeyCommand(action: #selector(newTabKeyCommand), input: "t", modifierFlags: .command, discoverabilityTitle: shortcuts.NewTab),
            UIKeyCommand(action: #selector(selectLocationBarKeyCommand), input: "l", modifierFlags: .command, discoverabilityTitle: shortcuts.SelectLocationBar),
            UIKeyCommand(action: #selector(newPrivateTabKeyCommand), input: "p", modifierFlags: [.command, .shift], discoverabilityTitle: shortcuts.NewPrivateTab),
            UIKeyCommand(action: #selector(closeTabKeyCommand), input: "w", modifierFlags: .command, discoverabilityTitle: shortcuts.CloseCurrentTab),

            // Edit
            UIKeyCommand(action: #selector(findInPageKeyCommand), input: "f", modifierFlags: .command, discoverabilityTitle: shortcuts.Find),
            UIKeyCommand(action: #selector(findInPageAgainKeyCommand), input: "g", modifierFlags: .command, discoverabilityTitle: shortcuts.FindAgain),

            // View
            // TODO: Zoom in - Command + +
            // TODO: Zoom out - Command + -
            // TODO: Actual size - Command + 0
            UIKeyCommand(action: #selector(reloadTabKeyCommand), input: "r", modifierFlags: .command, discoverabilityTitle: shortcuts.ReloadPage),
            
            // History
            UIKeyCommand(action: #selector(goBackKeyCommand), input: "[", modifierFlags: .command, discoverabilityTitle: shortcuts.Back),
            UIKeyCommand(action: #selector(openClearHistoryPanelKeyCommand), input: "\u{8}", modifierFlags: [.shift, .command], discoverabilityTitle: shortcuts.ClearRecentHistory),
            UIKeyCommand(action: #selector(goForwardKeyCommand), input: "]", modifierFlags: .command, discoverabilityTitle: shortcuts.Forward),
            UIKeyCommand(action: #selector(showHistoryKeyCommand), input: "y", modifierFlags: .command, discoverabilityTitle: shortcuts.ShowHistory),
            
            // Bookmarks
            UIKeyCommand(action: #selector(showBookmarksKeyCommand), input: "o", modifierFlags: [.shift, .command], discoverabilityTitle: shortcuts.ShowBookmarks),
            UIKeyCommand(action: #selector(addBookmarkKeyCommand), input: "d", modifierFlags: .command, discoverabilityTitle: shortcuts.AddBookmark),

            // Tools
            UIKeyCommand(action: #selector(showDownloadsKeyCommand), input: "j", modifierFlags: .command, discoverabilityTitle: shortcuts.ShowDownloads),

            // Window
            // TODO: Show tab # 1-9 - Command + 1-9
            UIKeyCommand(action: #selector(nextTabKeyCommand), input: "\t", modifierFlags: .control, discoverabilityTitle: shortcuts.ShowNextTab),
            UIKeyCommand(action: #selector(previousTabKeyCommand), input: "\t", modifierFlags: [.control, .shift],  discoverabilityTitle: shortcuts.ShowPreviousTab),
            UIKeyCommand(action: #selector(showTabTrayKeyCommand), input: "\t", modifierFlags: [.command, .alternate], discoverabilityTitle: shortcuts.ShowTabTray),
            UIKeyCommand(input: "\\", modifierFlags: [.command, .shift], action: #selector(showTabTrayKeyCommand)), // Safari on macOS
        ]

        let isEditingText = tabManager.selectedTab?.isEditing ?? false

        if urlBar.inOverlayMode {
            return commands + searchLocationCommands
        } else if !isEditingText {
            return commands + overridesTextEditing
        }
        return commands
    }
}
