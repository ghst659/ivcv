unit graphics;
(*
 * Generic graphics interface for TP 5.5,
 * adapted from previous TP4 graphics packages.
 *)
interface
uses 
  Graph, generics, error, site, scaling;

const
  FIG_CROSS = 0;
  FIG_PLUS = 1;
  FIG_RECTANGLE = 2;
  FIG_DIAMOND = 3;
  FIG_TRIANGLE = 4;

var
  g_max_x, g_max_y : integer;
  g_device, g_mode : integer;
  g_colour : word;

procedure draw_border;
procedure blank_region;

procedure g_setcolor (colour:word);

function g_getx : single;
function g_gety : single;

procedure g_plot (x,y:single);
procedure g_putpixel (x,y:single; pixel:word);
function g_getpixel (x,y:single) : word;

procedure g_outtextxy (x,y:single; textstring:string);

procedure g_line (x1,y1,x2,y2:single);
procedure g_lineto  (x,y:single);
procedure g_linerel (Dx,Dy:single);

procedure g_moveto  (x,y:single);
procedure g_moverel (Dx,Dy:single);

procedure g_rectangle (x1,y1,x2,y2:single);
procedure g_bar (x1,y1,x2,y2:single);
procedure g_bar3d (x1,y1,x2,y2:single; depth:word; top:boolean);
procedure g_ellipse (x,y:single; stangle,endangle:word; xrad,yrad:single);

procedure g_figure (x,y:single; fig,size:byte);

(****************************************************************************)
implementation
(*
 * The initial state of the transformation is the identity transformation.
 * The transformation is set by USING a world and/or window.  Initially,
 * this system is only capable of irrotational matrices M.
 *)

var
  g_et : error_table;
  init_world : world;
  init_region : region;

procedure reset_transformation;
begin
  use_world(init_world);
  use_region(init_region);
  recompute_transformation;
end;

procedure draw_border;
var
  rgn : region;
begin
  sc_get_current_region(rgn);
  with rgn do
     Rectangle(x_lo,y_lo,x_hi,y_hi);
end;

procedure blank_region;
var
  filler : FillSettingsType;
  rgn : region;
begin
  GetFillSettings(filler);
  SetFillStyle(EmptyFill, Black);
  sc_get_current_region(rgn);
  with rgn do
     Bar(x_lo,y_lo,x_hi,y_hi);
  SetFillStyle(filler.Pattern, filler.Color);
end;

procedure g_setcolor (colour:word);
begin
  SetColor(colour);
  g_colour := colour;
end;

function g_getx : single;
begin
  g_getx := sc_wld_x(GetX);
end;

function g_gety : single;
begin
  g_gety := sc_wld_y(GetY);
end;

procedure g_plot (x,y:single);
begin
  PutPixel(sc_abs_x(x),sc_abs_y(y),g_colour);
end;

procedure g_putpixel (x,y:single; pixel:word);
begin
  PutPixel(sc_abs_x(x),sc_abs_y(y),pixel);
end;

function g_getpixel (x,y:single) : word;
begin
  g_getpixel := GetPixel(sc_abs_x(x),sc_abs_y(y));
end;

procedure g_outtextxy (x,y:single; textstring:string);
begin
  OutTextXY (sc_abs_x(x), sc_abs_y(y), textstring);
end;

procedure g_line (x1,y1,x2,y2:single);
begin
  Line(sc_abs_x(x1),sc_abs_y(y1),sc_abs_x(x2),sc_abs_y(y2));
end;

procedure g_lineto  (x,y:single);
begin
  LineTo(sc_abs_x(x),sc_abs_y(y));
end;

procedure g_linerel (Dx,Dy:single);
begin
  LineRel(round(sc_Mxx*Dx), round(sc_Myy*Dy));
end;

procedure g_moveto  (x,y:single);
begin
  MoveTo (sc_abs_x(x), sc_abs_y(y));
end;

procedure g_moverel (Dx,Dy:single);
begin
  MoveRel(round(sc_Mxx*Dx), round(sc_Myy*Dy));
end;

procedure g_rectangle (x1,y1,x2,y2:single);
begin
  Rectangle(sc_abs_x(x1),sc_abs_y(y1),sc_abs_x(x2),sc_abs_y(y2));
end;

procedure g_bar (x1,y1,x2,y2:single);
begin
  Bar(sc_abs_x(x1),sc_abs_y(y1),sc_abs_x(x2),sc_abs_x(y2));
end;

procedure g_bar3d (x1,y1,x2,y2:single; depth:word; top:boolean);
begin
  Bar3D(sc_abs_x(x1),sc_abs_y(y1),sc_abs_x(x2),sc_abs_x(y2),depth,top);
end;

procedure g_ellipse (x,y:single; stangle,endangle:word; xrad,yrad:single);
begin
  Ellipse(sc_abs_x(x),sc_abs_y(y),stangle,endangle, 
          round(sc_Mxx*xrad),round(sc_Myy*yrad));
end;

procedure g_figure (x,y:single; fig,size:byte);
var
  ax, ay : integer;
begin
  ax := sc_abs_x(x);
  ay := sc_abs_y(y);
  case fig of
    FIG_CROSS:
      begin
        Line(ax-size,ay-size,ax+size,ay+size);
        Line(ax-size,ay+size,ax+size,ay-size);
      end;
    FIG_PLUS:
      begin
        Line(ax-size,ay,ax+size,ay);
        Line(ax,ay-size,ax,ay+size);
      end;
    FIG_RECTANGLE:
      begin
        Line(ax-size,ay-size,ax+size,ay-size);
        Line(ax+size,ay-size,ax+size,ay+size);
        Line(ax+size,ay+size,ax-size,ay+size);
        Line(ax-size,ay+size,ax-size,ay-size);
      end;
    FIG_DIAMOND:
      begin
        Line(ax,ay-size,ax+size,ay);
        Line(ax+size,ay,ax,ay+size);
        Line(ax,ay+size,ax-size,ay);
        Line(ax-size,ay,ax,ay-size);
      end;
    FIG_TRIANGLE:
      begin
        Line(ax,ay-size,ax+size,ay+size);
        Line(ax+size,ay+size,ax-size,ay+size);
        Line(ax-size,ay+size,ax,ay-size);
      end;
    else
      PutPixel(ax,ay,g_colour);
  end; (* case *)
end;

var
  err_code : integer;

begin (* preamble *)
  g_et.init;
  g_et.add(grNoInitGraph, '(BGI) graphics not installed');
  g_et.add(grNotDetected, 'graphics hardware not detected');
  g_et.add(grFileNotFound, 'device driver not found');
  g_et.add(grInvalidDriver, 'invalid device driver file');
  g_et.add(grNoLoadMem, 'out of memory loading driver');
  g_et.add(grNoScanMem, 'out of memory in scan fill');
  g_et.add(grNoFloodMem, 'out of memory in flood fill');
  g_et.add(grInvalidMode, 'bad mode for driver');
  g_et.add(grError, 'graphics error');
  g_et.add(grIOerror, 'graphics I/O error');
  g_et.add(grInvalidFont, 'invalid font file');
  g_et.add(grInvalidFontNum, 'bad font number');
  g_et.add(grOk, '');
  g_device := Detect;
  InitGraph(g_device, g_mode, site.graph_lib_dir);
  err_code := GraphResult;
  if (err_code = grOk) then begin
     g_max_x := GetMaxX;
     g_max_y := GetMaxY;
     with init_world do begin
       x_lo := 0.0;
       y_lo := 0.0;
       x_hi := g_max_x;
       y_hi := g_max_y;
     end;
     with init_region do begin
       x_lo := 0;
       y_lo := 0;
       x_hi := g_max_x;
       y_hi := g_max_y;
     end;
     use_world(init_world);
     use_region(init_region);
     reset_transformation;
     RestoreCrtMode;
  end
  else begin
     g_et.complain(err_code,'graphics','initializing graphics');
     halt;
  end;
end.  (* preamble *)
