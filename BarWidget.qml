import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons

// Now playing: the album art *is* the bar widget. No glyph, no scrolling
// title — the bar stays a glance, not a marquee. Click opens the panel,
// where the art is bigger and the transport controls live.
//
// Talks to Quickshell.Services.Mpris directly rather than Omarchy's own
// first-party "omarchy.media" service: firstPartyServiceFor() is scoped to
// first-party plugins and kind "bar" (full custom bars) only — an ordinary
// third-party bar-widget never gets a handle to it, first-party BarWidget
// precedent notwithstanding. Confirmed by testing against a live player;
// nothing rendered until this switched to a direct Mpris binding.
BarWidget {
  id: root
  moduleName: "io.github.saikomantisu.playerwidget"

  readonly property var players: Mpris.players ? Mpris.players.values : []

  // "Most recently active" player, preferring one that is currently playing:
  // every player earns a serial the moment it appears or its playing/track
  // state changes, and the pick is the highest serial among playing players,
  // falling back to the highest serial overall so a paused track still shows.
  property var lastActiveAt: ({})
  property int serial: 0

  function hasMetadata(p) { return !!(p && (p.trackTitle || p.trackArtist)) }
  function keyFor(p) { return p ? String(p.dbusName || p.identity || p.desktopEntry || "") : "" }

  function touch(p) {
    var key = keyFor(p)
    if (!key) return
    serial += 1
    var next = {}
    for (var k in lastActiveAt) next[k] = lastActiveAt[k]
    next[key] = serial
    lastActiveAt = next
  }

  readonly property var activePlayer: {
    var bestPlaying = null, bestPlayingOrder = -1
    var bestAny = null, bestAnyOrder = -1
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (!hasMetadata(p)) continue
      var order = lastActiveAt[keyFor(p)] || 0
      if (order > bestAnyOrder) { bestAny = p; bestAnyOrder = order }
      if (p.isPlaying && order > bestPlayingOrder) { bestPlaying = p; bestPlayingOrder = order }
    }
    return bestPlaying || bestAny
  }

  readonly property bool hasMedia: activePlayer !== null
  readonly property bool isPlaying: !!(activePlayer && activePlayer.isPlaying)
  readonly property string artUrl: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""
  readonly property real thumbSize: Math.max(Style.space(18), root.barSize - Style.space(6))

  property bool panelOpen: false
  function close() { panelOpen = false }

  // A player can vanish (app closed) while the panel is open — nothing left
  // to control, so the popup would otherwise hang around showing stale art.
  onHasMediaChanged: if (!hasMedia) panelOpen = false

  onPlayersChanged: {
    for (var i = 0; i < players.length; i++) touch(players[i])
  }

  Instantiator {
    model: root.players
    delegate: Connections {
      required property var modelData
      target: modelData
      function onIsPlayingChanged() { root.touch(modelData) }
      function onTrackTitleChanged() { root.touch(modelData) }
    }
  }

  function runAction(action) {
    var p = root.activePlayer
    if (!p) return
    if (action === "previous") { if (p.canGoPrevious) p.previous() }
    else if (action === "next") { if (p.canGoNext) p.next() }
    else if (action === "playPause") {
      if (p.isPlaying && p.canPause) p.pause()
      else if (!p.isPlaying && p.canPlay) p.play()
      else if (p.canTogglePlaying) p.togglePlaying()
    }
  }

  visible: hasMedia
  implicitWidth: hasMedia ? thumbSize : 0
  implicitHeight: barSize

  BorderSurface {
    id: thumb
    anchors.centerIn: parent
    width: root.thumbSize
    height: root.thumbSize
    radius: Style.cornerRadius > 0 ? Style.cornerRadius : width / 4
    color: Style.normalFillFor(root.bar ? root.bar.barForeground : Color.foreground, Color.accent)
    borderSpec: Border.controlSpec(root.isPlaying ? "selected" : "normal",
      root.bar ? root.bar.barForeground : Color.foreground, Color.accent)

    Behavior on color { ColorAnimation { duration: 160 } }

    Image {
      anchors.fill: parent
      anchors.margins: Style.space(2)
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      source: root.artUrl
      visible: source !== "" && status === Image.Ready
    }

    Text {
      anchors.centerIn: parent
      visible: root.artUrl === ""
      textFormat: Text.PlainText
      text: "󰝚"
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.title
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.hasMedia ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (root.hasMedia) root.panelOpen = !root.panelOpen
    onEntered: if (root.bar) root.bar.showTooltip(root, root.hasMedia
      ? (root.title + (root.artist ? " — " + root.artist : "")) : "")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.panelOpen
    contentWidth: popup.fittedContentWidth(Style.space(220))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(12)

      BorderSurface {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Style.space(132)
        height: Style.space(132)
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : width / 6
        color: Style.normalFillFor(root.bar.foreground, Color.accent)
        borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

        Image {
          anchors.fill: parent
          anchors.margins: Style.space(3)
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          source: root.artUrl
          visible: source !== "" && status === Image.Ready
        }

        Text {
          anchors.centerIn: parent
          visible: root.artUrl === ""
          textFormat: Text.PlainText
          text: "󰝚"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.displayLarge
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(2)

        Text {
          textFormat: Text.PlainText
          text: root.title
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          width: parent.width
        }

        Text {
          textFormat: Text.PlainText
          visible: text !== ""
          text: root.artist
          color: Qt.darker(root.bar.foreground, 1.3)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          width: parent.width
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Button {
          iconText: "󰒮"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.runAction("previous")
        }

        Button {
          iconText: root.isPlaying ? "󰏤" : "󰐊"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.runAction("playPause")
        }

        Button {
          iconText: "󰒭"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.runAction("next")
        }
      }
    }
  }
}
