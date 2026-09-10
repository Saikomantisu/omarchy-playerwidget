import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons

// Now playing: the album art is the bar widget, with a short elided slice
// of the title alongside it — no scrolling marquee, just enough to glance
// at without opening the panel. Click opens the panel, where the art is
// bigger, the title has room to breathe, and the transport controls live.
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
  readonly property real titleWidth: Style.space(72)
  // Right-click toggles the title slice off, for anyone who'd rather the
  // bar widget stay just the album-art thumbnail.
  property bool showTitle: true

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

  // Album art tile. The image is masked to the surface radius rather than
  // just parked inside it: a plain Image paints square corners straight over
  // a rounded BorderSurface, which is what made the bar thumbnail look boxy.
  component AlbumArt: BorderSurface {
    id: surface

    property string artSource: ""
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family
    property real glyphSize: Style.font.title
    property real inset: Style.space(3)
    // Used when the theme leaves rounding at 0 — art still reads as a tile.
    property real fallbackRadius: width / 6

    radius: Style.cornerRadius > 0 ? Style.cornerRadius : fallbackRadius
    color: Style.normalFillFor(surface.foreground, Color.accent)

    Item {
      id: artClip
      anchors.fill: parent
      anchors.margins: surface.inset
      visible: art.status === Image.Ready
      layer.enabled: true
      layer.smooth: true
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: artMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.1
      }

      Image {
        id: art
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        source: surface.artSource
      }
    }

    Rectangle {
      id: artMask
      anchors.fill: artClip
      radius: Math.max(0, surface.radius - surface.inset)
      color: "black"
      visible: false
      layer.enabled: true
      layer.smooth: true
    }

    Text {
      anchors.centerIn: parent
      visible: !artClip.visible
      textFormat: Text.PlainText
      text: "󰝚"
      color: surface.foreground
      font.family: surface.fontFamily
      font.pixelSize: surface.glyphSize
    }
  }

  visible: hasMedia
  implicitWidth: hasMedia ? thumbSize + (title !== "" && showTitle ? Style.space(6) + titleWidth : 0) : 0
  implicitHeight: barSize

  AlbumArt {
    id: thumb
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    width: root.thumbSize
    height: root.thumbSize
    inset: 0
    fallbackRadius: width / 4
    artSource: root.artUrl
    foreground: root.bar ? root.bar.barForeground : Color.foreground
    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
    glyphSize: Style.font.title
    borderSpec: Border.controlSpec(root.isPlaying ? "selected" : "normal",
      root.bar ? root.bar.barForeground : Color.foreground, Color.accent)

    Behavior on color { ColorAnimation { duration: 160 } }
  }

  Text {
    id: titleLabel
    visible: root.title !== "" && root.showTitle
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: thumb.right
    anchors.leftMargin: Style.space(6)
    textFormat: Text.PlainText
    text: root.title
    color: root.bar ? root.bar.barForeground : Color.foreground
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
    width: visible ? root.titleWidth : 0
  }

  // Left click opens the panel, but is held for one interval to see whether
  // a second click turns it into a double-click (pause) instead — otherwise
  // a double-click's two onClicked deliveries would flash the panel open
  // and shut before onDoubleClicked ever fires.
  Timer {
    id: singleClickTimer
    interval: 250
    onTriggered: root.panelOpen = !root.panelOpen
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: root.hasMedia ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: (mouse) => {
      if (!root.hasMedia) return
      if (mouse.button === Qt.RightButton) root.showTitle = !root.showTitle
      else singleClickTimer.restart()
    }
    onDoubleClicked: (mouse) => {
      if (!root.hasMedia || mouse.button !== Qt.LeftButton) return
      singleClickTimer.stop()
      var p = root.activePlayer
      if (p && p.canPause) p.pause()
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.hasMedia
      ? (root.title + (root.artist ? " — " + root.artist : "")) : "")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // Panel layout: art on the left, a centered text + transport stack on the
  // right, and a small media glyph tucked into the card's top-right corner.
  // Wide-and-short rather than tall — the title gets room to breathe on one
  // line instead of wrapping under a big square of art.
  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.panelOpen
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(layout.implicitHeight)

    readonly property real artSize: Style.space(96)
    // Keeps a long title from eliding into the corner media glyph.
    readonly property real glyphReserve: Style.space(18)

    Item {
      anchors.fill: parent

      Row {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(14)

        AlbumArt {
          id: art
          anchors.verticalCenter: parent.verticalCenter
          width: popup.artSize
          height: popup.artSize
          fallbackRadius: width / 8
          artSource: root.artUrl
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          glyphSize: Style.font.display
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)
        }

        Column {
          id: details
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(0, layout.width - art.width - layout.spacing - popup.glyphReserve)
          spacing: Style.space(12)

          Column {
            width: parent.width
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: root.title
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              visible: text !== ""
              text: root.artist
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(14)

            Button {
              iconText: "󰒮"
              foreground: root.bar.foreground
              iconSize: Style.font.display
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              enabled: root.activePlayer && root.activePlayer.canGoPrevious
              opacity: enabled ? 1.0 : 0.4
              onClicked: root.runAction("previous")
            }

            Button {
              iconText: root.isPlaying ? "󰏤" : "󰐊"
              foreground: root.bar.foreground
              iconSize: Style.font.displayLarge
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
              opacity: enabled ? 1.0 : 0.4
              onClicked: root.runAction("playPause")
            }

            Button {
              iconText: "󰒭"
              foreground: root.bar.foreground
              iconSize: Style.font.display
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              enabled: root.activePlayer && root.activePlayer.canGoNext
              opacity: enabled ? 1.0 : 0.4
              onClicked: root.runAction("next")
            }
          }
        }
      }

      Text {
        anchors.top: parent.top
        anchors.right: parent.right
        textFormat: Text.PlainText
        text: "󰎇"
        color: root.bar.foreground
        opacity: 0.65
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.icon
      }
    }
  }
}
