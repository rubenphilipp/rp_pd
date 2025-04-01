--------------------------------------------------------------------------------
-- File: matrixctrl.pd_lua
-- Description: Implementation of the [matrixctrl] object.
--              Requires pd-lua. 
-- Author: Ruben Philipp <me@rubenphilipp.com>
-- Created: 2025-04-01
-- $$ Last modified:  23:16:33 Tue Apr  1 2025 CEST
--------------------------------------------------------------------------------

local matrixctrl = pd.Class:new():register("matrixctrl")

-- the base size to be multiplied by size
local BASE_SIZE = 20

function matrixctrl:initialize(sel, atoms)
   self.inlets = 1
   self.outlets = 2

   self.columns = 4 -- default value
   self.rows = 4 -- default value

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
         val = self:get_data_value(i, j)
         g:set_color(1)
         g:stroke_ellipse(x, y, item_w, item_h, stroke_width)
         -- TEST
         if val == 1 then
            g:fill_ellipse(x, y, item_w, item_h)
         end
      end
   end
   --self:paint_dials(g)
end

function matrixctrl:mouse_down(x, y)
   -- store values
   self.mouse_down_x = x
   self.mouse_down_y = y

   local col, row = self:identify_cell(x,y)
   self:toggle_data_value(col, row)
   
   self:update()
end

function matrixctrl:mouse_drag(x, y)
   local dx = x - self.mouse_down_x
   local dy = y - self.mouse_down_y
   
   pd.post(string.format("dx: %s, dy: %s", dx, dy))
   
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
      return 0
   end
end

-- set the value of a cell
function matrixctrl:set_data_value(col, row, val)
   local index = self:get_data_index(col, row)
   -- test if in range
   if index < self.columns*self.rows then
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
   val_a = val_a or 0
   val_b = val_b or 1
   if (col < self.columns) and (row < self.rows) then
      local current = self:get_data_value(col, row)
      -- fall back to val_a if test does not match
      if current == val_a then
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

--------------------------------------------------------------------------------
-- EOF matrixctrl.pd_lua
