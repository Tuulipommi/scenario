local Game = require 'utils.game'
local Global = require 'utils.global'

local Reports = {
    user_reports={},
    events = {
        on_player_reported = script.generate_event_name(),
        on_player_report_removed = script.generate_event_name()
    }
}

Global.register(Reports.user_reports,function(tbl)
    Reports.user_reports = tbl
end)

local function event_emit(event,player,by_player_name)
    local reports = Reports.user_reports[player.name]
    local reason = reports and reports[by_player_name]
    script.raise_event(event,{
        name=event,
        tick=game.tick,
        player_index=player.index,
        by_player_name=by_player_name,
        reason=reason
    })
end

--- Adds a report to a player, reports are stored in global table and can be accessed later
-- @tparam LuaPlayer player the player that will be reported
-- @tparam[opt='Non string Given.'] reason the reason that the player is being reported
-- @tparam[opt='<server>'] string by_player_name the name of the player doing the action
-- @treturn boolean true if the report was added, nil if there is an error
function Reports.report_player(player,reason,by_player_name)
    player = Game.get_player_from_any(player)
    if not player then return end
    reason = reason or 'Non Given.'
    by_player_name = by_player_name or '<server>'
    local reports = Reports.user_reports[player.name]
    if not reports then
        Reports.user_reports[player.name] = {
            [by_player_name] = reason
        }
    elseif not reports[by_player_name] then
        reports[by_player_name] = reason
    else return false end
    event_emit(Reports.events.on_player_reported,player,by_player_name)
    return true
end

--- Removes a report from a player by the given player, see clear_player_reports to remove all
-- @tparam LuaPlayer player the player that will have the report removed
-- @tparam[opt='<server>'] string by_player_name the name of the player doing the action
-- @treturn boolean true if the report was removed, nil if there was an error
function Reports.remove_player_report(player,by_player_name)
    player = Game.get_player_from_any(player)
    if not player then return end
    by_player_name = by_player_name or '<server>'
    local reports = Reports.user_reports[player.name]
    if reports and reports[by_player_name] then
        event_emit(Reports.events.on_player_report_removed,player,by_player_name)
        reports[by_player_name] = nil
        if Reports.count_player_reports(player) == 0 then
            Reports.user_reports[player.name] = nil
        end
        return true
    end
    return false
end

--- Clears all reports from a player, will emit an event for each individual report as if remove_player_report was used
-- @tparam LuaPlayer player the player to clear the reports of
-- @treturn boolean true if the reports were cleared, nil if error
function Reports.clear_player_reports(player)
    player = Game.get_player_from_any(player)
    if not player then return end
    local reports = Reports.user_reports[player.name]
    if reports then
        for by_player_name,reason in pairs(reports) do
            event_emit(Reports.events.on_player_report_removed,player,by_player_name)
        end
        Reports.user_reports[player.name] = nil
        return true
    end
    return false
end

--- Test for if a player has been reported by another player, can also return the reason from that player
-- @tparam LuaPlayer player the player to check the reports of
-- @tparam string by_player_name the player that made if the report if present (note server is not default here)
-- @tparam[opt=false] boolean rtn_reason true will return the reason for the report rather than a boolean
-- @treturn boolean true if a report from the player is present unless rtn_reason is true when a string is returned (or false)
function Reports.player_is_reported_by(player,by_player_name,rtn_reason)
    player = Game.get_player_from_any(player)
    if not player then return end
    local reports = Reports.user_reports[player.name]
    if reports and reports[by_player_name] then
        return rtn_reason and reports[by_player_name] or true
    end
    return false
end

--- Gets all the reports that are on a player
-- @tparam LuaPlayer player the player to get the reports of
-- @treturn table a table of all the reports for this player, empty table if no reports
function Reports.get_player_reports(player)
    player = Game.get_player_from_any(player)
    if not player then return end
    return Reports.user_reports[player.name] or {}
end

--- Counts all reports on a player returning a number, a custom count function can be given which should return a number
-- @tparam LuaPlayer player the player to count the reports of
-- @tparam[opt] number function count_callback should return a or true (for 1) this will be passed every report on the player
-- count_callback param - player_name string - the name of the player who made the report
-- count_callback param - reason string - the reason the reason was made
-- count_callback return - number or boolean - if number then this will be added to the count, if boolean then false = 0 and true = 1
-- @treturn number the number of reports on the player
function Reports.count_player_reports(player,count_callback)
    player = Game.get_player_from_any(player)
    if not player then return end
    local reports = Reports.user_reports[player.name] or {}
    if not count_callback then
        local ctn = 0
        for _ in pairs(reports) do
            ctn=ctn+1
        end
        return ctn
    else
        local ctn = 0
        for player_name,reason in pairs(reports) do
            local success,err = pcall(count_callback,player_name,reason)
            if success and err then
                if err == true then err = 1 end
                ctn = ctn+err
            end
        end
        return ctn
    end
end

return Reports