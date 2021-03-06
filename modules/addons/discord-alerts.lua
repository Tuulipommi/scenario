local Event = require 'utils.event'
local Game = require 'utils.game'
local Colors = require 'resources.color_presets'
local write_json,format_time = ext_require('expcore.common','write_json','format_time')
local config = require 'config.discord_alerts'

local function get_player_name(event)
    local player = Game.get_player_by_index(event.player_index)
    return player.name, event.by_player_name
end

local function to_hex(color)
    local hex_digits = '0123456789ABCDEF'
    local function hex(bit)
        local major, minor = math.modf(bit/16)
        major,minor = major+1,minor*16+1
        return hex_digits:sub(major,major)..hex_digits:sub(minor,minor)
    end

    return hex(color.r)..hex(color.g)..hex(color.b)
end

local function emit_event(args)
    local title = args.title or ''
    local color = args.color or '0x0'
    local description = args.description or ''

    if type(color) == 'table' then
        color = to_hex(color)
    end

    local tick = args.tick or 0
    local tick_formated = format_time(tick,{hours = true,minutes = true,string = true,long = true})

    local players_online = 0
    local admins_online = 0
    for _,player in pairs(game.connected_players) do
        players_online = players_online+1
        if player.admin then
            admins_online = admins_online + 1
        end
    end

    local done = {title=true,color=true,description=true}
    local fields = {{
        name='Server Details',
        value=string.format('Server name: ${serverName} Players: %d Admins: %d Time: %s',players_online,admins_online,tick_formated)
    }}

    for key,value in pairs(args) do
        if not done[key] then
            done[key] = true
            local field = {
                name=key,
                value=value,
                inline=false
            }

            local new_value, inline = value:gsub('<inline>','',1)
            if inline then
                field.value = new_value
                field.inline = true
            end

            table.insert(fields,field)
        end
    end

    write_json('log/discord.log',{
        title=title,
        description=description,
        color=color,
        fields=fields
    })
end

--- Reports added and removed
if config.player_reports then
    local Reports = require 'modules.addons.reports-control'
    Event.add(Reports.events.on_player_reported,function(event)
        local player_name,by_player_name = get_player_name(event)
        emit_event{
            title='Report',
            description='A player was reported',
            color=Colors.yellow,
            ['Player:']='<inline>'..player_name,
            ['By:']='<inline>'..by_player_name,
            ['Reason:']=event.reason
        }
    end)
    Event.add(Reports.events.on_player_report_removed,function(event)
        local player_name,by_player_name = get_player_name(event)
        emit_event{
            title='Report Removed',
            description='A player has a report removed',
            color=Colors.green,
            ['Player:']='<inline>'..player_name,
            ['By:']='<inline>'..by_player_name
        }
    end)
end

--- Warnings added and removed
if config.player_warnings then
    local Warnings = require 'modules.addons.warnings-control'
    Event.add(Warnings.events.on_player_warned,function(event)
        local player_name,by_player_name = get_player_name(event)
        emit_event{
            title='Warning',
            description='A player has been given a warning',
            color=Colors.yellow,
            ['Player:']='<inline>'..player_name,
            ['By:']='<inline>'..by_player_name
        }
    end)
    Event.add(Warnings.events.on_player_warning_removed,function(event)
        local player_name,by_player_name = get_player_name(event)
        emit_event{
            title='Warning Removed',
            description='A player has a warning removed',
            color=Colors.green,
            ['Player:']='<inline>'..player_name,
            ['By:']='<inline>'..by_player_name
        }
    end)
end

--- Ban and unban
if config.player_bans then
    Event.add(defines.events.on_player_banned,function(event)
        if event.by_player then
            local by_player = Game.get_player_by_index(event.by_player)
            emit_event{
                title='Banned',
                description='A player has been banned',
                color=Colors.red,
                ['Player:']='<inline>'..event.player_name,
                ['By:']='<inline>'..by_player.name,
                ['Reason:']=event.reason
            }
        end
    end)
    Event.add(defines.events.on_player_unbanned,function(event)
        if event.by_player then
            local by_player = Game.get_player_by_index(event.by_player)
            emit_event{
                title='Un-Banned',
                description='A player has been un-banned',
                color=Colors.green,
                ['Player:']='<inline>'..event.player_name,
                ['By:']='<inline>'..by_player.name
            }
        end
    end)
end

--- Mute and unmute
if config.player_mutes then
    Event.add(defines.events.on_player_muted,function(event)
        local player_name = get_player_name(event)
        emit_event{
            title='Muted',
            description='A player has been muted',
            color=Colors.yellow,
            ['Player:']='<inline>'..player_name
        }
    end)
    Event.add(defines.events.on_player_unmuted,function(event)
        local player_name = get_player_name(event)
        emit_event{
            title='Un-Muted',
            description='A player has been un-muted',
            color=Colors.green,
            ['Player:']='<inline>'..player_name
        }
    end)
end

--- Kick
if config.player_kicks then
    Event.add(defines.events.on_player_kicked,function(event)
        if event.by_player then
            local player_name = get_player_name(event)
            local by_player = Game.get_player_by_index(event.by_player)
            emit_event{
                title='Kick',
                description='A player has been kicked',
                color=Colors.orange,
                ['Player:']='<inline>'..player_name,
                ['By:']='<inline>'..by_player.name,
                ['Reason:']=event.reason
            }
        end
    end)
end

--- Promote and demote
if config.player_promotes then
    Event.add(defines.events.on_player_promoted,function(event)
        local player_name = get_player_name(event)
        emit_event{
            title='Promote',
            description='A player has been promoted',
            color=Colors.green,
            ['Player:']='<inline>'..player_name
        }
    end)
    Event.add(defines.events.on_player_demoted,function(event)
        local player_name = get_player_name(event)
        emit_event{
            title='Demote',
            description='A player has been demoted',
            color=Colors.yellow,
            ['Player:']='<inline>'..player_name
        }
    end)
end

--- Other commands
Event.add(defines.events.on_console_command,function(event)
    if event.player_index then
        local player_name = get_player_name(event)
        if config[event.command] then
            emit_event{
                title=event.command:gsub('^%l',string.upper),
                description='/'..event.command..' was used',
                color=Colors.grey,
                ['By:']='<inline>'..player_name,
                ['Details:']=event.parameters
            }
        end
    end
end)