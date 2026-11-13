import QtQuick
import Quickshell

import qs.modules.common
import qs.modules.ii.background
import qs.modules.ii.bar
import qs.modules.ii.cheatsheet
import qs.modules.ii.dock
import qs.modules.ii.lock
import qs.modules.ii.mediaControls
import qs.modules.ii.notificationPopup
import qs.modules.ii.onScreenDisplay
import qs.modules.ii.onScreenKeyboard
import qs.modules.ii.overview
import qs.modules.ii.polkit
import qs.modules.ii.regionSelector
import qs.modules.ii.screenCorners
import qs.modules.ii.screenTranslator
import qs.modules.ii.sessionScreen
import qs.modules.ii.sidebarLeft
import qs.modules.ii.sidebarRight
import qs.modules.ii.overlay
import qs.modules.ii.verticalBar
import qs.modules.ii.wallpaperSelector
import qs.modules.mosaic.debug
import qs.modules.mosaic.dock
import qs.modules.mosaic.island
import qs.modules.mosaic.sidebars
import qs.modules.mosaic.stage
import qs.modules.mosaic.topbar
import qs.modules.mosaic.wallpapers
import qs.desk

Scope {
    // Mosaic OS: the ii bar left; the dock (modules/mosaic/dock) took its place
    // PanelLoader { extraCondition: !Config.options.bar.vertical; component: Bar {} }
    PanelLoader { extraCondition: MosaicDebug.papel; component: Background {} }
    // Mosaic OS: the desk of widgets from impasto (desk/), under the windows
    PanelLoader { extraCondition: MosaicDebug.widgets; component: MosaicDesk {} }
    PanelLoader { component: Cheatsheet {} }
    // PanelLoader { extraCondition: Config.options.dock.enable; component: Dock {} }
    PanelLoader { extraCondition: MosaicDebug.dock; component: MosaicDock {} }
    // Mosaic OS: the lock screen from impasto (desk/), with the ii's calls and keys
    PanelLoader { component: MosaicLock {} }
    PanelLoader { component: MediaControls {} }
    // Mosaic OS: notifications show up whole in the island
    // PanelLoader { component: NotificationPopup {} }
    // Mosaic OS: volume and brightness show up in the island
    // PanelLoader { component: OnScreenDisplay {} }
    PanelLoader { component: OnScreenKeyboard {} }
    PanelLoader { component: Overlay {} }
    PanelLoader { component: Overview {} }
    PanelLoader { component: Polkit {} }
    PanelLoader { component: RegionSelector {} }
    PanelLoader { extraCondition: MosaicDebug.cantos; component: ScreenCorners {} }
    PanelLoader { component: ScreenTranslator {} }
    PanelLoader { component: SessionScreen {} }
    // Mosaic OS: the sidebars are modules/mosaic/sidebars (same shortcuts)
    // PanelLoader { component: SidebarLeft {} }
    PanelLoader { extraCondition: MosaicDebug.ladoEsq; component: MosaicSidebarLeft {} }
    // PanelLoader { component: SidebarRight {} }
    PanelLoader { extraCondition: MosaicDebug.ladoDir; component: MosaicSidebarRight {} }
    // PanelLoader { extraCondition: Config.options.bar.vertical; component: VerticalBar {} }
    // Mosaic OS: the wallpaper carousel and its transition, and the settings window
    // (modules/mosaic/wallpapers; same wallpaper shortcuts)
    // PanelLoader { component: WallpaperSelector {} }
    PanelLoader { component: MosaicCarousel {} }
    PanelLoader { component: MosaicWallFx {} }
    PanelLoader { component: MosaicSettings {} }
    // Mosaic OS
    PanelLoader { extraCondition: MosaicDebug.ilha; component: Island {} }
    // Mosaic OS: the reserved top band (workspaces on the left, states on the right)
    PanelLoader { extraCondition: MosaicDebug.barra; component: MosaicTopBar {} }
    // Mosaic OS: the Stage Manager on the left edge
    PanelLoader { extraCondition: MosaicDebug.stage; component: MosaicStage {} }
    // Mosaic OS: the "Desliga-tudo" panel (Super+Alt+G), switches above are MosaicDebug
    PanelLoader { component: MosaicDebugPanel {} }
}
