pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.mosaic.island

// The Estudo tab of the settings window: the study mode's schedule (a start
// and a length for each day of the week), the blocked apps and the blocked
// sites. It only edits agenda.json through MosaicEstudo; the blocking itself is
// the service's (scripts/estudo/estudo.py).
// There is no "turn off" here on purpose, and while a session is on the whole
// tab is read-only: leaving early is asked for (estudo.py liberar), with a reason.
Item {
    id: page

    property string part: "agenda" // agenda | apps | sites
    readonly property bool locked: MosaicEstudo.locked
    // a veil of the text colour: it reads on any theme's card (colLayer1 nearly
    // vanishes on the dark ones)
    readonly property color surface: MosaicTheme.brutal ? MosaicTheme.slabRaised : ColorUtils.transparentize(page.fg, 0.93)
    readonly property color fg: Appearance.colors.colOnLayer0
    onVisibleChanged: if (visible) MosaicEstudo.refresh()

    function dayOf(ms) {
        const d = new Date(ms), today = new Date();
        if (d.toDateString() === today.toDateString())
            return "hoje";
        return MosaicEstudo.dayNames[(d.getDay() + 6) % 7].toLowerCase();
    }

    // ---------- what is going on, and the three parts ----------
    Rectangle {
        id: status
        width: parent.width - MosaicTheme.shadow
        height: 68
        radius: Appearance.rounding.normal
        color: MosaicEstudo.active ? (MosaicTheme.brutal ? Appearance.colors.colPrimaryContainer : ColorUtils.mix(Appearance.colors.colPrimary, Appearance.colors.colLayer1, 0.32)) : page.surface
        border.width: MosaicTheme.brutal ? MosaicTheme.border : 0
        border.color: MosaicTheme.ink
        Behavior on color { ColorAnimation { duration: 200 } }
        HardShadow { visible: MosaicTheme.brutal }

        Rectangle {
            id: statusIcon
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: Appearance.rounding.small
            color: MosaicEstudo.active ? Appearance.colors.colPrimary : (MosaicTheme.brutal ? MosaicTheme.slab : ColorUtils.transparentize(page.fg, 0.88))
            border.width: MosaicTheme.brutal ? 1.5 : 0
            border.color: MosaicTheme.ink
            MaterialSymbol {
                anchors.centerIn: parent
                text: MosaicEstudo.active ? "lock" : "school"
                iconSize: 24
                fill: MosaicEstudo.active ? 1 : 0
                color: MosaicEstudo.active && !MosaicTheme.brutal ? Appearance.colors.colOnPrimary : page.fg
            }
        }
        Column {
            anchors.left: statusIcon.right
            anchors.leftMargin: 12
            anchors.right: parts.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: !MosaicEstudo.installed ? "O serviço do modo Estudo não está rodando"
                    : MosaicEstudo.active ? `Estudando até as ${MosaicEstudo.clock(MosaicEstudo.until)}`
                    : MosaicEstudo.next > 0 ? `Próxima sessão: ${page.dayOf(MosaicEstudo.next)} às ${MosaicEstudo.clock(MosaicEstudo.next)}`
                    : "Nenhum dia marcado"
                font.family: MosaicTheme.fontUi
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: page.fg
            }
            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: !MosaicEstudo.installed ? "Instale com scripts/estudo/instalar.sh."
                    : MosaicEstudo.release ? `Liberado até as ${MosaicEstudo.clock(MosaicEstudo.release.ate * 1000)}: ${MosaicEstudo.release.motivo}`
                    : MosaicEstudo.active ? "Tudo travado até acabar. Para sair antes, peça ao Claude, com um bom motivo."
                    : MosaicEstudo.pending ? "O que afrouxa (menos tempo, app ou site retirado) só vale a partir de amanhã."
                    : "Firefox e Claude ficam sempre livres. Só o que está nas listas é fechado."
                font.pixelSize: 11
                color: page.fg
                opacity: 0.7
            }
        }
        Row {
            id: parts
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: [{ id: "agenda", label: "Agenda", icon: "calendar_month" }, { id: "apps", label: "Apps", icon: "block" }, { id: "sites", label: "Sites", icon: "public_off" }]
                delegate: Rectangle {
                    id: partTab
                    required property var modelData
                    readonly property bool on: page.part === modelData.id
                    width: partRow.implicitWidth + 20
                    height: 34
                    radius: MosaicTheme.r(17)
                    color: on ? Appearance.colors.colPrimary : (partArea.containsMouse ? ColorUtils.transparentize(page.fg, 0.9) : "transparent")
                    border.width: MosaicTheme.brutal && on ? 1.5 : 0
                    border.color: MosaicTheme.ink
                    Row {
                        id: partRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: partTab.modelData.icon
                            iconSize: 16
                            color: partTab.on ? Appearance.colors.colOnPrimary : page.fg
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: partTab.modelData.label
                            font.pixelSize: 12
                            font.weight: partTab.on ? Font.Bold : Font.Normal
                            color: partTab.on ? Appearance.colors.colOnPrimary : page.fg
                        }
                    }
                    MouseArea {
                        id: partArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: page.part = partTab.modelData.id
                    }
                }
            }
        }
    }

    // ---------- Agenda: a row per day of the week ----------
    Column {
        id: agendaPart
        visible: page.part === "agenda"
        anchors.top: status.bottom
        anchors.topMargin: 16
        width: parent.width
        spacing: 6

        Repeater {
            model: MosaicEstudo.agenda.dias
            delegate: Item {
                id: day
                required property var modelData
                required property int index
                readonly property bool on: modelData.ativo
                width: agendaPart.width
                height: 40
                opacity: page.locked ? 0.55 : 1

                Toggle {
                    id: dayToggle
                    anchors.verticalCenter: parent.verticalCenter
                    on: day.on
                    onToggled: MosaicEstudo.setDay(day.index, { ativo: !day.on })
                }
                StyledText {
                    id: dayName
                    anchors.left: dayToggle.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 86
                    text: MosaicTheme.brutal ? MosaicEstudo.dayNames[day.index].toUpperCase() : MosaicEstudo.dayNames[day.index]
                    font.family: MosaicTheme.fontUi
                    font.pixelSize: 14
                    font.weight: day.on ? Font.DemiBold : Font.Normal
                    color: page.fg
                    opacity: day.on ? 1 : 0.55
                }
                Row {
                    anchors.left: dayName.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 18
                    opacity: day.on ? 1 : 0.4
                    Stepper {
                        label: "começa"
                        value: day.modelData.inicio
                        onStep: dir => MosaicEstudo.setDay(day.index, { inicio: MosaicEstudo.shift(day.modelData.inicio, dir * 15) })
                    }
                    Stepper {
                        label: "dura"
                        value: MosaicEstudo.span(day.modelData.minutos)
                        onStep: dir => MosaicEstudo.setDay(day.index, { minutos: Math.max(15, Math.min(960, day.modelData.minutos + dir * 15)) })
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `até ${MosaicEstudo.endOf(day.modelData.inicio, day.modelData.minutos)}`
                        font.family: "JetBrains Mono"
                        font.pixelSize: 12
                        color: page.fg
                        opacity: 0.65
                    }
                }
            }
        }

        // a session right now: the first click arms the button, the second starts
        Item { width: 1; height: 6 }
        Row {
            spacing: 10
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: 150
                text: MosaicEstudo.active ? "Estender a sessão" : "Começar agora"
                font.family: MosaicTheme.fontUi
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: page.fg
            }
            Repeater {
                model: [25, 50, 90, 120]
                delegate: Rectangle {
                    id: now
                    required property int modelData
                    property bool armed: false
                    width: nowText.implicitWidth + 26
                    height: 34
                    radius: MosaicTheme.r(17)
                    color: armed ? Appearance.colors.colPrimary : page.surface
                    border.width: MosaicTheme.brutal ? 1.5 : 0
                    border.color: MosaicTheme.ink
                    Behavior on color { ColorAnimation { duration: 160 } }
                    scale: nowArea.pressed ? 0.94 : 1
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                    StyledText {
                        id: nowText
                        anchors.centerIn: parent
                        text: now.armed ? "Sem volta. Confirmar?" : MosaicEstudo.span(now.modelData)
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: now.armed ? Appearance.colors.colOnPrimary : page.fg
                    }
                    Timer { running: now.armed; interval: 3500; onTriggered: now.armed = false }
                    MouseArea {
                        id: nowArea
                        anchors.fill: parent
                        onClicked: {
                            if (now.armed)
                                MosaicEstudo.startNow(now.modelData);
                            now.armed = !now.armed;
                        }
                    }
                }
            }
        }
    }

    // ---------- Apps: the blocked ones on the left, the installed ones on the right ----------
    Item {
        id: appsPart
        visible: page.part === "apps"
        anchors.top: status.bottom
        anchors.topMargin: 16
        anchors.bottom: parent.bottom
        width: parent.width
        property string query: ""
        // the two apps the mode is for can't go on the list
        readonly property var installedApps: {
            const q = appsPart.query.trim().toLowerCase();
            return DesktopEntries.applications.values
                .filter(e => !e.noDisplay && !/firefox|zen|claude|quickshell/i.test(e.id) && !MosaicEstudo.hasApp(e.id) && (q === "" || e.name.toLowerCase().includes(q)))
                .sort((a, b) => a.name.localeCompare(b.name));
        }

        Flickable {
            id: blockedView
            width: Math.floor(parent.width * 0.52)
            height: parent.height
            contentHeight: blockedCol.height
            clip: true
            Column {
                id: blockedCol
                width: parent.width
                spacing: 10
                PartTitle { text: "Bloqueados durante o estudo" }
                Flow {
                    width: parent.width - 8
                    spacing: 6
                    Repeater {
                        model: MosaicEstudo.agenda.apps
                        delegate: Chip {
                            required property var modelData
                            text: modelData.nome
                            onRemoved: MosaicEstudo.removeApp(modelData.id)
                        }
                    }
                }
            }
        }
        Column {
            anchors.left: blockedView.right
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: MosaicTheme.shadow
            height: parent.height
            spacing: 10
            opacity: page.locked ? 0.45 : 1
            PartTitle { text: "Adicionar um app" }
            Field {
                id: appField
                width: parent.width
                hint: "buscar nos apps instalados"
                icon: "search"
                onEdited: text => appsPart.query = text
            }
            ListView {
                width: parent.width
                height: parent.height - y
                clip: true
                spacing: 2
                model: appsPart.installedApps
                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    width: ListView.view.width
                    height: 36
                    radius: Appearance.rounding.small
                    color: appArea.containsMouse ? ColorUtils.transparentize(page.fg, 0.9) : "transparent"
                    IconImage {
                        id: appIcon
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 22
                        source: Quickshell.iconPath(AppSearch.guessIcon(appRow.modelData.icon || appRow.modelData.id), "image-missing")
                    }
                    StyledText {
                        anchors.left: appIcon.right
                        anchors.leftMargin: 10
                        anchors.right: appAdd.left
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: appRow.modelData.name
                        font.pixelSize: 13
                        color: page.fg
                    }
                    MaterialSymbol {
                        id: appAdd
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "add_circle"
                        iconSize: 18
                        color: page.fg
                        opacity: appArea.containsMouse ? 1 : 0.35
                    }
                    MouseArea {
                        id: appArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !page.locked
                        onClicked: MosaicEstudo.addApp(appRow.modelData)
                    }
                }
            }
        }
    }

    // ---------- Sites ----------
    Column {
        id: sitesPart
        visible: page.part === "sites"
        anchors.top: status.bottom
        anchors.topMargin: 16
        width: parent.width - MosaicTheme.shadow
        spacing: 10
        PartTitle { text: "Sites fechados durante o estudo" }
        StyledText {
            width: parent.width
            wrapMode: Text.Wrap
            text: MosaicEstudo.sitesInstalled
                ? "Valem para todos os navegadores. Um site que já estava aberto pode levar um minuto para parar de carregar."
                : "Falta instalar o bloqueio de sites (precisa de sudo, uma vez só). No terminal:  sudo ~/.config/quickshell/mosaic/scripts/estudo/instalar-sites.sh"
            font.pixelSize: 11
            color: MosaicEstudo.sitesInstalled ? page.fg : Appearance.m3colors.m3error
            opacity: MosaicEstudo.sitesInstalled ? 0.7 : 1
        }
        Field {
            id: siteField
            width: Math.min(360, parent.width)
            hint: "adicionar: site.com e Enter"
            icon: "add_link"
            opacity: page.locked ? 0.45 : 1
            onAccepted: text => {
                if (MosaicEstudo.addSite(text))
                    siteField.clear();
            }
        }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: MosaicEstudo.agenda.sites
                delegate: Chip {
                    required property string modelData
                    text: modelData
                    mono: true
                    onRemoved: MosaicEstudo.removeSite(modelData)
                }
            }
        }
    }

    // ---------- the pieces ----------
    component PartTitle: StyledText {
        font.family: MosaicTheme.fontUi
        font.pixelSize: 15
        font.weight: MosaicTheme.brutal ? Font.Black : Font.DemiBold
        font.letterSpacing: MosaicTheme.brutal ? 1.2 : 0
        font.capitalization: MosaicTheme.brutal ? Font.AllUppercase : Font.MixedCase
        color: page.fg
    }

    // the switch of the Widgets tab: the knob slides on a spring
    component Toggle: Rectangle {
        id: tog
        property bool on: false
        signal toggled()
        width: 46
        height: 26
        radius: MosaicTheme.r(13)
        color: on ? Appearance.colors.colPrimary : (MosaicTheme.brutal ? MosaicTheme.slab : ColorUtils.transparentize(page.fg, 0.86))
        border.width: MosaicTheme.brutal ? 1.5 : 0
        border.color: MosaicTheme.ink
        Behavior on color { ColorAnimation { duration: 180 } }
        Rectangle {
            width: 18
            height: 18
            radius: MosaicTheme.r(9)
            anchors.verticalCenter: parent.verticalCenter
            x: 4 + (parent.width - width - 8) * knob.value
            color: tog.on ? Appearance.colors.colOnPrimary : page.fg
            MosaicSpring { id: knob; response: 0.3; damping: 0.7; epsilon: 0.002; target: tog.on ? 1 : 0; Component.onCompleted: settle(target) }
        }
        MouseArea {
            anchors.fill: parent
            enabled: !page.locked
            onClicked: tog.toggled()
        }
    }

    // "começa  − 14:00 +": minus and plus, or the wheel over the value
    component Stepper: Row {
        id: stepper
        property string label: ""
        property string value: ""
        signal step(int dir)
        spacing: 6
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: stepper.label
            font.pixelSize: 11
            color: page.fg
            opacity: 0.65
        }
        Rectangle {
            width: 118
            height: 32
            radius: MosaicTheme.r(16)
            color: page.surface
            border.width: MosaicTheme.brutal ? 1.5 : 0
            border.color: MosaicTheme.ink
            MouseArea {
                anchors.fill: parent
                enabled: !page.locked
                onWheel: wheel => stepper.step(wheel.angleDelta.y > 0 ? 1 : -1)
            }
            StepButton { anchors.left: parent.left; icon: "remove"; onClicked: stepper.step(-1) }
            StyledText {
                anchors.centerIn: parent
                text: stepper.value
                font.family: "JetBrains Mono"
                font.pixelSize: 13
                font.weight: Font.Bold
                color: page.fg
            }
            StepButton { anchors.right: parent.right; icon: "add"; onClicked: stepper.step(1) }
        }
    }
    // holding it repeats
    component StepButton: Item {
        id: sb
        property string icon: ""
        signal clicked()
        width: 32
        height: 32
        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: width / 2
            color: ColorUtils.transparentize(page.fg, sbArea.containsMouse ? 0.85 : 1)
        }
        MaterialSymbol {
            anchors.centerIn: parent
            text: sb.icon
            iconSize: 16
            color: page.fg
        }
        Timer { running: sbArea.pressed; interval: 140; repeat: true; triggeredOnStart: false; onTriggered: sb.clicked() }
        MouseArea {
            id: sbArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: !page.locked
            onClicked: sb.clicked()
        }
    }

    // a name with an × (hidden while the tab is locked)
    component Chip: Rectangle {
        id: chip
        property string text: ""
        property bool mono: false
        signal removed()
        width: chipText.implicitWidth + (chipX.visible ? 44 : 24)
        height: 32
        radius: MosaicTheme.r(16)
        color: page.surface
        border.width: MosaicTheme.brutal ? 1.5 : 0
        border.color: MosaicTheme.ink
        StyledText {
            id: chipText
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: chip.text
            font.family: chip.mono ? "JetBrains Mono" : MosaicTheme.fontUi
            font.pixelSize: 12
            color: page.fg
        }
        MaterialSymbol {
            id: chipX
            visible: !page.locked
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: "close"
            iconSize: 16
            color: chipArea.containsMouse ? Appearance.m3colors.m3error : page.fg
            opacity: chipArea.containsMouse ? 1 : 0.5
            MouseArea {
                id: chipArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                onClicked: chip.removed()
            }
        }
    }

    // a one-line text field
    component Field: Rectangle {
        id: field
        property string hint: ""
        property string icon: ""
        signal edited(string text)
        signal accepted(string text)
        function clear() { input.text = ""; }
        height: 36
        radius: MosaicTheme.r(18)
        color: page.surface
        border.width: MosaicTheme.brutal ? 1.5 : (input.activeFocus ? 1.5 : 0)
        border.color: MosaicTheme.brutal ? MosaicTheme.ink : Appearance.colors.colPrimary
        MaterialSymbol {
            id: fieldIcon
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: field.icon
            iconSize: 16
            color: page.fg
            opacity: 0.6
        }
        TextInput {
            id: input
            anchors.left: fieldIcon.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            enabled: !page.locked
            font.family: MosaicTheme.fontUi
            font.pixelSize: 13
            color: page.fg
            selectionColor: Appearance.colors.colPrimary
            clip: true
            onTextChanged: field.edited(text)
            onAccepted: field.accepted(text)
            StyledText {
                visible: input.text === ""
                anchors.verticalCenter: parent.verticalCenter
                text: field.hint
                font: input.font
                color: page.fg
                opacity: 0.45
            }
        }
    }
}
