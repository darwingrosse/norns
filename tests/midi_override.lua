-- MIDI Override
--
-- A test of MIDI class overrides on the norns
--

engine.name = "PolyPerc"

local Midi = require 'midi'

Midi.add = function(dev)
  print("ddg adding " .. dev.name)
end

Midi.remove = function(dev)
  -- we have to check to see if dev is passed. If it is, we are seeing
  -- the class-level remove function. If not, we are getting this as
  -- a device level function...
  if (dev) then
    print("ddg removing " .. dev.name)
  end
end

function key(k, v)
  if (k == 3 and v == 1) then
    print("MIDI devices:")
    for id, dev in pairs(midi.devices) do
      print("id: " .. id .. " name: " .. dev.name)
    end
  end
end
