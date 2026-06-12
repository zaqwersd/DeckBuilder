# Deck Builder Tutorial for Godot
A roguelike deckbuilder tutorial project made in Godot 4.

This branch contains the latest code for the series.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/M4M0RXV24)

### Use this version if you want to check the current status of the project.

### Credits
- [Ben from Heartbeast](https://www.youtube.com/@uheartbeast): he originally started working on this project. He gave me permission, inspiration and also great ideas for this tutorial.
- [Kenney](https://kenney.nl)'s tiny dungeon asset pack
- Sound effects:
  - [StarNinjas](https://opengameart.org/users/starninjas) from OpenGameArt 
  - [Pixabay](https://pixabay.com/sound-effects/shield-guard-6963/) 
  - [artisticdude](https://opengameart.org/users/artisticdude) from OpenGameArt
- Music made by [Tad](https://www.youtube.com/c/Tadon)

### 卡牌图鉴长图导出（命令行）

开发时用 Godot headless 导出当前类别全部卡牌：左栏未升级、右栏已升级。

```powershell
# 将 GODOT 换成本机 Godot 4.6 可执行文件；或在环境变量中设置 GODOT_EXE
cd d:\Godot\deck_builder_tutorial-main
& $env:GODOT_EXE --display-driver windows --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 64x64 `
  tools/export_card_compendium.tscn -- `
  --category blade `
  --output exports/card_compendium_blade.png
```

- `--category`：`blade`（剑客）或 `common`（公共）
- `--output`：长图 PNG 路径（可选）
- `--log`：卡牌日志 Markdown 路径（可选；默认项目根目录 `card_compendium_{类别}.md`）

日志格式：每张卡一张 PNG（`card_compendium_{类别}_images/`）+ 一段文字说明。

也可使用：`tools\export_card_compendium.bat blade`
