--- The base functions required to make the others work.
-- @module ExpGamingAdmin.AdminLib@4.0.0
-- @author Cooldude2606
-- @license https://github.com/explosivegaming/scenario/blob/master/LICENSE
-- @alais Admin 

-- Module Require
local Game = require('FactorioStdLib.Game@^0.8.0')
local Role -- ExpGamingCore.Role@^4.0.0
local Sync -- ExpGamingCore.Sync@^4.0.0

-- Module Define
local module_verbose = false
local Admin = {
    on_init=function()
        if loaded_modules['ExpGamingCore.Role@^4.0.0'] then Role = require('ExpGamingCore.Role@^4.0.0') end
        if loaded_modules['ExpGamingCore.Sync@^4.0.0'] then Sync = require('ExpGamingCore.Sync@^4.0.0') end
        if loaded_modules['ExpGamingCore.Server@^4.0.0'] then require('ExpGamingCore.Server@^4.0.0').add_module_to_interface('Admin','ExpGamingAdmin.AdminLib') end
    end,
    actions={},
    action_names={}
}

-- Global Define
local global = global{
    banned = {}
}

-- Function Define
function Admin.create_reason(reason,name)
    local reason = reason or 'No Reason'
    if not string.find(string.lower(reason),string.lower(name)) then reason = reason..' - '..name end
    if Sync and Sync.info.date ~= '0000/00/00' and not string.find(string.lower(reason),Sync.info.date) then reason = reason..' - '..Sync.info.date end
    if not string.find(string.lower(reason),'appeal') then reason = reason..' - Vist www.explosivegaming.nl to appeal.' end
    return reason
end

function Admin.open(player,pre_select_player,pre_select_action)
    if Admin.center then Gui.center.clear(player) Admin.center.open(player,pre_select_player,pre_select_action) end
end

function Admin.allowed(player)
    local player = Game.get_player(player)
    if Role then
        return Role.allowed(player,'admin-commands')
    else return player.admin end
end

function Admin.set_banned(player,set)
    local player=Game.get_player(player)
    if not player then return false end
    global.banned[player.name] = set
end

function Admin.is_banned(player,detail)
    local player=Game.get_player(player)
    if not player then return false end
    local banned = global.banned[player.name]
    if banned == true then return true end
    if not banned then return false end
    if detail then return banned
    else return true end
end

function Admin.add_action(action,callback)
    verbose('Added admin action: '..action)
    table.insert(Admin.action_names,action)
    Admin.actions[string.lower(action)] = callback
end

function Admin.take_action(action,player,by_player,reason)
    if Admin[action] then Admin[action](player,by_player,reason) end
    if Admin.actions[string.lower(action)] then Admin.actions[string.lower(action)](player,by_player,reason) end
end

function Admin.clear_player(player,by_player)
    local player, by_player_name = valid_players(player,by_player)
    if not player then return end
    if Admin.is_banned(player,true) == true then Server.interface(game.unban_player,true,player,by_player) end
    if Admin.clear_warings then Admin.clear_warings(player,by_player,true) end
    if Admin.clear_reports then Admin.clear_reports(player,by_player,true) end
    if Role.has_flag(player,'is_jail') then Server.interface(Role.revert,true,player,by_player,2) end
    if Sync then Sync.emit_embeded{
        title='Player Clear',
        color=Color.to_hex(defines.textcolor.low),
        description='A player had their reports and warnings cleared.',
        ['Player:']='<<inline>>'..player.name,
        ['By:']='<<inline>>'..by_player_name,
    } end
    Admin.set_banned(player,false)
end

-- Module Return
return Admin 