
-- storage == global


local function replace_roboport(grid, old, new_name)

   local pos = old.position
   local energy = old.energy
   grid.take{ position = old.position }
   local new = grid.put{ name = new_name, position = pos }
   if new then
      new.energy = energy
   else
      game.print("Error in closest-first: could not replace roboport. Please report it on the mod page.")
   end
end

local function get_orig_range(eq)
   return eq.prototype.take_result.place_as_equipment_result.logistic_parameters.construction_radius
end


local function get_original_range(g)
   local original_range = 0
   for _, eq in next, g.equipment do
      if eq.type == "roboport-equipment" then
         original_range = original_range + get_orig_range(eq)
      end
   end
   return original_range
end

local function find_close_entities_swinter(player, area)
   return player.surface.find_entities_filtered{area = area, force = {player.force, "neutral"}}
end

local function find_close_entities(player)
   local logistic = player.character.logistic_network
   local grid = player.character.grid
   if logistic and logistic.all_construction_robots > 0 and logistic.robot_limit > 0 and grid then
      local limit_area = 10 --d.range_setting_table[settings.get_player_settings(player)[d.limit_area_setting].value]
      local original_range = 2 * get_original_range(grid)
      if limit_area > 0 then
         original_range = math.min(original_range, limit_area)
      end
      original_range = original_range / 2
      if original_range <= 0 then return nil end
      local search_area_radius = 5 --d.range_setting_table[settings.global[d.search_area_setting].value] / 2;
      if search_area_radius <= 0 then search_area_radius = original_range end

      -- Search the smallest of the original range and the setting
      local radius = math.min(original_range, search_area_radius)
      local pos = player.position;
      local px = pos.x
      local py = pos.y -- I'm just unrolling everything now...
      local area = {
         {px-radius, py-radius},
         {px+radius, py+radius}}
      return player.surface.find_entities_filtered{area = area, force = {player.force, "neutral"}}
   end
   return nil
end

local function get_eq_radius(eq)
   return eq.prototype.take_result.place_as_equipment_result.logistic_parameters.construction_radius
end


local function get_grid_radius(grid)
   -- the area of each individual roboport is added to the total area.
   -- we then take the squareroot of the total area to get the edge -> /2 -> radius.
   local area = 0
   for _, eq in pairs(grid.equipment) do
      if eq.type == "roboport-equipment" then
         local radius = get_eq_radius(eq) * 2 -- the radius is half the edge length
         
         area = area + (radius * radius)
      end
   end
   game.print("total area: ".. area)
   local area_edge = math.sqrt(area)
   game.print("area_edge: ".. area_edge)
   -- /2 because we need the radius
   return math.floor((area_edge/2) + 0.5) -- round
end

local function get_eq_robot_limit(eq)
   return eq.prototype.logistic_parameters.robot_limit
end

local function get_grid_robot_limit(grid)
   local limit = 0
   for _, eq in next, grid.equipment do
      if eq.type == "roboport-equipment" then
         limit = limit + get_eq_robot_limit(eq)
      end
   end
   return limit
end




local function tick()

   --only firee every 10 ticks
   if game.tick % 10 ~= 0 then
       --return
   end
   game.print("tick");
   
   --local found = find_close_entities(game.players[1])
   --game.print("found: ".. #found)
   local player = game.players[1]
   local player_pos = player.position
   local grid = player.character.grid
   local grid_radius = get_grid_radius(grid)
   game.print("grid radius: ".. grid_radius)
   local area = {
     {player_pos.x - grid_radius, player_pos.y - grid_radius},
     {player_pos.x + grid_radius, player_pos.y + grid_radius}
   }
   local found_entitys = find_close_entities_swinter(game.players[1], area)
   --for every item found draw a circle as around it
   for _, entity in pairs(found_entitys) do
      if entity.valid and entity.type ~= "character" then
         local pos = entity.position

         rendering.draw_circle{
            color = {r = 1, g = 0, b = 0, a = 1},
            radius = 0.3,                -- tiles (small)
            filled = true,
            target = pos,    -- center at player
            surface = entity.surface,
            time_to_live = 1,       -- 5 seconds
            draw_on_ground = false
         }
      end
   end

   --draw range
   
   rendering.draw_rectangle{
      surface = player.surface, 
      left_top = area[1], 
      right_bottom = area[2], 
      color = {1, 1, 1},
      time_to_live = 1
   }



    --local n = math.random(1, 5)
    


    for _, eq in pairs(grid.equipment) do
        if eq.type == "roboport-equipment" then
            --game.print("range: ".. eq.prototype.take_result.place_as_equipment_result.logistic_parameters.construction_radius)
            --local new_name = "personal-roboport-equipment" .. "-reduced-" .. n;
            --replace_roboport(grid, eq, new_name)
        end
    end

    --replace_roboport(g, )

    --local logistic = game.players[1].character.logistic_network
    --game.print("tick");
    --if logistic and logistic.all_construction_robots > 0 and logistic.robot_limit > 0 then
        
        --game.print("available: " .. logistic.available_construction_robots)
        --game.print("range: " .. logistic.cells[1].construction_radius)
    --end
end


local SHORTCUT = "shortcut-toggle-robots-build-closest-first"

local function toggle_shortcut(e)
  local p = game.get_player(e.player_index)
  local new_state = not p.is_shortcut_toggled(SHORTCUT)
  p.set_shortcut_toggled(SHORTCUT, new_state) -- <- makes it yellow when true
end


local function shortcutToggle(e)
  if e.prototype_name == SHORTCUT then
    game.print("toggle!!!!")
    toggle_shortcut(e)
  end
end



script.on_event({defines.events.on_tick}, tick)



script.on_event(defines.events.on_lua_shortcut, shortcutToggle)

script.on_event("input-toggle-robots-build-closest-first", shortcutToggle)