--------------------------------------------------------------------------------
-- File: matrixctrl.pd_lua
-- Description: Implementation of the [matrixctrl] object.
--              Requires pd-lua. 
-- Author: Ruben Philipp <me@rubenphilipp.com>
-- Created: 2025-04-01
-- $$ Last modified:  18:26:13 Thu Apr  3 2025 CEST
--------------------------------------------------------------------------------

local matrixctrl = pd.Class:new():register("matrixctrl")

-- the base size to be multiplied by size
local BASE_SIZE = 20
-- mouse step-width per pixel (esp. for dial-mode)
local DEFAULT_MOUSE_PIXEL_STEP_WIDTH = 0.0004

-- default max and min vals
local V_MAX = 1
local V_MIN = 0

function matrixctrl:initialize(sel, atoms)
   self.inlets = 1
   self.outlets = 2

   self.columns = 4 -- default value
   self.rows = 4 -- default value

   self.v_min = V_MIN
   self.v_max = V_MAX

   self.step_width = DEFAULT_MOUSE_PIXEL_STEP_WIDTH

   self.size = 1.0 -- default size multiplier

   -- modes: 0 = toggle; 1 = dial (0.0-1.0)
   self.mode = 0

   -- the data array
   -- the data is stored in a 1-dimensional array, read from left to right,
   -- top to bottom.  
   self.data = {}

   -- TODO
   local w, h = self:get_actual_size()
   self:set_size(w, h)

   return true
end

function matrixctrl:update()
   -- TODO
   local w, h = self:get_actual_size()
   self:set_size(w, h)
   -- TODO: repaint-delay (?) -> cf. hello-gui.pd_lua
   self:repaint()
end

-- return the box dimensions according to the current settings
function matrixctrl:get_actual_size()
   local width, height = (self.size * self.columns * BASE_SIZE),
      (self.size * self.rows * BASE_SIZE)
   return width, height
end

function matrixctrl:in_1_bang()
   -- TODO
   --pd.post(string.format("%s", self.size))
end

-- set step width (per pixel)
function matrixctrl:in_1_step_width(x)
   local val = x[1]
   self.step_width = val
end

-- set range (min/max)
-- also clip existing values to new bounds (without output)
function matrixctrl:in_1_range(x)
   local old_min = self.v_min
   local old_max = self.v_max
   local new_min = x[1]
   local new_max = x[2]
   if (type(new_min) == "number" and type(new_max) == "number")
      and (new_min < new_max) then
      self.v_min = new_min
      self.v_max = new_max
   else
      pd.post("min must be < max.")
      return false
   end

   -- clip values to new bounds
   for i = 0, (self.columns*self.rows - 1), 1 do
      local current_val = self.data[i]
      if current_val then
         if current_val > new_max then
            -- clip to max
            self.data[i] = new_max
         elseif current_val < new_min then
            -- clip to min
            self.data[i] = new_min
         end
      end
   end
   
   self:repaint()
end

-- set rows
function matrixctrl:in_1_rows(x)
   local val = self:validate_colrows(x)
   if val then
      self.rows = val
   end
   self:update()
end

-- set columns
function matrixctrl:in_1_columns(x)
   local val = self:validate_colrows(x)
   if val then
      self.columns = val
   end
   self:update()
end

-- set mode
-- when no value given, return the mode in second outlet
function matrixctrl:in_1_mode(x)
   local val = x[1]
   if val == 1 or val == "dial" then
      -- dial mode
      self.mode = 1
   elseif val == 0 or val == "toggle" then
      -- toggle mode (always fallback)
      self.mode = 0
   else
      -- return current mode in second outlet
      self:outlet(2, "list", {"mode", self.mode})
   end
end

-- set size
function matrixctrl:in_1_size(x)
   if type(x[1]) == "number" and x[1] > 0 then
      self.size = x[1]
      self:update()
   else
      return false
   end
end


function matrixctrl:in_1_list(x)

   local col = x[1]
   local row = x[2]
   local val = x[3]
   
   self:set_data_value(col, row, val)

   -- output the data immediately
   self:outlet(1, "list", {col, row, self:get_data_value(col, row)})

   self:update()

end

-- set data without output
function matrixctrl:in_1_set(x)
   local col = x[1]
   local row = x[2]
   local val = x[3]
   
   self:set_data_value(col, row, val)

   self:update()
end


-- paint
function matrixctrl:paint(g)
   g:set_color(0)
   g:fill_all()

   ----------------------------------------
   -- PAINT DIALS
   -- TODO: unfinished
   ----------------------------------------
   local width, height = self:get_actual_size()
   local item_w, item_h = width/self.columns, height/self.rows
   local stroke_width = 1.0
   local x, y = 0
   local val = nil
   for i = 0, (self.columns - 1), 1
   do
      for j = 0, (self.rows - 1), 1
      do
         x = item_w*i
         y = item_h*j
         val = self:get_data_value(i, j) or self.v_min
         
         local color_scaler = self:rescale_value(val,
                                                 self.v_min,
                                                 self.v_max,
                                                 0.0,
                                                 1.0)
         -- rgb color value:
         -- inverted val because 255 is white (thus should be reversed)
         local c_val = 255 * (1 - color_scaler)

         g:set_color(1)
         g:stroke_ellipse(x, y, item_w, item_h, stroke_width)
         
         g:set_color(c_val, c_val, c_val)
         g:fill_ellipse(x, y, item_w, item_h)
            
         -- if val then
         --    pd.post(tostring(val))
         --    g:set_color(c_val, c_val, c_val)
         --    g:fill_ellipse(x, y, item_w, item_h)
         -- else
         --    g:set_color(c_val)
         --    g:fill_ellipse(x, y, item_w, item_h)
         -- end
      end
   end
end

function matrixctrl:mouse_down(x, y)
   -- store values
   -- these are also needed e.g. in mouse_drag,
   -- so they need to be here (i.e. mode-agnostic)
   self.mouse_down_x = x
   self.mouse_down_y = y

   ----------------------------------------
   -- TOGGLE
   -- when mode == 0 (toggle), toggle values:
   ----------------------------------------
   if self.mode == 0 then
      local col, row = self:identify_cell(x,y)
      self:toggle_data_value(col, row)
      self:update()
      -- output changed data
      self:outlet(1, "list", {col, row, self:get_data_value(col, row)})
   end
end

function matrixctrl:mouse_drag(x, y)
   -- set limits
   
   
   local dx = x - self.mouse_down_x
   -- invert dy, so that upwards implies positive
   local dy = (y - self.mouse_down_y) * -1
   local col, row = self:identify_cell(self.mouse_down_x,
                                       self.mouse_down_y)
   
   ----------------------------------------
   -- DIAL
   -- when mode == 1 (dial), dial values in range
   ----------------------------------------
   if self.mode == 1 then
      local old_val = self:get_data_value(col, row) or 0
      local new_val = old_val + dy * self.step_width
      self:set_data_value(col, row, new_val, self.v_min, self.v_max)
      self:update()
      self:outlet(1, "list", {col, row, self:get_data_value(col, row)})
   end
end


function matrixctrl:postreload()
   -- TODO: check if something can be cleaned up
   -- init for testing
   self:initialize()
   self:update()
end



--------------------------------------------------------------------------------
-- helper functions

function matrixctrl:validate_colrows(x)
   local val = math.floor(x[1])
   if val >= 1 then
      return val
   else
      return false
   end
end

-- zero-based!
function matrixctrl:get_data_value(col, row)
   local index = self:get_data_index(col, row)
   if self.data[index] then
      return self.data[index]
   else
      return false
   end
end

-- set the value of a cell
function matrixctrl:set_data_value(col, row, val,
                                   -- optional:
                                   val_min, val_max)
   col = math.floor(col)
   row = math.floor(row)
   -- default values
   val_min = val_min or self.v_min
   val_max = val_max or self.v_max
   local index = self:get_data_index(col, row)
   -- test if in range
   if index < self.columns*self.rows then
      -- clamp to min/max vals if given
      if val_min and val < val_min then
         val = val_min
      end
      if val_max and val > val_max then
         val = val_max
      end
      
      self.data[index] = val
   else
      pd.post(string.format("matrixctrl: Index %s out of range "..
                            "in a %sx%s (%s indices) matrix)",
                            index, self.columns, self.rows,
                            self.columns*self.rows))
      return false
   end
end

-- toggle value of cell
function matrixctrl:toggle_data_value(col, row, val_a, val_b)
   -- default values
   val_a = val_a or self.v_min
   val_b = val_b or self.v_max
   if (col < self.columns) and (row < self.rows) then
      local current = self:get_data_value(col, row)
      -- fall back to val_a if test does not match
      if current == val_a or current == false then
         self:set_data_value(col, row, val_b)
      else
         self:set_data_value(col, row, val_a)
      end
   else
      pd.post(string.format("matrixctrl: Cell (c: %s, r: %s) is out "..
                            "of range.", col, row))
   end
end

-- get the array index for a cell
function matrixctrl:get_data_index(col, row)
   return (row*self.columns)+col
end

-- identify the data coordinates by (mouse/graphics) pixel coordinates
-- returns two values: col, row (zero-based)
function matrixctrl:identify_cell(x, y)
   local width, height = self:get_actual_size()
   local cell_w = width/self.columns
   local cell_h = height/self.rows
   local column = math.floor(x/cell_w)
   local row = math.floor(y/cell_h)
   return column, row
end

-- scale a value to a new range
function matrixctrl:rescale_value(val, min, max, new_min, new_max)
   new_min = new_min or 0.0
   new_max = new_max or 1.0
   if (min >= max) or (new_min >= new_max) then
      pd.post(string.format("matrixctrl: min (%s) must be < max (%s), "..
                            "and sim. for new_min (%s) and new_max (%s).",
                            min, max, new_min, new_max))
      return false 
   end

   local range1 = max - min
   local range2 = new_max - new_min
   local prop = (val - min) / range1
   local result = new_min + (prop * range2)
   return result
end

--------------------------------------------------------------------------------
-- EOF matrixctrl.pd_lua
