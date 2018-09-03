-- walkabout.lua
-- A slider-based sequencer
-- PolyPerc output - and MIDI
--
-- enc2 = select sequence #
-- enc3 = set step value
-- key2 = decrement step #
-- key3 = increment step #
--
-- key1 = hold for ALT
--
-- alt-enc1 = select setting
-- enc1 = change setting
--
-- parameters set MIDI

engine.name = "PolyPerc"

local ControlSpec = require 'controlspec'
local Control = require 'params/control'
local Option = require 'params/option'

-- constants
local NUMSTEPS = 8
local NUMSEQS = 8

-- table starters...
local sq = {
  {0,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0},
  {0,0,0,0,0,0,0,0}
}

local ed = {}
local st = {}

local md = {
  _startup = true,
  _available = false,
  _devlist = {"none"},

  midi_on = false,
  midi_msg = nil,
  midi_name = "none",
  midi_device = nil,
}

-- -----------------------
-- initialization routine
-- -----------------------
function init()
  -- environment setup
  encoders.set_sens(2, .01)

  -- sq (sequence) data setup
  walkabout_load()

  -- ed (editor) data setup
  ed.cseq = 1
  ed.step = 1
  ed.onedown = false

  ed.view = Option.new("view", {"view", "start/stop", "tempo", "direction"})

  -- st (stepper) data setup
  st.curdir = 1
  st.curloc = 0

  st.dir = Option.new("dir", {"fwd","bwd","udn","rot","rnd"})
  st.dirString = {"forward", "backward", "up-down", "rotate", "random"}

  st.running = Option.new("running", {"off", "on"})
  st.running.action =
    function(r)
      if (r == 1) then counter:stop()
      else counter:start() end
    end

  st.tempo = Control.new("tempo", ControlSpec.new(40, 280, 'lin', 1, 120, 'bpm'))
  st.tempo.action =
    function(t)
      counter.time = (60 / t) / 4
    end

  counter = metro.alloc(count, 0.125, -1)
  counter2 = metro.alloc(noteoff_count)

  -- comment out the next line if you don't want to start running
  st.running:set(2)
end


-- ------------------------
-- parameter setup routine.
-- ------------------------
function setup_params()
  if (md._available) then
    params:clear()
    params:add_option("midi_on", {"off", "on"})
    params:set_action("midi_on", function(x) md.midi_on = (x == 2) end)
    params:add_option("midi_device", md._devlist)
    params:set_action("midi_device", function(x) selectMidiDevice(md._devlist[x]) end)

    if (md._startup) then
      walkabout_loadmidi()
      md._startup = false
    end

    if md.midi_on then params:set("midi_on", 2)
    else params:set("midi_on", 1) end
    params:set("midi_device", getMidiIndex(md.midi_name))
  else
    params:clear()
  end
end


-- ------------------------------------------------------
-- deal with a 'pulse', moving the sequencer by one step.
-- ------------------------------------------------------
function count()
  local dir = st.dir:get()

  if (dir == 1) then
    st.curloc = (st.curloc + 1) % NUMSTEPS
    st.curdir = 1
  elseif (dir == 2) then
    st.curloc = (st.curloc - 1) % NUMSTEPS
    st.curdir = -1
  elseif (dir == 3) then
    st.curloc = (st.curloc + st.curdir)
    if (st.curloc > (NUMSTEPS - 1)) then
      st.curloc = NUMSTEPS - 2
      st.curdir = -1
    end
    if (st.curloc < 0) then
      st.curloc = 1
      st.curdir = 1
    end
  elseif (dir == 4) then
    st.curloc = (st.curloc + st.curdir)
    if (st.curloc < 0) then
      st.curloc = 0
      st.curdir = 1
    elseif (st.curloc > (NUMSTEPS - 1)) then
      st.curloc = NUMSTEPS - 1
      st.curdir = -1
    end
  elseif (dir == 5) then
    st.curloc = math.random(0, NUMSTEPS - 1)
    st.curdir = 1
  end
  play()
  redraw()
end


-- ----------------------------------------------
-- play the current note in the current sequence.
-- ----------------------------------------------
function play()
  local m = sq[ed.cseq][st.curloc + 1]
  if (m > 0) then
    engine.hz(midi_to_hz(m + 36))
    midi_noteon(m + 36)
  end
end


-- -----------------------------------
-- convert a midi note to a frequency.
-- -----------------------------------
function midi_to_hz(note)
  return (440/32) * (2 ^ ((note - 9) / 12))
end


-- ------------------------
-- deal with encoder input.
-- ------------------------
function enc(c, v)
  local move = 0
  if (c == 1) then
    if (ed.onedown) then
      if (v > 0) then ed.view:delta(1)
      else ed.view:delta(-1) end
      redraw()
    else
      status_entry(v)
      redraw()
    end
  elseif (c == 2) then
    if (v > 0) then move = 1 end
    if (v < 0) then move = -1 end
    ed.cseq = util.clamp(ed.cseq + move, 1, NUMSEQS)
    redraw()
  elseif (c == 3) then
    sq[ed.cseq][ed.step] = util.clamp(sq[ed.cseq][ed.step] + v, 0, 36)
    redraw()
  end
end


-- ---------------------------------
-- conditional entry of status info.
-- ---------------------------------
function status_entry(v)
  local ev = ed.view:get()

  if (ev == 1) then
    return
  elseif (ev == 2) then
    st.running:delta(v)
  elseif (ev == 3) then
    st.tempo:delta(v)
  elseif (ev == 4) then
    if (v > 0) then st.dir:delta(1)
    else st.dir:delta(-1) end
  end
end


-- --------------------
-- deal with key input.
-- --------------------
function key(c, v)
  if (c == 1) then
    ed.onedown = (v == 1)
    redraw()
  end
  if (c == 2 and v == 1) then
    ed.step = util.clamp(ed.step - 1, 1, NUMSTEPS)
    redraw()
  end
  if (c == 3 and v == 1) then
    ed.step = util.clamp(ed.step + 1, 1, NUMSTEPS)
    redraw()
  end
end


-- ------------------------------
-- the standard drawing function.
-- ------------------------------
function redraw()
  screen.clear()
  screen.font_face(4)
  screen.font_size(10)

  draw_status()

  for i = 1, NUMSTEPS do
    local l = (16 * (i - 1)) + 8
    screen.rect(l, 15, 8, 36)
    screen.stroke()
    screen.rect(l, 15 + (36 - sq[ed.cseq][i]), 8, sq[ed.cseq][i])
    screen.fill()
  end

  screen.move(16 * (ed.step - 1) + 8, 60)
  screen.text(" ^")
  screen.move(16 * (st.curloc) + 8, 63)
  screen.text("x")

  screen.update()
end


-- -------------------------------------
-- conditional drawing of status header.
-- -------------------------------------
function draw_status()
  if (ed.onedown) then
    screen.move(5, 10)
    screen.text(ed.view:string())
  else
    local v = ed.view:get()
    screen.move(5, 10)

    if (v == 1) then
      screen.text("sq:" .. ed.cseq
        .. " edit step:" .. ed.step
        .. "(" .. sq[ed.cseq][ed.step] .. ")"
        .. "  dir: " .. st.dir:string())
    elseif (v == 2) then
      screen.text("running: " .. st.running:string())
    elseif (v == 3) then
      screen.text("tempo: " .. st.tempo:get("tempo"))
    elseif (v == 4) then
      screen.text("direction: " .. st.dirString[st.dir:get()])
    end
  end
end


-- ------------------------------
-- save the data during shutdown.
-- ------------------------------
function cleanup()
  -- make sure we hard-stop the metros
  counter:stop()
  counter2:stop()

  -- save all the data!
  walkabout_save()
  walkabout_savemidi()
end


-- =======================================================================
-- MIDI Handling Routines
-- =======================================================================


-- ---------------------------
-- select a named MIDI device.
-- ---------------------------
function selectMidiDevice(n)
  -- first, deal with clearing out the old...
  if (md.midi_device) then
    if (md.midi_device.name == n) then return
    else md.midi_device = nil end
  end

  -- next, check if it is valid
  local dev = getMidiDevice(n)
  if (not dev) then return end

  -- finally, set the dinner plates!
  md.midi_name = dev.name
  md.midi_device = dev
end


-- ---------------------------
-- find a MIDI device by name.
-- ---------------------------
function getMidiDevice(n)
  for i,dev in pairs(midi.devices) do
    if (dev.name == n) then
      return dev
    end
  end
  return nil
end


-- --------------------------
-- find a MIDI index by name.
-- --------------------------
function getMidiIndex(n)
  for i,v in ipairs(md._devlist) do
    if (v == n) then return i end
  end
  return 1
end


-- -----------------------------------------------
-- deal with a new midi device add (incl startup).
-- -----------------------------------------------
function midi.add(dev)
  md._available = false
  md._devlist = {"none"}

  if (midi.devices) then
    for i,v in pairs(midi.devices) do
      md._available = true
      table.insert(md._devlist, v.name)
    end
  end

  setup_params()
end


-- ---------------------------
-- deal with a device removal.
-- ---------------------------
function midi.remove(dev)
  -- only do this at the class level...
  if (dev) then
    local testname = dev.name

    md._available = false
    md._devlist = {"none"}

    if (midi.devices) then
      for i,v in pairs(midi.devices) do
        if (v.name ~= testname) then
          md._available = true
          table.insert(md._devlist, v.name)
        end
      end
    end

    if (testname == md.midi_name) then
      md.midi_on = false
      md.midi_name = "none"
      md.midi_device = nil
    end

    setup_params()
  end
end


-- --------------------------------------
-- send a note, queue up a noteoff timer.
-- --------------------------------------
function midi_noteon(note)
  if (not md.midi_on) then return end
  if (not md.midi_device) then return end

  -- print("note on to " .. md.midi_device.name .. ": " .. note)
  md.midi_msg = {144, note, 127}
  md.midi_device:send(md.midi_msg)
  counter2:start(0.01, 1)
end


-- ---------------------------
-- deal with a note-off timer.
-- ---------------------------
function noteoff_count()
  if (md.midi_device and md.midi_msg) then
    -- print("note off: " .. md.midi_msg[2])
    md.midi_msg[3] = 0
    md.midi_device:send(md.midi_msg)
    md.midi_msg = nil
  end
end


-- =======================================================================
-- Data Storage Routines
-- =======================================================================


-- -----------------------------
-- save the set data to storage.
-- -----------------------------
function walkabout_save()
  if (not isdir(data_dir .. "ddg")) then
    os.execute("mkdir " .. data_dir .. "ddg")
  end

  local fd=io.open(data_dir .. "ddg/walkabout.data","w+")
  io.output(fd)
  for x=1,NUMSEQS do
    for y=1,NUMSTEPS do
      io.write(sq[x][y] .. "\n")
    end
  end
  io.close(fd)
end


-- -------------------------------
-- save the MIDI setup to storage.
-- -------------------------------
function walkabout_savemidi()
  if (not isdir(data_dir .. "ddg")) then
    os.execute("mkdir " .. data_dir .. "ddg")
  end

  tab.print(md)

  local fd=io.open(data_dir .. "ddg/walkabout_midi.data","w+")
  io.output(fd)
  io.write("1\n") -- version number
  if (md.midi_on) then io.write("true\n")
  else io.write("false\n") end
  io.write(md.midi_name .. "\n")
  io.close(fd)
end


-- -------------------------------
-- load the set data from storage.
-- -------------------------------
function walkabout_load()
  local fd=io.open(data_dir .. "ddg/walkabout.data","r")

  if fd then
    print("datafile found")
    io.input(fd)
    for x=1,NUMSEQS do
      for y=1,NUMSTEPS do
        sq[x][y] = tonumber(io.read()) or 0
      end
    end
    io.close(fd)
  else
    print("datafile not found")
  end
end


-- ---------------------------------
-- load the MIDI setup from storage.
-- ---------------------------------
function walkabout_loadmidi()
  local fd=io.open(data_dir .. "ddg/walkabout_midi.data","r")

  if fd then
    print("midi setup found")
    io.input(fd)
    local version = tonumber(io.read())
    if (version > 0) then
      md.midi_on = (io.read() == "true")
      md.midi_name = io.read()
    end
    io.close(fd)
  else
    print("midi setup not found")
  end
end


-- -------------------------------------------------
-- check if a file or directory exists in this path.
-- -------------------------------------------------
function exists(file)
   local ok, err, code = os.rename(file, file)
   if not ok then
      if code == 13 then
         -- Permission denied, but it exists
         return true
      end
   end
   return ok, err
end


-- -----------------------------------------
-- Check if a directory exists in this path.
-- -----------------------------------------
function isdir(path)
   -- "/" works on both Unix and Windows
   return exists(path.."/")
end
