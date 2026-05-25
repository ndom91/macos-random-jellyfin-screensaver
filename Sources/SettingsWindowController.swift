import AppKit

final class SettingsWindowController: NSWindowController {
    private let baseURLField = NSTextField()
    private let apiKeyField = NSSecureTextField()
    private let userIDField = NSTextField()
    private let mediaTypeButton = NSPopUpButton()
    private let mutedCheckbox = NSButton(checkboxWithTitle: "Play muted", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 270),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Jellyfin Screensaver Options"
        super.init(window: window)
        buildUI()
        loadSettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        loadSettings()
        super.showWindow(sender)
    }

    private func buildUI() {
        guard let contentView = window?.contentView else {
            return
        }

        baseURLField.placeholderString = "https://watch.example.com"
        userIDField.placeholderString = "93d8622aa94048c59454ae6c12ce54b9"

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        stackView.addArrangedSubview(row(label: "Jellyfin Base URL:", control: baseURLField))
        stackView.addArrangedSubview(row(label: "Jellyfin API Key:", control: apiKeyField))
        stackView.addArrangedSubview(row(label: "Jellyfin User ID:", control: userIDField))

        let userIDHelp = NSTextField(labelWithString: "Use the ID from /Users/{userId}/Items, not a media item ID.")
        userIDHelp.textColor = .secondaryLabelColor
        userIDHelp.font = NSFont.systemFont(ofSize: 11)
        userIDHelp.widthAnchor.constraint(equalToConstant: 398).isActive = true
        stackView.addArrangedSubview(userIDHelp)

        mediaTypeButton.addItems(withTitles: MediaType.allCases.map(\.displayName))
        stackView.addArrangedSubview(row(label: "Media Type:", control: mediaTypeButton))

        mutedCheckbox.target = self
        stackView.addArrangedSubview(mutedCheckbox)

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        buttonRow.addArrangedSubview(spacer)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        buttonRow.addArrangedSubview(cancelButton)
        buttonRow.addArrangedSubview(saveButton)
        stackView.addArrangedSubview(buttonRow)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            buttonRow.widthAnchor.constraint(equalTo: stackView.widthAnchor),
        ])
    }

    private func row(label: String, control: NSControl) -> NSStackView {
        let labelView = NSTextField(labelWithString: label)
        labelView.alignment = .right
        labelView.widthAnchor.constraint(equalToConstant: 130).isActive = true

        control.widthAnchor.constraint(equalToConstant: 260).isActive = true

        let stackView = NSStackView(views: [labelView, control])
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 8
        return stackView
    }

    private func loadSettings() {
        let settings = ScreensaverSettings.load()
        baseURLField.stringValue = settings.baseURL
        apiKeyField.stringValue = settings.apiKey
        userIDField.stringValue = settings.userID
        mutedCheckbox.state = settings.muted ? .on : .off

        let index = MediaType.allCases.firstIndex(of: settings.mediaType) ?? 0
        mediaTypeButton.selectItem(at: index)
    }

    @objc private func save() {
        let selectedMediaType = MediaType.allCases[mediaTypeButton.indexOfSelectedItem]
        ScreensaverSettings(
            baseURL: baseURLField.stringValue,
            apiKey: apiKeyField.stringValue,
            userID: userIDField.stringValue,
            mediaType: selectedMediaType,
            muted: mutedCheckbox.state == .on
        ).save()

        closeSheet()
    }

    @objc private func cancel() {
        closeSheet()
    }

    private func closeSheet() {
        guard let window else {
            return
        }

        if let sheetParent = window.sheetParent {
            sheetParent.endSheet(window)
        } else {
            window.close()
        }
    }
}
