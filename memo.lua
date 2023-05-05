-- memo.lua
--
-- A recent files menu for mpv

local options = {
    -- File path gets extended
    history_path = "~~/memo-history.log",

    -- How many entries to display in menu
    entries = 10,

    -- Allow navigating to older entries
    pagination = true,

    -- Display files only once
    hide_duplicates = true,

    -- Check if files still exist
    hide_deleted = true,

    -- Date format https://www.lua.org/pil/22.1.html
    timestamp_format = "%Y-%m-%d %H:%M:%S",

    -- Display titles instead of filenames when available
    use_titles = true,

    -- Truncate titles to n characters, 0 to disable
    truncate_titles = 60,

    -- Meant for use in auto profiles
    enabled = true
}

local script_name = mp.get_script_name()

mp.utils = require "mp.utils"
mp.options = require "mp.options"
mp.options.read_options(options, "memo")

local history_path = mp.command_native({"expand-path", options.history_path})
local history = io.open(history_path, "a+")
local last_state = nil

local uosc_available = false

local function write_history()
    local path = mp.get_property("path")
    if path == nil then return end
    local directory = path:find("^%a[%a%d-_]+:") == nil and mp.get_property("working-directory", "") or ""
    local full_path = mp.utils.join_path(directory, path)
    local playlist_pos = mp.get_property_number("playlist-pos") or -1
    local title = playlist_pos > -1 and mp.get_property("playlist/"..playlist_pos.."/title") or ""
    local title_length = #title
    local timestamp = os.time()

    -- format: <timestamp>,<title length>,<title>,<path>,<entry length>
    local entry = timestamp .. "," .. (title_length > 0 and title_length or "") .. "," .. title .. "," .. full_path
    local entry_length = #entry

    history:write(entry .. "," .. entry_length, "\n")
    history:flush()
end

local function show_history(entries, resume)
    local max_digits_length = 4 + 1
    local retry_offset = 1024
    local menu_items = {}
    local state = resume and last_state or {
        known_files = {},
        existing_files = {},
        cursor = history:seek("end")
    }

    -- all of these error cases can only happen if the user messes with the history file externally
    local function read_line()
        history:seek("set", state.cursor - max_digits_length)
        local tail = history:read(max_digits_length)
        if not tail then
            mp.msg.debug("error could not read entry length @ " .. state.cursor - max_digits_length)
            return
        end

        local entry_length_str, whitespace = tail:match("(%d+)(%s*)$")
        if not entry_length_str then
            mp.msg.debug("invalid entry length @ " .. state.cursor)
            state.cursor = math.max(state.cursor - retry_offset, 0)
            history:seek("set", state.cursor)
            local retry = history:read(retry_offset)
            local last_valid = string.match(retry, ".*(%d+\n.*)")
            local offset = last_valid and #last_valid or retry_offset
            state.cursor = state.cursor + retry_offset - offset + 1
            mp.msg.debug("retrying @ " .. state.cursor)
            return
        end

        local entry_length = tonumber(entry_length_str)
        state.cursor = state.cursor - entry_length - #entry_length_str - #whitespace - 1
        history:seek("set", state.cursor)

        local entry = history:read(entry_length)
        local timestamp_str, title_length_str, file_info = entry:match("([^,]*),(%d*),(.*)")
        if not timestamp_str then
            mp.msg.debug("invalid entry data @ " .. state.cursor)
            return
        end

        local timestamp = tonumber(timestamp_str)
        timestamp = timestamp and os.date(options.timestamp_format, timestamp) or timestamp_str

        local title_length = title_length_str ~= "" and tonumber(title_length_str) or 0
        local full_path = file_info:sub(title_length + 2)

        if options.hide_duplicates and state.known_files[full_path] then
            return
        end

        if full_path:find("^%a[%a%d-_]+:") ~= nil then
            state.existing_files[full_path] = true
            state.known_files[full_path] = true
        end

        if options.hide_deleted then
            if state.known_files[full_path] and not state.existing_files[full_path] then
                return
            end
            if not state.known_files[full_path] then
                local stat = mp.utils.file_info(full_path)
                if stat then
                    state.existing_files[full_path] = true
                else
                    return
                end
            end
        end

        local title = file_info:sub(1, title_length)
        if not options.use_titles then
            title = ""
        end

        if title == "" then
            local protocol_stripped, matches = full_path:gsub("^%a[%a%d-_]+:[/\\]*", "")
            if matches > 0 then
                title = protocol_stripped
            else
                local dirname, basename = mp.utils.split_path(full_path)
                title = basename ~= "" and basename or full_path
            end
        end

        if options.truncate_titles > 0 and #title > options.truncate_titles then
            title = title:sub(1, options.truncate_titles - 3) .. "..."
        end

        state.known_files[full_path] = true
        table.insert(menu_items, {title = title, hint = timestamp, value = {"loadfile", full_path}, keep_open = false})
    end

    while #menu_items < entries do
        if state.cursor - max_digits_length <= 0 then
            break
        end

        read_line()
    end

    last_state = state

    if uosc_available then
        if options.pagination and #menu_items > 0 and state.cursor - max_digits_length > 0 then
            table.insert(menu_items, {title = "Older entries", value = {"script-message-to", script_name, "memo-more"}, italic = "true", muted = "true", icon = "navigate_next"})
        end
        local menu = {
            type = "memo-history",
            title = "History (memo)",
            items = menu_items,
            selected_index = 1,
            keep_open = true
        }
        local json = mp.utils.format_json(menu)
        mp.commandv("script-message-to", "uosc", resume and "update-menu" or "open-menu", json)
    else
        mp.osd_message("[memo] uosc is required!", 5)
    end
end

local function file_load()
    mp.options.read_options(options, "memo")

    if options.enabled then
        write_history()
    end
end

mp.register_script_message("uosc-version", function(version)
    uosc_available = true
end)

mp.register_script_message("memo-more", function()
    show_history(options.entries, true)
end)

mp.command_native_async({"script-message-to", "uosc", "get-version", script_name}, function() end)

mp.add_key_binding(nil, "memo-history", function()
    show_history(options.entries)
end)

mp.register_event("file-loaded", file_load)
