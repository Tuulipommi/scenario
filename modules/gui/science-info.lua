--- Adds a science info gui that shows production usage and net for the different science packs as well as an eta
local Gui = require 'expcore.gui'
local Event = require 'utils.event'
local Colors = require 'resources.color_presets'
local format_time = ext_require('expcore.common','format_time')
local format_number = ext_require('util','format_number')
local config = require 'config.science'

local null_time_short = {'science-info.eta-time',format_time(0,{hours=true,minutes=true,seconds=true,time=true,null=true})}
local null_time_long = format_time(0,{hours=true,minutes=true,seconds=true,long=true,null=true})

--- Gets the production stats for a certain science pack
local function get_production_stats(player,science_pack)
    local force = player.force
    local stats = force.item_production_statistics
    local total_made = stats.get_input_count(science_pack)
    local total_used = stats.get_output_count(science_pack)
    local minute_made = stats.get_flow_count{
        name=science_pack,
        input=true,
        precision_index=defines.flow_precision_index.one_minute,
    }
    local minute_used = stats.get_flow_count{
        name=science_pack,
        input=false,
        precision_index=defines.flow_precision_index.one_minute,
    }
    return {
        total_made=total_made,
        total_used=total_used,
        total_net=total_made-total_used,
        minute_made=minute_made,
        minute_used=minute_used,
        minute_net=minute_made-minute_used
    }
end

--- Gets the font colour for a certain level of production
local function get_font_colour(value,secondary)
    if value > config.required_for_green then
        return Colors.light_green
    elseif value < config.required_for_red then
        return Colors.indian_red
    elseif secondary and secondary > 0 or not secondary and value ~= 0 then
        return Colors.orange
    else
        return Colors.grey
    end
end

--[[ Generates the main structure for the gui
    element
    > container
    >> header
    >> scroll
    >>> non_made
    >>> table
    >> footer (when eta is enabled)
    >>> eta-label
    >>> eta
    >>>> label
]]
local function generate_container(player,element)
    Gui.set_padding(element,1,2,2,2)
    element.style.minimal_width = 200

    -- main container which contains the other elements
    local container =
    element.add{
        name='container',
        type='frame',
        direction='vertical',
        style='window_content_frame_packed'
    }
    Gui.set_padding(container)

    -- main header for the gui
    Gui.create_header(
        container,
        {'science-info.main-caption'},
        {'science-info.main-tooltip'}
    )

    -- table that stores all the data
    local flow_table = Gui.create_scroll_table(container,4,185)

    -- message to say that you have not made any packs yet
    local non_made =
    flow_table.parent.add{
        name='non_made',
        type='label',
        caption={'science-info.no-packs'}
    }
    non_made.style.width = 200
    non_made.style.single_line = false

    local eta
    if config.show_eta then
        -- footer used to store the eta
        local footer =
        container.add{
            name='footer',
            type='frame',
            style='subheader_frame'
        }
        Gui.set_padding(footer,2,2,4,4)
        footer.style.horizontally_stretchable = true

        -- label for the footer
        footer.add{
            name='eta-label',
            type='label',
            caption={'science-info.eta-caption'},
            tooltip={'science-info.eta-tooltip'},
            style='heading_1_label'
        }

        -- data for the footer
        local right_align = Gui.create_alignment(footer,'eta')
        eta =
        right_align.add{
            name='label',
            type='label',
            caption=null_time_short,
            tooltip=null_time_long,
            style='heading_1_label'
        }
    end

    return flow_table, eta
end

--[[ Adds two labels where one is right aligned and the other is a unit
    element
    > "name"
    >> label
    > spm-"name"
]]
local function add_data_label(element,name,value,secondary,tooltip)
    local data_colour = get_font_colour(value,secondary)
    local caption = format_number(math.round(value,1),true)

    local surfix = caption:sub(-1)
    if not tonumber(surfix) then
        caption = caption:sub(1,-2)
    else
        surfix = ''
    end

    if value > 0 then
        caption = '+'..caption
    elseif value == 0 and caption:sub(1,1) == '-' then
        caption = caption:sub(2)
    end

    if element[name] then
        local data = element[name].label
        data.caption = caption
        data.tooltip = tooltip
        data.style.font_color = data_colour
        local label = element['spm-'..name]
        label.caption = {'science-info.unit',surfix}
        label.tooltip = tooltip
        label.style.font_color = data_colour

    else
        -- right aligned number
        local right_align = Gui.create_alignment(element,name)
        local data =
        right_align.add{
            name='label',
            type='label',
            caption=caption,
            tooltip=tooltip
        }
        data.style.font_color = data_colour

        -- adds the unit onto the end
        local label =
        element.add{
            name='spm-'..name,
            type='label',
            caption={'science-info.unit',surfix},
            tooltip=tooltip
        }
        label.style.font_color = data_colour
    end
end

--[[ Adds a science pack to the list
    element
    > icon-"science_pack"
    > delta-"science_pack"
    >> table
    >>> pos-"science_pack" (add_data_label)
    >>> neg-"science_pack" (add_data_label)
    > net-"science_pack" (add_data_label)
]]
local function generate_science_pack(player,element,science_pack)
    local stats = get_production_stats(player,science_pack)
    if stats.total_made > 0 then
        element.parent.non_made.visible = false

        local icon_style = 'quick_bar_slot_button'
        if stats.minute_net > config.required_for_green then
            icon_style = 'green_slot_button'
        elseif stats.minute_net < config.required_for_red then
            icon_style = 'red_slot_button'
        elseif stats.minute_made > 0 then
            icon_style = 'selected_slot_button'
        end

        local icon = element['icon-'..science_pack]

        if icon then
            icon.style = icon_style
            icon.style.height = 55
            if icon_style == 'quick_bar_slot_button' then
                icon.style.width = 36
                Gui.set_padding(icon,0,0,-2,-2)
            end

        else
            icon =
            element.add{
                name='icon-'..science_pack,
                type='sprite-button',
                sprite='item/'..science_pack,
                tooltip={'item-name.'..science_pack},
                style=icon_style
            }
            icon.style.height = 55
            if icon_style == 'quick_bar_slot_button' then
                icon.style.width = 36
                Gui.set_padding(icon,0,0,-2,-2)
            end

        end

        local delta = element['delta-'..science_pack]

        if not delta then
            delta =
            element.add{
                name='delta-'..science_pack,
                type='frame',
                style='bordered_frame'
            }
            Gui.set_padding(delta,0,0,3,3)

            local delta_table =
            delta.add{
                name='table',
                type='table',
                column_count=2
            }
            Gui.set_padding(delta_table)
        end

        add_data_label(delta.table,'pos-'..science_pack,stats.minute_made,nil,{'science-info.pos-tooltip',stats.total_made})
        add_data_label(delta.table,'neg-'..science_pack,-stats.minute_used,nil,{'science-info.neg-tooltip',stats.total_used})
        add_data_label(element,'net-'..science_pack,stats.minute_net,stats.minute_made+stats.minute_used,{'science-info.net-tooltip',stats.total_net})
    end
end

--- Updates the eta label that was created with generate_container
local function update_eta(player,element)
    if not config.show_eta then return end
    local force = player.force
    local research = force.current_research
    if not research then
        element.caption = null_time_short
        element.tooltip = null_time_long

    else
        local progress = force.research_progress
        local remaining = research.research_unit_count*(1-progress)
        local limit

        local stats = player.force.item_production_statistics
        for _,ingredient in pairs(research.research_unit_ingredients) do
            local pack_name = ingredient.name
            local required = ingredient.amount * remaining
            local consumed = stats.get_flow_count{
                name=pack_name,
                input=false,
                precision_index=defines.flow_precision_index.one_minute,
            }
            if consumed == 0 then
                limit = -1
                break
            end
            local minutes = required / consumed
            if not limit or limit < minutes then
                limit = minutes
            end
        end

        if not limit or limit == -1 then
            element.caption = null_time_short
            element.tooltip = null_time_long

        else
            local ticks = limit*3600
            element.caption = {'science-info.eta-time',format_time(ticks,{hours=true,minutes=true,seconds=true,time=true})}
            element.tooltip = format_time(ticks,{hours=true,minutes=true,seconds=true,long=true})

        end
    end
end

--- Registerse the new science info gui
local science_info =
Gui.new_left_frame('gui/science-info')
:set_sprites('entity/lab')
:set_direction('vertical')
:set_tooltip{'science-info.main-tooltip'}
:on_creation(function(player,element)
    local table, eta = generate_container(player,element)

    for _,science_pack in ipairs(config) do
        generate_science_pack(player,table,science_pack)
    end

    update_eta(player,eta)
end)
:on_update(function(player,element)
    local container = element.container
    local table = container.scroll.table
    local eta = container.footer.eta.label

    for _,science_pack in ipairs(config) do
        generate_science_pack(player,table,science_pack)
    end

    update_eta(player,eta)
end)

--- Updates the gui every 1 second
Event.on_nth_tick(60,science_info 'update_all')

return science_info