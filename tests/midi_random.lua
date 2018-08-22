-- MIDI Random
-- Shoot random notes out MIDI, with a 10 ms OFF delay
--
-- A test of MIDI on the norns
--

engine.name = "PolyPerc"

local midi_device
local midi_msg

function midi_remove()
  print("dev.remove called...")
  midi_device = nil
end

function midi.add(dev)
  if not midi_device then
    print("adding device:" .. dev.name)
    dev.event = midi_event
    dev.remove = midi_remove
    midi_device = dev
  end
end

local function midi_event(data)
  print("Midi event received...")
end

function count1()
  if (midi_device) then
    midi_msg = {144, 60, 127}
    midi_msg[2] = math.random(48, 96)
    midi_device:send(midi_msg)

    print("Note on: " .. midi_msg[2])
    counter2:start(0.01, 1)
  end
end

function count2()
  if (midi_device and midi_msg) then
    print("Note off: " .. midi_msg[2])

    midi_msg[3] = 0
    midi_device:send(midi_msg)
    midi_msg = nil
  end
end

function init()
  counter1 = metro.alloc(count1, 0.125, 10)
  counter2 = metro.alloc(count2)
  counter1:start()
end

function key(k, v)
  if (k == 3 and v == 1) then
    print("MIDI devices:")
    for id, dev in pairs(midi.devices) do
      print("id: " .. id .. " name: " .. dev.name)
    end
  end
end
