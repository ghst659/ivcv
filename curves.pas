unit curves;
(*
 * Generalized plotting library for Turbo Pascal 4.0 data acquisition.
 * This defines a data type tabloid, which can be manipulated by the
 * procedures defined herein.
 *)
interface
uses
  crt, graph, generics, values, graphics, scaling, penplot;
type
  tabloid = record
	       data : record
	       		 title : array[1..3] of string;
	       		 x_label, y_label : string63;
	       		 rdp : ^pararr;
			 rip, rnp : ^index;
			 cdp : ^valarr;
			 cip, cnp : ^index;
			 tbl : ^valarrarr;
		      end;
  	       limit : record
	       		  x_lo, x_hi, y_lo, y_hi : value;
		       end;
	       cur, old : record
	       		     x_lo, x_hi, y_lo, y_hi : single;
			  end;
  	       log_x, log_y, grid : boolean;
	       plot_rgn, msg_rgn, xnum_rgn, ynum_rgn,
	          xlabel_rgn, ylabel_rgn : region;
	       plot_wld, msg_wld, xnum_wld, ynum_wld : world;
	       mark_x, mark_y : single;
	       curs_x, curs_y : single;
	       dx, dy : single;
	       rptr, cptr, rmem, cmem : index;
	    end;

procedure set_regions (var t:tabloid);
procedure set_limits (var t:tabloid; xlo,xhi,ylo,yhi:value);
procedure set_bounds (var t:tabloid);
procedure set_flags (var t:tabloid;
		         log_x_flag,log_y_flag,grid_axes:boolean);
procedure set_static_data(var t:tabloid;
			      title_1,title_2,title_3:string;
			      xl,yl:string31);
procedure set_dynamic_data (var t:tabloid;
			    var rows:pararr; var nrows:index;
			    var cols:valarr; var ncols:index;
			    var matrix:valarrarr);
procedure set_dynamic_ptrs (var t:tabloid; var rowidx,colidx:index);

procedure dsp_ticks (var t:tabloid);
procedure dsp_curves(var t:tabloid);
procedure dsp_updates (var t:tabloid);
procedure dsp_title (var t:tabloid);
procedure dsp_message (var t:tabloid; msg:string);
procedure dsp_cursor_status(var t:tabloid);

procedure dsp_frame(var t:tabloid);
procedure undsp_frame(var t:tabloid);
procedure act_event (var t:tabloid; c:char);

(****************************************************************************)
implementation
const
  margin = 1.075;
  VERY_SMALL = 1.0e-36;
  MESSAGE_COLOUR = Green;
  PLOT_COLOUR    = White;
  AXIS_COLOUR	 = Yellow;

(*---------------------------------------------------------------------------
 * INTERNAL PRIVATE UTILITY PROCEDURES
 *)

function input_default (dval:single; thing:string31) : single;
var
  ix, iy : byte;
  code : integer;
  cbuf : string;
begin
  ix := WhereX;
  iy := WhereY;
  repeat
    code := 0;
    gotoxy(ix, iy);
    cbuf := input_line('Enter ' + thing + ' (RET for default: ' +
                       ftoa(dval,15,-1) + '):');
    if (cbuf = '') then
       input_default := dval
    else
       input_default := atof(cbuf,code);
  until code = 0;
end;

procedure zap (var w:world; var r:region; colour:word);
begin
  use_world(w);
  use_region(r);
  g_setcolor(colour);
end;

procedure horline (var x,y:single; dx:single);
begin
  g_line(x,y,x+dx,y);
end;

procedure verline (var x,y:single; dy:single);
begin
  g_line(x,y,x,y+dy);
end;

procedure draw_cursor (var x,y:single);
begin
  g_figure(x,y,FIG_PLUS,2);
end;

procedure draw_marker (var x,y:single);
begin
  g_figure(x,y,FIG_CROSS,2);
end;

procedure draw_ptr (var t:tabloid);
var
  x, y : single;
begin
  with t do begin
     if (data.rnp^ > rptr) and (data.cnp^ > cptr) then begin
        x := data.cdp^[1+cptr];
	y := data.tbl^[1+rptr][1+cptr];
	if (log_x) then
	   x := log10(abs(x)+VERY_SMALL);
	if (log_y) then
	   y := log10(abs(y)+VERY_SMALL);
	if (x < cur.x_lo) then x := cur.x_lo;
	if (y < cur.y_lo) then y := cur.y_lo;
	g_figure(x,y,FIG_DIAMOND,3);
     end;
  end;
end;

procedure draw_mem (var t:tabloid);
var
  x, y : single;
begin
  with t do begin
     if (data.rnp^ > rmem) and (data.cnp^ > cmem) then begin
        x := data.cdp^[1+cmem];
	y := data.tbl^[1+rmem][1+cmem];
	if (log_x) then
	   x := log10(abs(x)+VERY_SMALL);
	if (log_y) then
	   y := log10(abs(y)+VERY_SMALL);
	if (x < cur.x_lo) then x := cur.x_lo;
	if (y < cur.y_lo) then y := cur.y_lo;
	g_figure(x,y,FIG_RECTANGLE,3);
     end;
  end;
end;

procedure draw_chord (var t:tabloid);
var
  x0, y0, dydx, dxdy, xm, ym, xp, yp : single;
  msg : string;
begin
  with t do begin
     if (data.rnp^ > rmem) and (data.cnp^ > cmem) and
        (data.rnp^ > rptr) and (data.cnp^ > cptr) then begin
        xm := data.cdp^[1+cmem];
	xp := data.cdp^[1+cptr];
	ym := data.tbl^[1+rmem][1+cmem];
	yp := data.tbl^[1+rptr][1+cptr];
	if (log_x) then begin
	   xm := log10(abs(xm)+VERY_SMALL);
	   xp := log10(abs(xp)+VERY_SMALL);
	end;
	if (log_y) then begin
	   yp := log10(abs(yp)+VERY_SMALL);
	   ym := log10(abs(ym)+VERY_SMALL);
	end;
	if (yp <> ym) then begin
	   dxdy := (xp - xm) / (yp - ym);
	   x0 := xm - ym * dxdy;
	   msg := 'x(0) = '+ftoa(x0,9,-1)+'; dx/dy = '+ftoa(dxdy,9,-1);
	end
	else
	   msg := 'x(0) = INFINITE; dx/dy = INFINITE';
	if (xp <> xm) then begin
	   dydx := (yp - ym) / (xp - xm);
	   y0 := ym - xm * dydx;
	   msg := msg+'; y(0) = '+ftoa(y0,9,-1)+'; dy/dx = '+ftoa(dydx,9,-1);
	end
	else
	   msg := msg+'; y(0) = INFINITE; dy/dx = INFINITE';
	if (xm < cur.x_lo) then xm := cur.x_lo;
	if (ym < cur.y_lo) then ym := cur.y_lo;
	if (xp < cur.x_lo) then xp := cur.x_lo;
	if (yp < cur.y_lo) then yp := cur.y_lo;
	g_line(xm,ym,xp,yp);
	dsp_message(t,msg);
     end;
  end;
end;

procedure draw_point (var t:tabloid; x,y:single);
begin
  with t do begin
     if (log_x) then
	x := log10(abs(x)+VERY_SMALL);
     if (log_y) then
	y := log10(abs(y)+VERY_SMALL);
     if (x < cur.x_lo) then x := cur.x_lo;
     if (y < cur.y_lo) then y := cur.y_lo;
     g_moveto(x,y);
     g_plot(x,y);
  end;
end;

procedure draw_line (var t:tabloid; x,y:single);
begin
  with t do begin
     if (log_x) then
	x := log10(abs(x)+VERY_SMALL);
     if (log_y) then
	y := log10(abs(y)+VERY_SMALL);
     if (x < cur.x_lo) then x := cur.x_lo;
     if (y < cur.y_lo) then y := cur.y_lo;
     g_lineto(x,y);
  end;
end;

(*---------------------------------------------------------------------------
 * EXTERNAL (PUBLIC) ROUTINES
 *)

procedure set_regions (var t:tabloid);
var
  ixl, ixn, iyp, iyn, iyl : integer;
begin
  with t do begin
     set_world(msg_wld, -1.0, -1.0, 1.0, 1.0);
     ixl := round(0.045 * g_max_x);
     ixn := round(0.165 * g_max_x);
     iyp := round(0.800 * g_max_y);
     iyn := round(0.835 * g_max_y);
     iyl := round(0.870 * g_max_y);
     set_region(plot_rgn, ixn, 0, g_max_x, iyp);
     set_region(xnum_rgn, ixn, iyp, g_max_x, iyn);
     set_region(xlabel_rgn, ixn, iyn, g_max_x, iyl);
     set_region(ynum_rgn, ixl, 0, ixn, iyp);
     set_region(ylabel_rgn, 0, 0, ixl, iyp);
     set_region(msg_rgn, 0, iyl, g_max_x , g_max_y);
  end;
end;

procedure set_limits (var t:tabloid; xlo,xhi,ylo,yhi:value);
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

procedure set_bounds (var t:tabloid);

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

procedure set_static_data (var t:tabloid;
			       title_1,title_2,title_3:string;
			       xl,yl:string31);
begin
  with t do with data do begin
     x_label := xl;
     y_label := yl;
     title[1] := title_1;
     title[2] := title_2;
     title[3] := title_3;
  end;
end;

procedure set_dynamic_data (var t:tabloid;
			    var rows:pararr; var nrows:index;
			    var cols:valarr; var ncols:index;
			    var matrix:valarrarr);
begin
  with t do with data do begin
     rdp := addr(rows);
     rnp := addr(nrows);
     cdp := addr(cols);
     cnp := addr(ncols);
     tbl := addr(matrix);
  end;
end;

procedure set_dynamic_ptrs (var t:tabloid; var rowidx,colidx:index);
begin
  with t do with data do begin
     rip := addr(rowidx);
     cip := addr(colidx);
  end;
end;

procedure set_flags (var t:tabloid;
		         log_x_flag,log_y_flag,grid_axes:boolean);
begin
  with t do begin
     log_x := log_x_flag;
     log_y := log_y_flag;
     grid := grid_axes;
  end;
end;

procedure dsp_title (var t:tabloid);
var
  cpx, cpy : integer;
begin
  cpx := GetX;
  cpy := GetY;
  with t do begin
     SetTextStyle(SmallFont,HorizDir,4);
     zap(msg_wld,msg_rgn,MESSAGE_COLOUR);
     blank_region;
     SetTextJustify(CenterText,CenterText);
     g_outtextxy(0.0,0.80,data.title[1]);
     g_outtextxy(0.0,0.40,data.title[2]);
     g_outtextxy(0.0,0.0,data.title[3]);
     g_outtextxy(0.0,-0.5,
     		 '"q"=quit, "*"=rescale, F1=redraw, ENTER=zoom & redraw, ^P=hardcopy');
  end;
  MoveTo(cpx,cpy);
end;

procedure dsp_message (var t:tabloid; msg:string);
var
  cpx, cpy : integer;
begin
  cpx := GetX;
  cpy := GetY;
  with t do begin
     SetTextStyle(SmallFont,HorizDir,4);
     SetTextJustify(CenterText,CenterText);
     zap(msg_wld,msg_rgn,MESSAGE_COLOUR);
     blank_region;
     g_outtextxy(0.0,0.5,msg);
     g_outtextxy(0.0,-0.5,
     		 '"q"=quit, "*"=rescale, F1=redraw, ENTER=zoom & redraw, ^P=hardcopy');
  end;
  MoveTo(cpx,cpy);
end;

procedure dsp_cursor_status(var t:tabloid);
begin
  with t do
     dsp_message(t,'Cursor: ('+ftoa(curs_x,12,-1)+','+ftoa(curs_y,12,-1)+'); '
                 + 'Marker: ('+ftoa(mark_x,12,-1)+','+ftoa(mark_y,12,-1)+')');
end;

procedure dsp_ticks (var t:tabloid);
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
     if (sgn(cur.x_hi) * sgn(cur.x_lo) < 0.0) then
	g_line(0.0, cur.y_lo, 0.0, cur.y_hi);
     if (sgn(cur.y_hi) * sgn(cur.y_lo) < 0.0) then
	g_line(cur.x_lo, 0.0, cur.x_hi, 0.0);

     SetTextStyle(SmallFont, HorizDir, 4);
     SetTextJustify(CenterText, CenterText);

     x := xbase;
     while (x < cur.x_hi) do begin
	zap(plot_wld, plot_rgn, AXIS_COLOUR);
	if grid then begin
	  SetLineStyle(DottedLn, 0, NormWidth);
	  verline(x, cur.y_lo, yspan);
	  SetLineStyle(SolidLn, 0, NormWidth);
	end
	else begin
	  verline(x, cur.y_hi, -0.02*yspan);
	  verline(x, cur.y_lo,  0.02*yspan);
	end;
	zap(xnum_wld, xnum_rgn, AXIS_COLOUR);
	if (abs(x) < 1.0e-5 * xtick) then x := 0.0;
	if (x <= (cur.x_hi - 0.05*xspan)) then
	   if (log_x) then
	      g_outtextxy(x, 0.0, ftoa(x,11,5))
	   else
	      g_outtextxy(x, 0.0, ftoa(x,11,-1));
	x := x + xtick;
     end;

     y := ybase;
     while (y < cur.y_hi) do begin
	zap(plot_wld, plot_rgn, AXIS_COLOUR);
	if grid then begin
	   SetLineStyle(DottedLn,0, NormWidth);
	   horline(cur.x_lo, y, xspan);
	   SetLineStyle(SolidLn, 0, NormWidth);
	end
	else begin
	   horline (cur.x_hi, y, -0.01*xspan);
	   horline (cur.x_lo, y, 0.01*xspan);
	end;
	zap(ynum_wld, ynum_rgn, AXIS_COLOUR);
	if (abs(y) < 1.0e-5 * ytick) then y := 0.0;
	if (y <= (cur.y_hi - 0.01*yspan)) then
	   if (log_y) then
	      g_outtextxy(0.0, y, ftoa(y,11,5))
	   else
	      g_outtextxy(0.0, y, ftoa(y,11,-1));
	y := y + ytick;
     end;

     SetTextStyle(SmallFont,HorizDir,4);
     zap(msg_wld, xlabel_rgn, MESSAGE_COLOUR);
     if (log_x) then
	g_outtextxy(0.0, 0.1, 'log ('+data.x_label+')')
     else
	g_outtextxy(0.0, 0.1, data.x_label);

     SetTextStyle(SmallFont,VertDir,4);
     zap(msg_wld, ylabel_rgn, MESSAGE_COLOUR);
     if (log_y) then
	g_outtextxy(0.0,0.0, 'log ('+data.y_label+')')
     else
	g_outtextxy(0.0, 0.0, data.y_label);
  end;
end;

procedure calc_limits (var t:tabloid; var xl,xh,yl,yh:value);
var
  row, col : index;
begin
  with t.data do begin
     xl := cdp^[1];
     xh := xl;
     yl := tbl^[1][1];
     yh := yl;
     for row := 1 to (rip^ - 1) do begin
        for col := 1 to cnp^ do begin
	   if (yl > tbl^[row][col]) then yl := tbl^[row][col];
	   if (yh < tbl^[row][col]) then yh := tbl^[row][col];
	end;
     end;
     if (rip^ > 0) then begin
        for col := 1 to cip^ do begin
	   if (yl > tbl^[rip^][col]) then yl := tbl^[rip^][col];
	   if (yh < tbl^[rip^][col]) then yh := tbl^[rip^][col];
	   if (xl > cdp^[col]) then xl := cdp^[col];
	   if (xh < cdp^[col]) then xh := cdp^[col];
	end;
	for col := cip^+1 to cnp^ do begin
	   if (xl > cdp^[col]) then xl := cdp^[col];
	   if (xh < cdp^[col]) then xh := cdp^[col];
	end;
     end
     else begin
        for col := 2 to cip^ do begin
	   if (xl > cdp^[col]) then xl := cdp^[col];
	   if (xh < cdp^[col]) then xh := cdp^[col];
	end;
     end;
  end;
  if (xl = xh) then xh := xl + VERY_SMALL;
  if (yl = yh) then yh := yl + VERY_SMALL;
end;

procedure dsp_curves(var t:tabloid);
var
  row, col : index;
begin
  with t do begin
     rptr := 0;
     cptr := 0;
     rmem := 0;
     cmem := 0;
     zap(plot_wld, plot_rgn, PLOT_COLOUR);
     with data do begin
        for row := 1 to (rip^ - 1) do
	   if (cnp^ > 0) then begin
	      draw_point(t, cdp^[1], tbl^[row][1]);
	      for col := 2 to cnp^ do
	      	 draw_line(t, cdp^[col], tbl^[row][col]);
	      MoveRel(3,0);
	      OutText(ftoa(row,2,0))
	   end;
        if (rip^ > 0) then
	   if (cip^ > 0) then begin
	      draw_point(t, cdp^[1], tbl^[rip^][1]);
	      for col := 2 to cip^ do
	         draw_line(t, cdp^[col], tbl^[rip^][col]);
	      if (cip^ = cnp^) then begin
	         MoveRel(3,0);
	         OutText(ftoa(rip^,2,0));
	      end;
	   end;
     end;
  end;
end;

procedure dsp_updates (var t:tabloid);
begin
  with t do begin
     zap(plot_wld, plot_rgn, PLOT_COLOUR);
     with data do begin
	if (cip^ = 1) then
	   draw_point(t, cdp^[cip^], tbl^[rip^][cip^])
	else
	   draw_line(t, cdp^[cip^], tbl^[rip^][cip^]);
	if (cip^ = cnp^) then begin
	   MoveRel(3,0);
	   OutText(ftoa(rip^,2,0));
	end;
     end;
  end;
end;

procedure dsp_frame (var t:tabloid);
const 
  delta_divisor:single = 25.0;
var
  i : integer;
  xspan, yspan : single;
begin
  SetGraphMode(g_mode);
  with t do begin
     old.x_lo := cur.x_lo;
     old.x_hi := cur.x_hi; 
     old.y_lo := cur.y_lo; 
     old.y_hi := cur.y_hi;
     curs_x := 0.5 * (cur.x_hi + cur.x_lo);
     curs_y := 0.5 * (cur.y_hi + cur.y_lo);
     mark_x := curs_x;
     mark_y := curs_y;
     xspan := cur.x_hi - cur.x_lo; 
     yspan := cur.y_hi - cur.y_lo;
     dx := xspan / delta_divisor; 
     dy := yspan / delta_divisor;

     set_world (plot_wld, cur.x_lo, cur.y_lo, cur.x_hi, cur.y_hi);
     set_world (xnum_wld, cur.x_lo, -1.0, cur.x_hi, 1.0);
     set_world (ynum_wld, -1.0, cur.y_lo, 1.0, cur.y_hi);

     zap (plot_wld,plot_rgn,AXIS_COLOUR);
     blank_region;
     draw_border;
     dsp_ticks (t);
     zap(plot_wld, plot_rgn, PLOT_COLOUR);
     dsp_title(t);
  end;
end;

procedure undsp_frame (var t:tabloid);
begin
  RestoreCrtMode;
end;

procedure act_event (var t:tabloid; c:char);
var
  dummy : char;
  cbuf : string;
  image : paper;
  xl, xh, yl, yh : value;
begin
  with t do
     case c of
       'e':   (* EXPAND MANUALLY *)
	  begin
	    RestoreCrtMode;
	    clrscr;
	    gotoxy(1,10);
	    cur.x_lo := input_default(cur.x_lo, 'low  X bound');
	    cur.x_hi := input_default(cur.x_hi, 'high X bound');
	    writeln;
	    cur.y_lo := input_default(cur.y_lo, 'low  Y bound');
	    cur.y_hi := input_default(cur.y_hi, 'high Y bound');
	    SetGraphMode(g_mode);
	    dsp_frame(t);
	    dsp_curves(t);
	  end;
       ';':   (* RESET *)
	  begin
	    dsp_message(t,'Resetting...');
	    log_x := FALSE;
	    log_y := FALSE;
	    set_bounds(t);
	    dsp_frame(t);
	    dsp_curves(t);
	  end;
       '*':   (* RESCALE *)
          begin
	    dsp_message(t,'Rescaling...');
	    log_x := FALSE;
	    log_y := FALSE;
	    calc_limits(t,xl,xh,yl,yh);
	    set_limits(t,xl,xh,yl,yh);
	    set_bounds(t);
	    dsp_frame(t);
	    dsp_curves(t);
	  end;
       'g':   (* GRID TOGGLE *)
	  begin
	    grid := not grid;
	    dsp_frame(t);
	    dsp_curves(t);
	  end;
       ^P :   (* PEN PLOT *)
          begin
	    xl := cur.x_lo;
	    xh := cur.x_hi;
	    if (log_x) then begin
	       xl := pow(10.0,xl);
	       xh := pow(10.0,xh);
	    end;
	    yl := cur.y_lo;
	    yh := cur.y_hi;
	    if (log_y) then begin
	       yl := pow(10.0,yl);
	       yh := pow(10.0,yh);
	    end;
	    pp_set_regions(image);
	    pp_set_limits(image,xl,xh,yl,yh);
	    pp_set_flags(image,log_x, log_y, false);
	    pp_set_bounds(image);
	    with data do
	       pp_set_data(image,title[1],title[2],title[3],x_label,y_label,
	    		         rdp^, rnp^, cdp^, cnp^, tbl^);
	    dsp_message(t,'Set up plotter.  Press a key when ready...');
	    dummy := ReadKey;
            dsp_message(t,'Plotting on plotter...');
	    pp_dsp_frame(image);
	    pp_dsp_curves(image);
	    pp_undsp_frame(image);
	    dsp_title(t);
	  end;
       CR,LF:  (* dsp_frame *)
	  begin
	    dsp_frame(t);
	    dsp_curves(t);
	  end;
       ESC:   (* ABORT *)
	  begin
	    cur := old;
	    dsp_frame(t);
	    dsp_curves(t);
	  end;
       'm':   (* MARK *)
	  begin
	    zap(plot_wld,plot_rgn,Black);
	    draw_marker(mark_x,mark_y);
	    mark_x := curs_x;
	    mark_y := curs_y;
	    g_setcolor(AXIS_COLOUR);
	    draw_marker(mark_x,mark_y);
	  end;
       '\':   (* CHORD BETWEEN MARKER AND CURSOR *)
          begin
	    zap(plot_wld,plot_rgn,AXIS_COLOUR);
	    g_line(mark_x,mark_y,curs_x,curs_y);
	  end;
       'd':   (* DELTA STATS *)
	  begin
	    cbuf := 'dx = '+ftoa(curs_x-mark_x,9,-1) + 
		    '; dy = '+ftoa(curs_y-mark_y,9,-1);
	    if (curs_x <> mark_x) then
	       cbuf := cbuf + '; dy/dx = ' + 
		       ftoa((curs_y-mark_y)/(curs_x-mark_x),9,-1) +
		       '; y(0) = ' + 
		       ftoa(mark_y-mark_x*(curs_y-mark_y) /
			    (curs_x-mark_x),
			    9,-1)
	    else
	       cbuf := cbuf + '; dy/dx = INFINITE; y(0) = INFINITE';
	    if (curs_y <> mark_y) then
	       cbuf := cbuf + '; dx/dy = ' +
	       	       ftoa((curs_x-mark_x)/(curs_y-mark_y),9,-1) +
		       '; x(0) = ' +
		       ftoa(mark_x-mark_y*(curs_x-mark_x) /
		            (curs_y-mark_y),
			    9,-1)
	    else
	       cbuf := cbuf + '; dx/dy = INFINITE; x(0) = INFINITE';
	    dsp_message(t,cbuf);
	  end;
       't':   (* TITLE *)
	  begin
	    dsp_title(t);
	  end;
       'x','X':  (* X *)
	  begin
	    log_x := not log_x;
	    set_bounds(t);
            dsp_frame(t);
	    dsp_curves(t);
	  end;
       'y','Y':   (* Y *)
	  begin
	    log_y := not log_y;
	    set_bounds(t);
            dsp_frame(t);
	    dsp_curves(t);
	  end;
       'b','B':   (* Both *)
	  begin
	    log_x := not log_x;
	    log_y := not log_y;
	    set_bounds(t);
	    dsp_frame(t);
	    dsp_curves(t);
	  end;
       '.':
	  begin
	    cmem := cptr;
	    rmem := rptr;
	    draw_mem(t);
	  end;
       '/':
	  begin
	    draw_chord(t);
	  end;
       ^I,^H,'>','<':
          begin
	    zap(plot_wld,plot_rgn, Black);
	    draw_ptr(t);
	    case c of
	       ^I :
	          begin
		    cptr := (cptr + 1 + data.cnp^) mod data.cnp^;
		  end;
	       ^H :
	          begin
		    cptr := (cptr - 1 + data.cnp^) mod data.cnp^;
		  end;
	       '>':
	          begin
		    rptr := (rptr + 1 + data.rnp^) mod data.rnp^;
		  end;
	       '<':
	          begin
		    rptr := (rptr - 1 + data.rnp^) mod data.rnp^;
		  end;
	    end; (* case *)
	    zap(plot_wld,plot_rgn,AXIS_COLOUR);
	    draw_ptr(t);
	  end;
       '9','I':   (* PG UP *)
	  begin
	    if (cur.y_lo > old.y_lo) then begin
	      g_setcolor(Black);
	      horline(cur.x_lo,cur.y_lo,dx);
	      horline(cur.x_hi,cur.y_lo,-dx);
	    end;
	    if (cur.y_hi < old.y_hi) then begin
	      g_setcolor(Black);
	      horline(cur.x_lo,cur.y_hi,dx);
	      horline(cur.x_hi,cur.y_hi,-dx);
	    end;
	    dx := abs(2.0 * dx);
	    g_setcolor(White);
	    horline(cur.x_lo,cur.y_lo,dx);
	    horline(cur.x_hi,cur.y_lo,-dx);
	    horline(cur.x_lo,cur.y_hi,dx);
	    horline(cur.x_hi,cur.y_hi,-dx);
	  end;
       '3','Q':   (* PG DN *)
	  begin
	    if (cur.y_lo > old.y_lo) then begin
	      g_setcolor(Black);
	      horline(cur.x_lo,cur.y_lo,dx);
	      horline(cur.x_hi,cur.y_lo,-dx);
	    end;
	    if (cur.y_hi < old.y_hi) then begin
	      g_setcolor(Black);
	      horline(cur.x_lo,cur.y_hi,dx);
	      horline(cur.x_hi,cur.y_hi,-dx);
	    end;
	    dx := abs(dx / 2.0);
	    g_setcolor(White);
	    horline(cur.x_lo,cur.y_lo,dx);
	    horline(cur.x_hi,cur.y_lo,-dx);
	    horline(cur.x_lo,cur.y_hi,dx);
	    horline(cur.x_hi,cur.y_hi,-dx);
	  end;
       '7','G':    (* HOME *)
	  begin
	    if (cur.x_lo > old.x_lo) then begin
	      g_setcolor(Black);
	      verline(cur.x_lo,cur.y_lo,dy);
	      verline(cur.x_lo,cur.y_hi,-dy);
	    end;
	    if (cur.x_hi < old.x_hi) then begin
	      g_setcolor(Black);
	      verline(cur.x_hi,cur.y_lo,dy);
	      verline(cur.x_hi,cur.y_hi,-dy);
	    end;
	    dy := abs(2.0 * dy);
	    g_setcolor(White);
	    verline(cur.x_lo,cur.y_lo,dy);
	    verline(cur.x_lo,cur.y_hi,-dy);
	    verline(cur.x_hi,cur.y_lo,dy);
	    verline(cur.x_hi,cur.y_hi,-dy);
	  end;
       '1','O':    (* END *)
	  begin
	    if (cur.x_lo > old.x_lo) then begin
	      g_setcolor(Black);
	      verline(cur.x_lo,cur.y_lo,dy);
	      verline(cur.x_lo,cur.y_hi,-dy);
	    end;
	    if (cur.x_hi < old.x_hi) then begin
	      g_setcolor(Black);
	      verline(cur.x_hi,cur.y_lo,dy);
	      verline(cur.x_hi,cur.y_hi,-dy);
	    end;
	    dy := abs(dy / 2.0);
	    g_setcolor(White);
	    verline(cur.x_lo,cur.y_lo,dy);
	    verline(cur.x_lo,cur.y_hi,-dy);
	    verline(cur.x_hi,cur.y_lo,dy);
	    verline(cur.x_hi,cur.y_hi,-dy);
	  end;
       '8':  (* UP *)
	  begin
	    if (cur.y_lo + dy < cur.y_hi) then begin
	       if (cur.y_lo > old.y_lo) then begin
		  g_setcolor(Black);
		  horline(cur.x_lo,cur.y_lo,dx);
		  horline(cur.x_hi,cur.y_lo,-dx);
	       end;
	       if (cur.x_lo > old.x_lo) then begin
		  g_setcolor(Black);
		  verline(cur.x_lo,cur.y_lo,dy);
	       end;
	       if (cur.x_hi < old.x_hi) then begin
		  g_setcolor(Black);
		  verline(cur.x_hi,cur.y_lo,dy);
	       end;
	       cur.y_lo := cur.y_lo + dy;
	       g_setcolor(White);
	       horline(cur.x_lo,cur.y_lo,dx);
	       verline(cur.x_lo,cur.y_lo,dy);
	       horline(cur.x_hi,cur.y_lo,-dx);
	       verline(cur.x_hi,cur.y_lo,dy);
	    end
	    else
	       beep;
	  end;
       '2':  (* DOWN *)
	  begin
	    if (cur.y_hi - dy > cur.y_lo) then begin
	       if (cur.y_hi < old.y_hi) then begin
		  g_setcolor(Black);
		  horline(cur.x_lo,cur.y_hi,dx);
		  horline(cur.x_hi,cur.y_hi,-dx);
	       end;
	       if (cur.x_lo > old.x_lo) then begin
		  g_setcolor(Black);
		  verline(cur.x_lo,cur.y_hi,-dy);
	       end;
	       if (cur.x_hi < old.x_hi) then begin
		  g_setcolor(Black);
		  verline(cur.x_hi,cur.y_hi,-dy);
	       end;
	       cur.y_hi := cur.y_hi - dy;
	       g_setcolor(White);
	       horline(cur.x_lo,cur.y_hi,dx);
	       verline(cur.x_lo,cur.y_hi,-dy);
	       horline(cur.x_hi,cur.y_hi,-dx);
	       verline(cur.x_hi,cur.y_hi,-dy);
	    end
	    else
	       beep;
	  end;
       '4':  (* LEFT *)
	  begin
	    if (cur.x_hi - dx > cur.x_lo) then begin
	       if (cur.x_hi < old.x_hi) then begin
		  g_setcolor(Black);
		  verline(cur.x_hi,cur.y_lo,dy);
		  verline(cur.x_hi,cur.y_hi,-dy);
	       end;
	       if (cur.y_lo > old.y_lo) then begin
		  g_setcolor(Black);
		  horline(cur.x_hi,cur.y_lo,-dx);
	       end;
	       if (cur.y_hi < old.y_hi) then begin
		  g_setcolor(Black);
		  horline(cur.x_hi,cur.y_hi,-dx);
	       end;
	       cur.x_hi := cur.x_hi - dx;
	       g_setcolor(White);
	       verline(cur.x_hi,cur.y_lo,dy);
	       horline(cur.x_hi,cur.y_lo,-dx);
	       verline(cur.x_hi,cur.y_hi,-dy);
	       horline(cur.x_hi,cur.y_hi,-dx);
	    end
	    else
	       beep;
	  end;
       '6': (* RIGHT *)
	  begin
	    if (cur.x_lo + dx < cur.x_hi) then begin
	       if (cur.x_lo > old.x_lo) then begin
		  g_setcolor(Black);
		  verline(cur.x_lo,cur.y_lo,dy);
		  verline(cur.x_lo,cur.y_hi,-dy);
	       end;
	       if (cur.y_lo > old.y_lo) then begin
		  g_setcolor(Black);
		  horline(cur.x_lo,cur.y_lo,dx);
	       end;
	       if (cur.y_hi < old.y_hi) then begin
		  g_setcolor(Black);
		  horline(cur.x_lo,cur.y_hi,dx);
	       end;
	       cur.x_lo := cur.x_lo + dx;
	       g_setcolor(White);
	       verline(cur.x_lo,cur.y_lo,dy);
	       horline(cur.x_lo,cur.y_lo,dx);
	       verline(cur.x_lo,cur.y_hi,-dy);
	       horline(cur.x_lo,cur.y_hi,dx);
	    end
	    else
	       beep;
	  end;
       else
	  begin
	    zap(plot_wld,plot_rgn, Black);
	    draw_cursor(curs_x,curs_y);
	    case c of
	       's','S':   (* SHOW *)
		  begin
		    dsp_cursor_status(t);
		  end;
	       'H':   (* UP *)
		  begin
		    if (curs_y + dy <= old.y_hi) then
		       curs_y := curs_y + dy
		    else
		       beep;
		  end;
	       'P':   (* DOWN *)
		  begin
		    if (curs_y - dy >= old.y_lo) then
		       curs_y := curs_y - dy
		    else
		       beep;
		  end;
	       'K':   (* LEFT *)
		  begin
		    if (curs_x - dx >= old.x_lo) then
		       curs_x := curs_x - dx
		    else
		       beep;
		  end;
	       'M':   (* RIGHT *)
		  begin
		    if (curs_x + dx <= old.x_hi) then
		       curs_x := curs_x + dx
		    else
		       beep;
		  end;
	       else
		  begin
		    beep;
		  end; (* else *)
	    end; (* case *)
	    zap(plot_wld,plot_rgn,AXIS_COLOUR);
	    draw_cursor(curs_x,curs_y);
	  end; (* else *)
     end; (* case *)
end;

begin (* preamble *)
end.  (* preamble *)
