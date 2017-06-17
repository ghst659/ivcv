unit penplot;
(*
 * Generalized HPGL plotting library for Turbo Pascal 4.0 data acquisition.
 * This defines a data type paper, which can be manipulated by the
 * procedures defined herein.
 *)
interface
uses
  generics, values, hpgl, scaling, plotter;
type
  paper = record
	       data : record
	       		 title : array[1..3] of string;
	       		 x_label, y_label : string63;
	       		 rdp : ^pararr;
			 rnp : ^index;
			 cdp : ^valarr;
			 cnp : ^index;
			 tbl : ^valarrarr;
		      end;
  	       limit : record
	       		  x_lo, x_hi, y_lo, y_hi : value;
		       end;
	       cur   : record
	       		  x_lo, x_hi, y_lo, y_hi : single;
		       end;
  	       log_x, log_y, grid : boolean;
	       plot_rgn, msg_rgn, xnum_rgn, ynum_rgn,
	          xlabel_rgn, ylabel_rgn : region;
	       plot_wld, msg_wld, xnum_wld, ynum_wld : world;
	 end;

procedure pp_set_regions (var t:paper);
procedure pp_set_limits (var t:paper; xlo,xhi,ylo,yhi:value);
procedure pp_set_bounds (var t:paper);
procedure pp_set_flags (var t:paper;
		         log_x_flag,log_y_flag,grid_axes:boolean);
procedure pp_set_data(var t:paper;
			  title_1,title_2,title_3:string;
			  xl,yl:string31;
  		      var rows:pararr; var nrows:index;
		      var cols:valarr; var ncols:index;
		      var matrix:valarrarr);

procedure pp_dsp_ticks (var t:paper);
procedure pp_dsp_curves(var t:paper);
procedure pp_dsp_title (var t:paper);

procedure pp_dsp_frame(var t:paper);
procedure pp_undsp_frame (var t:paper);

(****************************************************************************)
implementation
const
  HorizDir = 0;
  VertDir = 1;
  margin = 1.000;
  VERY_SMALL = 1.0e-36;
  MESSAGE_COLOUR = 1;
  AXIS_COLOUR = 2;
  PLOT_COLOUR = 2;

(*---------------------------------------------------------------------------
 * INTERNAL PRIVATE UTILITY PROCEDURES
 *)

procedure zap (var w:world; var r:region; colour:byte);
begin
  use_world(w);
  use_region(r);
  (* There used to be a setcolour option
  setcolor(colour);
  *)
end;

procedure horline (var x,y:single; dx:single);
begin
  p_line(x,y,x+dx,y);
end;

procedure verline (var x,y:single; dy:single);
begin
  p_line(x,y,x,y+dy);
end;

procedure draw_point (var t:paper; x,y:single);
begin
  with t do begin
     if (log_x) then
	x := log10(abs(x)+VERY_SMALL);
     if (log_y) then
	y := log10(abs(y)+VERY_SMALL);
     if (x < cur.x_lo) then x := cur.x_lo;
     if (y < cur.y_lo) then y := cur.y_lo;
     p_moveto(x,y);
     p_plot(x,y);
  end;
end;

procedure draw_line (var t:paper; x,y:single);
begin
  with t do begin
     if (log_x) then
	x := log10(abs(x)+VERY_SMALL);
     if (log_y) then
	y := log10(abs(y)+VERY_SMALL);
     if (x < cur.x_lo) then x := cur.x_lo;
     if (y < cur.y_lo) then y := cur.y_lo;
     p_lineto(x,y);
  end;
end;

(*---------------------------------------------------------------------------
 * EXTERNAL (PUBLIC) ROUTINES
 *)

procedure pp_set_regions (var t:paper);
var
  ixl, ixn, iyp, iyn, iyl : integer;
begin
  with t do begin
     set_world(msg_wld, -1.0, -1.0, 1.0, 1.0);
     ixl := round(0.045 * p_max_x);
     ixn := round(0.165 * p_max_x);
     iyp := round(0.200 * p_max_y);
     iyn := round(0.150 * p_max_y);
     iyl := round(0.100 * p_max_y);
     set_region(plot_rgn, ixn, p_max_y, p_max_x, iyp);
     set_region(xnum_rgn, ixn, iyp, p_max_x, iyn);
     set_region(xlabel_rgn, ixn, iyn, p_max_x, iyl);
     set_region(ynum_rgn, ixl, p_max_y, ixn, iyp);
     set_region(ylabel_rgn, 0, p_max_y, ixl, iyp);
     set_region(msg_rgn, 0, iyl, p_max_x , 0);
  end;
end;

procedure pp_set_limits (var t:paper; xlo,xhi,ylo,yhi:value);
begin
  with t do begin
     if (xlo < xhi) then begin
	limit.x_lo := xlo;
	limit.x_hi := xhi;
     end
     else begin
	limit.x_lo := xhi;
	limit.x_hi := xlo;
     end;
     if (ylo < yhi) then begin
	limit.y_lo := ylo;
	limit.y_hi := yhi;
     end
     else begin
	limit.y_lo := yhi;
	limit.y_hi := ylo;
     end;
  end;
end;

procedure pp_set_bounds (var t:paper);

procedure swap(var a,b:single);
var t:single;
begin
  t := b;
  b := a;
  a := t;
end;

var
  xl, xh, yl, yh : single;		(* Virtual screen coords *)
begin
  with t do begin
     xh := limit.x_hi;
     xl := limit.x_lo;
     if (log_x) then begin
        xh := log10(abs(xh)+VERY_SMALL);
	xl := log10(abs(xl)+VERY_SMALL);
     end;

     yh := limit.y_hi;
     yl := limit.y_lo;
     if (log_y) then begin
     	yh := log10(abs(yh)+VERY_SMALL);
	yl := log10(abs(yl)+VERY_SMALL);
     end;

     if (xh < xl) then swap(xl,xh);
     if (yh < yl) then swap(yl,yh);

     cur.x_lo := xh - margin * (xh - xl + VERY_SMALL);
     cur.x_hi := xl + margin * (xh - xl + VERY_SMALL);
     cur.y_lo := yh - margin * (yh - yl + VERY_SMALL);
     cur.y_hi := yl + margin * (yh - yl + VERY_SMALL);
  end;
end;

procedure pp_set_data (var t:paper;
			   title_1,title_2,title_3:string;
			   xl,yl:string31;
		       var rows:pararr; var nrows:index;
		       var cols:valarr; var ncols:index;
		       var matrix:valarrarr);
begin
  with t do with data do begin
     x_label := xl;
     y_label := yl;
     title[1] := title_1;
     title[2] := title_2;
     title[3] := title_3;
     rdp := addr(rows);
     rnp := addr(nrows);
     cdp := addr(cols);
     cnp := addr(ncols);
     tbl := addr(matrix);
  end;
end;

procedure pp_set_flags (var t:paper;
		         log_x_flag,log_y_flag,grid_axes:boolean);
begin
  with t do begin
     log_x := log_x_flag;
     log_y := log_y_flag;
     grid := grid_axes;
  end;
end;

procedure pp_dsp_title (var t:paper);
begin
  with t do begin
     settextdir(HorizDir);
     zap(msg_wld,msg_rgn,MESSAGE_COLOUR);
     p_outtextxy(-1.0, 0.75,data.title[1]);
     p_outtextxy(-1.0, 0.00,data.title[2]);
     p_outtextxy(-1.0,-0.75,data.title[3]);
  end;
end;

procedure pp_dsp_ticks (var t:paper);
var
  x, y : single;
  xbase, ybase : single;
  xtick, ytick : single;
  xspan, yspan : single;
begin
  with t do begin
     xspan := cur.x_hi - cur.x_lo;
     yspan := cur.y_hi - cur.y_lo;
     xtick := tick_size(xspan); 
     ytick := tick_size(yspan);
     xbase := base_tick(cur.x_lo, xtick); 
     ybase := base_tick(cur.y_lo, ytick);

     zap(plot_wld,plot_rgn, AXIS_COLOUR);

     settextdir(HorizDir);

     x := xbase;
     while (x < cur.x_hi) do begin
	zap(plot_wld, plot_rgn, AXIS_COLOUR);
	if grid then begin
	  verline(x, cur.y_lo, yspan);
	end
	else begin
	  verline(x, cur.y_hi, -0.02*yspan);
	  verline(x, cur.y_lo,  0.02*yspan);
	end;
	zap(xnum_wld, xnum_rgn, AXIS_COLOUR);
	if (abs(x) < 1.0e-5 * xtick) then x := 0.0;
	if (x <= (cur.x_hi - 0.05*xspan)) then
	   if (log_x) then
	      p_outtextxy(x-0.05*xspan, 0.0, ftoa(x,9,3))
	   else
	      p_outtextxy(x-0.05*xspan, 0.0, ftoa(x,9,-1));
	x := x + xtick;
     end;

     y := ybase;
     while (y < cur.y_hi) do begin
	zap(plot_wld, plot_rgn, AXIS_COLOUR);
	if grid then begin
	   horline(cur.x_lo, y, xspan);
	end
	else begin
	   horline (cur.x_hi, y, -0.01*xspan);
	   horline (cur.x_lo, y, 0.01*xspan);
	end;
	zap(ynum_wld, ynum_rgn, AXIS_COLOUR);
	if (abs(y) < 1.0e-5 * ytick) then y := 0.0;
	if (y <= (cur.y_hi - 0.01*yspan)) then
	   if (log_y) then
	      p_outtextxy(0.0, y - 0.01*yspan, ftoa(y,9,3))
	   else
	      p_outtextxy(0.0, y - 0.01*yspan, ftoa(y,9,-1));
	y := y + ytick;
     end;

     settextdir(HorizDir);
     zap(msg_wld, xlabel_rgn,MESSAGE_COLOUR);
     if (log_x) then
	p_outtextxy(0.0, 0.25, 'log ('+data.x_label+')')
     else
	p_outtextxy(0.0, 0.25, data.x_label);

     settextdir(VertDir);
     zap(msg_wld, ylabel_rgn,MESSAGE_COLOUR);
     if (log_y) then
	p_outtextxy(0.0,-0.25, 'log ('+data.y_label+')')
     else
	p_outtextxy(0.0,-0.25, data.y_label);
  end;
end;

procedure pp_dsp_curves(var t:paper);
var
  row, col : index;
begin
  with t do begin
     zap(plot_wld, plot_rgn, PLOT_COLOUR);
     with data do begin
        for row := 1 to rnp^ do begin
	   if (cnp^ > 0) then begin
	      draw_point(t, cdp^[1], tbl^[row][1]);
	      for col := 2 to cnp^ do
	      	 draw_line(t, cdp^[col], tbl^[row][col]);
	      moverel(3,0);
	      outtext(ftoa(row,2,0))
	   end;
	end;
     end;
  end;
end;

procedure pp_dsp_frame (var t:paper);
const 
  delta_divisor:single = 25.0;
var
  i : integer;
begin
  hpgl.hp_reset;
  with t do begin
     set_world (plot_wld, cur.x_lo, cur.y_lo, cur.x_hi, cur.y_hi);
     set_world (xnum_wld, cur.x_lo, -1.0, cur.x_hi, 1.0);
     set_world (ynum_wld, 0.0, cur.y_lo, 1.0, cur.y_hi);

     setcolor(AXIS_COLOUR);
     zap (plot_wld,plot_rgn,AXIS_COLOUR);
     draw_border;
     pp_dsp_ticks (t);
     pp_dsp_title(t);
  end;
end;

procedure pp_undsp_frame (var t:paper);
begin
  hpgl.hp_reset;
end;

begin (* preamble *)
end.  (* preamble *)
