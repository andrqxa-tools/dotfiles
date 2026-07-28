-- yt_seek.lua — «перейти к» для консольного плеера yt.
--
-- mpv turns the file name into the script name, so the binding registered below
-- is `script-binding yt_seek/goto` — the underscore in the file name keeps the
-- two spellings identical (a dash would be mangled into `yt_seek` anyway).
--
-- Bound to `t` / `g` in mpv-input.conf. Accepts mm:ss, h:mm:ss, plain seconds,
-- a percentage (`42%`) and relative jumps (`+90`, `-1:30`).
--
-- mpv 0.38 added mp.input.get for exactly this, but 0.37 (Ubuntu 24.04) has no
-- such API, so the line is collected by hand through the `any_unicode` binding
-- the way console.lua does it. That also shadows every printable key while
-- typing, so `q` cannot quit the player mid-entry.

local mp = require 'mp'

local ALLOWED = '[0-9:%.%%%+%-]'
local BINDINGS = {}
local buffer = ''
local active = false

local function format_time(seconds)
    if not seconds then
        return '--:--'
    end
    local total = math.floor(seconds + 0.5)
    local hours = math.floor(total / 3600)
    local minutes = math.floor((total % 3600) / 60)
    if hours > 0 then
        return string.format('%d:%02d:%02d', hours, minutes, total % 60)
    end
    return string.format('%d:%02d', minutes, total % 60)
end

local function draw()
    local position = mp.get_property_number('time-pos')
    local duration = mp.get_property_number('duration')

    mp.osd_message(string.format(
        'Перейти к: %s_\n[сейчас %s / %s]  mm:ss · 42%% · +30 · -30 · Esc отмена',
        buffer, format_time(position), format_time(duration)), 3600)
end

-- "1:02:03" -> 3723, "1:30" -> 90, "90" -> 90. nil when it is not a time.
local function to_seconds(text)
    local total = 0
    local parts = 0

    for part in string.gmatch(text, '[^:]+') do
        local value = tonumber(part)
        if not value or value < 0 then
            return nil
        end
        total = total * 60 + value
        parts = parts + 1
    end
    if parts == 0 or parts > 3 then
        return nil
    end
    return total
end

local function stop()
    for _, name in ipairs(BINDINGS) do
        mp.remove_key_binding(name)
    end
    BINDINGS = {}
    buffer = ''
    active = false
    mp.osd_message('', 0)
end

local function apply()
    local text = buffer
    local sign = string.match(text, '^([%+%-])')
    local body = sign and string.sub(text, 2) or text
    local percent = string.match(body, '^([%d%.]+)%%$')

    stop()
    if body == '' then
        return
    end

    local value = percent and tonumber(percent) or to_seconds(body)
    if not value then
        mp.osd_message('Не понял: ' .. text, 2)
        return
    end

    -- Relative jumps keep mpv's own feel: overshooting the end starts the next
    -- playlist entry, exactly like `>`.
    if sign then
        mp.commandv('seek', tostring(sign == '-' and -value or value),
            percent and 'relative-percent' or 'relative')
        return
    end

    -- An absolute target past the end would end the file instead, so a typo like
    -- 1:02:03 in a ten-minute clip must not kill playback: clamp it.
    local duration = mp.get_property_number('duration')
    if duration then
        if percent then
            value = duration * value / 100
        end
        value = math.max(0, math.min(value, duration - 0.5))
        mp.commandv('seek', tostring(value), 'absolute')
        return
    end

    mp.commandv('seek', tostring(value), percent and 'absolute-percent' or 'absolute')
end

local function bind(key, name, fn, opts)
    mp.add_forced_key_binding(key, name, fn, opts)
    BINDINGS[#BINDINGS + 1] = name
end

local function on_char(info)
    if info.event ~= 'down' and info.event ~= 'press' and info.event ~= 'repeat' then
        return
    end
    local char = info.key_text
    if not char or not string.match(char, '^' .. ALLOWED .. '$') then
        return
    end
    -- A sign only makes sense as the first character.
    if (char == '+' or char == '-') and buffer ~= '' then
        return
    end
    buffer = buffer .. char
    draw()
end

local function backspace()
    buffer = string.sub(buffer, 1, -2)
    draw()
end

local function start()
    if active then
        stop()
        return
    end
    active = true
    buffer = ''

    bind('any_unicode', 'yt-seek-char', on_char, { repeatable = true, complex = true })
    bind('BS', 'yt-seek-bs', backspace, { repeatable = true })
    bind('ESC', 'yt-seek-esc', stop)
    bind('ENTER', 'yt-seek-enter', apply)
    bind('KP_ENTER', 'yt-seek-kp-enter', apply)
    draw()
end

mp.add_key_binding(nil, 'goto', start)
