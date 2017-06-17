unit scaling;
(*
 * Scaling tools for linear graphics devices.
 *)
interface
uses
  generics;
type
  region = record x_lo, x_hi, y_lo, y_hi : integer end;
  world  = record x_lo, x_hi, y_lo, y_hi : single end;

var
  sc_Mxx, sc_Myy : single;

procedure set_region (var r:region; xl,yl,xh,yh:integer);
procedure set_world  (var w:world; xl,yl,xh,yh:single);
procedure recompute_transformation;
procedure use_world  (var w:world);
procedure use_region (var r:region);

procedure sc_get_current_region(var r:region);

function sc_abs_x (x:single) : integer;
function sc_abs_y (y:single) : integer;
function sc_wld_x (x:integer) : single;
function sc_wld_y (y:integer) : single;

function tick_size (delta:single) : single;
function base_tick (min,tick:single) : single;

(****************************************************************************)
implementation
(*
 * We implement this by having a state-variable based graphics system.
 * The graphics unit keeps internal state which can be consulted to yield
 * actual plotting coordinates.  Let the actual screen coordinates be
 * (sx, sy), and let the "world" coordinates be (rx, ry).
 * Then we have some linear transformation
 *           (sx, sy) = M . [(rx,ry) - (rx0, ry0)]
 * in which M is some matrix, and (rx0, ry0) is the world vector 
 * describing the screen origin.
 * 
 *)
var
  cur_wld : world;
  cur_reg : region;
  rx0, ry0 : single;

procedure set_region (var r:region; xl,yl,xh,yh:integer);
begin
  if (xl <> xh) and (yl <> yh) then
     with r do begin
        x_lo := xl;
        y_lo := yl;
        x_hi := xh;
        y_hi := yh;
     end
  else
     beep;
end;

procedure set_world  (var w:world; xl,yl,xh,yh:single);
begin
  if (xl <> xh) and (yl <> yh) then
     with w do begin
        x_lo := xl;
        y_lo := yl;
        x_hi := xh;
        y_hi := yh;
     end
  else
     beep;
end;

procedure recompute_transformation;
var
  drx, dry : single;
  dsx, dsy : integer;
begin
  dsx := cur_reg.x_hi - cur_reg.x_lo;
  dsy := cur_reg.y_lo - cur_reg.y_hi;
  drx := cur_wld.x_hi - cur_wld.x_lo;
  dry := cur_wld.y_hi - cur_wld.y_lo;
  sc_Mxx := dsx / drx;
  sc_Myy := dsy / dry;
  rx0 := cur_wld.x_lo - (cur_reg.x_lo / sc_Mxx);
  ry0 := cur_wld.y_lo - (cur_reg.y_hi / sc_Myy);
end;

procedure use_world (var w:world);
begin
  cur_wld := w;
  recompute_transformation;
end;

procedure use_region (var r:region);
begin
  cur_reg := r;
  recompute_transformation;
end;

procedure sc_get_current_region(var r:region);
begin
  r := cur_reg;
end;

function sc_abs_x (x:single) : integer;
var
  t : single;
begin
  t := sc_Mxx * (x - rx0);
  if (abs(t) < maxint) then
     sc_abs_x := round(t)
  else
     sc_abs_x := round(sgn(t)*maxint);
end;

function sc_abs_y (y:single) : integer;
var
  t : single;
begin
  t := sc_Myy * (y - ry0);
  if (abs(t) < maxint) then
     sc_abs_y := round(t)
  else
     sc_abs_y := round(sgn(t)*maxint);
end;

function sc_wld_x (x:integer) : single;
begin
  sc_wld_x := x / sc_Mxx + rx0;
end;

function sc_wld_y (y:integer) : single;
begin
  sc_wld_y := y / sc_Myy + ry0;
end;

function tick_size (delta:single) : single;
const
  extremely_small:single = 1.0e-37;
var 
  order, norm, tick : single;
begin
  delta := abs(delta);
  if (delta < extremely_small) then delta := extremely_small;
  order := pow(10.0, floor(log10(delta)));
  norm := delta / order;
  if (norm <= 1.2) then
     tick := 0.2
  else if (norm <= 2.0) then
     tick := 0.25
  else if (norm <= 4.0) then
     tick := 0.5
  else if (norm <= 8.0) then
     tick := 1.0
  else
     tick := 2.0;
  tick_size := tick * order;
end;

function base_tick (min,tick:single) : single;
begin
  tick := abs(tick);
  base_tick := ceil(min/tick) * tick;
end;

begin (* preamble *)
  with cur_reg do begin
     x_hi := 100;
     x_lo := 0;
     y_hi := 100;
     y_lo := 0;
  end;
  with cur_wld do begin
     x_hi := 100.0;
     x_lo := 0.0;
     y_hi := 100.0;
     y_lo := 0.0;
  end;
end.  (* preamble *)
