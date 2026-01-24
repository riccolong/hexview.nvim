-- ===========================================================
-- Plugin Hexadecimal Viewer and Editor
-- Author: 	Damian V. Cechov
-- damianvcechov@gmail.com ©2026
-- ===========================================================

local M = {}
M.disabled_buffers = {}
local ns = vim.api.nvim_create_namespace("hexview_ns")
local cursor_ns = vim.api.nvim_create_namespace("hexview_cursor_ns")

-- ============================================================
-- KONFIGURACE
-- ============================================================
M.bytes_per_line = 52
M.ascii_start_col = 0
M.hex_width = 0

-- ============================================================
-- POMOCNÉ FUNKCE
-- ============================================================
function M.setup_layout()
	local width = 0
	for i = 0, M.bytes_per_line - 1 do
		width = width + 2
		if (i + 1) % 4 == 0 and (i + 1) < M.bytes_per_line then
			width = width + 3
		else
			width = width + 1
		end
	end
	M.hex_width = width
	M.ascii_start_col = 10 + M.hex_width + 3
end

-- ============================================================
-- 1. NAČTENÍ DAT
-- ============================================================
function M.load_binary()
	local filepath = vim.api.nvim_buf_get_name(0)
	local data = ""

	local f = io.open(filepath, "rb")
	if f then
		data = f:read("*all")
		f:close()
	else
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		data = table.concat(lines, "\n")
	end

	local t = {}
	for i = 1, #data do
		t[i] = data:byte(i)
	end
	vim.b.hex_data = t
	vim.b.hex_dirty = {}
end

-- ============================================================
-- 2. RENDER ŘÁDKU
-- ============================================================
function M.render_line(row)
	if not vim.b.hex_data then
		return
	end

	local base = (row - 1) * M.bytes_per_line
	local hex_parts = { string.format("%08X: ", base) }
	local ascii_parts = {}

	local dirty_ranges_hex = {}
	local dirty_indices_ascii = {}
	local dirty_map = vim.b.hex_dirty or {}

	local current_hex_pos = 10

	for i = 0, M.bytes_per_line - 1 do
		local idx = base + i + 1
		local b = vim.b.hex_data[idx]

		if b then
			local hex = string.format("%02X", b)

			if dirty_map[tostring(idx)] then
				table.insert(dirty_ranges_hex, { current_hex_pos, current_hex_pos + 2 })
				table.insert(dirty_indices_ascii, i)
			end

			if (i + 1) % 4 == 0 and (i + 1) < M.bytes_per_line then
				table.insert(hex_parts, hex .. " | ")
				current_hex_pos = current_hex_pos + 5
			else
				table.insert(hex_parts, hex .. " ")
				current_hex_pos = current_hex_pos + 3
			end

			local c = (b >= 32 and b <= 126) and string.char(b) or "."
			table.insert(ascii_parts, c)
		else
			if (i + 1) % 4 == 0 and (i + 1) < M.bytes_per_line then
				table.insert(hex_parts, "   | ")
			else
				table.insert(hex_parts, "   ")
			end
			table.insert(ascii_parts, " ")
		end
	end

	local hex_str = table.concat(hex_parts)
	local ascii_str = table.concat(ascii_parts)
	local final_line_str = hex_str .. " | " .. ascii_str

	vim.opt_local.modifiable = true
	vim.api.nvim_buf_clear_namespace(0, -1, row - 1, row)
	vim.api.nvim_buf_set_lines(0, row - 1, row, false, { final_line_str })

	vim.api.nvim_buf_set_extmark(0, ns, row - 1, 0, { end_col = 9, hl_group = "HexViewOffset", priority = 100 })

	for _, range in ipairs(dirty_ranges_hex) do
		if range[2] <= #final_line_str then
			vim.api.nvim_buf_set_extmark(
				0,
				ns,
				row - 1,
				range[1],
				{ end_col = range[2], hl_group = "HexViewChanged", priority = 101 }
			)
		end
	end

	local ascii_start = #hex_str + 3
	for _, offset_i in ipairs(dirty_indices_ascii) do
		local col = ascii_start + offset_i
		if col < #final_line_str then
			vim.api.nvim_buf_set_extmark(
				0,
				ns,
				row - 1,
				col,
				{ end_col = col + 1, hl_group = "HexViewChanged", priority = 101 }
			)
		end
	end

	vim.opt_local.modifiable = false
end

-- ============================================================
-- 3. LOGIKA KURZORU & ZVÝRAZNĚNÍ
-- ============================================================
function M.cursor_byte()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()
	local header_end = line:find(": ")
	if not header_end then
		return nil
	end

	local base = tonumber(line:sub(1, header_end - 1), 16)
	if not base then
		return nil
	end

	if col >= M.ascii_start_col then
		local ascii_offset = col - M.ascii_start_col
		if ascii_offset >= 0 and ascii_offset < M.bytes_per_line then
			return base + ascii_offset, 0, true
		end
		return nil
	end

	local char_at_cursor = line:sub(col + 1, col + 1)
	if not char_at_cursor:match("[%x]") then
		return nil
	end

	local start_idx = header_end + 2
	local byte_count = -0.5
	for i = start_idx, col + 1 do
		if line:sub(i, i):match("[%x]") then
			byte_count = byte_count + 0.5
		end
	end

	if byte_count < 0 then
		return nil
	end
	local nibble = (byte_count % 1 ~= 0) and 1 or 0
	return base + math.floor(byte_count), nibble, false
end

function M.highlight_cursor()
	vim.api.nvim_buf_clear_namespace(0, cursor_ns, 0, -1)
	local offset, _, _ = M.cursor_byte()
	if not offset then
		return
	end

	local row = vim.api.nvim_win_get_cursor(0)[1]
	local line_idx = row - 1
	local byte_in_line = offset % M.bytes_per_line

	local hex_col = 10
	for i = 0, byte_in_line - 1 do
		if (i + 1) % 4 == 0 and (i + 1) < M.bytes_per_line then
			hex_col = hex_col + 5
		else
			hex_col = hex_col + 3
		end
	end

	local ascii_col = M.ascii_start_col + byte_in_line

	vim.api.nvim_buf_set_extmark(0, cursor_ns, line_idx, hex_col, {
		end_col = hex_col + 2,
		hl_group = "HexViewCursor",
		priority = 200,
	})
	vim.api.nvim_buf_set_extmark(0, cursor_ns, line_idx, ascii_col, {
		end_col = ascii_col + 1,
		hl_group = "HexViewCursor",
		priority = 200,
	})
end

-- ============================================================
-- 4. EDITACE (r, R)
-- ============================================================

local function write_nibble(offset, nibble_idx, char)
	local val = tonumber(char, 16)
	if not val then
		return false
	end

	local hex_data = vim.b.hex_data
	local data = hex_data[offset + 1]
	if not data then
		return false
	end

	local bit = require("bit")
	local new_data = data

	if nibble_idx == 0 then
		new_data = bit.bor(bit.band(data, 0x0F), bit.lshift(val, 4))
	else
		new_data = bit.bor(bit.band(data, 0xF0), val)
	end

	hex_data[offset + 1] = new_data
	vim.b.hex_data = hex_data
	return true
end

local function write_byte(offset, byte_val)
	if not byte_val then
		return false
	end
	local hex_data = vim.b.hex_data
	hex_data[offset + 1] = byte_val
	vim.b.hex_data = hex_data
	return true
end

function M.replace_one()
	local offset, nibble, is_ascii = M.cursor_byte()
	if not offset then
		return
	end

	local char_code = vim.fn.getchar()
	if char_code == 27 then
		return
	end

	local char = (type(char_code) == "number") and vim.fn.nr2char(char_code) or char_code
	local changed = false

	if is_ascii then
		local byte_val = string.byte(char)
		changed = write_byte(offset, byte_val)
	else
		if char:match("[%x]") then
			changed = write_nibble(offset, nibble, char)
		end
	end

	if changed then
		local dirty = vim.b.hex_dirty or {}
		dirty[tostring(offset + 1)] = true
		vim.b.hex_dirty = dirty

		M.render_line(vim.api.nvim_win_get_cursor(0)[1])
		vim.opt_local.modified = true
	end
end

function M.replace_continuous()
	vim.b.hex_replace_active = true
	vim.cmd("redrawstatus")

	while true do
		M.highlight_cursor()
		vim.cmd("redraw")

		local ok, char_code = pcall(vim.fn.getchar)
		if not ok or char_code == 27 then
			break
		end

		local char = (type(char_code) == "number") and vim.fn.nr2char(char_code) or char_code
		local offset, nibble, is_ascii = M.cursor_byte()

		if not offset then
			break
		end
		local changed = false

		if is_ascii then
			local byte_val = string.byte(char)
			if byte_val and byte_val >= 32 and byte_val <= 255 then
				changed = write_byte(offset, byte_val)
			end
		else
			if char:match("[%x]") then
				changed = write_nibble(offset, nibble, char)
			end
		end

		if changed then
			local dirty = vim.b.hex_dirty or {}
			dirty[tostring(offset + 1)] = true
			vim.b.hex_dirty = dirty

			M.render_line(vim.api.nvim_win_get_cursor(0)[1])
			vim.opt_local.modified = true
			M.smart_move("l")
		end
	end

	vim.b.hex_replace_active = false
	vim.cmd("redrawstatus")
	print(" ") -- Vyčistit cmdline
end

-- ============================================================
-- 5. POHYB
-- ============================================================
function M.smart_move(key)
	local cmd = (key == "l" or key == "<Right>") and "l" or "h"
	local is_left = (cmd == "h")
	local cur_row = vim.api.nvim_win_get_cursor(0)[1]

	local line = vim.api.nvim_get_current_line()
	local hex_start = 10
	local hex_end = 10 + M.hex_width - 1
	local ascii_start = M.ascii_start_col
	local ascii_end = ascii_start + M.bytes_per_line

	vim.cmd("normal! " .. cmd)
	local cur_col = vim.api.nvim_win_get_cursor(0)[2]

	if not is_left and cur_col > hex_end and cur_col < ascii_start then
		vim.api.nvim_win_set_cursor(0, { cur_row, ascii_start })
		return
	end

	if is_left and cur_col < ascii_start and cur_col > hex_end then
		local target = hex_end
		while target > hex_start do
			if line:sub(target + 1, target + 1):match("[%x]") then
				break
			end
			target = target - 1
		end
		vim.api.nvim_win_set_cursor(0, { cur_row, target })
		return
	end

	if cur_col >= hex_start and cur_col <= hex_end then
		local safeguard = 0
		while line:sub(cur_col + 1, cur_col + 1):match("[ |]") and safeguard < 5 do
			vim.cmd("normal! " .. cmd)
			cur_col = vim.api.nvim_win_get_cursor(0)[2]
			safeguard = safeguard + 1
		end
	end

	if cur_col < hex_start then
		vim.api.nvim_win_set_cursor(0, { cur_row, hex_start })
	end
end

-- ============================================================
-- 6. KEYMAPY & UI
-- ============================================================
function M.setup_keymaps()
	local moves = { "h", "l", "<Left>", "<Right>" }
	for _, k in ipairs(moves) do
		vim.keymap.set("n", k, function()
			M.smart_move(k)
		end, { buffer = true, silent = true })
	end

	vim.keymap.set("n", "r", function()
		M.replace_one()
	end, { buffer = true, silent = true })
	vim.keymap.set("n", "R", function()
		M.replace_continuous()
	end, { buffer = true, silent = true })

	vim.api.nvim_buf_create_user_command(0, "HexSet", function(opts)
		local val = tonumber(opts.args)
		if val and val > 0 then
			require("hexview").set_columns(val)
		else
			print("HexView: Enter a valid number of columns (e.g. :HexSet 16)")
		end
	end, { nargs = 1 })
end

function M.cursor_offset_label()
	local offset, nibble, is_ascii = M.cursor_byte()
	if not offset then
		return ""
	end
	local loc = is_ascii and "[ASCII]" or "[HEX]"
	return string.format("%s 0x%08X", loc, offset)
end

function M.get_statusline_content()
	-- Pokud je aktivní kontinuální přepisování, zobrazíme červeně -- REPLACE --
	local mode_info = ""
	if vim.b.hex_replace_active then
		mode_info = "%#HexViewModeEdit# -- REPLACE -- %*"
	end
	return string.format("  %%f %%m %%= %s Sloupce: %d  %%l,%%c  %%P ", mode_info, M.bytes_per_line)
end

function M.setup_ui()
	-- Barvy
	vim.api.nvim_set_hl(0, "HexViewOffset", { fg = "#FF9E64", bold = true })
	vim.api.nvim_set_hl(0, "HexViewHeader", { fg = "#FF9E64", bold = true })
	vim.api.nvim_set_hl(0, "HexViewChanged", { fg = "#FF007C", bold = true })

	-- Barva kurzoru (vráceno k originálu)
	vim.api.nvim_set_hl(0, "HexViewCursor", { bg = "#330000", fg = "#FFFF00", bold = true })
	vim.api.nvim_set_hl(0, "HexViewModeEdit", { fg = "#00FF00", bg = "#003300", bold = true })

	local O, N = "%#HexViewHeader#", "%*"

	local hex_header_parts = {}
	for i = 0, M.bytes_per_line - 1 do
		local hex = string.format("%02X", i)
		if (i + 1) % 4 == 0 and (i + 1) < M.bytes_per_line then
			table.insert(hex_header_parts, hex .. " | ")
		else
			table.insert(hex_header_parts, hex .. " ")
		end
	end
	local hex_header_str = table.concat(hex_header_parts)

	local ascii_header = " | " .. O .. "ASCII" .. N
	local header = " Offset   " .. O .. hex_header_str .. N .. ascii_header

	vim.opt_local.winbar = header .. "%=" .. "%#HexViewHeader# %{v:lua.require'hexview'.cursor_offset_label()} "
	vim.opt_local.statusline = "%!v:lua.require'hexview'.get_statusline_content()"
end

-- ============================================================
-- 7. ENABLE / DISABLE / REFRESH
-- ============================================================

function M.set_columns(cols)
	if cols < 1 then
		return
	end
	local current_offset = M.cursor_byte() or 0
	M.bytes_per_line = cols
	M.refresh_view()
	local new_row = math.floor(current_offset / M.bytes_per_line) + 1
	pcall(vim.api.nvim_win_set_cursor, 0, { new_row, 10 })
	print("HexView: Set on " .. cols .. " columns.")
end

function M.refresh_view()
	M.setup_layout()
	M.setup_ui()

	vim.opt_local.modifiable = true
	local total_lines = math.ceil(#vim.b.hex_data / M.bytes_per_line)
	if total_lines == 0 then
		total_lines = 1
	end

	local empty_lines = {}
	for _ = 1, total_lines do
		table.insert(empty_lines, "")
	end
	vim.api.nvim_buf_set_lines(0, 0, -1, false, empty_lines)

	for row = 1, total_lines do
		M.render_line(row)
	end
	vim.opt_local.modifiable = false
end

function M.enable()
	M.disabled_buffers[vim.api.nvim_get_current_buf()] = nil
	M.load_binary()
	if not vim.b.hex_data or #vim.b.hex_data == 0 then
		vim.b.hex_data = {}
	end
	vim.b.hex_dirty = {}
	vim.b.hex_replace_active = false -- Inicializace stavu

	vim.opt_local.modifiable = true
	vim.opt_local.readonly = false
	vim.opt_local.number = false
	vim.opt_local.relativenumber = false
	vim.opt_local.wrap = false
	vim.bo.filetype = "hexview"

	M.refresh_view()
	vim.api.nvim_win_set_cursor(0, { 1, 10 })
	vim.b.did_ftplugin = 1
	M.setup_keymaps()

	local au_group = vim.api.nvim_create_augroup("HexViewCursor", { clear = true })
	vim.api.nvim_create_autocmd("CursorMoved", {
		group = au_group,
		buffer = 0,
		callback = M.highlight_cursor,
	})
	M.highlight_cursor()

	vim.api.nvim_create_autocmd("BufWriteCmd", { buffer = 0, callback = M.save })
end

function M.disable()
	M.save()
	local buf = vim.api.nvim_get_current_buf()
	M.disabled_buffers[buf] = true

	vim.api.nvim_clear_autocmds({ group = "HexViewCursor", buffer = 0 })
	vim.api.nvim_buf_clear_namespace(0, cursor_ns, 0, -1)

	vim.api.nvim_clear_autocmds({ event = "BufWriteCmd", buffer = 0 })
	pcall(vim.api.nvim_buf_del_user_command, 0, "HexSet")

	vim.opt_local.winbar = nil
	vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
	vim.cmd("edit!")
	vim.opt_local.binary = true
	vim.opt_local.fixeol = false
	vim.opt_local.eol = false
	vim.opt_local.readonly = true
	vim.opt_local.modifiable = false
	vim.opt_local.statusline = ""
	vim.opt_local.syntax = "off"
	vim.bo.filetype = ""
	vim.b.hex_data = nil
	vim.b.hex_dirty = nil
	vim.b.hex_replace_active = nil
	print("HexView: RAW mode.")
end

function M.save()
	local name = vim.api.nvim_buf_get_name(0)
	if name == "" then
		print("Error: Buffer has no name.")
		return
	end
	local f = assert(io.open(name, "wb"))
	for _, b in ipairs(vim.b.hex_data or {}) do
		f:write(string.char(b))
	end
	f:close()
	vim.b.hex_dirty = {}
	vim.opt_local.modified = false

	local total_lines = math.ceil(#vim.b.hex_data / M.bytes_per_line)
	if total_lines == 0 then
		total_lines = 1
	end
	for r = 1, total_lines do
		M.render_line(r)
	end
	print("Writed")
end

-- ============================================================
-- 8. SETUP
-- ============================================================
function M.setup(config)
	M.setup_layout()

	local group = vim.api.nvim_create_augroup("HexViewAutoDetect", { clear = true })
	vim.api.nvim_create_autocmd("BufReadPost", {
		group = group,
		pattern = "*",
		callback = function(ev)
			if require("hexview").disabled_buffers[ev.buf] then
				return
			end
			local file = ev.file
			if not file or file == "" then
				return
			end
			if vim.bo[ev.buf].binary then
				vim.schedule(function()
					if vim.bo[ev.buf].filetype ~= "hexview" then
						require("hexview").enable()
					end
				end)
				return
			end
			local f = io.open(file, "rb")
			if not f then
				return
			end
			local chunk = f:read(1024)
			f:close()
			if chunk and chunk:find("%z") then
				vim.schedule(function()
					if vim.bo[ev.buf].filetype ~= "hexview" then
						require("hexview").enable()
					end
				end)
			end
		end,
	})
end

return M
