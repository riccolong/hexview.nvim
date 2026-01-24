![Neovim HexView](/screenshot/screen.gif)

# hexview.nvim

A lightweight, pure Lua hex editor for Neovim.

`hexview.nvim` allows you to view and edit binary files directly inside Neovim without needing external tools like `xxd`. It features smart cursor navigation, synchronized Hex/ASCII editing, and visual dirty state tracking.

## ✨ Features

* **Pure Lua**: No external dependencies or binaries required.
* **Auto-detection**: Automatically enables itself for binary files or files containing null bytes.
* **Smart Editing**: Edit directly in the Hex column or the ASCII column.
* **Visual Feedback**: Highlights modified (dirty) bytes before saving.
* **Smart Navigation**: `h`/`l` jumps correctly between nibbles and columns, skipping separators.


![Neovim HexView](/screenshot/screen.png)

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "DamianVCechov/hexview.nvim",
    config = function()
        require("hexview").setup()
    end
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "DamianVCechov/hexview.nvim",
    config = function()
        require("hexview").setup()
    end
}
```

## 🚀 Usage
The plugin automatically activates when opening a binary file. You can also manually toggle it (implementation dependent) or trigger it by opening a file with binary set.

### Keymaps
Keymaps are set automatically within the hex buffer:
```
h / Left	Move left (smart jump between Hex and ASCII areas)
l / Right	Move right (smart jump between Hex and ASCII areas)
r	Replace Single: Replace the byte or nibble under the cursor.
R	Replace Mode: Continuously type Hex or ASCII characters to overwrite data. Press Esc to exit.
```
### Commands
`:Hex`                  Open actual file in hex editor

`:HexSet <columns>`     Dynamically change the number of bytes per line. Example: `:HexSet 16` (sets view to 16 bytes per line).

`:UnHex`                Save file and open in RAW mode.

`:w`                    Save file

### Open Neovim

`nvim binary.file`         Automatically activates, but RAW mode is in non binary

`nvim -b binary.file`      Better, RAW mode is in binary

`nvim -b +Hex`             Opens any file in hex mode instantly

### ⚙️ Configuration
Pass configuration options to the setup function.

```lua
quire("hexview").setup({
    -- Currently, the setup function initializes autocommands.
    -- Future configuration options will go here.
})
```

## 🎨 Highlights
The plugin defines the following highlight groups, which you can override in your colorscheme:

HexViewOffset: Color of the memory address offset (left column).

HexViewHeader: Color of the column headers.

HexViewCursor: The custom cursor highlight in Hex/ASCII columns.

HexViewChanged: Highlight for modified (dirty) bytes that haven't been saved yet.

HexViewModeEdit: Statusline indicator when in Replace mode.

## 🤝 Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

📄 License
MIT

© 2026 Damian V. Čechov 
