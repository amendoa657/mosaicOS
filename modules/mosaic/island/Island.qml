pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Mosaic OS island: a notch on the top edge with the living mark (Mascot) and
// the app in focus. It grows sideways for quick things (music) and down into a
// card for things with actions (notification, music controls, chat).
// Click depends on the moment: music -> controls, notification -> the
// notification center, nothing -> chat with the mascot (the AI).
Scope {
    id: root

    // ---------- state shared by every screen ----------
    property string card: "" // "" | "notif" | "controls" | "chat"
    property var notif: null
    readonly property bool playing: MprisController.isPlaying
    readonly property var lastAi: Ai.messageIDs.length > 0 ? Ai.messageByID[Ai.messageIDs[Ai.messageIDs.length - 1]] : null
    readonly property bool aiBusy: (root.lastAi?.role === "assistant") && !(root.lastAi?.done ?? true)

    readonly property string focusName: {
        const top = ToplevelManager.activeToplevel;
        if (!top || !top.activated)
            return `Área ${HyprlandData.activeWorkspace?.id ?? 1}`;
        const entry = DesktopEntries.heuristicLookup(top.appId);
        return entry?.name || top.appId || top.title;
    }

    function openCard(name) {
        root.card = root.card === name ? "" : name;
    }
    function clicked() {
        if (root.card !== "")
            root.card = "";
        else if (root.notif)
            GlobalStates.sidebarRightOpen = true;
        else if (root.playing)
            root.card = "controls";
        else
            root.card = "chat";
    }

    Connections {
        target: Notifications
        function onNotify(notification) {
            if (Notifications.silent || root.card === "chat")
                return;
            root.notif = notification;
            root.card = "notif";
            notifTimer.restart();
            root.jumpRequested();
        }
    }
    signal jumpRequested()

    // qs -c mosaic ipc call island <chat|controls|close|poke>
    IpcHandler {
        target: "island"
        function chat(): void { root.openCard("chat"); }
        function controls(): void { root.openCard("controls"); }
        function close(): void { root.card = ""; }
        function poke(): void { root.jumpRequested(); }
    }
    Timer {
        id: notifTimer
        interval: 4500
        onTriggered: {
            if (root.card === "notif")
                root.card = "";
            root.notif = null;
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            WlrLayershell.namespace: "quickshell:island"
            WlrLayershell.layer: WlrLayer.Top
            exclusiveZone: notch.restHeight
            anchors.top: true
            color: "transparent"
            implicitWidth: 760
            implicitHeight: 460
            // Only the notch takes clicks; the rest of the window lets them through
            mask: Region {
                item: notch
            }

            Item {
                id: notch
                readonly property real restHeight: 36
                readonly property real flare: 12 // the concave curves where it meets the edge
                readonly property bool open: root.card !== ""
                readonly property bool wide: root.playing && !open

                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                width: (open ? 420 : wide ? Math.min(restRow.implicitWidth + musicRow.implicitWidth + 40, 520) : restRow.implicitWidth + 32) + flare * 2
                height: open ? cardLoader.implicitHeight + restHeight + 14 : restHeight
                Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                Behavior on height { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

                // ---------- shape: notch body + concave flares ----------
                readonly property color fill: Appearance.colors.colLayer0
                Rectangle {
                    x: notch.flare
                    width: parent.width - notch.flare * 2
                    height: parent.height
                    color: notch.fill
                    topLeftRadius: 0
                    topRightRadius: 0
                    bottomLeftRadius: notch.open ? 24 : 18
                    bottomRightRadius: notch.open ? 24 : 18
                }
                Repeater {
                    model: 2
                    delegate: Canvas {
                        required property int index
                        width: notch.flare
                        height: notch.flare
                        x: index === 0 ? 0 : notch.width - notch.flare
                        property color fill: notch.fill
                        onFillChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            ctx.fillStyle = fill;
                            ctx.beginPath();
                            if (index === 0) {
                                ctx.moveTo(0, 0);
                                ctx.lineTo(width, 0);
                                ctx.lineTo(width, height);
                                ctx.arc(0, height, width, 0, -Math.PI / 2, true);
                            } else {
                                ctx.moveTo(width, 0);
                                ctx.lineTo(0, 0);
                                ctx.lineTo(0, height);
                                ctx.arc(width, height, width, Math.PI, Math.PI * 1.5, false);
                            }
                            ctx.closePath();
                            ctx.fill();
                        }
                    }
                }

                // ---------- rest line: mascot + app in focus (+ music when wide) ----------
                RowLayout {
                    id: topLine
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (notch.restHeight - height) / 2
                    spacing: 14
                    RowLayout {
                        id: restRow
                        spacing: 9
                        Mascot {
                            id: mascot
                            size: 24
                            baseMood: root.aiBusy ? "think" : root.playing ? "dance" : "idle"
                            Connections {
                                target: root
                                function onJumpRequested() { mascot.jump(); }
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                onClicked: mascot.poke()
                            }
                        }
                        StyledText {
                            text: root.focusName
                            font.family: "Space Grotesk"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer0
                            elide: Text.ElideRight
                            Layout.maximumWidth: 220
                        }
                    }
                    RowLayout {
                        id: musicRow
                        visible: notch.wide
                        opacity: notch.wide ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                        spacing: 8
                        ClippingRectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 5
                            color: Appearance.colors.colLayer1
                            Image {
                                anchors.fill: parent
                                source: MprisController.activePlayer?.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(40, 40)
                            }
                        }
                        StyledText {
                            text: MprisController.activePlayer?.trackTitle ?? ""
                            font.family: "Space Grotesk"
                            font.pixelSize: 12
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                            Layout.maximumWidth: 180
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: root.clicked()
                }

                // ---------- card ----------
                Loader {
                    id: cardLoader
                    active: notch.open
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: notch.restHeight + 4
                    width: 420 - 36
                    opacity: notch.open ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    sourceComponent: root.card === "notif" ? notifCard : root.card === "controls" ? controlsCard : chatCard
                }
            }

            // ---------- cards ----------
            Component {
                id: notifCard
                RowLayout {
                    spacing: 12
                    Rectangle {
                        implicitWidth: 40
                        implicitHeight: 40
                        radius: 11
                        color: Appearance.colors.colSecondaryContainer
                        StyledText {
                            anchors.centerIn: parent
                            text: (root.notif?.appName ?? "?").charAt(0).toUpperCase()
                            font.family: "JetBrains Mono"
                            font.weight: Font.Bold
                            font.pixelSize: 16
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText {
                            Layout.fillWidth: true
                            text: root.notif?.summary ?? ""
                            font.family: "Space Grotesk"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.notif?.body ?? ""
                            font.pixelSize: 12
                            color: Appearance.colors.colSubtext
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Component {
                id: controlsCard
                ColumnLayout {
                    spacing: 10
                    RowLayout {
                        spacing: 12
                        ClippingRectangle {
                            implicitWidth: 56
                            implicitHeight: 56
                            radius: 12
                            color: Appearance.colors.colLayer1
                            Image {
                                anchors.fill: parent
                                source: MprisController.activePlayer?.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(112, 112)
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            StyledText {
                                Layout.fillWidth: true
                                text: MprisController.activePlayer?.trackTitle ?? ""
                                font.family: "Space Grotesk"
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: MprisController.activePlayer?.trackArtist ?? ""
                                font.pixelSize: 12
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideRight
                            }
                        }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 18
                        Repeater {
                            model: [
                                { icon: "skip_previous", act: () => MprisController.previous() },
                                { icon: root.playing ? "pause" : "play_arrow", act: () => MprisController.togglePlaying() },
                                { icon: "skip_next", act: () => MprisController.next() }
                            ]
                            delegate: RippleButton {
                                required property var modelData
                                implicitWidth: 40
                                implicitHeight: 40
                                buttonRadius: 20
                                onClicked: modelData.act()
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    iconSize: 24
                                    fill: 1
                                    color: Appearance.colors.colOnLayer0
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: chatCard
                ColumnLayout {
                    spacing: 10
                    StyledText {
                        Layout.fillWidth: true
                        Layout.maximumHeight: 200
                        visible: text !== ""
                        text: root.lastAi?.role === "assistant" ? root.lastAi.content : ""
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        font.pixelSize: 13
                        textFormat: Text.MarkdownText
                    }
                    StyledText {
                        visible: root.lastAi?.role !== "assistant"
                        text: "Oi! Pergunta alguma coisa pra mim."
                        font.family: "Space Grotesk"
                        font.pixelSize: 13
                        color: Appearance.colors.colSubtext
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 38
                        radius: 19
                        color: Appearance.colors.colLayer1
                        StyledTextInput {
                            id: input
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            focus: true
                            font.family: "Space Grotesk"
                            font.pixelSize: 13
                            color: Appearance.colors.colOnLayer0
                            Component.onCompleted: forceActiveFocus()
                            Keys.onEscapePressed: root.card = ""
                            onAccepted: {
                                if (text.trim() === "")
                                    return;
                                Ai.sendUserMessage(text.trim());
                                text = "";
                            }
                            StyledText {
                                visible: input.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.aiBusy ? "pensando…" : "Escreva e aperte Enter"
                                font.family: "Space Grotesk"
                                font.pixelSize: 13
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }
            }

            // Keyboard focus only while chatting
            WlrLayershell.keyboardFocus: root.card === "chat" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        }
    }
}
