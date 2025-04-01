--------------------------------------------------------------------------------
-- File: matrixctrl.pd_lua
-- Description: Implementation of the [matrixctrl] object.
--              Requires pd-lua. 
-- Author: Ruben Philipp <me@rubenphilipp.com>
-- Created: 2025-04-01
-- $$ Last modified:  21:38:12 Tue Apr  1 2025 CEST
--------------------------------------------------------------------------------

local matrixctrl = pd.Class:new():register("matrixctrl")

-- the base size to be multiplied by size
local BASE_SIZE = 20

function matrixctrl:initialize(sel, atoms)
   self.inlets = 1
   self.outlets = 1

   self.columns = 4 -- default value
   self.rows = 4 -- default value

   self.size = 1.0 -- default size multiplier

   -- the data array
   -- the data is stored in a 1-dimensional array, read from left to right,
   -- top to bottom.  
   self.data = {}
   self.data[1] = 1 -- TEST
   pd.post(string.format("data: %s", table.concat(self.data)))

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
   width, height = (self.size * self.columns * BASE_SIZE),
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
      pd.post(string.format("col: %s, row: %s, idx: %s", col, row, col+row))
      --pd.post(self.data[row+col])
      return self.data[index]
   else
      return 0
   end
end

-- set the value of a cell
function matrixctrl:set_data_value(col, row, val)
   local index = self.get_data_index(col, row)
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

-- get the array index for a cell
function matrixctrl:get_data_index(col, row)
   return (row*self.columns)+col
end


--------------------------------------------------------------------------------
-- EOF matrixctrl.pd_lua
