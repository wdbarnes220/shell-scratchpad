pragma ComponentBehavior: Bound

// ShellScratchpad — a bar widget that opens a command runner popup.
//
// Click the terminal icon in the bar to open the popup. Type any shell command
// and press Enter to run it. Output appears inline. Use ↑/↓ to cycle
// through the command history. Press Escape to close.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "wdb.shell-scratchpad"

  // ── State ──────────────────────────────────────────────────────────────
  property bool panelOpen: false
  property string commandText: ""
  property string outputText: ""
  property bool running: false
  property bool hadError: false

  // Command history – most-recent-first, up to historyLimit entries
  property int historyLimit: 50
  property var commandHistory: []
  property int historyIndex: -1   // -1 = editing fresh command
  property string pendingCommand: ""

  // ── Sizing ─────────────────────────────────────────────────────────────
  implicitWidth: iconBtn.implicitWidth
  implicitHeight: iconBtn.implicitHeight

  // ── Bar icon button ────────────────────────────────────────────────────
  BarIconButton {
    id: iconBtn
    // The bar host sizes this widget from implicitWidth/implicitHeight;
    // anchors.fill alone does not give the root a nonzero implicit size.
    width: implicitWidth
    height: implicitHeight
    bar: root.bar
    // Nerd Font glyphs in the weather font's private-use area are not
    // guaranteed to exist in the user's selected bar font. Use a plain
    // terminal prompt glyph so the widget remains visible with any font.
    text: root.running ? "…" : ">_"
    active: root.panelOpen
    tooltipText: root.running ? "Running\u2026" : "Shell Scratchpad"
    onPressed: root.togglePanel()
  }

  // ── Popup panel ────────────────────────────────────────────────────────
  PopupCard {
    id: popup
    anchorItem: iconBtn
    bar: root.bar
    open: root.panelOpen
    contentWidth: Style.space(520)
    contentHeight: Math.min(
      panelContent.implicitHeight,
      Style.space(480)
    )
    onOpenChanged: if (!open) root.panelOpen = false

    Item {
      id: panelContent
      width: popup.contentWidth
      implicitHeight: innerCol.implicitHeight + Style.spacing.panelPadding * 2

      Column {
        id: innerCol
        anchors.top: parent.top
        anchors.topMargin: Style.spacing.panelPadding
        anchors.left: parent.left
        anchors.leftMargin: Style.spacing.panelPadding
        anchors.right: parent.right
        anchors.rightMargin: Style.spacing.panelPadding
        spacing: Style.spacing.md

        // ── Title ──────────────────────────────────────────────────────
        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: "Shell Scratchpad"
          color: Commons.Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          opacity: 0.9
        }

        // ── Command input row ──────────────────────────────────────────
        Row {
          width: parent.width
          spacing: Style.spacing.sm

          Text {
            id: prompt
            textFormat: Text.PlainText
            text: "$"
            color: Commons.Color.accent
            font.family: Style.font.monoFamily !== undefined ? Style.font.monoFamily : Style.font.family
            font.pixelSize: Style.font.body
            anchors.verticalCenter: parent.verticalCenter
          }

          Rectangle {
            width: parent.width - prompt.width - runButton.width - parent.spacing * 2
            height: Math.max(Style.space(30), Style.font.body + Style.spacing.inputPaddingY * 2)
            color: Qt.rgba(0, 0, 0, 0.2)
            radius: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter

            TextInput {
              id: cmdInput
              anchors.fill: parent
              anchors.leftMargin: Style.spacing.controlPaddingX
              anchors.rightMargin: Style.spacing.controlPaddingX
              anchors.verticalCenter: parent.verticalCenter
              text: root.commandText
              color: Commons.Color.foreground
              font.family: Style.font.monoFamily !== undefined ? Style.font.monoFamily : Style.font.family
              font.pixelSize: Style.font.body
              selectByMouse: true
              focus: root.panelOpen

              onTextChanged: root.commandText = text

              Keys.onReturnPressed: root.runCommand()
              Keys.onEnterPressed: root.runCommand()
              Keys.onEscapePressed: root.panelOpen = false

              Keys.onUpPressed: {
                if (root.commandHistory.length === 0) return
                if (root.historyIndex === -1) root.pendingCommand = root.commandText
                var next = root.historyIndex + 1
                if (next < root.commandHistory.length) {
                  root.historyIndex = next
                  root.commandText = root.commandHistory[next]
                  cmdInput.text = root.commandText
                  cmdInput.cursorPosition = cmdInput.text.length
                }
              }

              Keys.onDownPressed: {
                if (root.historyIndex <= 0) {
                  root.historyIndex = -1
                  root.commandText = root.pendingCommand
                  cmdInput.text = root.commandText
                  cmdInput.cursorPosition = cmdInput.text.length
                  return
                }
                root.historyIndex -= 1
                root.commandText = root.commandHistory[root.historyIndex]
                cmdInput.text = root.commandText
                cmdInput.cursorPosition = cmdInput.text.length
              }
            }

            Text {
              visible: cmdInput.text === "" && !cmdInput.activeFocus
              textFormat: Text.PlainText
              text: "type a command\u2026"
              color: Commons.Color.foreground
              opacity: 0.3
              font.family: cmdInput.font.family
              font.pixelSize: cmdInput.font.pixelSize
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: Style.spacing.controlPaddingX
            }
          }

          Rectangle {
            id: runButton
            width: runLabel.implicitWidth + Style.spacing.controlPaddingX * 2
            height: Math.max(Style.space(30), Style.font.body + Style.spacing.inputPaddingY * 2)
            anchors.verticalCenter: parent.verticalCenter
            color: runArea.pressed
              ? Qt.darker(Commons.Color.accent, 1.2)
              : (runArea.containsMouse ? Commons.Color.accent : Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.8))
            radius: Style.space(4)
            opacity: (root.running || root.commandText.trim() === "") ? 0.4 : 1.0

            Text {
              id: runLabel
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: root.running ? "\u2026" : "Run"
              color: Commons.Color.background
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            MouseArea {
              id: runArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              enabled: !root.running && root.commandText.trim() !== ""
              onClicked: root.runCommand()
            }
          }
        }

        // ── Output area ────────────────────────────────────────────────
        Rectangle {
          visible: root.outputText !== ""
          width: parent.width
          height: Math.min(outputLabel.implicitHeight + Style.spacing.sm * 2, Style.space(280))
          color: Qt.rgba(0, 0, 0, 0.25)
          radius: Style.space(4)

          Rectangle {
            visible: root.hadError
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(1, 0.2, 0.2, 0.08)
          }

          Flickable {
            anchors.fill: parent
            anchors.margins: Style.spacing.sm
            contentHeight: outputLabel.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick

            Text {
              id: outputLabel
              textFormat: Text.PlainText
              width: parent.width
              text: root.outputText
              color: root.hadError
                ? Qt.rgba(1, 0.5, 0.5, 1)
                : Commons.Color.foreground
              font.family: Style.font.monoFamily !== undefined ? Style.font.monoFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WrapAnywhere
              opacity: 0.9
            }
          }
        }
      }
    }
  }

  // ── Process runner ─────────────────────────────────────────────────────
  Process {
    id: proc
    running: false
    property string collected: ""

    stdout: SplitParser {
      onRead: function(data) { proc.collected += data + "\n" }
    }
    stderr: SplitParser {
      onRead: function(data) { proc.collected += data + "\n" }
    }

    onExited: function(exitCode) {
      root.running = false
      root.hadError = exitCode !== 0
      var out = proc.collected.replace(/\n+$/, "")
      root.outputText = out !== "" ? out : (exitCode === 0 ? "(no output)" : "(exited " + exitCode + ")")
      proc.collected = ""
    }
  }

  // ── Functions ──────────────────────────────────────────────────────────
  function togglePanel() {
    if (root.panelOpen) root.panelOpen = false
    else {
      root.historyIndex = -1
      root.panelOpen = true
    }
  }

  function runCommand() {
    var cmd = root.commandText.trim()
    if (cmd === "" || root.running) return

    if (root.commandHistory.length === 0 || root.commandHistory[0] !== cmd) {
      var h = [cmd].concat(root.commandHistory)
      if (h.length > root.historyLimit) h = h.slice(0, root.historyLimit)
      root.commandHistory = h
    }
    root.historyIndex = -1
    root.pendingCommand = ""

    root.outputText = ""
    root.hadError = false
    root.running = true
    proc.collected = ""
    proc.command = ["bash", "-c", "timeout 10 " + cmd + " 2>&1"]
    proc.running = true
  }
}
