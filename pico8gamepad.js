// https://github.com/krajzeg/pico8gamepad
// ====== [CONFIGURATION] - tailor to your specific needs

// How many PICO-8 players to support?
// - if set to 1, all connected controllers will control PICO-8 player 1
// - if set to 2, controller #0 will control player 1, controller #2 - player 2, controller #3 - player 1, and so on
// - higher numbers will distribute the controls among the players in the same way
var supportedPlayers = 1;

// These flags control whether or not different types of buttons should
// be mapped to PICO-8 O and X buttons.
var mapFaceButtons = true;
var mapShoulderButtons = true;
var mapTriggerButtons = false;
var mapStickButtons = false;

// How far you have to pull an analog stick before it register as a PICO-8 d-pad direction
var stickDeadzone = 0.4;

// ====== [IMPLEMENTATION]

// Array through which we'll communicate with PICO-8.
var pico8_buttons = [0,0,0,0,0,0,0,0];
var touch_buttons = 0;

// Start polling gamepads (if supported by browser)
if (navigator.getGamepads)
	requestAnimationFrame(updateGamepads);

// Workhorse function, updates pico8_buttons once per frame.
function updateGamepads() {
  var gamepads = navigator.getGamepads ? navigator.getGamepads() : [];
  
  // Reset the array.
  for (var p = 0; p < supportedPlayers; p++) {
  	pico8_buttons[p] = p == 0 ? touch_buttons : 0;
  }
  // Gather input from all known gamepads.
  for (var i = 0; i < gamepads.length; i++) {
  	var gp = gamepads[i];
  	if (!gp || !gp.connected) continue;

  	// which player is this assigned to?
  	var player = i % supportedPlayers;

  	var bitmask = 0;
    // directions (from axes or d-pad "buttons")
  	bitmask |= (axis(gp,0) < -stickDeadzone || axis(gp,2) < -stickDeadzone || btn(gp,14)) ? 1 : 0;  // left
  	bitmask |= (axis(gp,0) > +stickDeadzone || axis(gp,2) > +stickDeadzone || btn(gp,15)) ? 2 : 0; // right
  	bitmask |= (axis(gp,1) < -stickDeadzone || axis(gp,3) < -stickDeadzone || btn(gp,12)) ? 4 : 0;  // up
  	bitmask |= (axis(gp,1) > +stickDeadzone || axis(gp,3) > +stickDeadzone || btn(gp,13)) ? 8 : 0; // down
    // O and X buttons
    var pressedO = 
    	(mapFaceButtons && (btn(gp,0) || btn(gp,2))) ||
    	(mapShoulderButtons && btn(gp,5)) ||
    	(mapTriggerButtons && btn(gp,7)) ||
    	(mapStickButtons && btn(gp,11));
    var pressedX = 
    	(mapFaceButtons && (btn(gp,1) || btn(gp,3))) ||
    	(mapShoulderButtons && btn(gp,4)) ||
    	(mapTriggerButtons && btn(gp,6)) ||
    	(mapStickButtons && btn(gp,10));
    bitmask |= pressedO ? 16 : 0;
    bitmask |= pressedX ? 32 : 0;
  	// update array for the player (keeping any info from previous controllers)
  	pico8_buttons[player] |= bitmask;
  	// pause button is a bit different - PICO-8 only respects the 6th bit on the first player's input
  	// we allow all controllers to influence it, regardless of number of players
  	pico8_buttons[0] |= (btn(gp,8) || btn(gp,9)) ? 64 : 0;
  }
 
  requestAnimationFrame(updateGamepads);
}

// Helpers for accessing gamepad
function axis(gp,n) { return gp.axes[n] || 0.0; }
function btn(gp,b) { return gp.buttons[b] ? gp.buttons[b].pressed : false; }

// Touch Controls
var GPIO_BUTTONSET_INDEX=0,
pico8_gpio = new Array(128),              // <= used to let pico8-cart change buttonset
changeButtonset;                          // usage: changeButtonset(2) to activates .buttonset-2

function initTouchButtons() {

    changeButtonset=(function(){
        classHolder=document.getElementById("btns-markUsedButtonset");
        var current=-1;

        // poll for pico8_gpio to check if PICO8-game wants a buttonset-change
        window.setInterval(function(){
          var from_pico8 = pico8_gpio[GPIO_BUTTONSET_INDEX];
          if(!!from_pico8) changeButtonset(from_pico8);
        },100);

        return function(buttonset_number){
          if(current!==buttonset_number) {
            touch_buttons = 0; // reset pico btns
            if(pico8_gpio[GPIO_BUTTONSET_INDEX]!==buttonset_number){
              pico8_gpio[GPIO_BUTTONSET_INDEX]=buttonset_number;
            }
            classHolder.className = "buttonset-use-" + buttonset_number;
            current=buttonset_number;
          }
        };

    }());
    changeButtonset(1); // set starting buttonset!

    var updatePressedClasses = (function() {
          var target = document.getElementById("btns-markPressed");
          return function() {
            var classes="",pressed=touch_buttons;
            for(var key_string in KEY) {
              if(KEY.hasOwnProperty(key_string) && ((pressed & KEY[key_string]) > 0)) classes+= " pressed_" + key_string;
            }
            target.className = classes;
          };
	}()),
        KEY = { L: 1, R: 2, U: 4, D: 8, O: 16, X: 32 },
        btnDown = function(key) { touch_buttons |= key; updatePressedClasses(); },
        btnUp   = function(key) { touch_buttons &= ~key; updatePressedClasses(); },
        btnAxis = function(active_keys) {
          touch_buttons &= ~(KEY.U | KEY.D | KEY.L | KEY.R); // clear all axes
          for(var i=0; i<active_keys.length;i++) { touch_buttons |= active_keys[i]; }
          updatePressedClasses();
        },
        relTouchPosInEl = function(el, touch) {
          var rect = el.getBoundingClientRect();
          if(rect.width === 0 || rect.height === 0) return {x: 0, y: 0};
          return {
            x: Math.min(1, Math.max(0, (touch.clientX - rect.left) / rect.width)),
            y: Math.min(1, Math.max(0, (touch.clientY - rect.top) / rect.height))
          };
        },
        xAxisUpdate = function(el, touch) {
          if(!touch) return; // can occur when switching buttonsets
          var
            pos = relTouchPosInEl(el, touch),
            x_axis = 0, y_axis = 0;
          if(pos.x < .4) x_axis = KEY.L;
          if(pos.x > .6) x_axis = KEY.R;
          btnAxis([x_axis, y_axis]);
        },
        yAxisUpdate = function(el, touch) {
          if(!touch) return; // can occur when switching buttonsets
          var
            pos = relTouchPosInEl(el, touch),
            x_axis = 0, y_axis = 0;
          if(pos.y < .4) y_axis = KEY.U;
          if(pos.y > .6) y_axis = KEY.D;
          btnAxis([x_axis, y_axis]);
        },
        xyAxisUpdate = function(el, touch) {
          if(!touch) return; // can occur when switching buttonsets
          var
            pos = relTouchPosInEl(el, touch),
            x_axis = 0, y_axis = 0,
            x_range = .3, y_range = .3;
          if(pos.x < x_range) x_axis = KEY.L;
          if(pos.x > 1-x_range) x_axis = KEY.R;
          if(pos.y < y_range) y_axis = KEY.U;
          if(pos.y > 1-y_range) y_axis = KEY.D;
          btnAxis([x_axis, y_axis]);
        },
        axisEnd = function() { btnAxis([]); },
        killEvt = function(evt) { evt.preventDefault(); evt.stopPropagation(); },
        touchfinder=function(){
          var touchid=null;
          return {
            fillFromTouchStart:function(evt,el){
              var
                touches, touch,
                toucharea = el.getBoundingClientRect();

              console.log(toucharea.left, toucharea.right);

              if(touches = evt.changedTouches){
                for(var i=0; i<touches.length; i++){
                  touch=touches[i];
                  console.log(touch.clientX);
                  if( // is correct touchpoint?
                    (touch.clientX > toucharea.left - 10) &&
                    (touch.clientX < toucharea.right + 10) &&
                    (touch.clientY > toucharea.top - 10) &&
                    (touch.clientY < toucharea.bottom + 10)
                  ) {
                    touchid=touch.identifier;
                    return touch;
                  }
                }
              }
              touchid=null;
              return null;
            },
            findFromTouchMove:function(evt){
              if(touchid === null) return null;
              var touches,touch;
              if(touches=evt.changedTouches) {

                for(var i=0; i<touches.length; i++){
                  touch=touches[i];
                  if(touch.identifier===touchid) { return touch; }
                }
              }
              return null;
            },
            clear:function(){ touchid = null; }
          };
        },
        addXAxis = function(el) {
          var find_my_touch=touchfinder();
          el.addEventListener("touchstart", function(evt){ killEvt(evt); xAxisUpdate(el, find_my_touch.fillFromTouchStart(evt,el)); }, false);
          el.addEventListener("touchmove", function(evt){ killEvt(evt); xAxisUpdate(el, find_my_touch.findFromTouchMove(evt)); }, false);
          el.addEventListener("touchend", function(evt){ find_my_touch.clear(); killEvt(evt); axisEnd(); }, false);
          el.addEventListener("touchcancel", function(evt){ find_my_touch.clear(); killEvt(evt); axisEnd(); }, false);
        },
        addYAxis = function(el) {
          var find_my_touch=touchfinder();
          el.addEventListener("touchstart", function(evt){ killEvt(evt); yAxisUpdate(el, find_my_touch.fillFromTouchStart(evt,el)); }, false);
          el.addEventListener("touchmove", function(evt){ killEvt(evt); yAxisUpdate(el, find_my_touch.findFromTouchMove(evt)); }, false);
          el.addEventListener("touchend", function(evt){ find_my_touch.clear(); killEvt(evt); axisEnd(); }, false);
          el.addEventListener("touchcancel", function(evt){ find_my_touch.clear(); killEvt(evt); axisEnd(); }, false);
        },
        addXYAxis = function(el) {
          var find_my_touch=touchfinder();
          el.addEventListener("touchstart", function(evt){ killEvt(evt); xyAxisUpdate(el, find_my_touch.fillFromTouchStart(evt,el)); }, false);
          el.addEventListener("touchmove", function(evt){ killEvt(evt); xyAxisUpdate(el, find_my_touch.findFromTouchMove(evt)); }, false);
          el.addEventListener("touchend", function(evt){ find_my_touch.clear(); killEvt(evt); axisEnd(); }, false);
          el.addEventListener("touchcancel", function(evt){ find_my_touch.clear(); killEvt(evt); axisEnd(); }, false);
        },
        addButton = function(el, key) {
          el.addEventListener("touchstart", function(evt){ killEvt(evt); btnDown(key); }, false);
          el.addEventListener("touchmove", killEvt, false);
          el.addEventListener("touchend", function(evt){ killEvt(evt); btnUp(key); }, false);
          el.addEventListener("touchcancel", function(evt){ killEvt(evt); btnUp(key); }, false);
        };

      var
        axisXs=document.getElementsByClassName("axis-leftRight"),
        axisXYs=document.getElementsByClassName("axis-upDownLeftRight"),
        axisYs=document.getElementsByClassName("axis-upDown"),
        xBtns=document.getElementsByClassName("btn-fire-x"),
        oBtns=document.getElementsByClassName("btn-fire-o"),
        i;

      for(i=0; i<axisXs.length; i++){ addXAxis(axisXs[i]); }
      for(i=0; i<axisXYs.length; i++){ addXYAxis(axisXYs[i]); }
      for(i=0; i<axisYs.length; i++){ addYAxis(axisYs[i]); }
      for(i=0; i<xBtns.length; i++){ addButton(xBtns[i], KEY.X); }
      for(i=0; i<oBtns.length; i++){ addButton(oBtns[i], KEY.O); }

      // prevent "tilt-zooming" when accidentally touching between the buttons
      document.getElementById("btns-wrapper").addEventListener("touchstart", function(evt){ evt.preventDefault(); }, false);
}