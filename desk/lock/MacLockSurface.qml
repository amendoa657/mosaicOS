// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M A C   L O C K   S U R F A C E                                        │
// │   the macOS theme's lock screen · Mosaic OS                              │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects
import Quickshell

import "../theme"
import "../services"
import "../components"

// Mosaic OS: the lock screen of the macOS theme, after macOS's: the wallpaper
// barely blurred, the date over a huge clock at the top, "Now playing" on a
// glass card under it, and at the bottom the picture, the name and the password
// pill, which shakes when the password is wrong. Same face as LockSurface.qml
// (output, claim(), submitted), so LockScreen.qml picks either.
Item {
    id: root

    signal submitted(string password)
    property string output: ""

    function claim(): void {
        field.forceActiveFocus()
    }

    // 1 while the lock holds; the type fades and the blur lifts as it opens
    property real held: LockService.leaving ? 0 : 1
    Behavior on held { NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    TapHandler { onTapped: { LockService.rouse(); root.claim() } }
    Keys.onPressed: LockService.rouse()

    // ── the wallpaper, lightly blurred ──────────────────────────────────────
    Rectangle { anchors.fill: parent; color: "black" }
    Image {
        id: shot
        anchors.fill: parent
        source: LockService.shotSource(root.output)
        fillMode: Image.PreserveAspectCrop
        visible: false
        cache: false
    }
    MultiEffect {
        anchors.fill: parent
        source: shot
        visible: shot.status === Image.Ready
        blurEnabled: true
        blurMax: 48
        blur: 0.55 * root.held
        brightness: -0.08 * root.held
    }

    // ── the date and the clock ──────────────────────────────────────────────
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.07
        opacity: root.held
        spacing: -root.height * 0.012
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Theme.fmt(clock.date, "dddd, d 'de' MMMM")
            font.family: Theme.fontDisplay
            font.pixelSize: Math.round(root.height * 0.024)
            font.weight: Font.DemiBold
            color: Qt.rgba(1, 1, 1, 0.88)
        }
        Text {
            id: time
            anchors.horizontalCenter: parent.horizontalCenter
            text: Theme.fmt(clock.date, "HH:mm")
            font.family: Theme.fontDisplay
            font.pixelSize: Math.round(root.height * 0.135)
            font.weight: Font.Bold
            font.letterSpacing: -root.height * 0.002
            color: Qt.rgba(1, 1, 1, 0.9)
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.6; shadowOpacity: 0.25; shadowVerticalOffset: 2 }
        }
    }

    // ── now playing, as on the Mac's lock ───────────────────────────────────
    Rectangle {
        id: playing
        visible: MediaService.available
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.34
        width: Math.min(380, root.width * 0.8)
        height: 84
        radius: 22
        color: Qt.rgba(1, 1, 1, 0.14)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.22)
        opacity: root.held
        Rectangle {
            id: artBox
            x: 14; anchors.verticalCenter: parent.verticalCenter
            width: 56; height: 56; radius: 10
            color: Qt.rgba(1, 1, 1, 0.12)
            Image { id: art; anchors.fill: parent; source: MediaService.artUrl; fillMode: Image.PreserveAspectCrop; visible: false; asynchronous: true }
            Rectangle { id: artMask; anchors.fill: parent; radius: 10; visible: false; layer.enabled: true }
            MultiEffect { anchors.fill: parent; source: art; maskEnabled: true; maskSource: artMask; visible: art.status === Image.Ready }
        }
        Column {
            anchors.left: artBox.right; anchors.leftMargin: 12
            anchors.right: controls.left; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text { width: parent.width; text: MediaService.title; elide: Text.ElideRight; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: "white" }
            Text { width: parent.width; text: MediaService.artist; elide: Text.ElideRight; font.family: Theme.fontFamily; font.pixelSize: 13; color: Qt.rgba(1, 1, 1, 0.7) }
        }
        Row {
            id: controls
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16
            Repeater {
                model: [{ g: "󰒮", f: () => MediaService.previous() }, { g: MediaService.playing ? "󰏤" : "󰐊", f: () => MediaService.toggle() }, { g: "󰒭", f: () => MediaService.next() }]
                Text {
                    required property var modelData
                    text: modelData.g
                    font.family: Theme.fontMono; font.pixelSize: 22
                    color: "white"
                    TapHandler { onTapped: parent.modelData.f() }
                }
            }
        }
    }

    // ── the account and the password ────────────────────────────────────────
    Column {
        id: account
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.height * 0.07
        spacing: 10
        opacity: root.held
        Avatar {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 72
            height: 72
            source: AccountService.avatar
            initials: AccountService.initials
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: AccountService.name
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: "white"
        }
        // the pill
        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            width: 200
            height: 32
            radius: 16
            color: Qt.rgba(1, 1, 1, field.activeFocus ? 0.24 : 0.18)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.25)
            property real shake: 0
            transform: Translate { x: pill.shake }
            SequentialAnimation {
                id: shakeIt
                NumberAnimation { target: pill; property: "shake"; to: -14; duration: 50 }
                NumberAnimation { target: pill; property: "shake"; to: 12; duration: 70 }
                NumberAnimation { target: pill; property: "shake"; to: -9; duration: 70 }
                NumberAnimation { target: pill; property: "shake"; to: 6; duration: 60 }
                NumberAnimation { target: pill; property: "shake"; to: 0; duration: 60 }
            }
            TextInput {
                id: field
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: go.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.letterSpacing: 2
                color: "white"
                clip: true
                enabled: !LockService.authenticating && !LockService.leaving
                focus: true
                onTextEdited: LockService.rouse()
                onAccepted: if (text !== "") root.submitted(text)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text === ""
                    text: "Digite a senha"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Qt.rgba(1, 1, 1, 0.6)
                }
            }
            Rectangle { // the arrow, once something is typed
                id: go
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24; radius: 12
                color: Qt.rgba(1, 1, 1, 0.28)
                opacity: field.text !== "" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }
                Text { anchors.centerIn: parent; text: LockService.authenticating ? "󰔟" : "󰁔"; font.family: Theme.fontMono; font.pixelSize: 15; color: "white" }
                TapHandler { onTapped: if (field.text !== "") root.submitted(field.text) }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: LockService.failed ? (LockService.message || "Senha incorreta") : "Digite a senha para desbloquear"
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: Qt.rgba(1, 1, 1, LockService.failed ? 0.9 : 0.6)
        }
    }

    // a wrong password: the pill shakes and empties, as on the Mac
    Connections {
        target: LockService
        function onFailedChanged(): void {
            if (LockService.failed) {
                shakeIt.restart()
                field.text = ""
                root.claim()
            }
        }
    }

    // ── power, small in the corner ──────────────────────────────────────────
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 14
        opacity: 0.8 * root.held
        Repeater {
            model: [{ g: "󰜉", a: "reboot", t: "Reiniciar" }, { g: "󰐥", a: "shutdown", t: "Desligar" }]
            Column {
                required property var modelData
                spacing: 4
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 34; height: 34; radius: 17
                    color: Qt.rgba(1, 1, 1, powerHover.hovered ? 0.3 : 0.18)
                    Text { anchors.centerIn: parent; text: modelData.g; font.family: Theme.fontMono; font.pixelSize: 16; color: "white" }
                    HoverHandler { id: powerHover }
                    TapHandler { onTapped: SessionService.run(modelData.a) }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.t; font.family: Theme.fontFamily; font.pixelSize: 11; color: "white" }
            }
        }
    }
}
