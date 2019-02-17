pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- lob lob lob! a tank game
-- bright moth games

-- known bugs:
-- engine sound plays forever when moving at end of turn
-- camera doesn't track to next player after death

title, pregame, aim, move, shop, movecam, select, firing, death, postgame = 0, 1, 2, 4, 8, 16, 32, 64, 128, 256
state = title
nextstate = title
statetime=0
fieldwidth=256
gravity=30
maxslope=3
minstart=68
maxstart=92
heightmap={}
grassmap={}
fallingdirt={}
cam={x=0,y=0}
camtarget=nil
camspeed=90
anglespeed=0
pspeed=0
tankspeed=10
players=4
titlefade = false
activetank=1 -- this will change to active tank/player
step=1/60
far_l=0
far_r=128
shield_r=8
defl_r=6
bloomtime=80
offset=0
offset_x=0
offset_y=0
shakemag=2
camfocus=nil
titleidx = 1
titletime = 1
bgframe = 0
text="in the year 30xd, there were... a bunch of tanks... that started... fighting!"
startcolours = { 7, 7, 7, 6, 13, 6}
bloomtypes={
    0x028e, --red
    0x289a --yellow/orange
}
items={
 { ico=32, name="shell", dmg=50, spalsh=25, size=2, mag=1, duration=.065, c=8 },
 { ico=33, name="roll", dmg=75, spalsh=25, size=4, mag=2, duration=.075, c=10},
 { ico=34, name="bomb", dmg=50, spalsh=25, size=15, mag=3.5, duration=.3, c=14 },
 { ico=53, name="leap", dmg=50, spalsh=25, size=4, mag=2, duration=.075, c=11 },
 { ico=49, name="nplm", dmg=0, spalsh=25, c=9 },
 { ico=50, name="mirv", dmg=25, spalsh=50, size=8, mag=2, duration=.095, c=15 },
 { ico=40, name="araid", dmg=0, splash=75, size=10, mag=3, duration=.095, c=7},
 { ico=35, name="shld" },
 { ico=48, name="defl" },
 { ico=51, name="chute"},
 { ico=52, name="fuel" },
 { ico=18, name="warp" }
}
teams={
    {c=nil, name="red"},
    {c=0xc61, name="skye"}, -- light blue
    --{c=0x3b1, name="hunter"}, -- dark green
    {c=0x150, name="royal"},
    {c=0x051, name="void"},
    {c=0x9a4, name="oj"}, -- orange
    {c=0x4f2, name="mud"}, -- brown
    {c=0xb63, name="forest"}, -- light green
    {c=0xf64, name="coach"}, -- tan
    {c=0xaf9, name="sunny"},-- yellow
    {c=0x671, name="gary"}  -- light grey
}
bulletfade={10,10,10,10,10,10,9,9,9,15,15,8,8}
shopitem=1
show_itemselect=false
show_store=false
message=nil

function _init()
 cls()
 poke(0x5f2d, 1)
 music(0)
 state=title
end

function initgame()
 colourlist={1,2,3,4,5,6,7,8,9,10}
 tanks={}
 bullets={}
 blooms={}
 initmap()
 --here we add tanks based on game mode
 for i=1,players,1 do
  local team = colourlist[flr(rnd(#colourlist)+1)]
  del(colourlist, team)
  add_tank(team,(fieldwidth-24)/players*i) -- team
 end
end

function add_tank(team,x)
 if(team == nil) team = 0
 local t={
  sprite=1,
  team=team,
  x=x,
  y=heightmap[x]-7,
  health=100,
  angle=45,
  power=50,
  frame=0,
  item=9,
  ox=4,
  oy=4,
  shp=0,
  grade_r=0,
  grade_l=0,
  ax=cos(45/360),
  ay=sin(45/360),
  cpu=false,
  chute=false,
  shield=false,
  deflector=false,
  tracktgl=false,
  deathclock=0
 }
 for i=1, 8, 1 do
  heightmap[t.x+i] = t.y+8
  grassmap[t.x+i] = heightmap[t.x+i] + 3
 end
 add(tanks,t)
end

function initmap()
 local x = 0
 local y = flr(rnd(maxstart-minstart)) + minstart
 for x=1,fieldwidth do
  add(heightmap, y)
  add(grassmap, y+3)
  local slope = flr(rnd(maxslope*2+1))-maxslope
  y = max(4, y-slope)
 end
end

function addbloom(type, x, y, size, dmg)
 add(blooms, {
     type=type,
     x=x,
     y=y,
     time=0,
     size=size,
     dmg=dmg
 })
end

function addbullet(x,y,velx,vely,id,col)
 local b={
  x=x,y=y,velx=velx,vely=vely,id=id,life=0,idx=1,c=col
 }
 return add(bullets,b)
end

-->8
--update
function _update60()
 if(nextstate == aim and state != aim) then

 end
 state=nextstate
 message=nil
 show_itemselect=false
 if(state == title) then
  updatetitle()
  return
 end

 ct = tanks[activetank]
 if(state == pregame) then
  updatepregame()
 elseif(state == aim) then
  updateaim()
 elseif(state == move) then
  updatemove()
 elseif(state == shop) then
  updateshop()
 elseif(state == movecam) then
  updatemovecam()
 elseif(state == select) then
  updateselect()
 elseif(state == firing) then
  updatefiring()
 elseif(state == death) then
  updatedeath()
 end
 titletime += 1
 if(titletime > 12) bgframe += 1 titletime = 0
 if(bgframe > 3) bgframe = 0
 updatecamera()
end

function updatebullets()
 for i=#bullets,1,-1 do
  local b,hit,itm,cancel = bullets[i], false, items[bullets[i].id], false
  camtarget = b
  local lvy = b.vely
  b.vely += gravity * step
  b.px = b.x
  b.py = b.y
  b.x += b.velx * step
  b.y += b.vely * step
  b.life += 1
  b.idx += 1
  if(b.idx > #bulletfade) b.idx = 1

  if(itm.name == "mirv" and b.vely >= 0 and lvy < 0) then
   b.split = true
   local b1 = addbullet(b.x,b.y,b.velx * 1.5, b.vely, b.id, b.col)
   b1.split = true
   local b2 = addbullet(b.x,b.y,b.velx * .5, b.vely, b.id, b.col)
   b2.split = true
  end
  far_r = max(far_r, b.x)
  far_l = min(far_l, b.x)
  for t in all(tanks) do
   local diff= v_subtr(b,t)
   local dist= v_len(diff.x, diff.y)
   if(t.health <= 0) then -- nuffin
   elseif(t.shield and t.shp > 0) then
    if(dist <= shield_r and (t!=ct or b.life > 10)) then
     -- hit shield, explode
     hit = true
     local ehp = t.shp * 25 - (itm.dmg or 0)
     if(ehp > 0) then
      -- shield absorbed the hit, don't explode (except napalm)
      cancel = true
      t.shp = ceil(ehp/25)
     else
      -- shield broken, munition will explode and full splash damage will be applied
      t.shp = 0
     end
    end
   elseif(t.deflector and t.shp > 0) then
    if(dist <= defl_r and (t!=ct or b.life > 10)) then
     -- hit deflector, calculate bounce
     local normal = v_normalized(diff)
     local vel = {x=b.velx,y=b.vely * -1}
     local dot = v_dot(vel, normal)
     local newvel = v_add(v_mult(normal,-2*dot), vel)
     local newpos = v_add(t, v_mult(normal, (defl_r+1)*-1))
     b.velx = newvel.x
     b.vely = newvel.y
     b.x = newpos.x
     b.y = newpos.y
     t.shp -= 1
    end
   else
    if((ct != t or b.life > 10) and (dist <= 1 or (b.x >= t.x and b.x < (t.x + 7) and b.y > (t.y + 3) and b.y < (t.y + 8)))) then
     -- hit tank, explode
     t.health -= itm.dmg
     hit = true
    end
   end
   if(t.shp < 1) t.shield = false t.deflector = false
   if(hit) break
  end
  if(b.x < 0 or b.x >= fieldwidth
     or b.y >= heightmap[flr(b.x)+1]
     or b.y > 128) then
      hit = true
  end
  if(hit) then
   del(bullets, b)
   if(itm.size and not cancel and (b.split or itm.name != "mirv")) then
    addbloom(1, b.x, b.y, itm.size, itm.dmg)
    if(itm.mag and itm.duration) setshake(itm.mag,itm.duration)
   end
  end
 end

end

function updateblooms(firing)
 for i=#blooms,1,-1 do
  local bl = blooms[i]
  camtarget = bl
  if(bl.time < 21 or not firing) bl.time += 1
  if(bl.time == 25) then
   -- do all the damage calculations once we hit full size.
   local sz=bl.size
   local cx,cy = flr(bl.x),flr(bl.y)
   local mnx,mny,mxx,mxy = cx-sz, cy-sz, cx+sz, cy+sz
   for x = -sz, sz, 1 do
    local miny,maxy,height=1000,-1000,heightmap[x+1+cx] or 128
    for y = -sz, sz, 1 do
     if(x*x + y*y <= sz*sz) then
      if(height <= y+cy and y+cy < miny) miny = y+cy -- hit
      maxy = max(y+cy,maxy)
     end
    end

    if(miny != 1000 and maxy != -1000) then
     if(miny == height) then
      -- circle is at or above the top of the column
      heightmap[x+1+cx] = maxy + 1
     elseif(miny > height) then
      -- circle is top of the column
      -- todo: add leftover dirt to dirt map to fall in another step.
      heightmap[x+1+cx] = maxy + 1 - (miny-height)
     end
    end
   end
   for t in all(tanks) do
    local diff= v_subtr(bl,t)
    local dist= v_len(diff.x, diff.y)
    if(t.health > 0 and dist <= bl.size) then
     -- linear interpolate damage over the blast radius
     local dmg = lerp(1, bl.dmg, dist/bl.size)
     -- shields eat half of any remaining damage, deflectors 25%
     if(t.shield and t.shp > 0) dmg *= .5 t.shp -= 1
     if(t.deflector and t.shp > 0) dmg *=.75 t.shp -= 1
     -- round up the damage to whole numbers.
     t.health -= ceil(dmg)
    end
   end
  end
  if(bl.time > 80) del(blooms, bl)
 end
end

function updatemovecam()
  message="camera"
  camtarget = nil
  local cx, cy = 0, 0
  if (btn(1)) cx += 1
  if (btn(0)) cx -= 1
  if (btn(2)) cy -= 1
  if (btn(3)) cy += 1
  cam.x = mid(0, 128, cam.x + cx)
  cam.y = mid(-128, 0, cam.y + cy)
  if(btnp(4)) then
   sfx(12)
   nextstate = select
   shopitem = ct.item
  end
  if(btnp(5)) nextstate = useitem()
end

function updatemove()
 message="move"
 camtarget = ct
 local tx, cx, cy = 0, flr(ct.x), flr(ct.y)
 local floor = cy + 8
 ct.grade_l=0
 ct.grade_r=0
 if (btn(1) and cx+8 < fieldwidth) then
  tx += tankspeed * step
  sfx(13,3)
  local p6,p7,p8 = heightmap[cx+7],heightmap[cx+8],heightmap[cx+9]
  local maxgrade = max(p6-p7,p7-p8)
  if((p8 < floor and maxgrade > 3) or (p7 < floor and (floor - p7) > 4)) tx = 0
 elseif (btn(0) and cx > 0) then
  tx -= tankspeed * step
  sfx(13,3)
  local p1,p0,pn1 = heightmap[cx+2],heightmap[cx+1],heightmap[cx]
  local maxgrade = max(p1-p0,p0-pn1)
  if((pn1 < floor and maxgrade > 3) or (p0 < floor and (floor - p0) > 4)) tx = 0
 else
  sfx(-2,3)
 end
 local center,r,l = heightmap[flr(ct.x)+5],heightmap[flr(ct.x)+6],heightmap[flr(ct.x)+4]
 ct.grade_l = center-l
 ct.grade_r = center-r
 ct.y = center-8
 ct.x = mid(0, fieldwidth, ct.x + tx)
 if(flr(ct.x) != cx) ct.tracktgl = not ct.tracktgl
 if(btnp(4) or btnp(5)) nextstate = firing
end

function updateaim()
 message="aim"
 local pw,ang,x,y = 0,0,0,0,0,0
 if(ct.cpu) return
 -- todo: cpu aiming

 if (btn(2)) pw += 1
 if (btn(3)) pw -= 1
 if (btn(0)) ang += 1
 if (btn(1)) ang -= 1
 ct.power = mid(0, 100, ct.power + pw)
 ct.angle = mid(0, 180, ct.angle + ang)
 ct.ax = cos(ct.angle/360)
 ct.ay = sin(ct.angle/360)
 if(btnp(4)) nextstate = movecam
 if(btnp(5)) then
  nextstate = firing
  local x = ct.x + 4 + (5 * ct.ax)
  local y = ct.y + 2 + (5 * ct.ay)
  addbullet(x,y,ct.ax*ct.power,ct.ay*ct.power,ct.item,items[ct.item].c)
  setshake(2,0.075)
  sfx(8)
 end
end

function updatefiring()
 camtarget = nil
 updatebullets()
 updateblooms(true)
 if(#bullets<1) then
  nextstate = death
  statetime = 100
 end
end

function updatedeath()
 -- handle any post death 'splosions
 camtarget = nil
 updatebullets()
 updateblooms(false)
 -- finish explosions before doing anything else.
 if(#blooms > 0) return
 local falling,dying = false,false
 for i=#tanks, 1, -1 do
  local t=tanks[i]
  local fl=heightmap[flr(t.x)+1]
  if(flr(t.y) + 8 < fl) then
   t.y += gravity * step
   falling =true
  elseif(flr(t.y) + 8 != fl) then t.y = fl + 8 end
 end

 if(falling) return

 for i=#tanks, 1, -1 do
  local t=tanks[i]
  if(t.health <= 0) t.deathclock += 1 dying = true cam.x = mid(0, fieldwidth-128, t.x-60)
  if(t.deathclock == 1) setshake(5, .3)
  if(t.deathclock > 51) dying = false
 end

if(dying) return

 statetime -= 1
 if(statetime == 90) then
  picknexttank()
 end
 if(statetime <= 90) camtarget = ct
 if(statetime <= 0) nextstate = movecam
end

function updateshop()
  camtarget = nil
end

function updatetitle()
 titletime += 1
 if(titletime > 8) titleidx += 1 titletime = 0
 if(titleidx > 6) titleidx = 1
 if(titlefade) then
  statetime += 1
  if(statetime >= 72) then
   titlefade = false
   nextstate = pregame
   statetime = 72
   initgame()
  end
 elseif(btnp(4) or btnp(5)) then
  titlefade = true
  music(-1, 144)
  sfx(63)
 end
end

function updateselect()
 camtarget = nil
 show_itemselect=true
 message="select item"
 if (btnp(1)) shopitem = min(#items, shopitem + 6) sfx(9)
 if (btnp(0)) shopitem -= 6 sfx(9)
 if (btnp(2)) shopitem -= 1 sfx(9)
 if (btnp(3)) shopitem += 1 sfx(9)
 if(shopitem<1) shopitem = #items
 if(shopitem>#items) shopitem = 1
 if(btnp(4)) nextstate = movecam  sfx(11)
 if(btnp(5)) then
  sfx(10)
  nextstate = movecam
  ct.item = shopitem
 end
end

function updatepregame()
 statetime -= 1
 if(statetime < -32) then
  statetime = 0
  nextstate = movecam
 end
end

function updatesplash()

end

function updatecamera()
 if(camtarget == nil) return
 focus = {x=camtarget.x-60, y=camtarget.y-64}
 camdiff = v_subtr(cam,focus)
 if(flr(v_len(camdiff.x, camdiff.y)) >= 1) then
  cam = v_add(v_mult(v_normalized(camdiff), camspeed * step), cam)
  cam.x = mid(cam.x, 0, fieldwidth-128)
  cam.y = mid(cam.y, -128, 0)
 end
end

-->8
--draw
function _draw()
 cls()
 if(state==title) then
  drawtitle()
  print("press 🅾️ or ❎ to start!", 20, 76, startcolours[titleidx])
 else
  drawgame()
 end

 if(state == pregame or state == postgame or titlefade) then
  local idx = mid(0, flr(statetime / 8), 7)
  fadepalette(idx, 1)
 end
end

function drawgame()
 screen_shake()
 camera(cam.x,cam.y)
 pal()
 rectfill(0,44,fieldwidth,128,1)
 rectfill(0,64,fieldwidth,128,3)
 camera(cam.x*.1,cam.y*1.2)
 map(0,0,0,12,8,4)
 map(0,0,64,12,8,4)
 map(0,0,128,12,3,4)
 camera(cam.x*.3,cam.y*1.1)
 map(0,15,0,48,32,3)
 map(0,18+bgframe,0,72,32,1)
 setcam()
 local t=nil
 for t in all(tanks) do
  t.frame=2+flr(t.angle/180*11)
  local team=teams[t.team]
  if(team.c) then
   c=teams[t.team].c
   pal(8,shr(band(c,0xf00),8))
   pal(14,shr(band(c,0x0f0),4))
   pal(2,band(c,0x00f))
  end
  if(t.tracktgl) pal(13,5) pal(5,13)
  if(t.health > 0 or t.deathclock < 1) then
   if(t.grade_l == t.grade_r) then spr(t.sprite,t.x,t.y)
   elseif(t.grade_r > 1 or t.grade_l < -1) then spr(17,t.x,t.y)
   elseif(t.grade_l > 1 or t.grade_r < -1) then spr(17,t.x,t.y,1,1,true)
   elseif(t.grade_r > 0 or t.grade_l < 0) then spr(16,t.x,t.y)
   elseif(t.grade_l > 0 or t.grade_r < 0) then spr(16,t.x,t.y,1,1,true) end
   spr(t.frame,t.x,t.y-1)
  elseif(t.deathclock>40) then -- nuffin
  elseif(t.deathclock>30) then spr(29,t.x-4,t.y-8,2,2)
  elseif(t.deathclock>20) then spr(27,t.x-4,t.y-8,2,2)
  elseif(t.deathclock>10) then spr(42,t.x,t.y)
  else spr(41,t.x,t.y) end
  pal()

  if(t.shield and t.shp > 0) circ(t.x+4,t.y+4,shield_r,sget(124-flr(t.shp/2),0)) circ(t.x+4,t.y+4,shield_r-1,sget(121,0))
  if(t.deflector and t.shp > 0) circ(t.x+4,t.y+4,defl_r,sget(128-t.shp,0)) circ(t.x+4,t.y+4,defl_r-1,sget(125,0))
  if(t == ct) then
   if(state < firing) spr(20, t.x-1, t.y-11)
   if(state == aim) spr(55, t.x + 4 + (8 * t.ax), t.y + 1 + (8 * t.ay))
  end
 end
 drawmap()
 for b in all(bullets) do
  pset(flr(b.px), flr(b.py),6)
  pset(flr(b.x),flr(b.y),b.c)--bulletfade[b.idx])
 end
 drawblooms()
 drawui()
end

function drawui()
 local cmy = 0
 mx,my = stat(32), stat(33)
 circ(mx,my,1,10)
 if(state == pregame) cmy = 33 + statetime
 camera(0,cmy)
 rect(0,0,127,18,7)
 rectfill(1,1,126,17,0)
 local t = tanks[activetank]
 -- life
 print("armor:",2,3,7)
 rect(25,2,62,8,7)
 if(t.health>0) rectfill(26,3,26+t.health/100*35,7, 8)
 -- item
 local itm = items[t.item]
 print("item:" .. itm.name,66,3,7)
 palt(12,true)
 spr(itm.ico,106-(5-#itm.name)*4,1)
 -- status icons
 if(ct.chute) spr(51,109,10)
 if(ct.shield) spr(35,118,9)
 if(ct.deflector) spr(48,118,9)
 palt(12,false)
 -- power
 print("power:",2,11,7)
 rect(25,10,62,16,7)
 if(t.power>0) rectfill(26,11,26+t.power/100*35,15, 8)
 -- angle
 print("angle:" .. t.angle,66,11,7)


 if(message != nil) then
  local msg = teams[ct.team].name .. ": " .. message
  local width,cl=(#msg*4)+5,shr(band(teams[ct.team].c or 0x800,0xf00),8) or 8
  local x=128/2 -width/2
  rect(x-1,18,x+width+1,26,7)
  rectfill(x,19,x+width,25,0)
  print(msg, x+3,20,cl)
 end
 if(show_itemselect) drawselectitem()
 --print("[" .. cam.x .. "," .. cam.y .. "]",2,122,7)
end

function drawmap()
 for x=1, #heightmap do
  rectfill(x-1, heightmap[x], x-1, 128, 4)
  --fillp(0b1111000011110000)
  fillp(0b1010010110100101)
  if(heightmap[x] <= grassmap[x]) rectfill(x-1, heightmap[x], x-1, grassmap[x], 0xab)
  fillp()
 end
end

function drawselectitem()
    rect(32,32,96,88,7)
    rectfill(33,33,95,87,0)
    local y=34 x=34
    for itm in all(items) do
     local selected = itm == items[ct.item]
     local shopselect = itm == items[shopitem]
     if(shopselect) then palt(12,true)
     elseif(selected) then pal(12,11) end
     spr(itm.ico, x, y)
     palt(12,false)
     pal(12,12)
     print(itm.name, x+10, y+2, 7)
     if(shopselect) spr(54, x, y)
     y += 9
     if(y >= 87) y=34 x=65
    end
end

function drawtitle()
 rectfill(0,12,128,72,1)
 pal(1,0)
 map(0,3,-1,1,16,1)
 pal()
 map(8,4,0,0,16,3)
 fillp(0b1010010110100101)
 rectfill(0,100,128,128,0x43)
 fillp(0)
 map(8,0,0,62,8,2)
 map(8,0,64,62,8,2)
 map(20,0,0,77,4,3)
 map(20,0,32,77,4,3)
 map(20,0,64,77,4,3)
 map(20,0,96,77,4,3)
 map(8,4,0,70,16,1)
 map(16,3,0,96,16,1)
 --map(0,14,0,86,16,1)
 map(0,8,-2,80,16,5)
 drawlob(5,21)
 drawlob(40,35)
 drawlob(75,49)
end

function picknexttank()
 repeat
  activetank += 1
  if(activetank > #tanks) activetank = 1
  ct = tanks[activetank]
 until ct.health > 0
end

function drawsplash()
 rectfill(0,0,128,128,12)
 palt(12,true)
 palt(0,false)
 map(0,4,32,48,8,4)
 palt()
 local idx = mid(0, flr(statetime / 8), 7)
 fadepalette(idx, 1)
end

function drawlob(x,y)
 spr(70,x,y,2,2)
 spr(72,x+15,y,2,2)
 spr(74,x+27,y,2,2)
 spr(76,x+38,y,2,2)
end

function drawblooms()
 for bl in all(blooms) do
  local bstep,ringsize,grd = bl.size/20, bl.size / min(bl.size, 4), bloomtypes[bl.type]
  local mn, mx, c = 1, bl.size, circfill
  if(bl.time < 20) then mx = flr(bl.time * bstep)
  elseif(bl.time > 59) then mn = ceil((bl.time -60) * bstep) c = circ end

  if(bl.time >18) grd = rotl(bor(shr(grd,16), grd),4*flr((bl.time-20)/5))

  for i=mx,mn,-1 do
   if(i >= 4 * ringsize) then c(bl.x,bl.y,i,shr(band(grd,0xf000),12))
   elseif(i >= 3 * ringsize) then c(bl.x,bl.y,i,shr(band(grd,0x0f00),8))
   elseif(i >= 2 * ringsize) then c(bl.x,bl.y,i,shr(band(grd,0x00f0),4))
   else c(bl.x,bl.y,i,band(grd,0x000f)) end
  end
 end
end
-->8
--helpers
function useitem()
 local used,st,itm=false,firing,items[ct.item]
 if(itm.name == "chute") then ct.chute = not ct.chute used = true
 elseif(itm.name == "shld") then ct.shp = 8 ct.shield = true ct.deflector = false used = true
 elseif(itm.name == "defl") then ct.shp = 4 ct.deflector = true ct.shield = false used = true
 elseif(itm.name == "fuel") then  used = true st = move end
 if(used) return st
 return aim
end

function v_len(x, y)
  local d = max(abs(x),abs(y))
  local n = min(abs(x),abs(y)) / d
  return sqrt(n*n + 1) * d
end

function v_subtr(a,b)
 return {
    x = (b.x + (b.ox or 0)) - (a.x + (a.ox or 0)),
    y = (b.y + (b.oy or 0)) - (a.y + (a.oy or 0))
 }
end

function v_normalized(v)
 local len,nv = v_len(v.x, v.y), {x=v.x,y=v.y}
 if(len != 0) nv.x /= len nv.y /= len
 return nv
end

function v_distance(a, b)
 local v = v_subtr(a,b)
 return v_len(v.x, v.y)
end

function v_dot(a,b)
 return a.x * b.x + a.y * b.y
end

function v_mult(v,f)
 return {
     x=v.x*f,
     y=v.y*f
 }
end

function v_add(a,b)
 return {
    x = (b.x + (b.ox or 0)) + (a.x + (a.ox or 0)),
    y = (b.y + (b.oy or 0)) + (a.y + (a.oy or 0))
 }
end

function setcam()
 camera(cam.x+offset_x, cam.y+offset_y)
end

function setshake(mag,duration)
 offset = duration
 shakemag = mag
end

function screen_shake()
  local fade = 0.95
  offset_x=(1-rnd(2))*shakemag
  offset_y=(1-rnd(2))*shakemag
  offset_x*=offset
  offset_y*=offset

  offset*=fade
  if offset<0.05 then
    offset=0
  end
end

function round(a)
 return flr(a + .5)
end

function v_round(v)
	return {x=round(v.x),y=round(v.y)}
end

function lerp(v0, v1, t)
  return (1 - t) * v0 + t * v1;
end

function fadepalette(idx, fullscreen)
	pal(1, sget(120 + idx, 1), fullscreen)
	pal(2, sget(120 + idx, 2), fullscreen)
	pal(3, sget(120 + idx, 3), fullscreen)
	pal(4, sget(120 + idx, 4), fullscreen)
	pal(5, sget(120 + idx, 5), fullscreen)
	pal(6, sget(120 + idx, 6), fullscreen)
	pal(7, sget(120 + idx, 7), fullscreen)
	pal(8, sget(120 + idx, 8), fullscreen)
	pal(9, sget(120 + idx, 9), fullscreen)
	pal(10, sget(120 + idx, 10), fullscreen)
	pal(11, sget(120 + idx, 11), fullscreen)
	pal(12, sget(120 + idx, 12), fullscreen)
	pal(13, sget(120 + idx, 13), fullscreen)
	pal(14, sget(120 + idx, 14), fullscreen)
	pal(15, sget(120 + idx, 15), fullscreen)
end
__gfx__
00000000000000000000000000000000000000050000005000005000000500000000500000050000050000005000000000000000000000000000000076d5e2d5
00000000000000000000000000000000000000500000056000005600000560000006500000650000065000000500000000000000000000000000000011000000
007007000008e0000000000000000555000005600000560000005600000560000006500000650000006500000650000055500000000000000000000021100000
0007700000888e000000055500000660000006000000060000000600000000000000000000600000006000000060000006600000555000000000000033110000
0007700088eeee8e0000006000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000044221000
00700700282882820000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055110000
00000000d22222250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066dd5100
0000000005d5d5d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007776d510
0000000000000000ccddddcc00000000006667700000000000000000000000000000000000002000002220000a00000000000000000000000000000088842100
00000000008e00e0cd6776dc0000000000067700000000000000000000000000000000000004220000424000000000000080000a00000000000000a099942100
000e80000088e882cca9f9cc000000000000700000000000000000000000000005d61420001624000016100000000000000800000000000a09000000aa994210
00e88e8808ee822dccafa9cc000000000000000000000000000000000000000055dd62200dd1100000dd60000000000900000000a000090000000000bbb33100
e8eee28208282250ccf9afcc00000000000000000000d0000000055550000000055d142055dd0000005dd00000000000000000000000000000090000ccdd5100
2828222588225d00cd6776dc00000000000000000000600005555213000000000000000055d000000055500000880900009900000000000000000000dd511000
d222d5d0525d0000c1dddd1c005e8500000000000d007e5554442130000008800000000000000000000500000080090a09a0000009a0000000000080ee444210
05d500000d000000cc1111cc00dd6d0000000000060fd8664442130022007e88000000000000000000000000000099000090900000000000000a0000fff94210
cccccccccccccccccccccccccccccccc0000000007e5d832222130022220e7e8cccc6558000000000900008000008900a0900000800000090000009000033000
cccccccccccddcccccc6688ccaaaaaac000000d6fd86d6442213555551118e7ec655638e0008080080000a08000880000a009008000000000000009003533530
c6d668ccccd77dccc6d77ee8c9d77dac00d75d675d83d34211159988944188e72d5335110088e0000998e9900a08880000008800000900000000000035333353
c7d77eecc57987dcc7d77eeec967769c0d6739393d5551111133338931122880c11111cc0889ae800a89ae00000000099008800000000000000000003535d353
c656688cc568975cc656688ec9d66d9c025393939d33d22222d3333332220000cc68cccc88a99e8e889a9a8e000009000000a000080000000000000035d5bd53
c656681cc156651cc6566888c196691c56d22223333364444663332220000000cc11cccc28298a82289aa2820000d00000000000088800a0009008805db5bbd5
c11111cccc1551ccc1166881cc1991cc00000002222251111152225000000000cccc68ccd22a2225da2922a500d00500a0d0d5d0008800000000000005050050
ccccccccccc11cccccc1111cccc11ccc00000000000050000050550000000000cccc11cc05d5d5d005d5d5d0000d005005005d000d500050005dd05d05050050
cccc8ccccccccccccccccccccce7e7cccccccccccccccccc0a9009a00a0000000003d000004004000000000000000000000000000000000000000000005dd500
cccc7ccc9cac9cccc8eccccccee66e7ccefd35cccccccccca000000aa0a000005d0d300005404500000000000000000000000000000000000000000096969454
cddc6ccc191ca9ccc8866cccee666ee7c11f115c66ccc82c900000090a00000053033000045040400000000000000000000155000000000000000000979794d4
ceed666cc198fa9cc116c78c61117116cc33335ccc6c788c000000000000000053d3d0d50545454405565000000000000005d600000000000000000099999454
c22edcccc9f99a9ccc6c7c1c16cc7c61cc33535cccc7c11c000000000000000005333035445454005d666500044449f000015500000000505050505000000000
cd22edccc19f891cccc7c8cccc6996cccc35335cccc7cccc9000000900000000000d3d35005450006ddd665005554f9001551550000506d6d6d6d6d600000000
c352edcccc1991ccccc8c1ccccc11ccccc33335ccccccccca000000a000000000003335000054000d5d6dd65444f94f905d65d60006d505d505d505d00000000
c11111ccccc11cccccc1cccccccccccccc11111ccccccccc0a9009a00000000000033000005544005d5dd55d5449f59f01551550d500d50d050d050d00000000
cccccccc00000000000000000000000000000000cccccccc0000000aa7710000000000449aa771000000000aaaa771000000000aa7710000ccccccc8cccccccc
cccccccc00000000000000000000000000000000cccccccc0000009aaa7200000000049aaaaaa7100000009aaaaaa7100000009aaa720000ccccccc98ccccccc
cccccccc00000000000000000000016100000000cccccccc000000aaf6a2000000004aaffffffaa1000000aaaaaffa20000000aaf6a20000ccccccfa9fcccccc
cccccccc00000000000000000000d606008e0000cccccccc000009aaa621000000009aaa444aafa2000009aa944aaf20000009aaa621000005cccc7777cccc50
cccccccc0000000000000000000d676d00826000cccccccc00005aff662000000005aaf91129fa6200005aff222ff41000005aff662000000005c07ff70c5000
cccccccc000000000000000000d67dd000067600cccccccc00004aaa621000000004aa620059a66200004aa91099620000004aaa621000000600500ff0050060
cccccccc00022222002222201d6dd10000005750cccccccc0005fff662000000005fff61004ff6210005ffffffff42000005fff6620000005002050440502005
cccccccc2224242222888e22d6dd0000000005a0cccccccc00049faf210000000049f6200599f6200004999999f5210000049faf210000006506005dd5006056
000000552442222882888fe5d5d00000cccccccca00000000059996f20000000059996100499621000599992299910000059996f20000000c65000522500056c
00000515522222288f2288855d000000cccccccc00000000004996f21000000004996200599962000049962109992000002996f2100000009465565665655649
000051112522228888e2288820000000cccccccc09000000059996f20000000049996100499f210005999510499f20000522222200000000ac00602dd20600ca
000511211252248898e2228882000000cccccccc00aa00000499f66aaaaa77704996655d669620000499faaa999620000496642100000000c56000022000065c
00051211116522488a82222882000000cccccccc000000004999f666666666a249999999996210004999f6666662100049996d2000000000c65005600650056c
000651111156d2244428822242000000cccccccc00000a004999999999996f2154999999f6520000499999999452000049999210000000009c6556a55a6556c9
00051111255f655222888e2220000000cccccccc000000005444444444444420054444444421000054444444422100005444420000000000ca966999999669ac
0006511215d6f65222488ee222000000cccccccc000000000122222222222210012222222100000001222222210000000122210000000000cccc44999944cccc
0005612155d46f58222888ee22200000cccccccccccccccc0000000000000000ccccccccccccccccccccccccccccccccc0cccccccccc0ccccccccccccccccccc
000551115d6d4658882288eee2222000cccccccccccccccc0990900000000000cccccccccccccccccccccccccccccccc0c0cccccccc0c0cccccccccccccccccc
000051156dd6d569988228ee842fe200cccccccccccccccc97a90000000000000ccccccccccccccccccccc00ccccccccc0c0cccccc0c0cccccccccccc000cccc
00000565d6dd6529a88e22ee82288e20cccccccccccccccc0aa6000000000000000000ccccccc00ccccc000ccccc000ccccc000000cccccccccc000c000ccccc
00000056dd6d562228eee22842288820cccccccccccccccc0015d60000000000000cc00ccccc00ccccccc00cccc000ccccc00000000cccccccc000ccc00ccccc
000000056dd6511222ee882252489820cccccccccccccccc90005dd600000000c00cc00cccccccccccccc00ccccc00c00c00cc00cc00cccccccc00c0000c0ccc
0000000056550011222e998555248a20cccccccccccccccc000009ddfa000000c00000cc0c00c00c0000c00c0c000000c000cc00cc000cc00c000000c00000cc
000000000000000112229a85fd522200cccccccccccccccc0000999999a00000c0000cc0000c00c00c00000000c0000cc0000c00c0000c0000c0000cc00c00cc
cccccccccccccccc1122285d6fd55000cccccccccccccccc00affffffffaff00c00c00cc00cc00c00c00c00c00cc00ccc0000c00c0000000c00c00ccc00c000c
cccccccccccccccc0512255d46f50000cccccccccccccccc55ff9999ddd55af0c00cc00c00cc00c00c00c00c00cc00ccc0000c00c0000c00c00c00ccc00cc00c
cccccccccccccccc005656d6d4650000ccccccccccccccccddaa99aa55111d5fc00ccc00000cc00c0000000c00c000c0cc000c00c000cc00c00000cc000cc00c
cccccccccccccccc00056d6d6d500000cccccccccccccccc55444444dd21112dc00ccc00c0ccc0ccc000c0c00ccc000ccc00cc00cc00ccc0000c000cc0cc000c
cccccccccccccccc000056d6d6500000cccccccccccccccc0dd2222255111115c00cc000ccccccc00c00ccc0ccccc0cc0c0cc0000cc0c0cc00ccc0ccccc000cc
cccccccccccccccc0000055d55000000cccccccccccccccc0055d5d11ddd5d5dc000000cccccc000000ccccc0cccccccc0cccccccccc0cccccccccccccc00ccc
cccccccccccccccc0000005550000000cccccccccccccccc0000000000000000000000cccccccc00ccccccccccccccccccccccccccccccccccccccccccc0cccc
cccccccccccccccc0000000000000000cccccccccccccccc000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccccccccccccc0ccc
00000000000000000000000000000000000000000000000000000000000000000000005444000000000000000000000000000000000000000000000000000000
00000000000d50000000000000000000000000000000000000000000000000000000544455440000000000000000000000000000000000000000000004450000
00000000005dd55d00000000000000000000000000000d0000000000000000000000445445540400000000000000000000000000000000000000000004554540
000000000555ddddd00005d5000000000000000000555dd000000000000000000000445445540400000000004445400000000000000000000000000044554540
0000000005555dddd00555dd50000000000000000555ddddd0000000550000005450445445440400000000045445445000000000000000000000400044545540
000000005555d55dd555555ddd500000000000055555d5dddd5000555d0000004450445444454400000000045445545000000004454000000004400054545540
0000dd055555d55ddd55555ddddd0000000000555dd5dd5dddd50555ddd500004450444444444550000000045444555400000044454000000004400054545540
00055dd5ddd5d555ddd55555ddddd0000000055555d55d5dddd5d555dddd50004445554444544444000000045454555400004045455400000004440454445544
055555dddddd5d55dddddd55dd55ddd000005dd555dd5dd5d5dddd55d5dddd004544455555445444400000444454555400004045455404000404454454444554
5555dd5d5dddddd55dd55dd555d555dd005555dd555d55d55ddd5d55dd5ddd504544545445444554444000445554555500054045445444000454554544554554
5dd5ddddddddd55d5dd5555dd5dd55555dd5555dddddd5dd5ddddd55d555ddd55555544445544444445444555554454405055445445445444444544544544545
55dd555ddd5dd55555555555555dd5555d55ddd5ddd5dd5d55d55dd5d5555ddd5555544445544444454454444444444444445544455444545454444445544555
d5555555dd5555551515151555555555555555ddddd55555555555d55dd5555d1554555544554455554445555555555555454445554555554544555454555555
55555555555555515151515151515151555555555dd555555555555555dd55555155545555555555555555555555555555555555555555555555555555555551
55555555151555151515151515151515151515155555555555555555555d55151515555555555555151515551555555515555555555555551515555555551515
51515151515151515151515151515151515151515151515155555555515151515151515155515151515151555151515151515151555551515151515151515151
15151515000000000000000770000000151515151515151515151515151555150000000000000000000000000000000000000000000000000000000000000000
515151510000000000000677f7600000515551515151515151515151515151510000000000000000000000000000000000000000000000000000000000000000
151515150000000000067c7ccbf76000155555151515151515155515155515150000000000000000000000000000000000000000000000000000000000000000
5151515100000000006cdc6cccb77600555555515151515551555555555551510000000000000000000000000000000000000000000000000000000000000000
111511150000000000777cccc77b7700555555551515155555555555555555550000000000000000000000000000000000000000000000000000000000000000
151115110000000006f76c6ccc777760555555555551555555555555555555550000000000000000000000000000000000000000000000000000000000000000
111511150000000007c6bc76c6c776d0555555555555555555555555555555550000000000000000000000000000000000000000000000000000000000000000
151115110000000067b67c6cd7d46611555555555555555555555555555555550000000000000000000000000000000000000000000000000000000000000000
111111150000000067bbc76dcd566d215555ddd5d555555555555555555555550000000000000000000000000000000000000000000000000000000000000000
11111111000000000d76bfcdd561dd10555ddd6dddd55555555dd55555dd55550000000000000000000000000000000000000000000000000000000000000000
111511110000000001d7745511525100dddd66666ddd5555ddddddddddd6d5550000000000000000000000000000000000000000000000000000000000000000
1111111100000000001125d2521500006666666666ddddddd666dddddd666ddd0000000000000000000000000000000000000000000000000000000000000000
1111111500000000000001551100000066666666666dddd6666666dd666666dd0000000000000000000000000000000000000000000000000000000000000000
11111111000000000000000000000000666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000
11151111000000000000000000000000661111116666611166166666661111660505050505050505050505050505050505050505050505050505050505050505
11111111000000000000000000000000111111111111111111111111111111115050505050505050505050505050505050505050505050505050505050505050
00000000000000000000000000000000454445444544444545444445454445440000000000000000000000000000000000000000000000000000000000000000
05000000000500000030000000000000544444444444444454445444444454440000000000000000000000000000000000000000000000000878000000000000
0550005000055000003d000500000000444444454444454444444545454444450000000000000000000000000000000000878000000000000606000077870000
55500050005500300333d05500305005444454444545544444445254444454440000000000065000000000000000000000606000000000000800000886687000
050030550005033d003500055333550554454444444544444444454454454444500000065575555500000005755000000000800786e0000006b0007682686800
05533055035555300333d035003d50554445454444444254544442444445454455500075565555560000055655655000bbbb608e678600bbb8bbbb267bb268bb
0500305553553d330333303d333330054444424445444424544444444444424455d555556d5d55755000566d55556550bbbb8b673b27bb3bbbbbb788bbbb277b
555333555d55533533d333355330505544444444244444442554444444444444555555555555555555556d5555565555b3bb6b72bbb8bbbbbbbbb768ebbb688b
5353335533355343d3433335333335554444444444444444454425444444244455555555555555555555555555555555b3bbbb87bbbbbbebb3b3bbbbbbbe287b
53d34335533533433343d34333d333354454444454544552425454444542444455dd57005d555dd55555555555555565bbbb3b76bbb3b3bb83333bb3bbbb667b
d333d33334333d433dd333d333433d334445445442444444545244444455445455555555555555555655d555d5555555bbbbbb62bbbbbb3b338ee33bb8bb668e
3333dd3dd43333d33d4333d3334d333d444242444444444455544444444245445655d555555555565556000006055555eebbbb86bbbbbb3333888333b3bb288b
33434333343d334dd3433d4d3343d4335542544445522454452444554444554455565000d6d7055555d5700d557d5d55bbb33b67bbb3b333b333b3333bb8267b
3343433d343d333333d333433d433d33444454454444454445244544444425445d6d550000d550055555555555555555bb33b372bb3b8ee33333338eebbb667b
3d434d3334d43ddd334dd343334334d355425454445444445552444444242544d555555555555d55555d555555555d5533e33bbbbbb388833833338883bb688b
d34343333d34334333433333334334d3445444444445444444444454444444445555556555555555555555d55655555d333333bbbb333333333333b3333b287b
3343333333333343334333333d33333344444444424444444444544544424444555555555555555555555555555555553b3333333833b3333333333333b36673
334343d333333d43d34333433333333342444444444444444444444454544444555555555555d05d6d6d5555555555553333b383333333333338ee3333336683
3333433334d333433d333333334d3d334445444544444445445244442544444455555555d55d00d6d666655555505d6533833333333333333338883333332233
3d334333343333333333d333334d3333444444244454452444524444424444455555555555d00000000666555d5d05d033338333333338333833333338333633
334d43333333333333433333334d343d4244525444424544444524445244444400d765555d560000000065dd5555555533333333333333333333333333333333
33333333d33333d33333d33d3343333344444544442454444445444455244444d000dd5d55d5d00000065d555555555d33333333338333333333833333333333
33334d3333333333d3333343d33333334444444444444444444444444544454455555555555d5dd5d5d5555555555d5533333338333333333333333333333338
33333333333333333333333333333333444444442444444444444444444444445555555555555555555555555555555533333333333333333333333333333333
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000000000000000000000000000
d76dd6dd6d676d66d6dd66d767d6d676dddd7666dddddd76d67ddddddd667ddd0000000000000000000000000000000000000000000000000000000000000000
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000000000000000000000000000
dd67d6d6766d6676dd67d66d6ddd6d66dddd66dddd667dddddd6667ddddd676d0000000000000000000000000000000000000000000000000000000000000000
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000000000000000000000000000
ddddddddddddddddddddddddddddddddd6667ddd666d766d667ddddd6667dddd0000000000000000000000000000000000000000000000000000000000000000
d67dd67d666d676d66d67d666d766dd6dddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000000000000000000000000000
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000330000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000030000000000000000000000000000333000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000030000000000000000000000000030333300000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000030000000000000000000000000033443300000000000000000000000000000000000000000000000000000000
00030000000000000000000003000000000003343000000000000000000000000333444300000000000000000000000000000000000000000000000000000000
00330000000000000000000003030000003033343000000000000000000000000343444430000000000000000000000000000000000000000000000000000000
03330300000000000000000003330300033333343300000000000000000000003344444430300000000000000000000000000000000000000000000000000000
03343300000000003330003034333330033334444330000000000000000000003444444433300000000000000000000000000000000000000000000000000000
33443300000000303330033034343333034344444330000000000000000000033444444443300000000000000000000000000000000000000000000000000000
34443430000303303330033034443433344444444433000000000000000033034444444443433300000000000000000000000000000000000000000000000000
34444433030333334443334344444443344444444443000000000303000033034444444444433300000000000000000000000000000000000000000000000000
44444433330333434443344344444444344444444443300000003333300033344444444444433300000000000000000000000000000000000000000000000000
44444443333434434443344344444444444444444444303300033333333344344444444444444430000000000000000000000000000000000000000000000000
44444444343444444444444444444444444444444444333300033434333344344444444444444433000000000000000000000000000000000000000000000000
44444444443444444444444444444444444444444444433330034444433344444444444444444433000000000000000000000000000000000000000000000000
44444444444444444444444444444444444444444444434430344444444444444444444444444443000003000000000000000000000000000000000000000000
44444444444444444444444444444444444444444444444433344444444444444444444444444444300003000000000000000003300000030000000000000000
44444444444444444444444444444444444444444444444443344444444444444444444444444444300003030000000000000003330000033000300000000000
44444444444444444444444444444444444444444444444443444444444444444444444444444444303034330000000300000003330300033300300000000000
44444444444444444444444444444444444444444444444444444444444444444444444444444444433034333000000300000034430330343300303000000000
44444444444444444444444444444444444444444444444444444444444444444444444444444444433034343300003300333034443333344303433000000000
44444444444444444444444444444444444444444444444444444444444444444444444444444444434344443303003433333334443433344433433300000030
44444444444444444444444444444444444444444444444444444444444444444444444444444444444344444333033433333344443443444433434330003030
44444444444444444444444444444444444444444444444444444444444444444444444444444444444344444433334433444344444444444434444330003330
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444434334444444444444444444444444430003343
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444344444444444444444444444444443334343
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444443334443
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444443334444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444

__map__
808182838485868788898a8b8c8d8e8fc0c1c2c3c4c5c6c7c8c9cacbcccdcecf000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
909192939495969798999a9b9c9d9e9fd0d1d2d3d4d5d6d7d8d9dadbdcdddedf000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0e0e1e2e3e4e5e6e7e8e9eaebecedeeef000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b03e3e3e3e3e3e3e3e3e3c3c003d3e3e3e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000004e4f000000b8b8b8b8b8b8b8b8b8b8b8b8b8b8b8b80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000005e5f000000a4a5a6a7a4a5a6a7a4a5a6a7a4a5a6a70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
68696a6b6c6d6e6fb4b5b6b7b4b5b6b7b4b5b6b7b4b5b6b70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
78797a7b7c7d7e7f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000004142430000000000005500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000505152530000000000000055000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001b606162630039000000000000666700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2d1d2a1e72730000000039000000767700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0038003a38000000003d3d3b0038000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c0c1c2c3c2c1c2c3c0c1c2c3c3c1c2c3c1c1c2c0c0c1c2c3c0c1c2c1c3c1c2c3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d0d1d2d3d0d1d2d3d0d1d2d3d0d1d2d3d0d1d2d3d0d1d2d3d0d1d2d3d0d1d2d3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0e1e2e3e0e1e2e3e0e1e2e3e0e1e2e3e0e1e2e3e0e1e2e3e0e1e2e3e0e1e2e3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1f2f3f0f1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010800001d5501d5501f5501f55022550225502755027550275502755027550275502755027550275502755027550275502655026550265502655026550265502150021500225002150021500215000000000000
010c00000e70500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001865018650186501865018650186501865018650186501865018650186501865018650186501865018650186501865018650186501865018650186501865018650186501865018650186501865018650
011000001812018120181201812018120181201812018120181201812018120181201812018120181201812018120181201812018120181201812018120181201812018120181201812018120181201812018120
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0105000034d5027d501ed5010d500ad503fd5035d502ed502fd502fd502bd5025d501cd4016d4011d400ed400bd300ad3008d3008d3006d3004d3004d3005d3005d3005d3004d2003d2002d2003d1004d1003d10
010c00000e73500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01070000181251f125241250010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
010a0000107350c735007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
010400000c73010731117311773100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400020022000210002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
010600000f0520f0520f0520f0520f0520f0520f0520f0520f0520f0420f0320f0220f0120f0150f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600001105211052110521105211052110521105211052110521104211032110221101211015000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010818000505000000000000000005050000000505000000000000000005050000000505000000000000000005050000000505000000000500000005050000000000000000000000000000000000000000000000
010800003761500000000000000000000000003761500000376150000037615000003761500000000000000000000000003761500000000000000000000000000000000000000000000000000000000000000000
010800001d5501d5501d5501d5501d5501d5501d5501d55018550185501d5501d5501f5501f5501f5501f5501f5501f5501f5501f550185501855022550225502150021500225002150021500215000000000000
01080000225502255021550215501f5501f5502155021550215502155021550215502155021550215502155021550215502155021550215502155021550215500000000000000000000000000000000000000000
010800002255022550225502255024550245502155021550215502155021550215502155021550215502155021550215501d5501d550215502155024550245500000000000000000000000000000000000000000
010800002755027550275502755027550275502755027550275502755027550275502655026550265502655026550265502655026550265502655026550265502150021500225002150021500215000000000000
010800002455024550225502255021550215502155021550215502155021550215502155021550215502155021550215502155021550215502155021550215502150021500225002150021500215000000000000
010818000305000000000000000003050000000305000000000000000003050000000305000000000000000003050000000305000000000500000000050000000000000000000000000000000000000000000000
010818000505000000000000000005050000000505000000000000000005050000000505000000000000000005050000000505000000000500000005050000000000000000000000000000000000000000000000
010800002755027550275502755027550275502755027550275502755027550275502b5502b5502b5502b550245502455024550245502b5502b5502b5502b5500000000000000000000000000000000000000000
010800002d5502d5502d5502d5502d5502d5502d5502d5502d5502d5502d5502d5502d5502d5502d5502d5502d5402d5402d5302d5302d5202d5202d5102d5100000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0106000018e401de401fe4024e4018e301de301fe3024e3018e201de201fe2024e2018e101de101fe1024e1000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e00
__music__
00 0f101112
00 0f101113
00 0f101112
00 0f101114
00 0e171115
00 0f101116
00 0e171119
02 0f10111a
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 0f101100

