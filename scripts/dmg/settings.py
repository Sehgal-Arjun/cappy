# dmgbuild settings for Cappy's DMG window. Used by scripts/make-dmg.sh.
# Positions are in points and match scripts/make-dmg-background.py.
import os.path

app = defines.get("app", "dist/Cappy.app")  # noqa: F821 (dmgbuild provides `defines`)
here = defines.get("dmg_dir", "scripts/dmg")  # noqa: F821

format = "UDZO"
filesystem = "HFS+"
volume_name = "Cappy"

files = [app, os.path.join(here, "Read me first.txt")]
symlinks = {"Applications": "/Applications"}
hide_extensions = ["Read me first.txt"]

background = os.path.join(here, "background.tiff")
# Height covers the 440pt layout plus the title bar, with room to spare
# for Finder tab/path bars; the art runs on below that.
window_rect = ((200, 120), (640, 500))
icon_size = 96
text_size = 13
label_pos = "bottom"
icon_locations = {
    "Cappy.app": (180, 190),
    "Applications": (460, 190),
    "Read me first.txt": (320, 322),
}

default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
sidebar_width = 0
show_icon_preview = False
arrange_by = None
