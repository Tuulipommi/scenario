--- Command system that allows middle ware and auto validation of command arguments.
-- @module ExpGamingCore.Command@4.0.0
-- @author Cooldude2606
-- @license https://github.com/explosivegaming/scenario/blob/master/LICENSE
-- @alias commands

local Game = require('FactorioStdLib.Game')
local Color = require('FactorioStdLib.Color')

--- Used as an error constant for validation
-- @field commands.error
-- @usage return commands.error, 'err message'
-- @usage return commands.error('err message')
commands.error = setmetatable({},{__call=function(...) return ... end})
commands._add_command = commands.add_command
local commandDataStore = {}
local middleware = {}

--- Used to add middle ware to the command handler, functions should return true or false
-- @tparam function callback function(player,commandName,event) should return true to allow next middle ware to run
function commands.add_middleware(callback) if not is_type(callback,'function') then error('Callback is not a function',2) return end table.insert(middleware,callback) end

--- Index of all command data
-- @field commands.data
-- @usage commands.command_name -- returns command data
-- @usage commands.data -- returns all data
-- @tparam string table ?string|table|event key the command that will be returned: is the name, is the command data, event is event from add_command
-- @treturn table the command data
setmetatable(commands,{
    __index=function(tbl,key) return is_type(key,'table') and (key.command and rawget(commandDataStore,key.name) or key) or key == 'data' and commandDataStore or rawget(commandDataStore,key) end
})

--- Collection of functions that can be used to validate inputs
-- @table commands.validate
-- @usage commands.validate[type](value,event,...)
-- @tparam string type the type that the value should be
-- @param value the value that will be tested
-- @param ... any other data that can be passed to the function
-- @return[1] the validated value
-- @return[2] error constant
-- @return[2] the err message
-- @field __comment replace _ with - the ldoc did not like me using - in the names
-- @field string basically does nothing but a type filed is required
-- @field string_inf same as string but is infinite in length, must be last arg
-- @field string_len same as string but can define a max length
-- @field number converts the input into a number
-- @field number_int converts the input to a number and floors it
-- @field number_range allows a number in a range min < X <= max
-- @field number_range allows a number in a range after it has been floored min < math.floor(X) <= max
-- @field player converts the input into a valid player
-- @field player_online converts the input to a player if the player is online
-- @field player_alive converts the input to a player if the player is online and alive
-- @field player_role converts the input to a player if the player is a lower rank than the user or if the person is not admin and the user is
-- @field player_role-online converts the input to a player if the player is a lower rank than the user and online
-- @field player_role_alive converts the input to a player if the player is a lower rank than the user and online and alive
commands.validate = {
    ['boolean']=function(value) value = value.lower() if value == 'true' or value == 'yes' or value == 'y' or value == '1' then return true else return false end end,
    ['string']=function(value) return tostring(value) end,
    ['string-inf']=function(value) return tostring(value) end,
    ['string-list']=function(value,event,list)
        local rtn = tostring(value) and table.includes(list,tostring(value)) and tostring(value) or nil
        if not rtn then return commands.error{'expcore-commands.error-string-list',table.concat(list,', ')} end return rtn end,
    ['string-len']=function(value,event,max)
        local rtn = tostring(value) and tostring(value):len() <= max and tostring(value) or nil 
        if not rtn then return commands.error{'expcore-commands.error-string-len',max} end return rtn end,
    ['number']=function(value)
        local rtn = tonumber(value) or nil
        if not rtn then return commands.error{'expcore-commands.error-number'} end return rtn end,
    ['number-int']=function(value)
        local rtn = tonumber(value) and math.floor(tonumber(value)) or nil
        if not rtn then return commands.error{'expcore-commands.error-number'} end return rtn end,
    ['number-range']=function(value,event,min,max)
        local rtn = tonumber(value) and tonumber(value) > min and tonumber(value) <= max and tonumber(value) or nil
        if not rtn then return commands.error{'expcore-commands.error-number-range',min,max} end return rtn end,
    ['number-range-int']=function(value,event,min,max)
        local rtn = tonumber(value) and math.floor(tonumber(value)) > min and math.floor(tonumber(value)) <= max and math.floor(tonumber(value)) or nil
        if not rtn then return commands.error{'expcore-commands.error-number-range',min,max} end return rtn end,
    ['player']=function(value)
        local rtn = Game.get_player(value) or nil
        if not rtn then return commands.error{'expcore-commands.error-player',value} end return rtn end,
    ['player-online']=function(value)
        local player,err = commands.validate['player'](value)
        if err then return commands.error(err) end
        local rtn = player.connected and player or nil
        if not rtn then return commands.error{'expcore-commands.error-player-online'} end return rtn end,
    ['player-alive']=function(value)
        local player,err = commands.validate['player-online'](value)
        if err then return commands.error(err) end
        local rtn = player.character and player.character.health > 0 and player or nil
        if not rtn then return commands.error{'expcore-commands.error-player-alive'} end return rtn end,
    ['player-rank']=function(value,event)
        local player,err = commands.validate['player'](value)
        if err then return commands.error(err) end
        local rtn = player.admin and Game.get_player(event).admin and player or nil
        if not rtn then return commands.error{'expcore-commands.error-player-rank'} end return rtn end,
    ['player-rank-online']=function(value)
        local player,err = commands.validate['player-online'](value)
        if err then return commands.error(err) end
        local player,err = commands.validate['player-rank'](player)
        if err then return commands.error(err) end return player end,
    ['player-rank-alive']=function(value)
        local player,err = commands.validate['player-alive'](value)
        if err then return commands.error(err) end
        local player,err = commands.validate['player-rank'](player)
        if err then return commands.error(err) end return player end,
}
--- Adds a function to the validation list
-- @tparam string name the name of the validation
-- @tparam function callback function(value,event) which returns either the value to be used or commands.error{'error-message'}
function commands.add_validation(name,callback) if not is_type(callback,'function') then error('Callback is not a function',2) return end commands.validate[name]=callback end

--- Returns the inputs of this command as a formated string
-- @usage commands.format_inputs('interface') -- returns <code> (if you have ExpGamingCore.Server)
-- @tparam ?string|table|event command the command to get the inputs of
-- @treturn string the formated string for the inputs
function commands.format_inputs(command)
    command = commands[command]
    if not is_type(command,'table') then error('Command is not valid',2) end
    local rtn = ''
    for name,data in pairs(command.inputs) do
        if data[1] == false then rtn=rtn..string.format('[%s] ',name)
        else rtn=rtn..string.format('<%s> ',name) end
    end
    return rtn
end

--- Used to validate the arguments of a command, will understand strings with "" as a single param else spaces divede the params
-- @usage commands.validate_args(event) -- returns args table
-- @tparam table event this is the event created by add_command not on_console_command
-- @treturn[1] table the args for this command
-- @return[2] command.error
-- @treturn string the error that happend while parsing the args
function commands.validate_args(event)
    local command = commands[event.name]
    if not is_type(command,'table') then error('Command not valid',2) end
    local rtn = {}
    local count = 0
    local count_opt = 0
    for _,data in pairs(command.inputs) do count = count + 1 if data[1] == false then count_opt = count_opt + 1 end end
    -- checks that there is some args given if there is meant to be
    if not event.parameter then
        if count == count_opt then return rtn
        else return commands.error('invalid-inputs') end
    end
    -- splits the args into words so that it can be used to assign values
    local words = string.split(event.parameter,' ')
    local index = 0
    for _,word in pairs(words) do
        index = index+1
        if not word then break end
        local pos, _pos = word:find('"')
        local hasSecond = pos and word:find('"',pos+1) or nil
        while not hasSecond and pos and pos == _pos do
            local next = table.remove(words,index+1)
            if not next then return commands.error('invalid-parse') end
            words[index] = words[index]..' '..next
            _pos = words[index]:find('"',pos+1)
        end
    end
    -- assigns the values from the words to the args
    index = 0
    for name,data in pairs(command.inputs) do
        index = index+1
        local arg = words[index]
        if not arg and data[1] then return commands.error('invalid-inputs') end
        if data[2] == 'string-inf' then rtn[name] = table.concat(words,' ',index) break end
        local valid = is_type(data[2],'function') and data[2] or commands.validate[data[2]] or error('Invalid validation ("'..tostring(data[2])..'") for command: "'..command.name..'/'..name..'"')
        local temp_tbl = table.deepcopy(data) table.remove(temp_tbl,1) table.remove(temp_tbl,1)
        local value, err = valid(arg,event,unpack(temp_tbl))
        if value == commands.error then return value, err end
        rtn[name] = is_type(value,'string') and value:gsub('"','') or value
    end
    return rtn
end

--- Used to return all the commands a player can use
-- @usage get_commands(1) -- return table of command data for each command that the player can use
-- @tparam ?index|name|player| player the player to test as
-- @treturn table a table containg all the commands the player can use
function commands.get_commands(player)
    player = Game.get_player(player)
    local commands = {}
    if not player then return error('Invalid player',2) end
    for name,data in pairs(commandDataStore) do
        if #middleware > 0 then for _,callback in pairs(middleware) do
            local success, err = pcall(callback,player,name,data)
            if not success then error(err)
            elseif err then table.insert(commands,data) end
        end elseif data.default_admin_only == true and player.admin then table.insert(commands,data) end
    end
    return commands
end

local function logMessage(player_name,command,message,args)
    game.write_file('commands.log',
        game.tick
        ..' Player: "'..player_name..'"'
        ..' '..message..': "'..command.name..'"'
        ..' With args of: '..table.tostring(args)
        ..'\n'
    , true, 0)
end

--- Used to call the custom commands
-- @usage You dont its an internal command
-- @tparam table command the event rasied by the command
local function run_custom_command(command)
    local data = commands.data[command.name]
    local player = Game.get_player(command) or SERVER
    -- runs all middle ware if any, if there is no middle where then it relies on .default_admin_only
    if #middleware > 0 then for _,callback in pairs(middleware) do
        local success, err = pcall(callback,player,command.name,command)
        if not success then error(err)
        elseif not err then
            player_return({'expcore-commands.command-fail',{'expcore-commands.unauthorized'}},defines.textcolor.crit)
            logMessage(player.name,command,'Failed to use command (Unauthorized)',commands.validate_args(command))
            game.player.play_sound{path='utility/cannot_build'}
            return
        end
    end elseif data.default_admin_only == true and player and not player.admin then
        player_return({'expcore-commands.command-fail',{'expcore-commands.unauthorized'}},defines.textcolor.crit)
        logMessage(player.name,command,'Failed to use command (Unauthorized)',commands.validate_args(command))
        game.player.play_sound{path='utility/cannot_build'}
        return
    end
    -- gets the args for the command
    local args, err = commands.validate_args(command)
    if args == commands.error then
        if is_type(err,'table') then table.insert(err,command.name) table.insert(err,commands.format_inputs(data))
        player_return({'expcore-commands.command-fail',err},defines.textcolor.high) else player_return({'expcore-commands.command-fail',{'expcore-commands.invalid-inputs',command.name,commands.format_inputs(data)}},defines.textcolor.high) end
        logMessage(player.name,command,'Failed to use command (Invalid Args)',args)
        player.play_sound{path='utility/deconstruct_big'}
        return
    end
    -- runs the command
    local success, err = pcall(data.callback,command,args)
    if not success then error(err) end
    if err ~= commands.error then player_return({'expcore-commands.command-ran'},defines.textcolor.info) end
    logMessage(player.name,command,'Used command',args)
end

--- Used to define commands
-- @usage --see examples in file
-- @tparam string name the name of the command
-- @tparam[opt='No string Description'] description the description of the command
-- @tparam[opt=an table table infinite string] inputs a of the inputs to be used, last index being true makes the last parameter open ended (longer than one word)
-- @tparam function function callback the to call on the event
commands.add_command = function(name, description, inputs, callback)
    if commands[name] then error('That command is already registered',2) end
    if not is_type(name,'string') then error('Command name has not been given') end
    if not is_type(callback,'function') or not is_type(inputs,'table') then
        if is_type(inputs,'function') then commands._add_command(name,description,inputs) 
        else error('Invalid args given to add_command') end
    end
    verbose('Created Command: '..name)
    -- test for string and then test for locale string
    description = is_type(description,'string') and description
    or is_type(description,'table') and is_type(description[1],'string') and string.find(description[1],'.+[.].+') and {description,''}
    or 'No Description'
    inputs = is_type(inputs,'table') and inputs or {['param']={false,'string-inf'}}
    commandDataStore[name] = {
        name=name,
        description=description,
        inputs=inputs,
        callback=callback,
        admin_only=false
    }
    local help = is_type(description,'string') and commands.format_inputs(name)..'- '..description
    or is_type(description,'table') and is_type(description[1],'string') and string.find(description[1],'.+[.].+') and {description,commands.format_inputs(name)..'- '}
    or commands.format_inputs(name)
    commandDataStore[name].help = help
    commands._add_command(name,help,function(...)
        local success, err = Manager.sandbox(run_custom_command,{},...)
        if not success then error(err) end
    end)
    return commandDataStore[name]
end

return commands

--[[
    command example

    **locale file**
    [foo]
    description=__1__ this is a command

    **control.lua**
    commands.add_command('foo',{'foo.description'},{
        ['player']={true,'player'}, -- a required arg that must be a valid player
        ['number']={true,'number-range',0,10}, -- a required arg that must be a number 0<X<=10
        ['pwd']={true,function(value,event) if value == 'password123' then return true else return commands.error('Invalid Password') end} -- a required arg pwd that has custom validation
        ['reason']={false,'string-inf'} -- an optional arg that is and infinite length (useful for reasons)
    },function(event,args)
        args.player.print(args.number)
        if args.reasons then args.player.print(args.reason) end
    end)
]]