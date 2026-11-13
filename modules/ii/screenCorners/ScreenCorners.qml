import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: screenCorners
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    property var actionForCorner: ({
        [RoundCorner.CornerEnum.TopLeft]: () => GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen,
        [RoundCorner.CornerEnum.BottomLeft]: () => GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen,
        [RoundCorner.CornerEnum.TopRight]: () => GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen,
        [RoundCorner.CornerEnum.BottomRight]: () => GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
    })

    // Mosaic OS: one thin strip per screen edge (top and bottom) holding that
    // edge's two corners, instead of a window per corner: 4 windows instead of
    // 8, and every window costs its own render context (~5 MB each). The strip
    // takes input only where a corner's sidebar zone is (mask), so the rest of
    // the edge stays the windows'.
    component CornerItem: Item {
        id: cornerItem
        property var corner
        property bool fullscreen
        readonly property alias hotZone: sidebarCornerOpenInteractionLoader
        implicitWidth: cornerWidget.implicitWidth
        implicitHeight: cornerWidget.implicitHeight
        RoundCorner {
            id: cornerWidget
            corner: cornerItem.corner
            rightVisualMargin: (Config.options.interactions.deadPixelWorkaround.enable && cornerWidget.isRight) * 1
            bottomVisualMargin: (Config.options.interactions.deadPixelWorkaround.enable && cornerWidget.isBottom) * 1

            implicitSize: Appearance.rounding.screenRounding
            implicitHeight: Math.max(implicitSize, sidebarCornerOpenInteractionLoader.implicitHeight)
            implicitWidth: Math.max(implicitSize, sidebarCornerOpenInteractionLoader.implicitWidth)

            Loader {
                id: sidebarCornerOpenInteractionLoader
                active: {
                    if (!Config.options.sidebar.cornerOpen.enable) return false;
                    if (cornerItem.fullscreen) return false;
                    return (Config.options.sidebar.cornerOpen.bottom == cornerWidget.isBottom);
                }
                anchors {
                    top: (cornerWidget.isTopLeft || cornerWidget.isTopRight) ? parent.top : undefined
                    bottom: (cornerWidget.isBottomLeft || cornerWidget.isBottomRight) ? parent.bottom : undefined
                    left: (cornerWidget.isLeft) ? parent.left : undefined
                    right: (cornerWidget.isTopRight || cornerWidget.isBottomRight) ? parent.right : undefined
                }

                sourceComponent: FocusedScrollMouseArea {
                    id: mouseArea
                    implicitWidth: Config.options.sidebar.cornerOpen.cornerRegionWidth
                    implicitHeight: Config.options.sidebar.cornerOpen.cornerRegionHeight
                    hoverEnabled: true
                    onPositionChanged: {
                        if (!Config.options.sidebar.cornerOpen.clicklessCornerEnd) return;
                        const verticalOffset = Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset;
                        const correctX = (cornerWidget.isRight && mouseArea.mouseX >= mouseArea.width - 2) || (cornerWidget.isLeft && mouseArea.mouseX <= 2);
                        const correctY = (cornerWidget.isTop && mouseArea.mouseY > verticalOffset || cornerWidget.isBottom && mouseArea.mouseY < mouseArea.height - verticalOffset);
                        if (correctX && correctY)
                            screenCorners.actionForCorner[cornerItem.corner]();
                    }
                    onEntered: {
                        if (Config.options.sidebar.cornerOpen.clickless)
                            screenCorners.actionForCorner[cornerItem.corner]();
                    }
                    onPressed: {
                        screenCorners.actionForCorner[cornerItem.corner]();
                    }
                    onScrollDown: {
                        if (!Config.options.sidebar.cornerOpen.valueScroll)
                            return;
                        if (cornerWidget.isLeft)
                            Brightness.decreaseBrightness()
                        else {
                            const currentVolume = Audio.value;
                            const step = currentVolume < 0.1 ? 0.01 : 0.02 || 0.2;
                            Audio.sink.audio.volume -= step;
                        }
                    }
                    onScrollUp: {
                        if (!Config.options.sidebar.cornerOpen.valueScroll)
                            return;
                        if (cornerWidget.isLeft)
                            Brightness.increaseBrightness()
                        else {
                            const currentVolume = Audio.value;
                            const step = currentVolume < 0.1 ? 0.01 : 0.02 || 0.2;
                            Audio.sink.audio.volume = Math.min(1, Audio.sink.audio.volume + step);
                        }
                    }
                    onMovedAway: {
                        if (!Config.options.sidebar.cornerOpen.valueScroll)
                            return;
                        if (cornerWidget.isLeft)
                            GlobalStates.osdBrightnessOpen = false;
                        else
                            GlobalStates.osdVolumeOpen = false;
                    }

                    Loader {
                        active: Config.options.sidebar.cornerOpen.visualize
                        anchors.fill: parent
                        sourceComponent: Rectangle {
                            color: Appearance.colors.colPrimary
                        }
                    }
                }
            }
        }
    }

    component EdgePanelWindow: PanelWindow {
        id: edgeWindow
        property bool bottomEdge: false
        property bool fullscreen
        visible: (Config.options.appearance.fakeScreenRounding === 1 || (Config.options.appearance.fakeScreenRounding === 2 && !fullscreen))

        exclusionMode: ExclusionMode.Ignore
        mask: Region {
            Region { item: leftCorner.hotZone.active ? leftCorner.hotZone : null }
            Region { item: rightCorner.hotZone.active ? rightCorner.hotZone : null }
        }
        WlrLayershell.namespace: "quickshell:screenCorners"
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        anchors {
            top: !edgeWindow.bottomEdge
            bottom: edgeWindow.bottomEdge
            left: true
            right: true
        }
        margins {
            right: Config.options.interactions.deadPixelWorkaround.enable ? -1 : 0
            bottom: (Config.options.interactions.deadPixelWorkaround.enable && edgeWindow.bottomEdge) ? -1 : 0
        }
        implicitHeight: Math.max(leftCorner.implicitHeight, rightCorner.implicitHeight)

        CornerItem {
            id: leftCorner
            anchors.left: parent.left
            anchors.top: edgeWindow.bottomEdge ? undefined : parent.top
            anchors.bottom: edgeWindow.bottomEdge ? parent.bottom : undefined
            width: implicitWidth
            height: implicitHeight
            corner: edgeWindow.bottomEdge ? RoundCorner.CornerEnum.BottomLeft : RoundCorner.CornerEnum.TopLeft
            fullscreen: edgeWindow.fullscreen
        }
        CornerItem {
            id: rightCorner
            anchors.right: parent.right
            anchors.top: edgeWindow.bottomEdge ? undefined : parent.top
            anchors.bottom: edgeWindow.bottomEdge ? parent.bottom : undefined
            width: implicitWidth
            height: implicitHeight
            corner: edgeWindow.bottomEdge ? RoundCorner.CornerEnum.BottomRight : RoundCorner.CornerEnum.TopRight
            fullscreen: edgeWindow.fullscreen
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: monitorScope
            required property var modelData
            property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)

            // Hide when fullscreen
            property list<HyprlandWorkspace> workspacesForMonitor: Hyprland.workspaces.values.filter(workspace => workspace.monitor && workspace.monitor.name == monitor.name)
            property var activeWorkspaceWithFullscreen: workspacesForMonitor.filter(workspace => ((workspace.toplevels.values.filter(window => window.wayland?.fullscreen)[0] != undefined) && workspace.active))[0]
            property bool fullscreen: activeWorkspaceWithFullscreen != undefined

            EdgePanelWindow {
                screen: modelData
                fullscreen: monitorScope.fullscreen
            }
            EdgePanelWindow {
                screen: modelData
                bottomEdge: true
                fullscreen: monitorScope.fullscreen
            }
        }
    }
}
