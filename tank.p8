pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- lob lob lob! a tank game
-- bright moth games

-- known bugs:
-- engine sound plays forever when moving at end of turn
-- camera doesn't track to next player after death

title, pregame, aim, move, shop, movecam, select, firing, death, postgame, logo = 0, 1, 2, 4, 8, 16, 32, 64, 128, 256, 512
state = logo
raidbombs=3
nextstate = logo
statetime=0
fieldwidth=256
gravity=30
camtarget=nil
camspeed=90
tankspeed=10
players=4
logotimer=0
titlefade = false
activetank=1 -- this will change to active tank/player
step=1/60
far_l=0
far_r=128
shield_r=8
defl_r=6
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
    0x289a, --yellow/orange
    0x7c7c -- blue
}
items={
 { ico=32, name="shell", dmg=50, spalsh=25, size=2, mag=1, duration=.065, c=8, stock = -1, cost = 0},
 { ico=33, name="roll ", dmg=5, spalsh=0, size=0, mag=.1, duration=.01, c=10, stock = 2, cost = 100 },
 { ico=34, name="bomb ", dmg=50, spalsh=25, size=16, mag=3.5, duration=.3, c=14, stock =  4, cost = 500 },
 { ico=53, name="leap ", dmg=50, spalsh=25, size=6, mag=2, duration=.075, c=11, stock = 4, cost = 100 },
 { ico=49, name="nplm ", dmg=0, spalsh=25, c=9, cost = 250 },
 { ico=50, name="mirv ", dmg=25, spalsh=50, size=8, mag=2, duration=.095, c=15, cost = 750},
 { ico=40, name="araid", dmg=0, splash=0, size=0, mag=0, duration=.095, c=7, stock = 1, cost = 2000},
 { ico=35, name="shld ", stock = 1, cost = 250 },
 { ico=48, name="defl ", cost = 500 },
 { ico=51, name="chute", stock = 1, cost = 50},
 { ico=52, name="fuel ", stock = 4, cost = 50 },
 { ico=18, name="warp ", stock = 2 , cost = 300 }
}

teams={
  {c=nil, name="red"},
  {c=0xc61, name="skye"}, -- light blue
  {c=0x3b1, name="hunter"}, -- dark green
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
message=nil

function _init()
 cls()
 cam=v_new(0,0)
 poke(0x5f2d, 1)
 rocktypes={
    v_new(56,24),
    v_new(60,24),
    v_new(56,28),
    v_new(60,28)
 }
 subitems={
    {name="roller", dmg=75, splash=25, size=6, mag=2, duration=.075, id=33, offsets={v_new(-4,-7)} },
    {name="bomb", dmg=50, splash=75, size=10, mag=3, duration=.095, id=24, offsets={v_new(0,-4),v_new(0,-6),v_new(-4,-7)} }
 }
end

function resetround()
 mapseed=rndi(12)
 bullets={}
 blooms={}
 plx=-64
 ply=-16
 plspeed=55
 plflip=true
 plalt=false
 plactive=false
 pltime=0
 plopen=false
 pltarget=128
 plbtime=0
 plbombcount=raidbombs
 initmap()
 for i=1,#tanks,1 do
  local t,x = tanks[i],(fieldwidth-24)/players*i
  t.deathclock = 0
  t.deflector = false
  t.shield = false
  t.chute = false
  t.shp = 0
  t.health = 100
  t.grade_r=0
  t.grade_l=0
  t.x=x
  t.y=heightmap[x]-4
  for i=1, 8, 1 do
   local lx,rx,tf = t.x - 8 + i, t.x + i + 8, t.y+8
   heightmap[t.x+i] = tf
   heightmap[rx] = flr(lerp(tf,heightmap[rx],i/8))
   heightmap[lx] = flr(lerp(heightmap[lx],tf,i/8))
   grassmap[t.x+i] = heightmap[t.x+i] + 3
   grassmap[lx] = heightmap[lx] + 3
   grassmap[rx] = heightmap[rx] + 3

  end
 end
 music(08)
end

function initgame()
 colourlist={1,2,3,4,5,6,7,8,9,10,11}
 tanks={}
 --here we add tanks based on game mode
 for i=1,players,1 do
  local team = colourlist[rndi(#colourlist)+1]
  del(colourlist, team)
  add_tank(team) -- team
 end
 resetround()
end

function add_tank(team)
 if(team == nil) team = 0
 local t={
  sprite=1,
  team=team,
  angle=45,
  power=50,
  frame=0,
  item=1,
  ox=4,
  oy=4,
  ax=cos(45/360),
  ay=sin(45/360),
  cpu=true,
  tracktgl=false,
  k=0,
  d=0,
  cash=1000,
  stock={}
 }
 for i=1, #items, 1 do
  add(t.stock, items[i].stock or 0)
 end
 add(tanks,t)
end

function initmap()
 heightmap={}
 rockmap={}
 grassmap={}
 fallingdirt={}
 keypoints={}
 k=2
 local x,keys,y = 0, rndi(14)+6
 local rocks,hstep,cstep = 1, flr(fieldwidth/keys), 0
 for i=1,keys+2,1 do
  add(keypoints, rndi(112-48) + 48)
 end
 for x=1,fieldwidth do
  y = mid(127, 48, lerp(keypoints[k], keypoints[k+1], cstep/hstep))
  add(heightmap, y)
  add(grassmap, y+3)
  --create rock table for each column
  if rndi(3)>1 then
   add(rockmap, {x=x, y=rndi(128-y)+y+1, type = rndi(4)+1, flx = rndi(2) == 1, fly = rndi(2) == 1})
  end
  cstep += 1
  if(cstep > hstep) cstep = 0 k += 1
 end
end

function addbloom(type, x, y, size, dmg)
 return add(blooms, {
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

function addbomb(x,y,velx,vely,flip,id)
 return add(bullets, {
     sub=true, id=id, x=x, y=y, velx=velx, vely=vely, flip=flip, frame=0, time=0, roll=id==1, life=0
 })
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
 elseif(state==logo) then return
 end

 ct = tanks[activetank]
 if(state == pregame) then
  updatepregame()
 elseif(state == postgame) then
  updatepostgame()
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
  local b,hit,cancel,itm = bullets[i], false, false
  if(b.sub) itm = subitems[b.id]
  if(not b.sub) itm = items[b.id]
  camtarget = b
  local lvy = b.vely
  if(b.roll) then
   if(b.x < 0) b.x = 0
   if(b.x > fieldwidth-1) b.x = fieldwidth
   local bx = flr(b.x)
   local l,c,r = (heightmap[bx] or 0), heightmap[bx+1], (heightmap[bx+2] or 0)
   if((c > l and c > r) or abs(b.velx) <= step) then b.velx = 0
   elseif(c == l and c == r) then b.velx *= .85
   elseif(l > c) then b.velx = -10
   elseif(r > c) then b.velx = 10 end

   if(flr(b.y) < c) then b.vely += gravity * step
   else b.vely = 0 end
  else
   b.vely += gravity * step
   b.px = b.x
   b.py = b.y
  end
  if(b.sub and b.id == 2) then
   if(b.vely > 20) b.frame = 1
   if(b.vely > 50) b.frame = 2
  end
  b.x += b.velx * step
  b.y += b.vely * step
  b.life += 1
  --b.idx += 1
  --if(b.idx > #bulletfade) b.idx = 1

  if(itm.name == "mirv " and b.vely >= 0 and lvy < 0) then
   b.split = true
   local b1 = addbullet(b.x,b.y,b.velx * 1.5, b.vely, b.id, b.c)
   b1.split = true
   local b2 = addbullet(b.x,b.y,b.velx * .5, b.vely, b.id, b.c)
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
     local vel = v_new(b.velx,b.vely * -1)
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
    if((ct != t or b.life > 10) and (dist <= 2 or (b.x >= t.x and b.x < (t.x + 7) and b.y > (t.y + 3) and b.y < (t.y + 8)))) then
     -- hit tank, explode
     t.health -= itm.dmg
     if(t != ct) ct.cash += itm.dmg * 10
     hit = true
    end
   end
   if(t.shp < 1) t.shield = false t.deflector = false
   if(hit) break
  end
  if(b.roll) then
   if(b.velx == 0 and b.vely == 0) hit = true
  elseif(b.x < 0 or b.x >= fieldwidth
     or b.y >= heightmap[flr(b.x)+1]
     or b.y > 128) then
      hit = true
  end
  if(hit) then
   del(bullets, b)
   if(itm.name == "araid") then
    plactive = true
    plopen = false
    plbtime = 20
    pltarget = b.x
    ply = min(b.y - 72, 24) 
    plflip = false
    plx = fieldwidth
    plbombcount=raidbombs
    sfx(61,3)
    if(b.x > 128) plflip = true plx = -32
   end
   if(itm.name == "roll ") then
    addbomb(b.x,b.y,b.velx*.25,0,false,1)
   elseif(itm.name == "leap " and not b.split) then
    local b = addbullet(b.x, b.y -6, b.velx, max(2.5,abs(b.vely)) * -1.1, b.id, b.c)
    b.split = true
   end
   if(itm.size) sfx(57)
   if(itm.size > 6) sfx(55)
   if(itm.size and not cancel and (b.split or itm.name != "mirv ")) then
    addbloom(1, b.x, b.y, itm.size, itm.dmg)
    if(itm.mag and itm.duration) setshake(itm.mag,itm.duration)
   end
  end
 end

end

function updateblooms(firing)
 for i=#blooms,1,-1 do
  local bl = blooms[i]
  if(bl.focus) camtarget = bl
  if(bl.time < 21 or not firing) bl.time += 1
  if(bl.time == 25) then
   if(ct.tpbls == bl) then
    local dest = mid(6, (rndi(fieldwidth) + 1) * 2 % fieldwidth, fieldwidth-6)
    sfx(51)
    ct.tpblt = addbloom(3, dest, heightmap[dest]-4,6,0)
    ct.tpblt.focus = true
    ct.x = -9
    ct.tpbls = nil
   elseif(ct.tpblt == bl) then
    ct.x = bl.x -4
    ct.y = bl.y -4
    ct.tpblt = nil
   end
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
    if(bl.dmg > 0 and t.health > 0 and dist <= bl.size) then
     -- linear interpolate damage over the blast radius
     local dmg = lerp(1, bl.dmg, dist/bl.size)
     -- shields eat half of any remaining damage, deflectors 25%
     if(t.shield and t.shp > 0) dmg *= .5 t.shp -= 1
     if(t.deflector and t.shp > 0) dmg *=.75 t.shp -= 1
     -- round up the damage to whole numbers.
     t.health -= ceil(dmg)
     if(t != ct) ct.cash += ceil(dmg) * 100
    end
   end
  end
  if(bl.time > 80) del(blooms, bl)
 end
 if(ct.tpblt) camtarget = ct.tpblt
 if(not camtarget and #blooms > 0) camtarget = blooms[#blooms]
end

function updateplane()
 if(not plactive) return
 camtarget = v_new(plx, ply+40)
 local velx = plspeed * step
 if(not plflip) velx *= -1
 plx += velx
 pltime += 1
 if((plflip and plx > fieldwidth + 32) or (plx < -32 and not plflip)) then
  plactive = false
  sfx(-2,3)
 end
 if(pltime > 2) plalt = not plalt pltime = 0
 plnose,pltail = plx, plx+8
 plbayx = pltail+5
 if(plflip) plnose = plx + 24 pltail = plx plbayx = pltail+13
 
 if((plflip and plbayx > pltarget-(2.5*plspeed) and plbayx < pltarget)
   or (not plflip and plbayx > pltarget and plbayx < pltarget+(plspeed*2.5))) then
  if(not plopen) sfx(59)
  plopen = true
  plbtime -= 1
  local bsp = plspeed
  if(not plflip) bsp *= -1
  if(plbtime < 1 and plbombcount > 0) then
   plbtime = 20 
   addbomb(plbayx + 2, ply + 16, bsp, 0, plflip, 2) 
   plbombcount-=1
   sfx(60)
  end
 else
  if(plopen) sfx(58)
  plopen=false
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
 local tx, cx, cy, center = 0, flr(ct.x), flr(ct.y), heightmap[flr(ct.x)+5]
 local floor = cy + 8

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
 ct.y = center-8
 ct.x = mid(0, fieldwidth, ct.x + tx)
 calculate_grade(ct)
 if(flr(ct.x) != cx) ct.tracktgl = not ct.tracktgl
 if(btnp(4) or btnp(5)) then
  nextstate = firing
  sfx(-2,3)
  sfx(58)
 end
end

function updateaim()
 message="aim"
 local pw,ang,x,y = 0,0,0,0,0,0
 if(ct.cpu) then
  local target = picknexttank()
  local times,vec = calc_shots(tanks[target])
  if(#times > 0)  then
   vec = calc_shotvel(tanks[target],times[rndi(#times)+1])
   setcannon(vec)
   nextstate = firing
  end
 else
  if (btn(2)) pw += 1
  if (btn(3)) pw -= 1
  if (btn(0)) ang += 1
  if (btn(1)) ang -= 1
  ct.power = mid(0, 100, ct.power + pw)
  ct.angle = mid(0, 180, ct.angle + ang)
  ct.ax = cos(ct.angle/360)
  ct.ay = sin(ct.angle/360)
  if(btnp(4)) nextstate = movecam
  if(btnp(5)) nextstate = firing
 end



 if(nextstate == firing) then
  if(ct.stock[ct.item] > 0) ct.stock[ct.item] -= 1
  local x = ct.x + ct.ox--4-- + (5 * ct.ax)
  local y = ct.y + ct.oy--2-- + (5 * ct.ay)
  addbullet(x, y, ct.ax * ct.power, ct.ay * ct.power, ct.item, items[ct.item].c)
  setshake(2,0.075)
  sfx(8)
 end
end

function updatefiring()
 camtarget = nil
 updatebullets()
 updateblooms(true)
 updateplane()
 if(#bullets<1 and not plactive) then
  nextstate = death
  -- in case the plane is still doing a noise
  sfx(-2,3)
  fallscalcd = false
  statetime = 100
 end
end

function updatedeath()
 -- handle any post death 'splosions
 camtarget = nil
 updatebullets()
 updateblooms(false)
 updateplane()
 local deadcount = 0
 -- finish explosions before doing anything else.
 if(#blooms > 0) return
 local falling,dying = false,false
 for i=#tanks, 1, -1 do
  local t=tanks[i]
  local fl,y=heightmap[flr(t.x)+5], flr(t.y) + 8
  local fdist,h = gravity * step, fl - y
  if(t.chute) fdist *= .5
  if(y < fl and h > 1) then
   if(not fallscalcd and not t.chute) then
    t.falld = h
   end
   t.y += fdist
   t.fell = true
   falling = true
  elseif(y != fl) then t.y = fl - 8 end
  calculate_grade(t)
 end
 fallscalcd = true
 if(falling) return
 local mdc=52
 for i=#tanks, 1, -1 do
  local t=tanks[i]
  if(t.falld and t.falld > 0) t.health -= t.falld t.falld = 0
  if(t.fell) t.fell=false t.chute = false
  if(t.y>121) t.health = 0 --tank fell off the map
  if(t.health <= 0) then
   t.deathclock += 1
   mdc = min(t.deathclock, mdc)
   dying = true
   deadcount += 1
  end
  if(t.deathclock == 1) then
   setshake(5, .3)
   sfx(56)
   t.d += 1
   cam.x = mid(0, fieldwidth-128, t.x-60)
   if(t != ct) ct.k += 1 ct.cash += 500
  end
 end
 if(mdc > 51) dying = false
 if(dying) return

 if(statetime == 90) then
  activetank = picknexttank()
  ct = tanks[activetank]
 end

 statetime -= 1
 if(statetime <= 90) then
  camtarget = ct
  if(deadcount >= #tanks-1) then
   nextstate = postgame
   statetime = 1
   return
  end
 end
 if(statetime <= 0) nextstate = movecam
end

function updatetitle()
 titletime += 1
 if(titletime > 8) titleidx += 1 titletime = 0
 if(titleidx > 6) titleidx = 1
 if(titlefade) then
  statetime += 1
  if(statetime >= 72) then
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

function updateitemmenu()
 camtarget = nil
 if (btnp(1) or btnp(0)) then
  if(shopitem < 7) then shopitem += 6
  else shopitem -= 6 end
  sfx(9)
 end
 if (btnp(2)) shopitem -= 1 sfx(9)
 if (btnp(3)) shopitem += 1 sfx(9)
 if(shopitem < 1) shopitem = #items
 if(shopitem>#items) shopitem = 1
end

function updateshop()
  message="shop $" .. ct.cash --"select item"
  if(titlefade) then
   statetime += 1
   if(statetime > 72) statetime = 72 nextstate = pregame resetround() titlefade = false
  end
  updateitemmenu()
  if(btnp(5)) then
    -- purchase
    itm = items[shopitem]
    if(itm.cost < 1 or itm.cost > ct.cash or ct.stock[shopitem] > 98) then sfx(11)
    else
     ct.cash -= itm.cost
     ct.stock[shopitem] += 1
     sfx(10)
    end
  end
  if(btnp(4)) then
   -- next
   if(activetank < #tanks) then activetank += 1
   else titlefade = true statetime = 0 end
   sfx(12)
 end
end

function updateselect()
 show_itemselect=true
 message="shop $" .. ct.cash --"select item"
 updateitemmenu()
 if(btnp(4)) nextstate = movecam  sfx(11)
 if(btnp(5)) then
  if(ct.stock[shopitem] != 0) then
   sfx(10)
   nextstate = movecam
   ct.item = shopitem
  else sfx(11) end
 end
end

function updatepregame()
 statetime -= 1
 camtarget = tanks[1]
 if(statetime < -32) then
  statetime = 0
  titlefade = false
  nextstate = movecam
 end
end

function updatepostgame()
 statetime += 1
 if(statetime > 72) then
  statetime = 72
  if(btnp(4) or btnp(5)) nextstate = shop activetank = 1
 end
end

function updatesplash()

end

function updatecamera()
 if(camtarget == nil) return
 local cvel = camspeed * step
 focus = v_new(camtarget.x-60, camtarget.y-64)
 camdiff = v_subtr(cam,focus)
 if(flr(v_len(camdiff.x, camdiff.y)) >= cvel) then
  cam = v_add(v_mult(v_normalized(camdiff), cvel), cam)
  cam.x = mid(cam.x, 0, fieldwidth-128)
  cam.y = mid(cam.y, -128, 0)
 end
end

-->8
--draw
function _draw()
 cls()
 if(state==logo) then
  drawlogo()
 elseif(state==title) then
  drawtitle()
  print("press 🅾️ or ❎ to start!", 20, 76, startcolours[titleidx])
 else
  drawgame()
 end

 if(state == pregame or state == postgame or titlefade) then
  local idx = mid(0, flr(statetime / 8), 7)
  fadepalette(idx, 1)
 end
 if(state == postgame and statetime >= 72) then
  pal()
  rect(0,0,127,127,7)
  rectfill(1,1,126,126,0)
  for i=1,#tanks,1 do
   local t = tanks[i]
   local name,y = teams[t.team].name,16 + i*10
   print(name, 16 + (3-#name)*4, y, 7)
   print( "  k:" .. t.k .. " d:" .. t.d .. "  $" .. t.cash, 24, y, 7)
  end
 end
end

function drawgame()
 screen_shake()
 camera(cam.x,cam.y)
 pal()
 rectfill(0,44,fieldwidth,128,1)
 fillp(0b1100001111000011)
 rectfill(0,64,fieldwidth,128,0x35)
 fillp()
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
  if(t.chute and t.fell) palt(12,true) spr(51,t.x,t.y-5) palt()
  if(t.shield and t.shp > 0) circ(t.x+4,t.y+4,shield_r,sget(124-flr(t.shp/2),0)) circ(t.x+4,t.y+4,shield_r-1,sget(121,0))
  if(t.deflector and t.shp > 0) circ(t.x+4,t.y+4,defl_r,sget(128-t.shp,0)) circ(t.x+4,t.y+4,defl_r-1,sget(125,0))
  if(t == ct) then
   if(state < firing) spr(20, t.x-1, t.y-11)
   if(state == aim) circ(t.x + 4 + (8 * t.ax), t.y + 1 + (8 * t.ay), 1, 10)
  end
 end
 drawmap()
 if(plactive) then
  if(plalt) then
   pal(15,13)
   pal(12,13)
   pal(11,7)
   pal(10,6)
  else
   pal(15,6)
   pal(11,13)
   pal(12,7)
   pal(10,13)
  end
  spr(36, plnose, ply+8, 1, 1, plflip)
  spr(21, pltail, ply, 3, 2, plflip)
  pal()
  if(plopen) then
   line(plbayx, ply+14, plbayx + 6, ply+14, 1)
   line(plbayx, ply+14, plbayx, ply+16, 5)
   line(plbayx+6, ply+14, plbayx+6, ply+16, 5)
  end
 end
 for b in all(bullets) do
  if(b.sub) then
   local itm=subitems[b.id]
   local sid,offs = itm.id + b.frame, itm.offsets[b.frame+1]
   if(b.id == 1) then circfill(b.x, b.y, 2, 7)
   else spr(sid, b.x+offs.x, b.y+offs.y, 1, 1, b.flip) end
  else
   pset(flr(b.px), flr(b.py),6)
   pset(flr(b.x),flr(b.y),b.c)--bulletfade[b.idx])
  end
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
 if(ct.stock[ct.item] == 0) pal(12,8) palt(12,false)
 spr(itm.ico,106-(5-#itm.name)*4,1)
 pal(12,12)
 palt(12,true)
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

 if(show_itemselect) drawselectitem()
 if(state == shop) drawshop()
 if(message != nil) then
  local msg = teams[ct.team].name .. ": " .. message
  local width,cl=(#msg*4)+5,shr(band(teams[ct.team].c or 0x800,0xf00),8) or 8
  local x=128/2 -width/2
  rect(x-1,18,x+width+1,26,7)
  rectfill(x,19,x+width,25,0)
  if(cl< 3) rectfill(x,19,x+width,25,5)
  print(msg, x+3,20,cl)
 end
end

function drawmap()
 local dino=0
 for x=1, #heightmap do
  line(x-1, heightmap[x], x-1, 128, 4)
  --fillp(0b1111000011110000)
  fillp(0b1010010110100101)
  if(grassmap[x] and heightmap[x] <= grassmap[x]) line(x-1, heightmap[x], x-1, grassmap[x], 0xab)
  fillp()
 end
 for rock in all(rockmap) do --pull in rock table and draw each rock
  if(rock.y > heightmap[rock.x]) then
   rt = rocktypes[rock.type]
   if rock.y == 111 then
    if(dino==0) sspr(0, 56, 16, 8, rock.x-2, rock.y, 16, 8)--only draw dino once
	dino=1
   else
    sspr(rt.x, rt.y, 4, 4, rock.x-2, rock.y, 4, 4)--, rock.flx, rock.fly)
   end
  end
 end
end

function drawselectitem()
    rect(22,32,106,88,7)
    rectfill(23,33,105,87,0)
    local y=34 x=33
    for i=1, #items, 1 do
     local itm = items[i]
     local stock = ct.stock[i]
     local selected,shopselect,hasitem,tc = itm == items[ct.item], itm == items[shopitem], stock > 0 or stock == -1, 7
     if(stock == -1) stock = 99
     if(stock < 9) stock = "0" .. stock
     if(not hasitem) then pal(12, 5) tc = 5
     elseif(shopselect) then palt(12,true) tc = 10
     elseif(selected) then pal(12,11) tc = 11 end
     spr(itm.ico, x, y)
     palt(12,false)
     pal(12,12)
     print(itm.name, x+10, y+2, tc)
     print(stock, x-9, y+2, tc)
     if(shopselect) spr(54, x, y)
     y += 9
     if(y >= 87) y=34 x=73
    end
end

function drawshop()
    rect(0,18,127,127,7)
    rectfill(1,19,126,126,0)
    local y=36 x=10
    for i=1, #items, 1 do
     local itm = items[i]
     local selected,shopselect,hasitem,tc = itm == items[ct.item], itm == items[shopitem], ct.stock[i] > 0 or ct.stock[i] == -1, 7
     if(itm.cost < 1 or itm.cost > ct.cash) then pal(12, 5) tc = 5
     elseif(shopselect) then palt(12,true) tc = 10 end
     local stock = ct.stock[i]
     if(stock == -1) stock = 99
     if(stock < 9) stock = "0" .. stock
     local price
     if((itm.cost) < 1) then price = ":free"
     else price = ":$" .. itm.cost end
     print(stock, x-8,y+2,6)
     spr(itm.ico, x, y)
     palt(12,false)
     pal(12,12)
     print(itm.name .. price, x+10, y+2, tc)
     if(shopselect) spr(54, x, y)
     y += 12
     if(y >= 106) y=36 x=70
    end
end

function drawlogo()
 local fl = false
 if(rnd(4)>2) fl = true
 palt(12,true)
 palt(0,false)
 rectfill(0,0,128,128,13)
 sspr(64,48,64,16,32,68)
 spr(78,56,48,2,2,fl)
 print("p r e s e n t s",34,86,0)
 if logotimer == 0 then
  logotimer += 1
  sfx(62) --picocity sound
 end
 if(logotimer >= 128) then
  titlefade = true
  statetime += 1
 end
 if logotimer > 200 or btnp() > 0 then
  nextstate = title
  titlefade = false
  statetime = 0
  sfx(-1,0)
  music(0)
  cls()
  palt()
 else
  logotimer += 1
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
 local found,at = false, activetank
 while(not found) do
  at += 1
  if(at > #tanks) at = 1
  if(tanks[at].health > 0) found = true
 end
 return at
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
 if(ct.stock[ct.item] == 0) then
  sfx(11)
  return movecam
 end
 if(itm.name == "chute") then ct.chute = not ct.chute used = true sfx(52)
 elseif(itm.name == "shld ") then ct.shp = 8 ct.shield = true ct.deflector = false used = true sfx(54)
 elseif(itm.name == "defl ") then ct.shp = 4 ct.deflector = true ct.shield = false used = true sfx(53)
 elseif(itm.name == "fuel ") then  used = true st = move sfx(52)
 elseif(itm.name == "warp ") then
  used = true
  sfx(51)
  ct.tpbls = addbloom(3, ct.x+4, ct.y+4, 6, 0)
 end
 if(used) ct.stock[ct.item] -= 1 return st
 return aim
end

function calculate_grade(t)
 local center,r,l = heightmap[flr(t.x)+5],heightmap[flr(t.x)+6],heightmap[flr(t.x)+4]
 t.grade_l = center-l
 t.grade_r = center-r
end

function v_len(x, y)
  local d = max(abs(x),abs(y))
  local n = min(abs(x),abs(y)) / d
  return sqrt(n*n + 1) * d
end

function v_subtr(a,b)
 return v_new((b.x + (b.ox or 0)) - (a.x + (a.ox or 0)),
 (b.y + (b.oy or 0)) - (a.y + (a.oy or 0)))
end

function v_normalized(v)
 local len,nv = v_len(v.x, v.y), v_new(v.x,v.y)
 if(len != 0) nv.x /= len nv.y /= len
 return nv
end

function v_dot(a,b)
 return a.x * b.x + a.y * b.y
end

function v_mult(v,f)
 return v_new(v.x*f, v.y*f)
end

function v_new(x,y)
 return {x=x,y=y}
end

function v_add(a,b)
 return v_new((b.x + (b.ox or 0)) + (a.x + (a.ox or 0)), (b.y + (b.oy or 0)) + (a.y + (a.oy or 0)))
end

function calc_shots(target)
 local diffp,acc,times=v_mult(v_subtr(v_new(target.x,target.y + 4),ct),.1),v_new(0,gravity/10),{}
 local accdot,dpdot,b1=v_dot(acc,acc),v_dot(diffp,diffp),v_dot(diffp,acc) + 100 -- max_pow^2 * .1
 local disc = sqrt(b1*b1 - accdot * dpdot)
 if(disc > 0) then -- otherwise, out of range
  add(times, sqrt((b1 - disc) * 2 / accdot)) -- min time
  add(times, sqrt((b1 + disc) * 2 / accdot)) -- max time
  add(times, sqrt(sqrt(2*dpdot/accdot))) -- lowest power time
 end
 return times
end

function calc_shotvel(target,t)
 local diffp = v_subtr(target,ct)
 return v_new(diffp.x / t-0, diffp.y / t - gravity * t / 2)
end

function setcannon(vec)
 local norm = v_normalized(vec)
 ct.power = v_len(vec.x, vec.y)
 ct.angle = round(atan2(-norm.x, norm.y) * 360)
 ct.ax = norm.x * -1
 ct.ay = norm.y
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
	return v_new(round(v.x),round(v.y))
end

function lerp(v0, v1, t)
  return (1 - t) * v0 + t * v1;
end

function rndi(max)
 return flr(rnd(max))
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
2828222588225d00cd6776dc00000000000000000000f00005555213000000000000000055d000000055500000880900009900000000000000000000dd511000
d222d5d0525d0000c1dddd1c005e8500000000000d00ce5554442130000008800000000000000000000500000080090a09a0000009a0000000000080ee444210
05d500000d000000cc1111cc00dd6d00000000000f0fd8664442130022007e88000000000000000000000000000099000090900000000000000a0000fff94210
cccccccccccccccccccccccccccccccc000000000ce5b832222130022220e7e8cccc6558000000000900008000008900a0900000800000090000009000033000
cccccccccccddcccccc6688ccaaaaaac000000d6fd86a6442213555551118e7ec655638e0008080080000a08000880000a009008000000000000009003533530
c6d668ccccd77dccc6d77ee8c9d77dac00d75d675b83d34211159988944188e72d5335110088e0000998e9900a08880000008800000900000000000035333353
c7d77eecc57987dcc7d77eeec967769c0d6739393a5551111133338931122880c11111cc0889ae800a89ae00000000099008800000000000000000003535d353
c656688cc568975cc656688ec9d66d9c025393939d33d22222d3333332220000cc68cccc88a99e8e889a9a8e000009000000a000080000000000000035d5bd53
c656681cc156651cc6566888c196691c56d22223333364444663332220000000cc11cccc28298a82289aa2820000d00000000000088800a0009008805db5bbd5
c11111cccc1551ccc1166881cc1991cc00000002222255555552225000000000cccc68ccd22a2225da2922a500d00500a0d0d5d0008800000000000005050050
ccccccccccc11cccccc1111cccc11ccc00000000000000000000550000000000cccc11cc05d5d5d005d5d5d0000d005005005d000d500050005dd05d05050050
cccc8ccccccccccccccccccccce7e7cccccccccccccccccc0a9009a056000d600003d000004004000000000000000000000000000000000000000000005dd500
cccc7ccc9cac9cccc8eccccccee66e7ccefd35cccccccccca000000a5d6005605d0d300005404500000000000000000000000000000000000000000096969454
cddc6ccc191ca9ccc8866cccee666ee7c11f115c66ccc82c900000092560022053033000045040400000000000000000000155000000000000000000979794d4
ceed666cc198fa9cc116c78c61117116cc33335ccc6c788c000000000220000053d3d0d50545454405565000000000000005d600000000000000000099999454
c22edcccc9f99a9ccc6c7c1c16cc7c61cc33535cccc7c11c000000000650000005333035445454005d666500044449f000015500000000505050505000000000
cd22edccc19f891cccc7c8cccc6996cccc35335cccc7cccc900000095d6000d6000d3d35005450006ddd665005554f9001551550000506d6d6d6d6d600000000
c352edcccc1991ccccc8c1ccccc11ccccc33335ccccccccca000000a55d600220003335000054000d5d6dd65444f94f905d65d60006d505d505d505d00000000
c11111ccccc11cccccc1cccccccccccccc11111ccccccccc0a9009a00222000000033000005544005d5dd55d5449f59f01551550d500d50d050d050d00000000
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
0d55d000000000001122285d6fd55000cccccccccccccccc00affffffffaff00c00c00cc00cc00c00c00c00c00cc00ccc0000c00c0000000c00c00ccc00c000c
06255d6052d626000512255d46f50000cccccccccccccccc55ff9999ddd55af0c00cc00c00cc00c00c00c00c00cc00ccc0000c00c0000c00c00c00ccc00cc00c
002651d000220260005656d6d4650000ccccccccccccccccddaa99aa55111d5fc00ccc00000cc00c0000000c00c000c0cc000c00c000cc00c00000cc000cc00c
00022552000000d000056d6d6d500000cccccccccccccccc55444444dd21112dc00ccc00c0ccc0ccc000c0c00ccc000ccc00cc00cc00ccc0000c000cc0cc000c
06565d2d600d6d20000056d6d6500000cccccccccccccccc0dd2222255111115c00cc000ccccccc00c00ccc0ccccc0cc0c0cc0000cc0c0cc00ccc0ccccc000cc
0222220d2555d2000000055d55000000cccccccccccccccc0055d5d11ddd5d5dc000000cccccc000000ccccc0cccccccc0cccccccccc0cccccccccccccc00ccc
0000d5d502d556d60000005550000000cccccccccccccccc0000000000000000000000cccccccc00ccccccccccccccccccccccccccccccccccccccccccc0cccc
000d52000000d52d0000000000000000cccccccccccccccc000000000000000000cccccccccccccccccccccccccccccccccccccccccccccccccccccccccc0ccc
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
000100000d5250a5200652003520035203160015600196000c60020500385001e5002a5002a5002b5002c5002d500305003250034500365003650037500375001a5001e50020500255002b500000000000000000
000100003945034430314203142035430394500170000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001865018650186501865018650186501865018650186501865018650186501865018650186501865018650186501865018650186501865018650186501865018650186501865018650186501865018650
011000001812018120181201812018120181201812018120181201812018120181201812018120181201812018120181201812018120181201812018120181201812018120181201812018120181201812018120
011000000c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c0400c040
0105000034d5027d501ed5010d500ad503fd5035d502ed502fd502fd502bd5025d501cd4016d4011d400ed400bd300ad3008d3008d3006d3004d3004d3005d3005d3005d3004d2003d2002d2003d1004d1003d10
010c00000e73500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01070000181251f125241250010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
010a0000107350c735007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
010400000c73010731117311773100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010300030042000210005200030000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
010600000f0520f0520f0520f0520f0520f0520f0520f0520f0520f0420f0320f0220f0120f0150f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600001105211052110521105211052110521105211052110521104211032110221101211015000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010818000505000000000000000005050000000505000000000000000005050000000505000000000000000005050000000505000000000500000005050000000000000000000000000000000000000000000000
010800003761500000000000000000000000003761500000376153760037615000003761500000000000000000000000003761500000000000000000000000000000000000000000000000000000000000000000
010800001d5501d5501d5501d5501d5501d5501d5501d55018550185501d5501d5501f5501f5501f5501f5501f5501f5501f5501f550185501855022550225502150021500225002150021500215000000000000
01080000225502255021550215501f5501f5502155021550215502155021550215502155021550215502155021550215502155021550215502155021550215500000000000000000000000000000000000000000
010800002255022550225502255024550245502155021550215502155021550215502155021550215502155021550215501d5501d550215502155024550245500000000000000000000000000000000000000000
010800002755027550275502755027550275502755027550275502755027550275502655026550265502655026550265502655026550265502655026550265502150021500225002150021500215000000000000
010800002455024550225502255021550215502155021550215502155021550215502155021550215502155021550215502155021550215502155021550215502150021500225002150021500215000000000000
010818000305000000000000000003050000000305000000000000000003050000000305000000000000000003050000000305000000000500000000050000000000000000000000000000000000000000000000
010818000505000000000000000005050000000505000000000000000005050000000505000000000000000005050000000505000000000500000005050000000000000000000000000000000000000000000000
010800002755027550275502755027550275502755027550275502755027550275502b5502b5502b5502b550245502455024550245502b5502b5502b5502b5500000000000000000000000000000000000000000
010700002d5502d5502d5502d5502d5502d5502d5502d5502d5502d5502d5502d5502d5502d5502d5502d5502d5412d5412d5312d5312d5212d5212d5112d5150350033505035000350033503035053350503505
01110000009730090000973009003ca1300973000003ca13009730000000973000003ca1300973000003ca13009730090000973009003ca1300973009003ca13009733ca1300973009003ca1300973009003ca13
01110000050300000000000000000000000000000300000003030000000803000000000000303000000000000503000000000000803000000000000a03000000000000b03000000000000a030080300303000000
011100003ca13009033ca11009033ca113ca133ca113ca133ca113ca133ca11009033ca113ca133ca113ca113ca11009033ca11009033ca113ca133ca113ca133ca113ca133ca11009033ca113ca13009033ca11
010800003761500000000000000000000000003761500000376153761537615000003761500000000000000000000000003761500000000000000000000000000000000000000000000000000000000000000000
010800003761500000000000000037615376153761537605376153760537615000003761500000000000000000000000003761500000000000000000000000000000000000000000000000000000000000000000
0111000011f4000f0000f0000f0000f0000f000cf4000f000ff4000f0014f4000f000ff4014f4000f000ff4511f4010f410ff410ef410df410cf410bf410af4109f0007f000ff4003f450ff0010f4004f4510f00
0111000011f4000f0000f0000f0000f0000f000ff4000f000cf4000f0014f4000f000cf400ff4000f000cf4011f4005f4500f000ff4003f4500f0016f400af4500f0014f4008f4500f000ff4003f450cf400ef00
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
010600000073710737077371773700737107370773717737007371073707737177370073710737077371773700707007070070700707007070070700707007070070700707007070070700707007070070700707
0106000024633186123c6230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010500000c5361c536135362353618536105361353623536005060050600506005060050600506005060050600506005060050600506005060050600506005060050600506005060050600506005060050600506
010400000c5501055113551175511a5511d5512155124551005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
010c00000033604636023360e6360032604626023260e6260031604616023160e6160031604615023060e60600006000060000600006000060000600006000060000600006000060000600006000060000600006
011400002f6370042724637004271862700417186270c417000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007
011a0000004310c4332f6031d6030c6030c6030060300403004030040300403004030040300403004030040300403004030040300403004030040300403004030040300403004030040300403004030040300403
0108000024633186120c0230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800000c02318610246330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010900002b0502805124041210001d001000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010100030e62002720001200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010700000302003020010200102003020030200102001020030200302003020030200302003020030200302003020030200302003020030200302003020030200300033015030000300033003030053301503005
0106000018e401de401fe4024e4018e301de301fe3024e3018e201de201fe2024e2018e101de101fe1024e1000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e0000e00
__music__
00 0f101112
00 0f101e13
00 0f101112
00 0f101f14
00 0e171115
00 0f101e16
00 0e171119
02 0f101f1a
01 1b1c5d44
00 1b215d44
00 1b5c1d44
00 1b1c5d44
02 1b205d44
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
00 39374344

