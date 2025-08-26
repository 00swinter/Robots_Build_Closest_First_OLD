
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


local function restore(g)
   for _, eq in next, g.equipment do
      if eq.type == "roboport-equipment" and eq.prototype.order == "abctest" then
         replace_roboport(g, eq, eq.prototype.take_result.name)
      end
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

local function get_grid_area(grid)
   local r = get_grid_radius(grid)
   return r*r
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

local function get_player_real_available_robots(player)


   local logistic = player.character.logistic_network
   local cell = logistic.cells[1]
   
   local robots_limit = logistic.robot_limit
   local robots_available = logistic.available_construction_robots
   local robots_all = logistic.all_construction_robots

   local robots_real_available = robots_limit - (robots_all - robots_available)
   return math.min(robots_available, robots_real_available)
end


local function tick()
   if true then
      return
   end
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

local function get_orig_name(eq)
   return eq.prototype.take_result.place_as_equipment_result.name
end


local function set_to_desired_range(grid, desired)
   local current_range = get_grid_radius(grid)

   -- game.print("current_range: " .. current_range)
   -- game.print("desired: " .. desired)

   if current_range < desired then
      -- In many situations this will be inefficient, but it seems reliable
      restore(grid)
      current_range = get_grid_radius(grid)
   end

   if current_range > desired then
      for _, eq in next, grid.equipment do
         if eq.type == "roboport-equipment" and current_range > desired then
            local eq_range = get_eq_radius(eq)
            if eq_range > 0 then
               -- Probably some closed formula for this, but I'm not aware of it and this is not a bottleneck
               local current_range2_without_this = get_grid_area(grid) - (eq_range * eq_range)
               while eq_range > 0 and current_range > desired do
                  eq_range = eq_range - 1
                  current_range = math.sqrt((eq_range * eq_range) + current_range2_without_this)
               end
               local new_name = get_orig_name(eq) .. "-reduced-" .. eq_range
               -- game.print("swapping in : " .. new_name)
               replace_roboport(grid, eq, new_name)
            end
         end
      end
   end
end


local function set_radius(grid, desired)
  if not (grid and desired and desired >= 0) then return end

  -- Collect all personal roboports with their current & original radii.
  local eqs = {}
  local max_sumsq = 0
  local cur_sumsq = 0
  for _, eq in pairs(grid.equipment) do
    if eq.type == "roboport-equipment" then
      local orig = get_orig_range(eq)         -- radius from the original prototype
      local curr = get_eq_radius(eq)          -- radius of the currently installed variant
      table.insert(eqs, {eq = eq, orig = orig, curr = curr})
      max_sumsq = max_sumsq + orig * orig
      cur_sumsq = cur_sumsq + curr * curr
    end
  end
  if #eqs == 0 then return end

  local max_possible = math.floor(math.sqrt(max_sumsq) + 0.5)
  desired = math.floor(desired + 0.5)  -- ensure integer radius
  local target2 = desired * desired

  -- If desired >= max achievable, just restore full-strength and exit.
  if desired >= max_possible then
    restore(grid)
    return
  end

  -- If our current radius is below target (because we were previously reduced),
  -- try restoring first to give ourselves headroom.
  if cur_sumsq < target2 then
    restore(grid)
    -- recompute current sums after restore
    cur_sumsq = max_sumsq
    if cur_sumsq <= target2 then
      -- Can't exceed target even at full strength; nothing else to do.
      return
    end
  end

  -- Sort roboports by current radius descending.
  table.sort(eqs, function(a, b) return a.curr > b.curr end)

  -- Reduce the biggest ones first. For each equipment, compute the exact radius
  -- needed so that Σ r_i^2 ≈ target2, clamped to [0, orig].
  for i, e in ipairs(eqs) do
    if cur_sumsq <= target2 then break end

    local others2 = cur_sumsq - e.curr * e.curr
    -- Choose the largest integer new_r such that others2 + new_r^2 <= target2
    local new_r = math.floor(math.sqrt(math.max(0, target2 - others2)) + 1e-9)

    -- Clamp to valid range and avoid pointless swaps.
    if new_r > e.orig then new_r = e.orig end
    if new_r < 0 then new_r = 0 end
    if new_r == e.curr then goto continue end

    -- Build the prototype name. If equal to original radius, use the original.
    local new_name
    if new_r == e.orig then
      new_name = get_orig_name(e.eq)
    else
      new_name = get_orig_name(e.eq) .. "-reduced-" .. new_r
    end

    replace_roboport(grid, e.eq, new_name)

    -- Update running total with the radius we just set.
    cur_sumsq = others2 + new_r * new_r
    e.curr = new_r

    ::continue::
  end
end


local function newTick()
   -- get max possible radius
   
   --get real available robots

   if game.tick % 15 ~= 0 then
      return
   end
   --if av = 0
   -- make smaller
   --else make bigger

   if storage.radius == nil then
      storage.radius = 3
   end

   local player = game.players[1]
   local player_pos = player.position
   local grid = player.character.grid


   local real_available = get_player_real_available_robots(player)

   game.print(real_available)

   
   

   if real_available > 0 then
      if storage.radius < 30 then
         storage.radius = storage.radius + 3
      end   
   else
      if storage.radius > 3 then
         storage.radius = storage.radius - 3
      end
   end
   

   local radius = storage.radius

   local area = {
      {player_pos.x - radius, player_pos.y - radius},
      {player_pos.x + radius, player_pos.y + radius}
   }

    rendering.draw_rectangle{
      surface = player.surface, 
      left_top = area[1], 
      right_bottom = area[2], 
      color = {1, 1, 1},
      time_to_live = 15
   }
   
   set_radius(grid, math.ceil(radius)+2)
    
end



local function setup()
   storage.radius = 1;
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





script.on_event({defines.events.on_tick}, newTick)



script.on_event(defines.events.on_lua_shortcut, shortcutToggle)

script.on_event("input-toggle-robots-build-closest-first", shortcutToggle)

script.on_configuration_changed(setup)
