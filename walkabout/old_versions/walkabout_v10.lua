-- walkabout.lua
-- A slider-based sequencer
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
-- sequencer values auto-saved
-- on select or shutdown
--
-- writes to "data/ddg/walkabout.data"

engine.name = "PolyPerc"

local ControlSpec = require 'controlspec'
local Control = require 'params/control'
local Option = require 'params/option'

-- constants
local NUMSTEPS = 8
local NUMSEQS = 8

-- table starters...
local sq = {
  {0, 0, 0, 0, 0, 0, 0, 0},
  {0, 0, 0, 0, 0, 0, 0, 0},
  {0, 0, 0, 0, 0, 0, 0, 0},
  {0, 0, 0, 0, 0, 0, 0, 0},
  {0, 0, 0, 0, 0, 0, 0, 0},
  {0, 0, 0, 0, 0, 0, 0, 0},
  {0, 0, 0, 0, 0, 0, 0, 0},
  {0, 0, 0, 0, 0, 0, 0, 0}
}

local ed = {}
local st = {}


-- -----------------------
-- initialization routine
-- -----------------------
function init()
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

  st.dir = Option.new("dir", {"fwd", "bwd", "udn", "rot", "rnd"})
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

  counter = metro.alloc(count, 0.125, - 1)
  -- comment out the next line if you don't want to start running
  st.running:set(2)
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
  end
end


-- -----------------------------------
-- convert a midi note to a frequency.
-- -----------------------------------
function midi_to_hz(note)
  return (440 / 32) * (2 ^ ((note - 9) / 12))
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
walkabout_save()
end


-- -----------------------------
-- save the set data to storage.
-- -----------------------------
function walkabout_save()
if (not isdir(data_dir .. "ddg")) then
  os.execute("mkdir " .. data_dir .. "ddg")
end

local fd = io.open(data_dir .. "ddg/walkabout.data", "w+")
io.output(fd)
for x = 1, NUMSEQS do
  for y = 1, NUMSTEPS do
    io.write(sq[x][y] .. "\n")
  end
end
io.close(fd)
end


-- -------------------------------
-- load the set data from storage.
-- -------------------------------
function walkabout_load()
local fd = io.open(data_dir .. "ddg/walkabout.data", "r")

if fd then
  print("datafile found")
  io.input(fd)
  for x = 1, NUMSEQS do
    for y = 1, NUMSTEPS do
      sq[x][y] = tonumber(io.read())
    end
  end
  io.close(fd)
else
  print("datafile not found")
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
