unit plotter;
(*
 * HPGL Plotter tools useful for Turbo Pascal 4.0
 *)
interface
uses 
  generics, scaling, hpgl;

const
  FIG_CROSS = 0;
  FIG_PLUS = 1;
  FIG_RECTANGLE = 2;
  FIG_DIAMOND = 3;
  FIG_TRIANGLE = 4;

var
  p_max_x, p_max_y : integer;

procedure draw_border;

procedure p_plot (x,y:single);

procedure p_outtextxy (x,y:single; textstring:string);

procedure p_line (x1,y1,x2,y2:single);
procedure p_lineto  (x,y:single);
procedure p_linerel (Dx,Dy:single);

procedure p_moveto  (x,y:single);
procedure p_moverel (Dx,Dy:single);

procedure p_rectangle (x1,y1,x2,y2:single);

procedure p_figure (x,y:single; fig,size:byte);

(****************************************************************************)
implementation
(*
 * The initial state of the transformation is the identity transformation.
 * The transformation is set by USING a world and/or window.  Initially,
 * this system is only capable of irrotational matrices M.
 *)

var
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
     rectangle(x_lo,y_lo,x_hi,y_hi);
end;

procedure p_plot (x,y:single);
begin
  plot(sc_abs_x(x),sc_abs_y(y));
end;

procedure p_outtextxy (x,y:single; textstring:string);
begin
  outtextxy (sc_abs_x(x), sc_abs_y(y), textstring);
end;

procedure p_line (x1,y1,x2,y2:single);
begin
  line(sc_abs_x(x1),sc_abs_y(y1),sc_abs_x(x2),sc_abs_y(y2));
end;

procedure p_lineto (x,y:single);
begin
  lineto(sc_abs_x(x),sc_abs_y(y));
end;

procedure p_linerel (Dx,Dy:single);
begin
  linerel(round(sc_Mxx*Dx), round(sc_Myy*Dy));
end;

procedure p_moveto  (x,y:single);
begin
  moveto (sc_abs_x(x), sc_abs_y(y));
end;

procedure p_moverel (Dx,Dy:single);
begin
  moverel(round(sc_Mxx*Dx), round(sc_Myy*Dy));
end;

procedure p_rectangle (x1,y1,x2,y2:single);
begin
  rectangle(sc_abs_x(x1),sc_abs_y(y1),sc_abs_x(x2),sc_abs_y(y2));
end;

procedure p_figure (x,y:single; fig,size:byte);
var
  ax, ay : integer;
begin
  ax := sc_abs_x(x);
  ay := sc_abs_y(y);
  case fig of
    FIG_CROSS:
      begin
        line(ax-size,ay-size,ax+size,ay+size);
        line(ax-size,ay+size,ax+size,ay-size);
      end;
    FIG_PLUS:
      begin
        line(ax-size,ay,ax+size,ay);
        line(ax,ay-size,ax,ay+size);
      end;
    FIG_RECTANGLE:
      begin
        line(ax-size,ay-size,ax+size,ay-size);
        line(ax+size,ay-size,ax+size,ay+size);
        line(ax+size,ay+size,ax-size,ay+size);
        line(ax-size,ay+size,ax-size,ay-size);
      end;
    FIG_DIAMOND:
      begin
        line(ax,ay-size,ax+size,ay);
        line(ax+size,ay,ax,ay+size);
        line(ax,ay+size,ax-size,ay);
        line(ax-size,ay,ax,ay-size);
      end;
    FIG_TRIANGLE:
      begin
        line(ax,ay-size,ax+size,ay+size);
        line(ax+size,ay+size,ax-size,ay+size);
        line(ax-size,ay+size,ax,ay-size);
      end;
    else
      plot(ax,ay);
  end; (* case *)
end;

begin (* preamble *)
  p_max_x := getmaxx;
  p_max_y := getmaxy;
  with init_world do begin
    x_lo := 0.0;
    y_lo := 0.0;
    x_hi := p_max_x;
    y_hi := p_max_y;
  end;
  with init_region do begin
    x_lo := 0;
    y_lo := 0;
    x_hi := p_max_x;
    y_hi := p_max_y;
  end;
  use_world(init_world);
  use_region(init_region);
  reset_transformation;
end.  (* preamble *)
