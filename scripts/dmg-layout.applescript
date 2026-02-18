on run argv
    set appName to item 1 of argv
    set bgFile to item 2 of argv

    tell application "Finder"
        tell disk appName
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set bounds of container window to {200, 200, 700, 460}
            set opts to icon view options of container window
            set icon size of opts to 96
            set arrangement of opts to not arranged
            set background picture of opts to file ".background:bg.png"
            set position of item (appName & ".app") of container window to {120, 130}
            set position of item "Applications" of container window to {380, 130}
            close
        end tell
    end tell
end run
