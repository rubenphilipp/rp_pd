--------------------------------------------------------------------------------
-- File: matrixctrl.pd_lua
-- Description: Implementation of the [matrixctrl] object.
--              Requires pd-lua. 
-- Author: Ruben Philipp <me@rubenphilipp.com>
-- Created: 2025-04-01
-- $$ Last modified:  02:44:05 Sat Apr  5 2025 CEST
--------------------------------------------------------------------------------

local matrixctrl = pd.Class:new():register("matrixctrl")

-- the base size to be multiplied by size
local BASE_SIZE = 20
-- mouse step-width per pixel (esp. for dial-mode)
local DEFAULT_MOUSE_PIXEL_STEP_WIDTH = 0.0004

-- default rgb-colors
local DEFAULT_COLOR_OFF = {255,255,255}
local DEFAULT_COLOR_ON = {0,0,0}
-- background-color
local DEFAULT_COLOR_BG = {255,255,255}

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

   self.color_off = DEFAULT_COLOR_OFF
   self.color_on = DEFAULT_COLOR_ON
   self.color_bg = DEFAULT_COLOR_BG

   self.step_width = DEFAULT_MOUSE_PIXEL_STEP_WIDTH

   self.size = 1.0 -- default size multiplier

   -- modes: 0 = toggle; 1 = dial (0.0-1.0)
   self.mode = 0

   -- the data array
   -- the data is stored in a 1-dimensional array, read from left to right,
   -- top to bottom.  
   self.data = {}

   local w, h = self:get_actual_size()
   self:set_size(w, h)

   return true
end

function matrixctrl:update()
   local w, h = self:get_actual_size()
   self:set_size(w, h)

   self:repaint()
end

-- return the box dimensions according to the current settings
function matrixctrl:get_actual_size()
   local width, height = (self.size * self.columns * BASE_SIZE),
      (self.size * self.rows * BASE_SIZE)
   return width, height
end

-- flush/dump all values in the matrix (alias to flush)
function matrixctrl:in_1_bang()
   self:flush_data()
end

-- flush/dump all values in the matrix
function matrixctrl:in_1_flush(ignore)
   self:flush_data()
end

-- clear all values in the matrix
function matrixctrl:in_1_clear(ignore)
   self:clear_data()
end

-- get all values of row N (2nd outlet)
function matrixctrl:in_1_getrow(n)
   local row = n[1]
   if not row or row >= self.rows or row < 0 then
      pd.post(string.format("Row %s does does not exist.", row))
      return false
   end

   local res = {}
   for col = 0, (self.columns - 1), 1 do
      local val = self:get_data_value(col, row) or self.v_min
      table.insert(res, val)
   end
   self:outlet(2, "row", res)
end

-- get all values of column N (2nd outlet)
function matrixctrl:in_1_getcolumn(n)
   local col = n[1]
   if not col or col >= self.columns or col < 0 then
      pd.post(string.format("Column %s does does not exist.", row))
      return false
   end

   local res = {}
   for row = 0, (self.rows - 1), 1 do
      local val = self:get_data_value(col, row) or self.v_min
      table.insert(res, val)
   end
   self:outlet(2, "column", res)
end

-- get the value of a cell
-- ARGS: column, row
function matrixctrl:in_1_get(x)
   local col = x[1]
   local row = x[2]
   if #x ~= 2 then
      pd.post("Wrong number of arguments. Need: col, row (in this order).")
      return false
   end

   local res = self:get_data_value(col, row) or self.v_min
   self:outlet(1, "list", {col, row, res})
end

-- imports the values from an array
-- does NOT clear the table before, but overrides all
-- values starting from index 0
-- values will be clipped when they don't fit the min/max-range
function matrixctrl:in_1_import(x)
   local len = #x
   for i = 0, len - 1, 1 do
      local val = x[i+1]
      if val > self.v_max then
         val = self.v_max
      elseif val < self.v_min then
         val = self.v_min
      end
      
      self.data[i] = val
   end

   self:repaint()
end

-- exports the values as an array
-- output in 2nd outlet
function matrixctrl:in_1_export(ignore)
   local res = {}
   for i = 0, (self.columns*self.rows - 1), 1 do
      local val = self.data[i] or self.v_min
      table.insert(res, val)
   end

   self:outlet(2, "export", res)
end

-- set step width (per pixel)
function matrixctrl:in_1_step_width(x)
   local val = x[1]
   self.step_width = val
end

-- set range (min/max)
-- also clip existing values to new bounds (without output)
function matrixctrl:in_1_range(x)
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

-- set array data by index
-- with output.
-- x[1]: data index (zero based)
-- x[2]: value
function matrixctrl:in_1_by_index(x)
   local i = x[1]
   local val = x[2]
   if #x == 2 then
      if val > self.v_max then
         val = self.v_max
      elseif val < self.v_min then
         val = self.v_min
      end
   end

   local col, row = self:get_coordinates(i)
   local res = self:set_data_value(col, row, val)

   if res then
      self:outlet(1, "list", {col, row, val})
   end

   self:repaint()
end

-- set array data by index
-- without output!
-- x[1]: data index (zero based)
-- x[2]: value
function matrixctrl:in_1_set_by_index(x)
   local i = x[1]
   local val = x[2]
   if #x == 2 then
      if val > self.v_max then
         val = self.v_max
      elseif val < self.v_min then
         val = self.v_min
      end

      self.data[i] = val
   end

   self:repaint()
end

-- set data without output
function matrixctrl:in_1_set(x)
   local col = x[1]
   local row = x[2]
   local val = x[3]
   
   self:set_data_value(col, row, val)

   self:update()
end

-- set color off
function matrixctrl:in_1_color_off(x)
   local color = self:validate_color(x)

   if color then
      self.color_off = color
   end

   self:repaint()
end

-- set color on
function matrixctrl:in_1_color_on(x)
   local color = self:validate_color(x)

   if color then
      self.color_on = color
   end

   self:repaint()
end

-- set background-color
function matrixctrl:in_1_color_bg(x)
   local color = self:validate_color(x)

   if color then
      self.color_bg = color
   end

   self:repaint()
end


-- paint
function matrixctrl:paint(g)
   -- set background   
   g:set_color(self.color_bg[1],
               self.color_bg[2],
               self.color_bg[3])
   g:fill_all()

   ----------------------------------------
   -- PAINT DIALS
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

         -- scale value to range 0.0-1.0 
         local color_scaler = self:rescale_value(val,
                                                 self.v_min,
                                                 self.v_max,
                                                 0.0,
                                                 1.0)
         -- rgb color value:
         local dial_color = self:interpolate_colors(color_scaler,
                                                    self.color_off,
                                                    self.color_on)

         g:set_color(1)
         g:stroke_ellipse(x, y, item_w, item_h, stroke_width)
         
         g:set_color(dial_color[1], dial_color[2], dial_color[3])
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
   --self:initialize()
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
      return true
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

-- get the coordinates for a given index
function matrixctrl:get_coordinates(index)
   local row = math.floor(index/self.columns)
   local col = math.floor(index%self.columns)

   return col, row
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

-- interpolate two values
-- x: inteprolation value 0.0 <= x <= 1.0
-- val_a: when x==0
-- val_b: when x==1
function matrixctrl:interpolate(x, val_a, val_b)
   if x < 0.0 or x > 1.0 then
      pd.post(string.format("Interpolation error. X (%s) must be "..
                            ">= 0 and <= 1.", x))
      return false
   end
   local diff = val_b - val_a
   return val_a + (x * diff)
end

-- interpolate between two colors
-- each color is a list/table of three values
function matrixctrl:interpolate_colors(x, color_a, color_b)
   if ((not type(color_a) == "table") and (not #color_a == 3))
      or ((not type(color_b) == "table") and (not #color_b == 3)) then
      pd.post("Both colors need two be a table of three values.")
      return false
   end

   local new_color = {}
   for i = 1, 3, 1 do
      new_color[i] = self:interpolate(x, color_a[i], color_b[i])
   end

   return new_color
end

-- validate a color table
function matrixctrl:validate_color(x)
   if #x ~= 3 then
      pd.post("Invalid color value. Color should be 3 8bit digits. ")
      return false
   end

   for i = 1, 3, 1 do
      if not self:validate_color_digit(x[i]) then
         pd.post(string.format("Invalid color digit (%s).", x[i]))
         return false
      end
   end
   
   return x
end

-- validate color value
-- test if a value is an rgb color-value (0<=val<=255)
function matrixctrl:validate_color_digit(val)
   if (val >= 0) and (val <= 255) then
      return val
   else
      return false
   end
end

-- clear the data and repaint
-- clear means set to val_min
function matrixctrl:clear_data()
   for i = 0, (self.columns*self.rows - 1), 1 do
      self.data[i] = self.val_min
   end
   self:repaint()
end

-- flush all data, each as a list, to outlet 1
function matrixctrl:flush_data()
   for i = 0, (self.columns - 1), 1 do
      for j = 0, (self.rows - 1), 1 do
         -- return actual value or min if no value is set
         local val = self:get_data_value(i, j) or self.v_min
         self:outlet(1, "list", {i, j, val})
      end
   end
   
end

--------------------------------------------------------------------------------
-- EOF matrixctrl.pd_lua
