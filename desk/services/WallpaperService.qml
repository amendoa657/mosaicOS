pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common

// Mosaic OS: a stand-in for impasto's WallpaperService. Mosaic has its own
// (MosaicWalls, the ii's Background), so only what the desk and the lock read
// is here: the current wallpaper, for the backdrop that hides the windows while
// arranging. (It was "" before, so that backdrop never showed.)
Singleton {
    id: root
    readonly property string currentWallpaper: Config.options?.background?.wallpaperPath ?? ""
}
