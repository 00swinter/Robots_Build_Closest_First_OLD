
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

local update_rate = 1


local function round256(n)
  if type(n) ~= "number" then return 0 end
  if n >= 0 then return math.floor(n * 256 + 0.5) end
  return math.ceil(n * 256 - 0.5)
end

local function entity_key(e)
  if not (e and e.valid) then return nil end

  -- Prefer stable numeric ids when available
  if e.unit_number then
    return e.unit_number
  end

  if e.name == "entity-ghost" and e.ghost_unit_number then
    return e.ghost_unit_number
  end

  -- Fallback for things without unit numbers (trees, rocks, many ghosts)
  local name = e.name
  if name == "entity-ghost" then
    name = e.ghost_name or name
  end

  local s = (e.surface and e.surface.index) or 0
  local pos = e.position or {x = 0, y = 0}
  local rx, ry = round256(pos.x or 0), round256(pos.y or 0)

  -- Include optional bits that help disambiguate unnumbered entities
  local dir = e.direction or 0
  local var = e.graphics_variation or e.tree_variant or e.tree_color_index or 0

  return string.format("%s@%d:%d,%d|%d|%d", name, s, rx, ry, dir, var)
end

-- Merge two lists of entities: returns a new list with no duplicates
local function merge_entities(a, b)
  local out, seen = {}, {}

  local function add(list)
    if not list then return end
    for i = 1, #list do
      local e = list[i]
      if e and e.valid then
        local k = entity_key(e)
        if not seen[k] then
          seen[k] = true
          out[#out + 1] = e
        end
      end
    end
  end

  add(a)
  add(b)
  return out
end



local function find_in_ring_around_player(player, max_distance, min_distance)
   local EPS = 1e-6 -- exclude the edges
   local surface = player.surface
   local position = player.position
   local px, py = position.x, position.y

   -- four non-overlapping strips (half-open edges via EPS to reduce dupes)
   local top_strip = {
      {px - max_distance, py - max_distance},
      {px + max_distance - EPS, py - min_distance}
   }
   local bottom_strip = {
      {px - max_distance, py + min_distance},
      {px + max_distance - EPS, py + max_distance}
   }
   local left_strip = {
      {px - max_distance, py - min_distance},
      {px - min_distance, py + min_distance - EPS}
   }
   local right_strip = {
      {px + min_distance, py - min_distance},
      {px + max_distance, py + min_distance - EPS}
   }
   --debug rendering
   rendering.draw_rectangle{
      surface = game.players[1].surface,
      left_top = top_strip[1],
      right_bottom = top_strip[2],
      color = {1, 1, 1},
      time_to_live = update_rate
   }
   rendering.draw_rectangle{
      surface = game.players[1].surface,
      left_top = bottom_strip[1],
      right_bottom = bottom_strip[2],
      color = {1, 1, 1},
      time_to_live = update_rate
   }
   rendering.draw_rectangle{
      surface = game.players[1].surface,
      left_top = left_strip[1],
      right_bottom = left_strip[2],
      color = {1, 1, 1},
      time_to_live = update_rate
   }
   rendering.draw_rectangle{
      surface = game.players[1].surface,
      left_top = right_strip[1],
      right_bottom = right_strip[2],
      color = {1, 1, 1},
      time_to_live = update_rate
   }

   local tb = storage.all_found

   local found = surface.find_entities_filtered{
      area = top_strip,
      force = {player.force, "neutral"}
   }
   tb = merge_entities(tb, found)

   found = surface.find_entities_filtered{
      area = bottom_strip,
      force = {player.force, "neutral"}
   }
   tb = merge_entities(tb, found)

   found = surface.find_entities_filtered{
      area = left_strip,
      force = {player.force, "neutral"}
   }
   tb = merge_entities(tb, found)

   found = surface.find_entities_filtered{
      area = right_strip,
      force = {player.force, "neutral"}
   }
   tb = merge_entities(tb, found)

   game.print("count: ".. #tb)
   storage.all_found = tb
end

local rad = 0

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
            color = {r = 0.8, g = 0.2, b = 0.2, a = 1},
            radius = 0.2,                -- tiles (small)
            filled = true,
            target = pos,    -- center at player
            surface = entity.surface,
            time_to_live = 1,       -- 5 seconds
            draw_on_ground = false
         }
      end
   end
   game.print("available_construction_robots: " .. player.character.logistic_network.available_construction_robots)
   game.print("charging: " .. player.character.logistic_network.cells[1].charging_robot_count)
   game.print("to charging: " .. player.character.logistic_network.cells[1].to_charge_robot_count)
   game.print("------------------------------")

   --draw range
   
   rendering.draw_rectangle{
      surface = player.surface, 
      left_top = area[1], 
      right_bottom = area[2], 
      color = {1, 1, 1},
      time_to_live = 1
   }

   local available_construction_robots = player.character.logistic_network.available_construction_robots
   local charging_robot_count = player.character.logistic_network.cells[1].charging_robot_count
   local to_charge_robot_count = player.character.logistic_network.cells[1].to_charge_robot_count
   local robot_limit = player.character.logistic_network.robot_limit
   local real_available = robot_limit - charging_robot_count - to_charge_robot_count
   rendering.draw_text{
      text = {"", "available_construction_robots: " .. available_construction_robots},
      surface = player.surface,
      target = {player.position.x - 5, player.position.y - 10},
      color = {1, 1, 1},
      time_to_live = 1,
      scale = 2
   }

   rendering.draw_text{
      text = {"", "charging: " .. charging_robot_count},
      surface = player.surface,
      target = {player.position.x - 5, player.position.y - 12},
      color = {1, 1, 1},
      time_to_live = 1,
      scale = 2
   }

   rendering.draw_text{
      text = {"", "to charging: " .. to_charge_robot_count},
      surface = player.surface,
      target = {player.position.x - 5, player.position.y - 14},
      color = {1, 1, 1},
      time_to_live = 1,
      scale = 2
   }
   rendering.draw_text{
      text = {"", "robot limit: " .. robot_limit},
      surface = player.surface,
      target = {player.position.x - 5, player.position.y - 16},
      color = {1, 1, 1},
      time_to_live = 1,
      scale = 2
   }

   rendering.draw_text{
      text = {"", "real available: " .. real_available},
      surface = player.surface,
      target = {player.position.x - 5, player.position.y - 20},
      color = {1, 1, 1},
      time_to_live = 1,
      scale = 2
   }


    --local n = math.random(1, 5)
    


    for _, eq in pairs(grid.equipment) do
        if eq.type == "roboport-equipment" then
            --game.print("range: ".. eq.prototype.take_result.place_as_equipment_result.logistic_parameters.construction_radius)
            local new_name = "personal-roboport-equipment" .. "-reduced-" .. n;
            replace_roboport(grid, eq, new_name)
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

local counter = 1
local entities = {}

local function testing()

   if game.tick % update_rate ~= 0 then
      return
   end

   

   --game.print("tick: ".. game.tick)
   --profiler = game.create_profiler()
   local player = game.players[1]
   local player_pos = player.position

   
   rad = rad + 1
   rad = rad % 20
   if rad == 0 then
      storage.all_found = {}
   else
      --find_in_ring_around_player(player, rad+1,rad)
   end


   --local area = {
   --  {player_pos.x - counter, player_pos.y - counter},
   --  {player_pos.x + counter, player_pos.y + counter}
   --}
--
   --local found = player.surface.find_entities_filtered{area = area, force = {player.force, "neutral"}}
   --counter = counter + 1
   --profiler.stop()
--
   --rendering.draw_rectangle{
   --   surface = player.surface,
   --   left_top = area[1],
   --   right_bottom = area[2],
   --   color = {1, 1, 1},
   --   time_to_live = 55
   --}
   --game.print("c: ".. counter)
   --game.print(profiler)
   --time[counter] = {"", "count: ".. counter .. "  time: " .. profiler}


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




local function setup()
   storage.all_found = {}
end



script.on_event({defines.events.on_tick}, testing)



script.on_event(defines.events.on_lua_shortcut, shortcutToggle)

script.on_event("input-toggle-robots-build-closest-first", shortcutToggle)

script.on_configuration_changed(setup)
