program MOS;
(*
 * MOS characterization program.
 * History:
 * 14 Oct 88		Version 1.07
 *	After several modifications, the first user-ready version appears
 *	finished.  It can read script files (using the source command)
 *	and properly stamps out the date on GIRAPHE3 files.
 * 18 Oct 88		Version 1.08
 *	At Akira's request, added function to convert an array to its log,
 *	exponential or reciprocal in modify menu, to allow surface
 *	state measurements.
 * 02 Nov 88		Version 1.09
 *	Added additional modifying functions to modify menu.  Prettied up
 *	data display.
 * 23 Nov 88		Version 1.10
 *	Changed native data saving mode to text file, using save_text
 *	and read_text.  This makes it easier to modify.
 * 23 Feb 89		Version 1.12
 *	Don't ask me what happened to Version 1.11.  Version 1.12 can deal
 *	with logarithmic plotting more rationally, plotting the absolute
 *	values, and it also allows the abortion of a data acquisition run
 *	halfway through the run.  It also talks to the 7470A Plotter!!!!!!
 *  4 Mar 89		Version 1.13
 *	Hacked together a mode to interface with the Multiprogrammer and the
 *	Keithley multimeter.
 * 11 Mar 89		Version 1.14
 *	After extensively hacking version 1.13 to do everything correctly,
 *	the source file was lost due to an EMACS swapping screwup.  Version
 *	1.14 recreates all the changes to the user-friendly 1.13.
 * 15 Mar 89		Version 1.15
 *	Some cleanup of the 1.14 code, including COM1 timing for the plotter
 * 	and addition of the POINTER and DOT concepts to graphics mode.
 * 20 Mar 89		Version 1.16
 *	The Last Feature: a "remeasure" command has been added to
 *	play_graphics in order to enable a measurement to be repeated without
 *	exiting graphics mode, and without being asked to save the data.
 * 25 Apr 89		Version 1.17
 *	Added new sweep mode to AC CV measurements.
 * 27 Dec 89		Version 1.18
 *	Completely restructured parser and menus units to save data segment
 *	space.
 *)

uses
  dos, crt, generics, site, error, values, gpib, curves, parser, menus,
  penplot, multprog;

const
  WHOAMI = 'MOS';
  INITFILE = 'MOS.INI';
  CODE_VERSION = '1.18';
  CURSED_ONE = 'Siang-Chun The (39-661, x3-0733, the@caf)';

(*****************************************************************************
 * BASIC TOOLS
 *)
const
  TINY = 1.0e-35;

procedure sort2 (var small,large:value);
var
  t : value;
begin
  if (small > large) then begin
     t := small;
     small := large;
     large := t;
  end;
end;

var
  autoexit : boolean;			(* Auto exit from graphics modes *)
  ref_dir : string127;

function check_safety (flag:boolean) : boolean;
begin
  if flag or autoexit then
     check_safety := TRUE
  else if user_confirm ('Data not saved.  Are you sure (yes)?',TRUE) then
     check_safety := TRUE
  else
     check_safety := FALSE;
end;

procedure macro_file (name:string63; var code:integer);
begin
  if not exists_file(name) then
     name := ref_dir + name;
  assign(input, name);
  {$i-}
  reset(input); code := IOResult;
  {$i+}
  if (code = 0) then
     autoexit := not (name = '')
  else begin
     assign(input,'');
     reset(input);
     autoexit := FALSE;
  end;
end;

function sgn(x:single) : single;
begin
  if (x < 0.0) then
     sgn := -1.0
  else
     sgn := 1.0;
end;

procedure calc_steps(var x1,x2,dx:single; quantum:single;
	 	     var nx:integer; maximum:integer);
var
  sign : single;
  i : integer;
begin
  sign := sgn(x2-x1);
  quantum := abs(quantum);
  if (quantum = 0.0) then begin
     if (x2 = x1) then x2 := x1 + TINY;
     if (dx = 0.0) then dx := (x2 - x1);
     quantum := abs(dx);
  end
  else begin
     if (dx = 0.0) then dx := sign * quantum;
     x1 := quantum * round(x1 / quantum);
     x2 := quantum * round(x2 / quantum);
     dx := quantum * round(dx / quantum);
  end;
  dx := sign * abs(dx);
  nx := 1 + round((x2 - x1) / dx);
  if (nx > maximum) then begin
     i := 0;
     while (nx > maximum) do begin
        inc(i);
        dx := i * sign * quantum;
	nx := 1 + round((x2 - x1) / dx);
     end;
  end;
  if (abs(x2 - x1) < abs(dx * (nx - 1))) then
     nx := nx - 1;
end;

(****************************************************************************
 * DATA TYPE DEFINITIONS
 *
 * Remember to update the DATA_VERSION constant every time the data set format
 * is changed.  This includes changing the contents of the unit values.pas,
 * which defines the types VALUE, VALARRARR, VALARR, PARARR and INDEX.
 *)
const
  DATA_VERSION = '1.01';
  SOURCE = 1;
  DRAIN  = 2;
  GATE   = 3;
  BULK   = 4;
  MP_NODES : array[1..4] of string[6] = ('SOURCE','DRAIN','GATE','BULK');
type
  data_rec = record
  		codever : string15;
		dataver : string15;
		date : date_rec;
                time : time_t;
                remarks : array[0..2] of string[84];
                x_label, y_label, p_label : string63;

                y : valarrarr;
                ymax, ymin : value;

                x : valarr;
                xmax, xmin : value;
                Nx : index;

                p : pararr;
                pmax, pmin : value;
                Np : index;

		padding : array[0..1038] of byte;
             end;

type
  par_GIV  = record
  		prog, meter_a, meter_b, meter_hp : device;
  		Vx_start, Vx_stop, Vx_step : single;
		Vp_start, Vp_stop, Vp_step : single;
		V_bias : single;
		t_hold, t_step : single;
		bidirect : boolean;
		node : record
		         x, p, bias, ref : byte;
		       end;
		Nx, Np : integer;
  	     end;
  par_4140 = record
  		dev : device;
  		Va_start, Va_stop, Va_step, Va_rate : single;
		Vb_start, Vb_stop, Vb_step : single;
		t_hold, t_step : single;
		bidirect : boolean;
		Nx, Np : integer;
  	     end;
  par_qcv  = record
  		dev : device;
  		Va_start, Va_stop, Va_step : single;
		r_start, r_stop, r_step : single;
		t_hold : single;
		bidirect : boolean;
		Nx, Np : integer;
  	     end;
  par_4192 = record
  		dev : device;
    		V_start, V_stop, V_step : single;
		f_start, f_stop, f_step : single;
		osc_level : single;
		t_hold, t_step : single;
		average, bidirect : boolean;
		Nx, Np : integer;
	     end;
  par_DCV = record
  		dev : device;
		V_start, V_stop, V_step : single;
		f_start, f_stop, f_step : single;
		V_accum : single;
		osc_level : single;
		t_hold, t_step : single;
		average : boolean;
		Nx, Np : integer;
  	     end;

(*
 * parse_bounds_opts provides a common plotting-option parsing centre
 * to enforce a common convention among all the plotting commands for
 * graphics display options.  Since it already parses some of the 
 * command line arguments, they must be flagged to be "seen", and are
 * simply set to the empty string.
 *)
procedure parse_bounds_opts (var dset:data_rec; var log_x,log_y:boolean;
			     var argc:integer; var argv:arglist);
var
  i, code : integer;
begin
  i := 2;
  while (i <= argc) do begin
     if (argv[i] = '-x-') then begin
        argv[i] := '';
        inc(i);
	if (i > argc) then
	   barf('not enough arguments for option', '-x-')
	else begin
           dset.xmin := atof(argv[i],code);
	   argv[i] := '';
	end;
     end
     else if (argv[i] = '-x+') then begin
        argv[i] := '';
        inc(i);
	if (i > argc) then
	   barf('not enough arguments for option', '-x+')
	else begin
           dset.xmax := atof(argv[i],code);
	   argv[i] := '';
	end;
     end
     else if (argv[i] = '-x') then begin
        argv[i] := '';
        inc(i);
	if (i >= argc) then
	   barf('not enough arguments for option', '-x')
	else begin
	   if (argv[i-1][1] <> '*') then
	      dset.xmin := atof(argv[i],code);
	   argv[i] := '';
	   inc(i);
	   if (argv[i][1] <> '*') then
              dset.xmax := atof(argv[i],code);
	   argv[i] := '';
	end;
     end
     else if (argv[i] = '-y-') then begin
        argv[i] := '';
        inc(i);
	if (i > argc) then
	   barf('not enough arguments for option', '-y-')
	else begin
           dset.ymin := atof(argv[i],code);
	   argv[i] := '';
	end;
     end
     else if (argv[i] = '-y+') then begin
        argv[i] := '';
        inc(i);
	if (i > argc) then
	   barf('not enough arguments for option', '-y+')
	else begin
           dset.ymax := atof(argv[i],code);
	   argv[i] := '';
	end;
     end
     else if (argv[i] = '-y') then begin
        argv[i] := '';
        inc(i);
	if (i >= argc) then
	   barf('not enough arguments for option', '-y')
	else begin
	   if (argv[i][1] <> '*') then
	      dset.ymin := atof(argv[i],code);
	   argv[i] := '';
	   inc(i);
	   if (argv[i][1] <> '*') then
              dset.ymax := atof(argv[i],code);
	   argv[i] := '';
	end;
     end
     else if (argv[i] = '-log_x') or (argv[i] = '-lx') then begin
        argv[i] := '';
        log_x := true;
     end
     else if (argv[i] = '-log_y') or (argv[i] = '-ly') then begin
        argv[i] := '';
        log_y := true;
     end;
     inc(i);
  end;
end;

(*
 * show_data_set is a common procedure called by all menus loops to
 * display the current status of the internal data set.
 *)
procedure show_data_set (var dset:data_rec);
var
  i, colour : byte;
begin
  colour := (TextAttr and $0F);
  TextColor(Yellow);
  with dset do begin
     for i := 0 to 2 do
        writeln('<',i,'> ',remarks[i]);
     writeln('Time mark = ',date_str(date,true),' at ',time_str(time,false));
     writeln('Array     Max        Min      Number   Label');
     screen_bar;
     writeln('  Y   ',ymax:10,' ',ymin:10,' ',Nx*Np:8,'   ',y_label);
     writeln('  X   ',xmax:10,' ',xmin:10,' ',Nx:8,'   ',x_label);
     writeln('  P   ',pmax:10,' ',pmin:10,' ',Np:8,'   ',p_label);
  end;
  TextColor(colour);
end;

(*
 * find boundaries on the data set --- used for autoscaling when plotting
 *)
procedure find_limits (var dset:data_rec);
var
  ip, ix : index;
begin
  with dset do begin
     pmin := p[1];    pmax := p[1];
     xmin := x[1];    xmax := x[1];
     ymin := y[1][1]; ymax := y[1][1];
     for ip := 2 to Np do begin
        pmin := lesser(pmin, p[ip]);
	pmax := greater(pmax, p[ip]);
     end;
     for ix := 2 to Nx do begin
        xmin := lesser(xmin, x[ix]);
	xmax := greater(xmax, x[ix]);
     end;
     for ip := 1 to Np do begin
        for ix := 1 to Nx do begin
	   ymin := lesser(ymin, y[ip][ix]);
	   ymax := greater(ymax, y[ip][ix]);
	end;
     end;
  end;
end;

(****************************************************************************
 * DATA SAVING ROUTINES
 *)

(*
 * saving a file in binary mode --- currently not used!
 *)
procedure save_binary (var d:data_rec; path:string127; var code:integer);
var
  f : file of data_rec;
begin
  code := 0;
  assign(f, path);
  {$i-}
  rewrite(f); code := IOResult;
  {$i+}
  if (code = 0) then begin
     {$i-}
     write(f, d); code := IOResult;
     {$i+}
     close(f);
  end;
end;

(*
 * save_text is the principal saving routine for saving in ".dat" files
 *)
procedure save_text (var d:data_rec; path:string127; var code:integer);
var
  f : text;
  ix, ip : index;
begin
  code := 0;
  assign(f, path);
  {$i-}
  rewrite(f); code := IOResult;
  {$i+}
  if (code = 0) then with d do begin
     {$i-}
     writeln(f,codever);  code := IOResult;
     if (code = 0) then begin
        writeln(f,dataver);  code := IOResult;
     end;
     if (code = 0) then begin
        writeln(f,date.year);  code := IOResult;
     end;
     if (code = 0) then begin
        writeln(f,date.month);  code := IOResult;
     end;
     if (code = 0) then begin
        writeln(f,date.day);  code := IOResult;
     end;
     if (code = 0) then begin
        writeln(f,time);  code := IOResult;
     end;
     if (code = 0) then for ix := 0 to 2 do begin
        writeln(f,remarks[ix]);  code := IOResult;
     end;
     if (code = 0) then begin
        writeln(f,x_label);  code := IOResult;
     end;
     if (code = 0) then begin
        writeln(f,y_label);  code := IOResult;
     end;
     if (code = 0) then begin
        writeln(f,p_label);  code := IOResult;
     end;
     if (code = 0) then begin
        writeln(f,ymax);  code := IOResult;
     end;
     if (code = 0) then begin
        writeln(f,ymin);  code := IOResult;
     end;
     if (code = 0) then begin
        writeln(f,xmax);  code := IOResult;
     end;
     if (code = 0) then begin
        writeln(f,xmin);  code := IOResult;
     end;
     if (code = 0) then begin
        writeln(f,pmax);  code := IOResult;
     end;
     if (code = 0) then begin
        writeln(f,pmin);  code := IOResult;
     end;
     if (code = 0) then begin
        writeln(f,Nx);  code := IOResult;
     end;
     if (code = 0) then begin
        writeln(f,Np);  code := IOResult;
     end;
     if (code = 0) then for ip := 1 to Np do begin
        writeln(f,p[ip]);  code := IOResult;
     end;
     if (code = 0) then for ix := 1 to Nx do begin
        writeln(f,x[ix]);  code := IOResult;
     end;
     if (code = 0) then for ip := 1 to Np do begin
        for ix := 1 to Nx do begin
	   writeln(f,y[ip][ix]);  code := IOResult;
	end;
     end;
     {$i+}
     close(f);
  end;
end;

(*
 * read_text can read files saved by save_text
 *)
procedure read_text (var d:data_rec; path:string127; var code:integer);
var
  f : text;
  ix, ip : index;
begin
  assign(f, path);
  {$i-}
  reset(f); code := IOResult;
  {$i+}
  if (code = 0) then with d do begin
     {$i-}
     readln(f,codever); code := IOResult;
     if (code = 0) then begin
        readln(f,dataver); code := IOResult;
     end;
     if (code = 0) then begin
        readln(f,date.year); code := IOResult;
     end;
     if (code = 0) then begin
        readln(f,date.month); code := IOResult;
     end;
     if (code = 0) then begin
        readln(f,date.day); code := IOResult;
     end;
     if (code = 0) then begin
        readln(f,time); code := IOResult;
     end;
     if (code = 0) then for ix := 0 to 2 do begin
        readln(f,remarks[ix]); code := IOResult;
     end;
     if (code = 0) then begin
        readln(f,x_label); code := IOResult;
     end;
     if (code = 0) then begin
        readln(f,y_label); code := IOResult;
     end;
     if (code = 0) then begin
        readln(f,p_label); code := IOResult;
     end;
     if (code = 0) then begin
        readln(f,ymax); code := IOResult;
     end;
     if (code = 0) then begin
        readln(f,ymin); code := IOResult;
     end;
     if (code = 0) then begin
        readln(f,xmax); code := IOResult;
     end;
     if (code = 0) then begin
        readln(f,xmin); code := IOResult;
     end;
     if (code = 0) then begin
        readln(f,pmax); code := IOResult;
     end;
     if (code = 0) then begin
        readln(f,pmin); code := IOResult;
     end;
     if (code = 0) then begin
        readln(f,Nx); code := IOResult;
     end;
     if (code = 0) then begin
        readln(f,Np); code := IOResult;
     end;
     if (code = 0) then for ip := 1 to Np do begin
        readln(f,p[ip]); code := IOResult;
     end;
     if (code = 0) then for ix := 1 to Nx do begin
        readln(f,x[ix]);  code := IOResult;
     end;
     if (code = 0) then for ip := 1 to Np do begin
        for ix := 1 to Nx do begin
	   readln(f,y[ip][ix]);  code := IOResult;
	end;
     end;
     {$i+}
     close(f);
  end;
end;

(*
 * read_binary can read files saved with save_binary
 *)
procedure read_binary (var d:data_rec; path:string127; var code:integer);
var
  f : file of data_rec;
begin
  assign(f, path);
  {$i-}
  reset(f); code := IOResult;
  {$i+}
  if (code = 0) then begin
     {$i-}
     read(f, d); code := IOResult;
     {$i+}
     close(f);
  end;
end;

(*
 * save_giraphe saves a file in ".grp" format, which can be uploaded to CAF
 *)

const
  LINEAR 	= 0;
  SEMILOG	= 1;
  LOGLOG	= 2;

procedure save_giraphe (var d:data_rec; mode:byte;
		      path:string127; var code:integer);
const
  TINY = 1.0e-36;
var
  ix, ip : index;
  f : text;
  buf : string31;
  xtmp, ytmp : double;
begin
  code := 0;
  assign(f, path);
  {$i-}
  rewrite(f);
  code := IOResult;
  {$i+}
  if (code = 0) then begin
     with d do begin
	writeln(f, 'title MOS (',d.codever,';',d.dataver,
		   ')                            ',
		   time_str(time,true),' on ',date_str(date,true));
	writeln(f, 'title ',remarks[0]);
	writeln(f, 'title ',remarks[1]);
	writeln(f, 'title ',remarks[2]);
	case (mode) of
	   LINEAR:
	      write(f, 'linear');
	   SEMILOG:
	      write(f, 'semilog');
	   LOGLOG:
	      write(f, 'loglog');
	   else
	      write(f, 'linear');
	end;
	write  (f, ' xmin=',xmin,' xmax=',xmax);
	write  (f, ' ymin=',ymin,' ymax=',ymax);
	writeln(f, ' frame=true');

	writeln(f, 'xlabel ',x_label);
	writeln(f, 'ylabel ',y_label);

	write  (f, 'read comfile=true');
	write  (f, ' xexp=x');
	write  (f, ' yexp=y');
	write  (f, ' family=p');
	writeln(f, ' numpoints=',Np*Nx);

	writeln(f, '.par p');
	writeln(f, '.col y x');
	for ip := 1 to Np do begin
	   writeln(f, '.set p=',p[ip]);
	   for ix := 1 to Nx do begin
	      xtmp := x[ix];
	      ytmp := y[ip][ix];
	      case (mode) of
	         LINEAR:
                    writeln(f, ytmp,'        ',xtmp);
		 SEMILOG:
		    writeln(f,abs(ytmp)+TINY,'        ',xtmp);
		 LOGLOG:
		    writeln(f,abs(ytmp)+TINY,'        ',abs(xtmp)+TINY);
	      end; (* case *)
	   end;
	end;
	writeln(f, '.end');
	write  (f, 'plot curve=true');
	write  (f, ' color=forground');
	write  (f, ' linestyle=next');
	writeln(f, ' symbol=next');
     end;
     close(f);
  end;
end;

(****************************************************************************
 * GPIB DATA ACQUISITION AND DYNAMIC PLOTTING ROUTINES
 * These routines perform the actual data acquisition, and plot the results
 * dynamically on the screen (hopefully!).
 *)

(*
 * The extract_* procedures all serve to extract a measured value from the
 * string passed back by the measuring instrument over the GPIB.
 *)

function extract_K619 (var s:string; var y:value) : boolean;
var
  code : integer;
begin
  y := atof(copy(s,4,255),code);
  extract_K619 := FALSE;
end;

function extract_4140 (var s:string; var y,x:value) : boolean;
var
  bad : boolean;
  sp1, sp2 : byte;
  code : integer;
begin
  bad := not (s[2] in ['N','L']);
  sp1 := 4;
  sp2 := pos(',',s);
  y := atof(copy(s, sp1, (sp2 - sp1 + 1)), code);
  sp1 := pos('A',s);
  sp2 := length(s) - 2;
  x := atof(copy(s, sp1, (sp2 - sp1 + 1)), code);
  extract_4140 := bad;
end;

function extract_4192 (var s:string; var y,x:value) : boolean;
var
  bad : boolean;
  sp1, sp2 : byte;
  code : integer;
begin
  bad := (s[1] <> 'N');
  sp1 := 5;
  sp2 := pos(',',s);
  y := atof(copy(s, sp1, (sp2 - sp1 + 1)), code);
  sp1 := 34;
  sp2 := length(s) - 2;
  x := atof(copy(s, sp1, (sp2 - sp1 + 1)), code);
  extract_4192 := bad;
end;

(*
 * setup_graphics initializes the graphics object "video"
 *)
procedure setup_graphics(var video:tabloid;
			 xmin,xmax,ymin,ymax:value;
			 x_log,y_log:boolean;
			 title_1,title_2,title_3,x_label,y_label:string127;
			 var p:pararr;
			 var Np:index;
			 var x:valarr;
			 var Nx:index;
			 var y:valarrarr;
			 var ip,ix:index);
begin
  sort2(xmin,xmax);
  sort2(ymin,ymax);
  set_regions(video);
  set_limits(video, xmin, xmax, ymin, ymax);	(* set plotting limits   *)
  set_flags (video, x_log, y_log, false);	(* set display modifiers *)
  set_bounds(video);				(* calculate coordinates *)
  set_static_data(video, title_1, title_2, title_3, x_label, y_label);
  set_dynamic_data(video, p, Np, x, Nx, y);
  set_dynamic_ptrs(video, ip, ix);
end;

procedure check_user_event (var video:tabloid; var finished:boolean;
			    pause:boolean);
var
  cmd : char;
begin
  if keypressed then begin
     cmd := get_kbd_char;
     case cmd of
        'q','Q':
	   finished := true;
	'p','P':
	   if (pause) then begin
	      dsp_message(video,'Pausing --- press a key to resume.');
	      cmd := get_kbd_char;
	   end
	   else
	      dsp_message(video,'Cannot pause: use quit (Q) to abort.');
        else
           act_event(video, cmd);
     end; (* case *)
  end;
end;

procedure bad_data_message (var video:tabloid; bad_data:boolean);
begin
  if (bad_data) then begin
     dsp_message(video,'BAD DATA WAS TAKEN');
     beep;
     beep;
     beep;
  end;
end;

procedure play_graphics (var video:tabloid; var redo:boolean);
var
  cmd : char;
  finished : boolean;
begin
  dsp_message(video,'Measurement done. "q" = quit, "r" = remeasure.');
  repeat
     redo := FALSE;
     finished := FALSE;
     cmd := get_kbd_char;
     case cmd of
       'q','Q':
          begin
	     finished := TRUE;
	  end;
       'r','R':
          begin
	     finished := TRUE;
	     redo := TRUE;
	  end;
       else
          act_event(video, cmd);
     end;
  until finished;
end;

(*
 * DEEP --- deep-depletion C-V measurements using the 4192A
 *          Only one curve can be taken.
 *)

procedure zero_DCV (var pars:par_DCV);
var
  c : char;
begin
  with pars do begin
     clear(dev);
     emit('Disconnect HI and LO leads:');
     c := get_kbd_char;
     put(dev,'ZO');
     emit('Short out HI and LO leads:');
     c := get_kbd_char;
     put(dev,'ZS');
  end;
end;

procedure DCV_steps (var pars:par_DCV);
begin
  with pars do begin
     calc_steps(V_start,V_stop,V_step,0.01,Nx,max_points);
     calc_steps(f_start,f_stop,f_step,0.01,Np,max_params);
  end;
end;

procedure DCV_measure (var pars:par_DCV; var dset:data_rec;
		      log_x,log_y:boolean);
var
  ix, ip : index;
  video : tabloid;
  ptmp, xtmp, ytmp : value;
  redo, finished, bad : boolean;
  code : integer;
  buf : string;
  dt : word;
begin
  DCV_steps(pars);
  dt := round(1000.0 * pars.t_step);
  with dset do begin
     Nx := pars.Nx;
     Np := pars.Np;
     x_label := 'V [V]';
     y_label := 'C [F]';
     p_label := 'log10(f [kHz])';

     xmin := lesser(pars.V_stop, pars.V_start);
     xmax := greater(pars.V_stop, pars.V_start);

     pmin := lesser(pars.f_stop, pars.f_start);
     pmax := greater(pars.f_stop, pars.f_start);
     sort2(ymin,ymax);
     setup_graphics(video, xmin, xmax, ymin, ymax, log_x, log_y,
     			   remarks[0], remarks[1], remarks[2],
			   x_label, y_label,
			   p, Np, x, Nx, y, ip, ix);
  end;

  dsp_frame(video);
  repeat
     dsp_message(video,'Measuring...');
     ptmp := pars.f_start;
     ip := 0;
     finished := FALSE;
     bad := FALSE;
     while (ip < pars.Np) and not finished do begin
	 inc(ip);
	 ix := 0;
	 with pars do begin
	    clear(dev);
	    delay(2000);
	    put(dev, 'ANBNA4B2C3W0F1T2');
	    if average then
	       put(dev, 'V1')
	    else
	       put(dev, 'V0');
	    put(dev, 'FR'+ftoa(pow10(ptmp),8,2)+'EN');
	    put(dev, 'OL'+ftoa(osc_level,8,2)+'EN');
	 end;
	 dset.p[ip] := ptmp;
	 dsp_message(video,dset.p_label+' = '+ftoa(ptmp,10,-1));
	 xtmp := pars.V_start;
	 while not finished and (ix < pars.Nx) do begin
	    inc(ix);
	    put(pars.dev, 'BI'+ftoa(pars.V_accum,8,2)+'EN');
	    delay(round(1000.0*pars.t_hold));
	    put(pars.dev, 'BI'+ftoa(xtmp,8,2)+'EN');
	    delay(dt);
	    put(pars.dev, 'EX');
	    get(pars.dev, buf, -ord(LF));
	    with dset do
	       bad := bad or extract_4192(buf, y[ip][ix], x[ix]);
	    if (bad) then dsp_message(video,'WARNING: bad data point!');
	    dsp_updates(video);
	    check_user_event(video, finished, TRUE);
	    xtmp := xtmp + pars.V_step;
	 end;
	 ptmp := ptmp + pars.f_step;
     end;
     put(pars.dev, 'I0');
     if (ix < pars.Nx) then begin
	ix := pars.Nx;
	ip := ip - 1;
	dsp_message(video,'RUN ABORTED');
	beep;
     end;
     dset.Np := ip;		(* Set to correct value if user aborted *)
     dset.Nx := pars.Nx;
     with dset do begin
	get_date(date);
	time := get_time;
	remarks[2] := p_label+' from '+ftoa(pars.f_start,10,-1)+
		      ' to '+ftoa(pars.f_stop,10,-1)+' by '+
		      ftoa(pars.f_step,10,-1);
     end;
     bad_data_message(video,bad);
     if not autoexit then
	play_graphics(video,redo);
  until not redo;
  undsp_frame(video);
end;

(*
 * GIV --- I-V curves using the Multiprogrammer D/A converter voltage sources
 * Currently, this uses the HP 4140B as an ammeter.
 *)
procedure zero_GIV (var pars:par_giv);
var
  c : char;
begin
  with pars do begin
     clear(meter_hp);
     emit('Disconnect HP4140, press a key when ready:');
     c := get_kbd_char;
     emit('Zeroing instrument...');
     put(meter_hp,'R12');
     delay(1000);
     put(meter_hp,'Z');
     emit('done.');
  end;
end;

(*
 * calculate & rationalize step sizes, limits, and numbers of points for
 * this kind of measurement.
 *)
procedure GIV_steps (var pars:par_giv);
var
  nsteps : integer;
begin
  with pars do begin
     if (bidirect) then begin
        calc_steps(Vx_start,Vx_stop,Vx_step,0.005,nsteps,max_points div 2);
	Nx := 2 * nsteps;
     end
     else begin
     	calc_steps(Vx_start,Vx_stop,Vx_step,0.005,Nx,max_points);
     end;
     calc_steps(Vp_start,Vp_stop,Vp_step,0.005,Np,max_params);
  end;
end;

(*
 * Perform the measurement!
 *)
procedure GIV_measure (var pars:par_giv; var dset:data_rec;
		       log_x,log_y:boolean);
var
  ix, ip : index;
  video : tabloid;
  ptmp, xtmp, ytmp, dummy: value;
  redo, finished, bad : boolean;
  code : integer;
  buf : string;
  dt : word;
begin
  GIV_steps(pars);
  dt := round(1000.0 * pars.t_step);
  with dset do begin
     Nx := pars.Nx;
     Np := pars.Np;
     x_label := 'V'+MP_NODES[pars.node.x]+' [V]';
     y_label := 'I [A]';
     p_label := 'V'+MP_NODES[pars.node.p]+' [V]';
     xmin := lesser(pars.Vx_stop, pars.Vx_start);
     xmax := greater(pars.Vx_stop, pars.Vx_start);

     pmin := lesser(pars.Vp_stop, pars.Vp_start);
     pmax := greater(pars.Vp_stop, pars.Vp_start);

     sort2(ymin,ymax);
     setup_graphics(video, xmin, xmax, ymin, ymax, log_x, log_y,
     			   remarks[0], remarks[1], remarks[2],
			   x_label, y_label,
			   p, Np, x, Nx, y, ip, ix);
  end; (* with dset *)

  dsp_frame(video);
  repeat
     dsp_message(video,'Measuring...');
     ptmp := pars.Vp_start;
     ip := 0;
     finished := FALSE;
     bad := FALSE;
     while (ip < pars.Np) and not finished do begin
	 with pars do begin
	    inc(ip);
	    clear(meter_hp);	
	    put(meter_hp,'F1RA1I3T2A6B2');
	    multprog.send(node.ref,0.0);
	    multprog.send(node.bias,V_bias);
	    multprog.send(node.x,Vx_start);
	    multprog.send(node.p,ptmp);
	    dsp_message(video,dset.p_label+' = '+ftoa(ptmp,10,-1));
	    delay(round(1000.0 * t_hold));
	 end;
	 dset.p[ip] := ptmp;
	 xtmp := pars.Vx_start;
	 ix := 0;
	 if (pars.bidirect) then begin
	    while not finished and (ix < (pars.Nx div 2)) do begin
	       inc(ix);
	       multprog.send(pars.node.x,xtmp);
	       delay(dt);
	       trigger(pars.meter_hp);
	       get(pars.meter_hp,buf,-ord(LF));
	       with dset do begin
		  bad := bad or extract_4140(buf, y[ip][ix], dummy);
		  x[ix] := xtmp;
	       end;
	       if (bad) then dsp_message(video,'WARNING: bad data point');
	       dsp_updates(video);
	       check_user_event(video,finished,TRUE);
	       xtmp := xtmp + pars.Vx_step;
	    end;
	    while not finished and (ix < pars.Nx) do begin
	       inc(ix);
	       multprog.send(pars.node.x,xtmp);
	       delay(dt);
	       trigger(pars.meter_hp);
	       get(pars.meter_hp,buf,-ord(LF));
	       with dset do begin 
	          bad := bad or extract_4140(buf, y[ip][ix], dummy);
		  x[ix] := xtmp;
	       end;
	       if (bad) then dsp_message(video,'WARNING: bad data point!');
	       dsp_updates(video);
	       check_user_event(video,finished,TRUE);
	       xtmp := xtmp - pars.Vx_step;
	    end;
	 end
	 else begin
	    while not finished and (ix < dset.Nx) do begin
	       inc(ix);
	       multprog.send(pars.node.x,xtmp);
	       delay(dt);
	       trigger(pars.meter_hp);
	       get(pars.meter_hp,buf,-ord(LF));
	       with dset do begin
		  bad := bad or extract_4140(buf, y[ip][ix], dummy);
		  x[ix] := xtmp;
	       end;
	       if (bad) then dsp_message(video,'WARNING: bad data point!');
	       dsp_updates(video);
	       check_user_event(video,finished,TRUE);
	       xtmp := xtmp + pars.Vx_step;
	    end;
	 end;
	 ptmp := ptmp + pars.Vp_step;
     end;
     multprog.send(pars.node.x,0.0);
     multprog.send(pars.node.p,0.0);
     multprog.send(pars.node.ref,0.0);
     multprog.send(pars.node.bias,0.0);
     if (ix < pars.Nx) then begin
	ix := pars.Nx;
	ip := ip - 1;
	dsp_message(video,'RUN ABORTED');
	beep;
     end;
     dset.Np := ip;		(* Set to correct value if user aborted *)
     dset.Nx := pars.Nx;
     with dset do begin
	get_date(date);
	time := get_time;
	remarks[2] := p_label+' from '+ftoa(pars.Vp_start,10,-1)+
		      ' to '+ftoa(pars.Vp_stop,10,-1)+' by '+
		      ftoa(pars.Vp_step,10,-1);
     end;
     bad_data_message(video,bad);
     if not autoexit then
	play_graphics(video,redo);
  until not redo;
  undsp_frame(video);
end;

(*
 * IV --- I-V curves using the voltage sources on the HP4140B, and the
 * pico-ammeter on the HP4140B
 *)
procedure zero_IV (var pars:par_4140);
var
  c : char;
begin
  with pars do begin
     clear(dev);
     emit('Disconnect HP4140, press a key when ready:');
     c := get_kbd_char;
     emit('Zeroing instrument...');
     put(dev,'R12');
     delay(1000);
     put(dev,'Z');
     emit('done.');
  end;
end;

procedure IV_steps(var pars:par_4140);
var
  nsteps : integer;
  quantum : single;
begin
  with pars do begin
     if (abs(Va_start) < 10.0) and (abs(Va_stop) < 10.0) then
        quantum := 0.01
     else
        quantum := 0.1;
     if (bidirect) then begin
        calc_steps(Va_start,Va_stop,Va_step,quantum,nsteps,max_points div 2);
	if (abs(Va_stop - Va_start) > abs(Va_step) * (nsteps - 1)) then
	   nsteps := nsteps + 1;
	Nx := 2 * nsteps;
     end
     else begin
	calc_steps(Va_start,Va_stop,Va_step,quantum,Nx,max_points);
	if (abs(Va_stop - Va_start) > abs(Va_step) * (Nx - 1)) then
	   Nx := Nx + 1;
     end;
     if (abs(Vb_start) < 10.0) and (abs(Vb_stop) < 10.0) then
        quantum := 0.01
     else
        quantum := 0.1;
     calc_steps(Vb_start, Vb_stop, Vb_step, quantum, Np, max_params);
  end;
end;

procedure IV_measure (var pars:par_4140; var dset:data_rec;
		      log_x,log_y:boolean);
var
  ix, ip : index;
  video : tabloid;
  ptmp, xtmp, ytmp : value;
  redo, finished, bad : boolean;
  code : integer;
  buf : string;
  dt : word;
begin
  IV_steps(pars);
  dt := round(1000.0 * pars.t_step);
  with dset do begin
     Nx := pars.Nx;
     Np := pars.Np;
     x_label := 'Va [V]';
     y_label := 'I [A]';
     p_label := 'Vb [V]';
     xmin := lesser(pars.Va_stop, pars.Va_start);
     xmax := greater(pars.Va_stop, pars.Va_start);

     pmin := lesser(pars.Vb_stop, pars.Vb_start);
     pmax := greater(pars.Vb_stop, pars.Vb_start);

     sort2(ymin,ymax);
     setup_graphics(video, xmin, xmax, ymin, ymax, log_x, log_y,
     			   remarks[0], remarks[1], remarks[2],
			   x_label, y_label,
			   p, Np, x, Nx, y, ip, ix);
  end; (* with dset *)

  dsp_frame(video);
  repeat
     dsp_message(video,'Measuring...');
     ptmp := pars.Vb_start;
     ip := 0;
     finished := FALSE;
     bad := FALSE;
     while (ip < pars.Np) and not finished do begin
	 with pars do begin
	    inc(ip);
	    clear(dev);
	    delay(2000);
	    put(dev, 'F2I3RA1');
	    if (bidirect) then
	       put(dev,'A4')
	    else
	       put(dev,'A3');
	    put(dev, 'B1L3M3');
	    put(dev, 'PS'+ftoa(Va_start,8,2)+';');
	    put(dev, 'PT'+ftoa(Va_stop,8,2)+';');
	    put(dev, 'PE'+ftoa(Va_step,8,2)+';');
	    put(dev, 'PH'+ftoa(t_hold,8,2)+';');
	    put(dev, 'PD'+ftoa(t_step,8,2)+';');
	    put(dev, 'PB'+ftoa(ptmp,8,2)+';');
	 end;
	 dset.p[ip] := ptmp;
	 dsp_message(video,dset.p_label+' = '+ftoa(ptmp,10,-1));
	 put(pars.dev, 'W1');			(* start sweep *)
	 xtmp := pars.Va_start;
	 ix := 0;
	 while not finished and (ix < pars.Nx) do begin
	    inc(ix);
	    get(pars.dev, buf, -ord(LF));
	    with dset do
	       bad := bad or extract_4140(buf, y[ip][ix], x[ix]);
	    if (bad) then dsp_message(video,'WARNING: bad data point!');
	    dsp_updates(video);
	    check_user_event(video,finished,FALSE);
	    xtmp := xtmp + pars.Va_step;
	 end;
	 ptmp := ptmp + pars.Vb_step;
     end;
     if (ix < pars.Nx) then begin
	ix := pars.Nx;
	ip := ip - 1;
	dsp_message(video,'RUN ABORTED');
	beep;
     end;
     put(pars.dev, 'W7');
     dset.Np := ip;		(* Set to correct value if user aborted *)
     dset.Nx := pars.Nx;
     with dset do begin
	get_date(date);
	time := get_time;
	remarks[2] := p_label+' from '+ftoa(pars.Vb_start,10,-1)+
		      ' to '+ftoa(pars.Vb_stop,10,-1)+' by '+
		      ftoa(pars.Vb_step,10,-1);
     end;
     bad_data_message(video,bad);
     if not autoexit then
	play_graphics(video,redo);
  until not redo;
  undsp_frame(video);
end;

(*
 * QCV --- perform quasi-static C-V measurements on the HP4140B
 *)
procedure zero_QCV (var pars:par_qcv; var dset:data_rec);
var
  buf : string;
  c : char;
begin
  with pars do begin
     if (odd(dset.Nx)) then dset.Nx := dset.Nx + 1;
     Va_step  := abs(Va_stop - Va_start) / ((dset.Nx div 2) + 1);
     Va_step := 0.01 * round(Va_step * 100.0);
     Va_stop := Va_start + ((dset.Nx div 2) + 1) * Va_step;
     if (dset.Np < 2) then dset.Np := 2;
     r_step := abs(r_stop - r_start) / (dset.Np - 1);
     clear(dev);
     delay(2000);
     put(dev, 'F3I3RA1A2B2L3M1');
     put(dev, 'PS'+ftoa(Va_start,8,2)+';');
     put(dev, 'PT'+ftoa(Va_stop, 8,2)+';');
     put(dev, 'PE'+ftoa(Va_step, 8,2)+';');
     put(dev, 'PH'+ftoa(t_hold,  8,2)+';');
     put(dev, 'PV'+ftoa(r_start, 8,2)+';');
     put(dev, 'W1');
     get(dev, buf, -ord(LF));
     put(dev, 'Z');
     get(dev, buf, -ord(LF));
     put(dev, 'W7');
  end;
end;

procedure QCV_steps(var pars:par_qcv);
var
  nsteps : integer;
  quantum : single;
begin
  with pars do begin
     sort2(Va_start,Va_stop);
     if (abs(Va_start) < 10.0) and (abs(Va_stop) < 10.0) then
        quantum := 0.01
     else
        quantum := 0.1;
     calc_steps(Va_start,Va_stop,Va_step,quantum,nsteps,(max_points div 2)+1);
     if (abs(abs(Va_step * (nsteps-1)) - abs(Va_stop - Va_start)) < 0.01) then
        nsteps := nsteps - 1;
     Nx := 2 * (nsteps - 1);
     if (abs(r_start) < 10.0) and (abs(r_stop) < 10.0) then
        quantum := 0.01
     else
        quantum := 0.1;
     calc_steps(r_start,r_stop,r_step,quantum,Np,max_params);
  end;
end;

procedure QCV_measure (var pars:par_qcv; var dset:data_rec;
		       log_x,log_y:boolean);
var
  ix, ip : index;
  video : tabloid;
  ptmp, xtmp, ytmp : value;
  redo, finished, bad : boolean;
  code : integer;
  buf : string;
begin
  QCV_steps(pars);
  with dset do begin
     Nx := pars.Nx;
     Np := pars.Np;
     x_label := 'Va [V]';
     y_label := 'C [F]';
     p_label := 'dVa/dt [V/s]';
     xmin := lesser(pars.Va_stop, pars.Va_start);
     xmax := greater(pars.Va_stop, pars.Va_start);

     pmin := lesser(pars.r_stop, pars.r_start);
     pmax := greater(pars.r_stop, pars.r_start);
     sort2(ymin,ymax);
     setup_graphics(video, xmin, xmax, ymin, ymax, log_x, log_y,
     			   remarks[0], remarks[1], remarks[2],
			   x_label, y_label,
			   p, Np, x, Nx, y, ip, ix);
  end;

  dsp_frame(video);
  repeat
     dsp_message(video,'Measuring...');
     ptmp := pars.r_start;
     ip := 0;
     finished := FALSE;
     bad := FALSE;
     while (ip < pars.Np) and not finished do begin
	 with pars do begin
	    inc(ip);
	    ix := 0;
	    clear(dev);
	    delay(2000);
	    put(dev, 'F3I3RA1A2B2L3M1');
	    put(dev, 'PS'+ftoa(Va_start,8,2)+';');
	    put(dev, 'PT'+ftoa(Va_stop, 8,2)+';');
	    put(dev, 'PE'+ftoa(Va_step, 8,2)+';');
	    put(dev, 'PH'+ftoa(t_hold,  8,2)+';');
	 end;
	 put(pars.dev, 'PV'+ftoa(ptmp,8,2)+';');
	 dset.p[ip] := ptmp;
	 dsp_message(video,dset.p_label+' = '+ftoa(ptmp,10,-1));
	 put(pars.dev, 'W1');
	 while not finished and (ix < pars.Nx) do begin
	    inc(ix);
	    get(pars.dev, buf, -ord(LF));
	    with dset do 
	       bad := bad or extract_4140(buf, y[ip][ix], x[ix]);
	    if (bad) then dsp_message(video,'WARNING: bad data point!');
	    dsp_updates(video);
	    check_user_event(video, finished, FALSE);
	 end;
	 ptmp := ptmp + pars.r_step;
     end;
     put(pars.dev, 'W7');
     if (ix < pars.Nx) then begin
	ix := pars.Nx;
	ip := ip - 1;
	dsp_message(video,'RUN ABORTED');
	beep;
     end;
     dset.Np := ip;		(* Set to correct value if user aborted *)
     dset.Nx := pars.Nx;
     with dset do begin
	get_date(date);
	time := get_time;
	remarks[2] := p_label+' from '+ftoa(pars.r_start,10,-1)+
		      ' to '+ftoa(pars.r_stop,10,-1)+' by '+
		      ftoa(pars.r_step,10,-1);
     end;
     bad_data_message(video,bad);
     if not autoexit then
	play_graphics(video,redo);
  until not redo;
  undsp_frame(video);
end;

(*
 * CV --- AC (1 kHz or higher) C-V measurements on the HP 4192A
 *)
procedure zero_CV (var pars:par_4192);
var
  c : char;
begin
  with pars do begin
     clear(dev);
     emit('Disconnect HI and LO leads:');
     c := get_kbd_char;
     put(dev,'ZO');
     emit('Short out HI and LO leads:');
     c := get_kbd_char;
     put(dev,'ZS');
  end;
end;

procedure CV_steps (var pars:par_4192);
begin
  with pars do begin
     calc_steps(V_start,V_stop,V_step,0.01,Nx,max_points);
     calc_steps(f_start,f_stop,f_step,0.01,Np,max_params);
  end;
end;

procedure CV_measure (var pars:par_4192; var dset:data_rec;
		      log_x,log_y:boolean);
var
  ix, ip : index;
  video : tabloid;
  ptmp, xtmp, ytmp : value;
  redo, finished, bad : boolean;
  code : integer;
  buf : string;
  dt : word;
begin
  CV_steps(pars);
  dt := round(1000.0 * pars.t_step);
  with dset do begin
     Nx := pars.Nx;
     Np := pars.Np;
     x_label := 'V [V]';
     y_label := 'C [F]';
     p_label := 'log10(f [kHz])';

     xmin := lesser(pars.V_stop, pars.V_start);
     xmax := greater(pars.V_stop, pars.V_start);

     pmin := lesser(pars.f_stop, pars.f_start);
     pmax := greater(pars.f_stop, pars.f_start);
     sort2(ymin,ymax);
     setup_graphics(video, xmin, xmax, ymin, ymax, log_x, log_y,
     			   remarks[0], remarks[1], remarks[2],
			   x_label, y_label,
			   p, Np, x, Nx, y, ip, ix);
  end;

  dsp_frame(video);
  repeat
     dsp_message(video,'Measuring...');
     ptmp := pars.f_start;
     ip := 0;
     finished := FALSE;
     bad := FALSE;
     while (ip < pars.Np) and not finished do begin
	 inc(ip);
	 ix := 0;
	 with pars do begin
	    clear(dev);
	    delay(2000);
	    put(dev, 'ANBNA4B2C3W1F1T3');
	    if average then
	       put(dev, 'V1')
	    else
	       put(dev, 'V0');
	    put(dev, 'FR'+ftoa(pow10(ptmp),8,2)+'EN');
	    put(dev, 'OL'+ftoa(osc_level,8,2)+'EN');
	    put(dev, 'TB'+ftoa(lesser(V_start,V_stop),8,2)+'EN');
	    put(dev, 'PB'+ftoa(greater(V_start,V_stop),8,2)+'EN');
	    put(dev, 'SB'+ftoa(abs(V_step), 8,2)+'EN');
	 end;
	 dset.p[ip] := ptmp;
	 dsp_message(video,dset.p_label+' = '+ftoa(ptmp,10,-1));
	 if (pars.V_start > pars.V_stop) then
	    put(pars.dev, 'W4')
         else
	    put(pars.dev, 'W2');
	 delay(round(1000.0*pars.t_hold));
	 while not finished and (ix < pars.Nx) do begin
	    inc(ix);
	    put(pars.dev, 'EX');
	    get(pars.dev, buf, -ord(LF));
	    with dset do
	       bad := bad or extract_4192(buf, y[ip][ix], x[ix]);
	    if (bad) then dsp_message(video,'WARNING: bad data point!');
	    dsp_updates(video);
	    check_user_event(video, finished, TRUE);
	    delay(dt);
	 end;
	 ptmp := ptmp + pars.f_step;
     end;
     put(pars.dev, 'W3I0');
     if (ix < pars.Nx) then begin
	ix := pars.Nx;
	ip := ip - 1;
	dsp_message(video,'RUN ABORTED');
	beep;
     end;
     dset.Np := ip;		(* Set to correct value if user aborted *)
     dset.Nx := pars.Nx;
     with dset do begin
	get_date(date);
	time := get_time;
	remarks[2] := p_label+' from '+ftoa(pars.f_start,10,-1)+
		      ' to '+ftoa(pars.f_stop,10,-1)+' by '+
		      ftoa(pars.f_step,10,-1);
     end;
     bad_data_message(video,bad);
     if not autoexit then
	play_graphics(video,redo);
  until not redo;
  undsp_frame(video);
end;

(*
 * GRAPHICS DISPLAY ROUTINES
 * pen_plot	displays on the HP 7470A plotter (connected to COM1)
 * crt_plot	displays on the monitor screen
 *)
procedure pen_plot (var dset:data_rec; x_log,y_log:boolean);
var
  image : paper;
begin
  if (dset.ymax <> dset.ymin) and (dset.xmax <> dset.xmin) then begin
     with dset do begin
	sort2(xmin,xmax);
	sort2(ymin,ymax);
	pp_set_regions(image);
	pp_set_limits(image, xmin, xmax, ymin, ymax);
	pp_set_flags(image, x_log, y_log, false);
	pp_set_bounds(image);
	pp_set_data(image, remarks[0], remarks[1], remarks[2],
		           x_label, y_label, p, Np, x, Nx, y);
     end;
     pp_dsp_frame(image);
     pp_dsp_curves(image);
     pp_undsp_frame(image);
  end
  else begin
     barf('cannot pen plot data', 'zero range');
     beep;
  end;
end;

procedure crt_plot (var dset:data_rec; x_log,y_log:boolean);
var
  video : tabloid;
  cmd : char;
  finished : boolean;
begin
  if (dset.ymax <> dset.ymin) and (dset.xmax <> dset.xmin) then begin
     with dset do begin
	setup_graphics(video, xmin, xmax, ymin, ymax, x_log, y_log,
			      remarks[0], remarks[1], remarks[2],
			      x_label, y_label,
			      p, Np, x, Nx, y, Np, Nx);
     end;
     dsp_frame(video);
     dsp_curves(video);
     if not autoexit then
        repeat
   	   finished := false;
   	   cmd := get_kbd_char;
	   if (cmd in ['q','Q']) then
	      finished := true
	   else
	      act_event(video, cmd);
        until finished;
     undsp_frame(video);
  end
  else begin
     barf('cannot plot data', 'zero range');
     beep;
  end;
end;

(****************************************************************************
 * GLOBAL STATE VARIABLES AND MANIPULATORS
 *)

var
  today : date_rec;
  save_path : string[63];
  data_saved : boolean;
  data_ranged : boolean;
  dset : data_rec;
  giv   : par_giv;
  qcv   : par_qcv;
  pa_vs : par_4140;
  lf_ia : par_4192;
  dcv   : par_DCV;

procedure show_environment;
var
  current_wdir : string[31];
  total_time : double;
  today : date_rec;
  now : time_t;
  i : integer;
begin
  getdir(0, current_wdir);
  get_date(today);
  now := get_time;

  writeln('Code version ',CODE_VERSION,'; Data format version ',DATA_VERSION);
  writeln('date/time = ',date_str(today,true),' at ',time_str(now,true));
  writeln('directory = "',current_wdir,'"; file = "',save_path,'"');
  screen_bar;
  show_data_set(dset);
end;

procedure init_environment;
var
  i, code : integer;
  ix, ip : index;
  do_init : boolean;
begin
  (*
   * Process command-line arguments
   *)
  do_init := true;
  for i := 1 to ParamCount do begin
     if ((ParamStr(i) = '-no_startup') or (ParamStr(i) = '-n')) then
     	do_init := false
     else begin				(* Print usage message, and die. *)
        writeln('usage: mos [options]');
	writeln('where [options] are:');
	writeln('        -no_startup, -n        don''t execute ',INITFILE);
	halt;
     end;
  end;
  (*
   * Switch input to init file.  Note: the commands in the init file are
   * NOT executed now, but are simply processed as user commands.  This
   * section only switches the input stream from the keyboard to the file.
   *)
  autoexit := FALSE;
  if (do_init and exists_file(INITFILE)) then begin
     macro_file(INITFILE, code);
     if (code <> 0) then begin
        barf(INITFILE, runtime.lookup(code));
	halt;
     end;
  end;
  (*
   * Lengthy section to set internal variable values to initial values.
   *)
  data_saved := TRUE;
  data_ranged := FALSE;
  save_path := 'data.dat';
  with dset do begin
     codever := CODE_VERSION;
     dataver := DATA_VERSION;
     get_date(date);
     time := get_time;
     x_label := 'X array';
     y_label := 'Y table';
     p_label := 'P array';
     remarks[0] := '';
     remarks[1] := '';
     remarks[2] := '';
     Nx := max_points;
     Np := max_params;
     for ix := 1 to max_points do
        x[ix] := 0.0;
     for ip := 1 to max_params do begin
        for ix := 1 to max_points do
	   y[ip][ix] := 0.0;	
	p[ip] := 0.0;
     end;
  end;
  find_limits(dset);
  with qcv do begin
     find(dev, 'HP4140B');
     t_hold   := 5.0;
     Va_start := -3.25;
     Va_stop  := 3.25;
     Va_step  := 0.1;
     r_start  := 0.01;
     r_stop   := 0.5;
     r_step   := 0.05;
     bidirect := TRUE;
  end;
  with giv do begin
     find(prog,'HP6940B');
     find(meter_a,'K619CHA');
     find(meter_b,'K619CHB');
     find(meter_hp,'HP4140B');
     t_hold := 1.0;
     t_step := 0.1;
     Vx_start := 0.0;
     Vx_stop  := 3.1;
     Vx_step  := 0.1;
     Vp_start := -1.4;
     Vp_stop  := 1.6;
     Vp_step  := 0.2;
     V_bias   := 0.0;
     bidirect := FALSE;
     node.ref  := SOURCE;
     node.x    := DRAIN;
     node.p    := GATE;
     node.bias := BULK;
     Nx := max_points;
     Np := max_params;
  end;
  with pa_vs do begin
     find(dev, 'HP4140B');
     t_hold   := 5.0;
     t_step   := 0.5;
     Va_start := 0.0;
     Va_stop  := 3.1;
     Va_step  := 0.1;
     Va_rate  := 0.1;
     Vb_start := -1.4;
     Vb_stop  := 1.6;
     Vb_step  := 0.2;
     bidirect := FALSE;
     Nx := max_points;
     Np := max_params;
  end;
  with lf_ia do begin
     find(dev, 'HP4192A');
     osc_level := 0.05;
     t_hold := 1.0;
     t_step := 0.5;
     V_start := -3.25;
     V_stop  :=  3.25;
     V_step  :=  0.1;
     f_start :=  0.0;
     f_stop  :=  3.0;
     f_step  :=  0.2;
     average := TRUE;
     bidirect := TRUE;
     Nx := max_points;
     Np := max_params;
  end;
  with dcv do begin
     find(dev, 'HP4192A');
     osc_level := 0.05;
     V_accum := 0.0;
     t_hold := 1.0;
     t_step := 0.5;
     V_start := -3.25;
     V_stop  :=  3.25;
     V_step  :=  0.1;
     f_start :=  0.0;
     f_stop  :=  3.0;
     f_step  :=  0.2;
     average := TRUE;
     Nx := max_points;
     Np := max_params;
  end;
end;

(****************************************************************************
 * DISPATCH PROCEDURES FROM COMMAND-LINES
 *)

procedure list_directory (var argc:integer; var argv:arglist);
var
  i:integer;
  c:char;
begin
  banner('Directory Listing');
  if (argc = 1) then
     list_cwd ('*.*')
  else
     for i := 2 to argc do
        list_cwd (argv[i]);
  emit('Press a key when done:  '); 
  c := get_kbd_char;
  emit('');
end;

procedure read_file (var argc:integer; var argv:arglist);
var
  binary : boolean;
  i, code : integer;
begin
  binary := false;
  i := 2;
  while (i <= argc) do begin
     if (argv[i] = '-binary') or (argv[i] = '-b') then begin
        binary := true;
     end
     else if (argv[i] = '-text') or (argv[i] = '-t') then begin
        binary := false;
     end
     else if (argv[i] = '-file') or (argv[i] = '-f') then begin
        inc(i);
	if (i > argc) then
	   barf('missing argument','no filename')
	else
	   save_path := argv[i];
     end
     else if (argv[i][1] = '-') then
         barf('bad option',argv[i])
     else
         save_path := argv[i];
     inc(i);
  end;
  if (save_path <> '') then begin
     emit('Reading "'+save_path+'" ... ');
     if (binary) then
        read_binary(dset, save_path, code)
     else
        read_text(dset, save_path, code);
     if (code = 0) then begin
        emit('done.');
	data_saved := true;
	if (dset.dataver <> DATA_VERSION) then begin
	   barf('data version mismatch',dset.dataver);
	   beep;
	end;
     end
     else
        barf(save_path, runtime.lookup(code));
  end
  else
     barf('cannot read file','no filename!');
end;

procedure save_file (var argc:integer; var argv:arglist);
var
  i : integer;
  proceed, ascii, update, lx, ly : boolean;
  mode : byte;
  code : integer;
begin
  code := 0;
  mode := LINEAR;
  ascii := FALSE;
  update := TRUE;
  emit('Ranging data ...');
  find_limits(dset);
  emit('Ranging data ... done.');
  parse_bounds_opts(dset, lx, ly, argc, argv);
  if (lx and ly) then
     mode := LOGLOG
  else if (ly and not lx) then
     mode := SEMILOG
  else
     mode := LINEAR;
  i := 2;
  while (i <= argc) do begin
     if (argv[i] = '-ascii') or (argv[i] = '-a') then
        ascii := TRUE
     else if (argv[i] = '-binary') or (argv[i] = '-b') then
        ascii := FALSE
     else if (argv[i] = '-no_update') or (argv[i] = '-nu') then begin
        update := FALSE;
     end
     else if (argv[i] = '-file') or (argv[i] = '-f') then begin
        inc(i);
	if (i <= argc) then save_path := argv[i] else save_path := '';
     end
     else if (argv[i] = '') then
        (* null, because parse_bounds_opts does this to stuff it has seen *)
     else
        save_path := argv[i];
     inc(i);
  end;

  if (save_path = '') then
     barf('cannot save data','no filename!')
  else begin
     emit('Saving "'+save_path+'" ... ');
     proceed := not exists_file(save_path);
     if not proceed then
        proceed := user_confirm('File exists.  Overwrite (no)?',FALSE);
     if proceed then begin
        if (update) then begin
	   dset.codever := CODE_VERSION;
	   dset.dataver := DATA_VERSION;
	end;
	if (ascii) then begin
	   sort2(dset.ymin,dset.ymax);
	   sort2(dset.xmin,dset.xmax);
	   save_giraphe(dset, mode, save_path, code);
	end
	else
	   save_text(dset, save_path, code);

	if (code = 0) then begin
	   emit('done.');
	   data_saved := TRUE;
	end
	else
	   barf(save_path, runtime.lookup(code));
     end
     else
        emit('Saving operation aborted.');
  end;
end;

procedure save_simple (var dset:data_rec; path:string);
var
  proceed : boolean;
  code : integer;
begin
  if (save_path = '') then begin
     barf('cannot save','no filename!');
  end
  else begin
     emit('Saving "'+save_path+'" ... ');
     proceed := not exists_file(save_path);
     if not proceed then
        proceed := user_confirm('File exists.  Overwrite (no)?',FALSE);
     if proceed then begin
	dset.codever := CODE_VERSION;
	dset.dataver := DATA_VERSION;
	save_text(dset, save_path, code);

	if (code = 0) then begin
	   emit('done.');
	   data_saved := true;
	end
	else
	   barf(save_path, runtime.lookup(code));
     end
     else
        emit('Saving operation aborted.');
  end;
end;

procedure dispatch_plot (var argc:integer; var argv:arglist);
var
  c : char;
  i, code : integer;
  log_x, log_y, hardcopy : boolean;
begin
  hardcopy := FALSE;
  log_x := FALSE;
  log_y := FALSE;
  emit('Ranging data ... ');
  find_limits(dset);
  emit('done.');
  parse_bounds_opts(dset, log_x, log_y, argc, argv);
  i := 2;
  while (i <= argc) do begin
     if (argv[i] = '-hardcopy') or (argv[i] = '-h') then begin
        hardcopy := TRUE;
     end;
     inc(i);
  end;
  with dset do begin
     sort2(xmin,xmax);
     sort2(ymin,ymax);
  end;
  if hardcopy then begin
     emit('Set up plotter.   Press a key when ready:  ');
     c := ReadKey;
     pen_plot(dset, log_x, log_y)
  end
  else
     crt_plot(dset, log_x, log_y);
end;

function get_value (var argc:integer; var argv:arglist) : single;
var
  code :integer;
begin
   if (argc = 2) then
      get_value := atof(argv[2],code)
   else
      get_value := atof(user_input_line('Value:'),code);
end;

function get_string (start:byte; var argc:integer; var argv:arglist) : string;
var
  i : integer;
  buf : string;
begin
  buf := '';
  for i := start to argc do
     buf := buf + argv[i] + SPC;
  if (argc < start) then
     buf := buf + user_input_line('Text:');
  get_string := buf;
end;

(****************************************************************************
 * SUBSIDIARY COMMAND LOOPS
 *)
procedure IV_loop (var pars:par_4140; var dset:data_rec);

procedure show_environment (var pars:par_4140; var dset:data_rec);
begin
  IV_steps(pars);
  with pars do begin
     writeln('VA: start = ',Va_start:7:2,'; stop = ',Va_stop:7:2,
     	     '; step = ',Va_step:6:2,' (',Nx:3,' pts); tstep = ',t_step:6:3);
     writeln('VB: start = ',Vb_start:7:2,'; stop = ',Vb_stop:7:2,
     	     '; step = ',Vb_step:6:2,' (',Np:3,' pts); thold = ',t_hold:6:3);
     writeln('Sweep +,- = ',bidirect);
  end;
  screen_bar;
  show_data_set(dset);
end;

var
   argv : arglist;
   argc : integer;
   code : integer;
   quit : boolean;
   cmd  : cmd_enum;
   buf  : string;
   log_x, log_y : boolean;
begin
  log_x := FALSE;
  log_y := FALSE;
  dset.ymax := 1.0e-2;			(*  10 mA *)
  dset.ymin := 1.0e-15;			(*   1 fA *)
  reset_parser;
  repeat
     quit := false;
     list_menu(IV_menu);
     screen_bar;
     show_environment(pars, dset);
     cmd := get_cmdline(IV_menu, argc, argv, autoexit);
     case cmd of
       CMD_NOOP:
          begin
	  end;
       CMD_UNKNOWN:
          begin
	     barf('unknown command', argv[1]);
	  end;
       CMD_QUIT:
          begin
	     quit := TRUE;
	  end;
       CMD_HELP:
          begin
	     list_requests(IV_menu, argc, argv);
	  end;
       CMD_SAVE:
          begin
	     save_file(argc, argv);
	  end;
       CMD_PLOT:
          if check_safety(data_saved) then begin
	     dispatch_plot(argc, argv);
	  end;
       CMD_DO:
          if check_safety(data_saved) then begin
	     parse_bounds_opts(dset,log_x,log_y, argc, argv);
	     IV_measure(pars,dset,log_x,log_y);
	     data_saved := FALSE;
	     if user_confirm('Save data (yes)?',TRUE) then begin
	        buf := user_input_line('File (RET for '+save_path+'):');
		if (buf <> '') then save_path := buf;
	        save_simple(dset,save_path);
	     end;
	  end;
       CMD_YMAX:
	  begin
	     dset.ymax := get_value(argc, argv);
	  end;
       CMD_YMIN:
	  begin
	     dset.ymin := get_value(argc, argv);
	  end;
       CMD_NX:
          begin
	     pars.Va_step := get_value(argc,argv);
	  end;
       CMD_NP:
          begin
	     pars.Vb_step := get_value(argc,argv);
	  end;
       CMD_THOLD:
          begin
	     pars.t_hold := abs(get_value(argc, argv));
	  end;
       CMD_TSTEP:
          begin
	     pars.t_step := abs(get_value(argc,argv));
	  end;
       CMD_X1:
          begin
	     pars.Va_start := get_value(argc, argv);
	  end;
       CMD_X2:
          begin
	     pars.Va_stop := get_value(argc, argv);
	  end;
       CMD_P1:
          begin
	     pars.Vb_start := get_value(argc, argv);
	  end;
       CMD_P2:
          begin
	     pars.Vb_stop := get_value(argc, argv);
	  end;
       CMD_XLABEL:
          begin
	     dset.x_label := get_string(2,argc,argv);
	  end;
       CMD_YLABEL:
          begin
	     dset.y_label := get_string(2, argc, argv);
	  end;
       CMD_PLABEL:
          begin
	     dset.p_label := get_string(2, argc, argv);
	  end;
       CMD_COMMENT:
          begin
	     dset.remarks[abs(atoi(argv[2],code)) mod 3] :=
	        get_string(3,argc,argv);
 	  end;
       CMD_ZERO:
          begin
	     zero_IV(pars);
	  end;
       CMD_SWEEP:
          begin
	     if (argc = 1) then
	        pars.bidirect := not pars.bidirect
	     else if (argv[2] = '2') then
	        pars.bidirect := TRUE
	     else if (argv[2] = '1') then
	        pars.bidirect := FALSE
	     else
	        barf('bad choice','specify 1 (single) or 2 (bidirectional)');
	  end;
       CMD_SRC:
          begin
	     if (argc < 2) then
	        macro_file('',code)
	     else
	        macro_file(argv[2],code);
	  end;
       else
          begin
	     barf('not implemented',argv[1]);
	  end;
     end; (* case *)
  until quit;
end; (* IV loop *)

procedure GIV_loop (var pars:par_GIV; var dset:data_rec);

procedure show_environment (var pars:par_GIV; var dset:data_rec);
begin
  GIV_steps(pars);
  with pars do begin
     writeln('X: start = ',Vx_start:7:3,'; stop = ',Vx_stop:7:3,
     	     '; step = ',Vx_step:7:3,' (',Nx:3,' pts); tstep = ',t_step:6:3);
     writeln('P: start = ',Vp_start:7:3,'; stop = ',Vp_stop:7:3,
     	     '; step = ',Vp_step:7:3,' (',Np:3,' pts); thold = ',t_hold:6:3);
     write  ('Bias = ',V_bias:7:3,'; ');
     writeln('Sweep +,- = ',bidirect);
     write  ('X is ',MP_NODES[pars.node.x],'; ');
     write  ('P is ',MP_NODES[pars.node.p],'; ');
     write  ('REF is ',MP_NODES[pars.node.ref],'; ');
     writeln('BIAS is ',MP_NODES[pars.node.bias]);
  end;
  screen_bar;
  show_data_set(dset);
end;

var
   argv : arglist;
   argc : integer;
   code : integer;
   quit : boolean;
   cmd  : cmd_enum;
   buf  : string;
   log_x, log_y : boolean;
begin
  log_x := FALSE;
  log_y := FALSE;
  dset.ymax := 1.0e-2;			(*  10 mA *)
  dset.ymin := 1.0e-15;			(*   1 fA *)
  reset_parser;
  repeat
     quit := false;
     list_menu(GIV_menu);
     screen_bar;
     show_environment(pars, dset);
     cmd := get_cmdline(GIV_menu, argc, argv, autoexit);
     case cmd of
       CMD_NOOP:
          begin
	  end;
       CMD_UNKNOWN:
          begin
	     barf('unknown command', argv[1]);
	  end;
       CMD_QUIT:
          begin
	     quit := TRUE;
	  end;
       CMD_HELP:
          begin
	     list_requests(GIV_menu, argc, argv);
	  end;
       CMD_SAVE:
          begin
	     save_file(argc, argv);
	  end;
       CMD_PLOT:
          if check_safety(data_saved) then begin
	     dispatch_plot(argc, argv);
	  end;
       CMD_DO:
          if check_safety(data_saved) then begin
	     parse_bounds_opts(dset,log_x,log_y,argc,argv);
	     GIV_measure(pars,dset,log_x,log_y);
	     data_saved := false;
	     if user_confirm('Save data (yes)?',TRUE) then begin
	        buf := user_input_line('File (RET for '+save_path+'):');
		if (buf <> '') then save_path := buf;
	        save_simple(dset,save_path);
	     end;
	  end;
       CMD_YMAX:
	  begin
	     dset.ymax := get_value(argc, argv);
	  end;
       CMD_YMIN:
	  begin
	     dset.ymin := get_value(argc, argv);
	  end;
       CMD_NX:
          begin
	     pars.Vx_step := get_value(argc,argv);
	  end;
       CMD_NP:
          begin
	     pars.Vp_step := get_value(argc,argv);
	  end;
       CMD_THOLD:
          begin
	     pars.t_hold := abs(get_value(argc, argv));
	  end;
       CMD_TSTEP:
          begin
	     pars.t_step := abs(get_value(argc,argv));
	  end;
       CMD_X1:
          begin
	     pars.Vx_start := get_value(argc, argv);
	  end;
       CMD_X2:
          begin
	     pars.Vx_stop := get_value(argc, argv);
	  end;
       CMD_P1:
          begin
	     pars.Vp_start := get_value(argc, argv);
	  end;
       CMD_P2:
          begin
	     pars.Vp_stop := get_value(argc, argv);
	  end;
       CMD_BIAS:
          begin
	     pars.V_bias := get_value(argc,argv);
	  end;
       CMD_SETX:
          begin
	     case argv[2][1] of
	        's','S':
		   pars.node.x := SOURCE;
		'd','D':
		   pars.node.x := DRAIN;
		'g','G':
		   pars.node.x := GATE;
		'b','B':
		   pars.node.x := BULK;
		else
		   barf('bad node designation',argv[2]);
	     end;
	  end;
       CMD_SETP:
          begin
	     case argv[2][1] of
	        's','S':
		   pars.node.p := SOURCE;
		'd','D':
		   pars.node.p := DRAIN;
		'g','G':
		   pars.node.p := GATE;
		'b','B':
		   pars.node.p := BULK;
		else
		   barf('bad node designation',argv[2]);
	     end;
	  end;
       CMD_SETGND:
          begin
	     case argv[2][1] of
	        's','S':
		   pars.node.ref := SOURCE;
		'd','D':
		   pars.node.ref := DRAIN;
		'g','G':
		   pars.node.ref := GATE;
		'b','B':
		   pars.node.ref := BULK;
		else
		   barf('bad node designation',argv[2]);
	     end;
	  end;
       CMD_SETBIAS:
          begin
	     case argv[2][1] of
	        's','S':
		   pars.node.bias := SOURCE;
		'd','D':
		   pars.node.bias := DRAIN;
		'g','G':
		   pars.node.bias := GATE;
		'b','B':
		   pars.node.bias := BULK;
		else
		   barf('bad node designation',argv[2]);
	     end;
	  end;
       CMD_COMMENT:
          begin
	     dset.remarks[abs(atoi(argv[2],code)) mod 3] :=
	        get_string(3,argc,argv);
 	  end;
       CMD_ZERO:
          begin
	     zero_GIV(pars);
	  end;
       CMD_SWEEP:
          begin
	     if (argc = 1) then
	        pars.bidirect := not pars.bidirect
	     else if (argv[2] = '2') then
	        pars.bidirect := TRUE
	     else if (argv[2] = '1') then
	        pars.bidirect := FALSE
	     else
	        barf('bad choice','specify 1 (single) or 2 (bidirectional)');
	  end;
       CMD_SRC:
          begin
	     if (argc < 2) then
	        macro_file('',code)
	     else
	        macro_file(argv[2],code);
	  end;
       else
          begin
	     barf('not implemented',argv[1]);
	  end;
     end; (* case *)
  until quit;
end; (* GIV loop *)

procedure QCV_loop (var pars:par_qcv; var dset:data_rec);

procedure show_environment (var pars:par_qcv; var dset:data_rec);
begin
  QCV_steps(pars);
  with pars do begin
     writeln('  V  : start = ',Va_start:7:2,'; stop = ',Va_stop:7:2,
     	     '; step = ',Va_step:6:2,' (',Nx:3,' pts)');
     writeln('dV/dt: start = ',r_start:7:2,'; stop = ',r_stop:7:2,
     	     '; step = ',r_step:6:2,' (',Np:3,' pts); thold = ',t_hold:6:3);
  end;
  screen_bar;
  show_data_set(dset);
end;

var
   argv : arglist;
   argc : integer;
   code : integer;
   quit : boolean;
   cmd  : cmd_enum;
   buf  : string;
   log_x, log_y : boolean;
begin
  log_x := FALSE;
  log_y := FALSE;
  dset.ymax := 2.0e-9;			(* 2000 pF *)
  dset.ymin := 2.0e-20;			(* Bad-value *)
  reset_parser;
  repeat
    quit := false;
    list_menu(QCV_menu);
    screen_bar;
    show_environment(pars,dset);
    cmd := get_cmdline(QCV_menu, argc, argv, autoexit);
    case cmd of 
       CMD_NOOP:
	  begin
	     (* Do nothing *)
	  end;
       CMD_UNKNOWN:
	  begin
	     barf('unknown command', argv[1]);
	  end;
       CMD_QUIT:
	  begin
	     quit := TRUE;
	  end;
       CMD_HELP:	
	  begin
	     list_requests(QCV_menu, argc, argv);
	  end;
       CMD_SAVE:
	  begin
	     save_file(argc, argv);
	  end;
       CMD_PLOT:
	  if check_safety(data_saved) then begin
	     dispatch_plot(argc, argv);
	  end;
       CMD_DO:
	  if check_safety(data_saved) then begin
	     parse_bounds_opts(dset,log_x,log_y,argc,argv);
	     QCV_measure (pars, dset, log_x, log_y);
	     data_saved := FALSE;
	     if user_confirm('Save data (yes)?',TRUE) then begin
		buf := user_input_line('File (RET for '+save_path+'):');
		if (buf <> '') then save_path := buf;
		save_simple(dset,save_path);
	     end;
	  end;
       CMD_YMAX:
	  begin
	     dset.ymax := get_value(argc, argv);
	  end;
       CMD_YMIN:
	  begin
	     dset.ymin := get_value(argc, argv);
	  end;
       CMD_NX:
	  begin
	     pars.Va_step := get_value(argc,argv);
	  end;
       CMD_NP:
	  begin
	     pars.r_step := get_value(argc,argv);
	  end;
       CMD_X1:
	  begin
	     pars.Va_start := get_value(argc, argv);
	  end;
       CMD_X2:
	  begin
	     pars.Va_stop := get_value(argc, argv);
	  end;
       CMD_P1:
	  begin
	     pars.r_start := get_value(argc, argv);
	  end;
       CMD_P2:
	  begin
	     pars.r_stop := get_value(argc, argv);
	  end;
       CMD_THOLD:
	  begin
	     pars.t_hold := greater(2.0,abs(get_value(argc,argv)));
	  end;
       CMD_XLABEL:
	  begin
	     dset.x_label := get_string(2,argc,argv);
	  end;
       CMD_YLABEL:
	  begin
	     dset.y_label := get_string(2, argc, argv);
	  end;
       CMD_PLABEL:
	  begin
	     dset.p_label := get_string(2, argc, argv);
	  end;
       CMD_COMMENT:
	  begin
	     dset.remarks[abs(atoi(argv[2],code)) mod 3] :=
		get_string(3,argc,argv);
	  end;
       CMD_ZERO:
	  begin
	     zero_QCV(pars, dset);
	  end;
       CMD_SWEEP:
	  begin
	     if (argc = 1) then
		pars.bidirect := not pars.bidirect
	     else if (argv[2] = '2') then
		pars.bidirect := TRUE
	     else if (argv[2] = '1') then
		pars.bidirect := FALSE
	     else
		barf('bad choice','specify 1 (single) or 2 (bidirectional)');
	  end;
       CMD_SRC:
	  begin
	     if (argc < 2) then
		macro_file('',code)
	     else
		macro_file(argv[2],code);
	  end;
       else
	  begin
	     barf('not implemented', argv[1]);
	  end;
     end;
  until quit;
end; (* QCV loop *)


procedure CV_loop (var pars:par_4192; var dset:data_rec);

procedure show_environment(var pars:par_4192; var dset:data_rec);
begin
  CV_steps(pars);
  with pars do begin
     writeln('V: start = ',V_start:7:2,'; stop = ',V_stop:7:2,
     	     '; step = ',V_step:7:2,' (',Nx:3,' pts); tstep = ',t_step:6:3);
     writeln('f: start = ',pow10(f_start):7,
     	     '; stop = ',pow10(f_stop):7,
             '; fact = ',pow10(f_step):7,
	     ' (',Np:3,' pts); thold = ',t_hold:6:3);
     writeln('Oscillator level = ',osc_level:10:3,'  Averaging = ',average);
  end;
  screen_bar;
  show_data_set(dset);
end;

var
   argv : arglist;
   i, argc : integer;
   code : integer;
   quit : boolean;
   cmd  : cmd_enum;
   buf  : string;
   log_x, log_y : boolean;
begin
  log_x := FALSE;
  log_y := FALSE;
  dset.ymax := 1.0e-10;		(* 100 pF *)
  dset.ymin := 1.0e-15;		(*   1 fF *)
  reset_parser;
  repeat
    quit := false;
    list_menu(ACV_menu);
    screen_bar;
    show_environment(pars, dset);
    cmd := get_cmdline(ACV_menu, argc, argv, autoexit);
    case cmd of
       CMD_NOOP:
	  begin
	     (* do nothing *)
	  end;
       CMD_UNKNOWN:
	  begin
	     barf('unknown command',argv[1]);
	  end;
       CMD_QUIT:
	  begin
	     quit := TRUE;
	  end;
       CMD_HELP:
	  begin
	     list_requests(ACV_menu, argc, argv);
	  end;
       CMD_SAVE:
	  begin
	     save_file(argc, argv);
	  end;
       CMD_PLOT:
	  if check_safety(data_saved) then begin
	     dispatch_plot(argc, argv);
	  end;
       CMD_DO:
	  if check_safety(data_saved) then begin
	     parse_bounds_opts(dset,log_x,log_y,argc,argv);
	     for i := 1 to argc do begin
	        if (argv[i] = '-average') or (argv[i] = '-a') then
		   pars.average := TRUE
		else if (argv[i] = '-no_average') or (argv[i] = '-na') then
		   pars.average := FALSE;
	     end;
	     CV_measure(pars,dset,log_x,log_y);
	     data_saved := FALSE;
	     if user_confirm('Save data (yes)?',TRUE) then begin
		buf := user_input_line('File (RET for '+save_path+'):');
		if (buf <> '') then save_path := buf;
		save_simple(dset,save_path);
	     end;
	  end;
       CMD_YMAX:
	  begin
	     dset.ymax := get_value(argc, argv);
	  end;
       CMD_YMIN:
	  begin
	     dset.ymin := get_value(argc, argv);
	  end;
       CMD_NX:
	  begin
	     pars.V_step := get_value(argc,argv);
	  end;
       CMD_NP:
	  begin
	     pars.f_step := log10(abs(get_value(argc,argv))+TINY);
	  end;
       CMD_X1:
	  begin
	     pars.V_start := get_value(argc, argv);
	  end;
       CMD_X2:
	  begin
	     pars.V_stop := get_value(argc, argv);
	  end;
       CMD_P1:
	  begin
	     pars.f_start := log10(greater(0.01,abs(get_value(argc,argv))));
	  end;
       CMD_P2:
	  begin
	     pars.f_stop  := log10(greater(0.01,abs(get_value(argc,argv))));
	  end;
       CMD_OL:
	  begin
	     pars.osc_level := abs(get_value(argc,argv));
	  end;
       CMD_THOLD:
	  begin
	     pars.t_hold := abs(get_value(argc,argv));
	  end;
       CMD_TSTEP:
	  begin
	     pars.t_step := abs(get_value(argc, argv));
	  end;
       CMD_XLABEL:
	  begin
	     dset.x_label := get_string(2,argc,argv);
	  end;
       CMD_YLABEL:
	  begin
	     dset.y_label := get_string(2, argc, argv);
	  end;
       CMD_PLABEL:
	  begin
	     dset.p_label := get_string(2, argc, argv);
	  end;
       CMD_COMMENT:
	  begin
	    dset.remarks[abs(atoi(argv[2],code)) mod 3] :=
	       get_string(3,argc,argv);
	  end;
       CMD_SWEEP:
	  begin
	     if (argc = 1) then
		pars.bidirect := not pars.bidirect
	     else if (argv[2] = '2') then
		pars.bidirect := TRUE
	     else if (argv[2] = '1') then
		pars.bidirect := FALSE
	     else
		barf('bad choice','specify 1 (single) or 2 (bidirectional)');
	  end;
       CMD_SRC:
	  begin
	     if (argc < 2) then
		macro_file('',code)
	     else
		macro_file(argv[2],code);
	  end;
       else
	  begin
	     barf('not implemented', argv[1]);
	  end;
     end;
  until quit;
end; (* CV loop *)

procedure DCV_loop (var pars:par_DCV; var dset:data_rec);

procedure show_environment(var pars:par_DCV; var dset:data_rec);
begin
  DCV_steps(pars);
  with pars do begin
     writeln('V: start = ',V_start:7:2,'; stop = ',V_stop:7:2,
     	     '; step = ',V_step:7:2,' (',Nx:3,' pts); tstep = ',t_step:6:3);
     writeln('f: start = ',pow10(f_start):7,
     	     '; stop = ',pow10(f_stop):7,
             '; fact = ',pow10(f_step):7,
	     ' (',Np:3,' pts); thold = ',t_hold:6:3);
     writeln('Oscillator level = ',osc_level:10:3,'   Averaging = ',average);
     writeln('Accumulation Voltage = ',V_accum:10:3);
  end;
  screen_bar;
  show_data_set(dset);
end;

var
   argv : arglist;
   i, argc : integer;
   code : integer;
   quit : boolean;
   cmd  : cmd_enum;
   buf  : string;
   log_x, log_y : boolean;
begin
  log_x := FALSE;
  log_y := FALSE;
  dset.ymax := 1.0e-10;		(* 100 pF *)
  dset.ymin := 1.0e-15;		(*   1 fF *)
  reset_parser;
  repeat
    quit := false;
    list_menu(DCV_menu);
    screen_bar;
    show_environment(pars, dset);
    cmd := get_cmdline(DCV_menu, argc, argv, autoexit);
    case cmd of
       CMD_NOOP:
	  begin
	     (* do nothing *)
	  end;
       CMD_UNKNOWN:
	  begin
	     barf('unknown command',argv[1]);
	  end;
       CMD_QUIT:
	  begin
	     quit := TRUE;
	  end;
       CMD_HELP:
	  begin
	     list_requests(ACV_menu, argc, argv);
	  end;
       CMD_SAVE:
	  begin
	     save_file(argc, argv);
	  end;
       CMD_PLOT:
	  if check_safety(data_saved) then begin
	     dispatch_plot(argc, argv);
	  end;
       CMD_DO:
	  if check_safety(data_saved) then begin
	     parse_bounds_opts(dset,log_x,log_y,argc,argv);
	     for i := 1 to argc do begin
	        if (argv[i] = '-average') or (argv[i] = '-a') then
		   pars.average := TRUE
		else if (argv[i] = '-no_average') or (argv[i] = '-na') then
		   pars.average := FALSE;
	     end;
	     DCV_measure(pars,dset,log_x,log_y);
	     data_saved := FALSE;
	     if user_confirm('Save data (yes)?',TRUE) then begin
		buf := user_input_line('File (RET for '+save_path+'):');
		if (buf <> '') then save_path := buf;
		save_simple(dset,save_path);
	     end;
	  end;
       CMD_YMAX:
	  begin
	     dset.ymax := get_value(argc, argv);
	  end;
       CMD_YMIN:
	  begin
	     dset.ymin := get_value(argc, argv);
	  end;
       CMD_NX:
	  begin
	     pars.V_step := get_value(argc,argv);
	  end;
       CMD_NP:
	  begin
	     pars.f_step := log10(abs(get_value(argc,argv))+TINY);
	  end;
       CMD_X1:
	  begin
	     pars.V_start := get_value(argc, argv);
	  end;
       CMD_X2:
	  begin
	     pars.V_stop := get_value(argc, argv);
	  end;
       CMD_P1:
	  begin
	     pars.f_start := log10(greater(0.01,abs(get_value(argc,argv))));
	  end;
       CMD_P2:
	  begin
	     pars.f_stop  := log10(greater(0.01,abs(get_value(argc,argv))));
	  end;
       CMD_OL:
	  begin
	     pars.osc_level := abs(get_value(argc,argv));
	  end;
       CMD_SETBIAS:
          begin
	     pars.V_accum := get_value(argc,argv);
	  end;
       CMD_THOLD:
	  begin
	     pars.t_hold := abs(get_value(argc,argv));
	  end;
       CMD_TSTEP:
	  begin
	     pars.t_step := abs(get_value(argc, argv));
	  end;
       CMD_XLABEL:
	  begin
	     dset.x_label := get_string(2,argc,argv);
	  end;
       CMD_YLABEL:
	  begin
	     dset.y_label := get_string(2, argc, argv);
	  end;
       CMD_PLABEL:
	  begin
	     dset.p_label := get_string(2, argc, argv);
	  end;
       CMD_COMMENT:
	  begin
	    dset.remarks[abs(atoi(argv[2],code)) mod 3] :=
	       get_string(3,argc,argv);
	  end;
       CMD_SRC:
	  begin
	     if (argc < 2) then
		macro_file('',code)
	     else
		macro_file(argv[2],code);
	  end;
       else
	  begin
	     barf('not implemented', argv[1]);
	  end;
     end;
  until quit;
end; (* CV loop *)

procedure modify_loop (var dset:data_rec);
(*
 * This loop allows modification of the data to calculate doping profiles
 * and so on.
 *)
const
  q	= 1.61e-19;
  e0	= 8.85e-12;
  k_Si	= 11.7;
  k_SiO2 = 3.9;
var
  argv : arglist;
  argc : integer;
  code : integer;
  quit : boolean;
  cmd  : cmd_enum;
  ip, ix : index;
  x0, y0, dydx, dydx_max, delta, scale, sx, sy, sxy, sxx, syy : extended;
  e, Cox, area : extended;
  i, smooth : integer;
  c : char;
  tmp : ^valarr;
begin
  reset_parser;
  repeat
    scale := 1.0;
    quit := false;
    list_menu(modify_menu);
    screen_bar;
    show_data_set(dset);
    cmd := get_cmdline(modify_menu, argc, argv, autoexit);
    case cmd of
       CMD_NOOP:
	  begin
	     (* do nothing *)
	  end;
       CMD_UNKNOWN:
	  begin
	     barf('unknown command',argv[1]);
	  end;
       CMD_QUIT:
	  begin
	     quit := TRUE;
	  end;
       CMD_HELP:
	  begin
	     list_requests(modify_menu, argc, argv);
	  end;
       CMD_SAVE:
	  begin
	     save_file(argc, argv);
	  end;
       CMD_PLOT:
	  if check_safety(data_saved) then begin
	     dispatch_plot(argc, argv);
	  end;
       CMD_XLABEL:
	  begin
	     dset.x_label := get_string(2,argc,argv);
	  end;
       CMD_YLABEL:
	  begin
	     dset.y_label := get_string(2, argc, argv);
	  end;
       CMD_PLABEL:
	  begin
	     dset.p_label := get_string(2, argc, argv);
	  end;
       CMD_COMMENT:
	  begin
	     dset.remarks[abs(atoi(argv[2],code)) mod 3] :=
		get_string(3,argc,argv);
	  end;
       CMD_SAVE:
	  begin
	     save_file(argc, argv);
	  end;
       CMD_MULT:
	  with dset do begin
	     data_saved := false;
	     scale := 1.0;
	     for i := 3 to argc do
		scale := scale * atof(argv[i],code);
	     if (argc < 3) then argv[2] := '*';
	     case argv[2][1] of
		'x','X':
		   begin
		      for ix := 1 to Nx do
			 x[ix] := x[ix] * scale;
		      x_label := ftoa(scale,9,-1)+' * ('+x_label+')';
		   end;
		'y','Y':
		   begin
		      for ip := 1 to Np do
			 for ix := 1 to Nx do
			    y[ip][ix] := y[ip][ix] * scale;
		      y_label := ftoa(scale,9,-1)+' * ('+y_label+')';
		   end;
		'p','P':
		   begin
		      for ip := 1 to Np do
			 p[ip] := p[ip] * scale;
		      p_label := ftoa(scale,9,-1)+' * ('+p_label+')';
		   end;
		else
		   barf(argv[1], '1st arg must be x, y, or p');
	     end; (* case *)
	     find_limits(dset);
	  end;
       CMD_ADD:
	  with dset do begin
	     data_saved := FALSE;
	     scale := 0.0;
	     for i := 3 to argc do
		scale := scale + atof(argv[i],code);
	     if (argc < 3) then argv[2] := '*';
	     case argv[2][1] of
		'x','X':
		   begin
		      for ix := 1 to Nx do
			 x[ix] := x[ix] + scale;
		      x_label := '('+x_label+')+'+ftoa(scale,9,-1);
		   end;
		'y','Y':
		   begin
		      for ip := 1 to Np do
			 for ix := 1 to Nx do
			    y[ip][ix] := y[ip][ix] + scale;
		      y_label := '('+y_label+')+'+ftoa(scale,9,-1);
		   end;
		'p','P':
		   begin
		      for ip := 1 to Np do
			 p[ip] := p[ip] + scale;
		      p_label := '('+p_label+')+'+ftoa(scale,9,-1);
		   end;
		else
		   barf(argv[1], '1st arg must be x, y, or p');
	     end; (* case *)
	     find_limits(dset);
	  end;
       CMD_DIV:
	  with dset do begin
	     data_saved := FALSE;
	     scale := 1.0;
	     for i := 3 to argc do
		scale := scale * atof(argv[i],code);
	     if (scale = 0.0) then begin
		beep;
		barf('bad divisor',ftoa(scale,9,-1));
	     end
	     else begin
	        if (argc < 3) then argv[2] := '*';
		case argv[2][1] of
		   'x','X':
		      begin
			 for ix := 1 to Nx do
			    x[ix] := x[ix] / scale;
			 x_label := '('+x_label+')/'+ftoa(scale,9,-1);
		      end;
		   'y','Y':
		      begin
			 for ip := 1 to Np do
			    for ix := 1 to Nx do
			       y[ip][ix] := y[ip][ix] / scale;
			 y_label := '('+y_label+')/'+ftoa(scale,9,-1);
		      end;
		   'p','P':
		      begin
			 for ip := 1 to Np do
			    p[ip] := p[ip] / scale;
			 p_label := '('+p_label+')/'+ftoa(scale,9,-1);
		      end;
		   else
		      barf(argv[1], '1st arg must be x, y, or p');
		end; (* case *)
		find_limits(dset);
	     end;
	  end;
       CMD_POW:
	  with dset do begin
	     data_saved := false;
	     scale := 1.0;
	     for i := 3 to argc do
		scale := scale * atof(argv[i],code);
	     if (argc < 3) then argv[2] := '*';
	     case argv[2][1] of
		'x','X':
		   begin
		      for ix := 1 to Nx do
			 if (scale = 2.0) then
			    x[ix] := x[ix] * x[ix]
			 else
			    x[ix] := pow(abs(x[ix]),scale);
		      x_label := '('+x_label+')^'+ftoa(scale,5,2);
		   end;
		'y','Y':
		   begin
		      for ip := 1 to Np do
			 for ix := 1 to Nx do
			    if (scale = 2.0) then
			       y[ip][ix] := y[ip][ix] * y[ip][ix]
			    else
			       y[ip][ix] := pow(abs(y[ip][ix]),scale);
		      y_label := '('+y_label+')^'+ftoa(scale,5,2);
		   end;
		'p','P':
		   begin
		      for ip := 1 to Np do
			 if (scale = 2.0) then
			    p[ip] := p[ip]*p[ip]
			 else
			    p[ip] := pow(abs(p[ip]),scale);
		      p_label := '('+p_label+')^'+ftoa(scale,5,2);
		   end;
		else
		   barf(argv[1], '1st arg must be x, y, or p');
	     end; (* case *)
	     find_limits(dset);
	  end;
       CMD_LOG:
	  with dset do begin
	     if (argc = 2) then begin
	        data_saved := FALSE;
		case argv[2][1] of
		   'x','X':
		      begin
			 for ix := 1 to Nx do
			    x[ix] := log10(abs(x[ix])+TINY);
			 x_label := 'log10('+x_label+')';
		      end;
		   'y','Y':
		      begin
			 for ip := 1 to Np do
			    for ix := 1 to Nx do
			       y[ip][ix] := log10(abs(y[ip][ix])+TINY);
			 y_label := 'log10('+y_label+')';
		      end;
		   'p','P':
		      begin
			 for ip := 1 to Np do
			    p[ip] := log10(abs(p[ip])+TINY);
			 p_label := 'log10('+p_label+')';
		      end;
		   else
		      barf(argv[1],'1st argument must be x,y or p');
		end;
		find_limits(dset);
	     end
	     else
		barf(argv[1], 'give x, y, or p as argument');
	  end;
       CMD_LN:
	  with dset do begin
	     if (argc = 2) then begin
 	        data_saved := FALSE;
		case argv[2][1] of
		   'x','X':
		      begin
			 for ix := 1 to Nx do
			    x[ix] := ln(abs(x[ix])+TINY);
			 x_label := 'ln('+x_label+')';
		      end;
		   'y','Y':
		      begin
			 for ip := 1 to Np do
			    for ix := 1 to Nx do
			       y[ip][ix] := ln(abs(y[ip][ix])+TINY);
			 y_label := 'ln('+y_label+')';
		      end;
		   'p','P':
		      begin
			 for ip := 1 to Np do
			    p[ip] := ln(abs(p[ip])+TINY);
			 p_label := 'ln('+p_label+')';
		      end;
		   else
		      barf(argv[1],'1st argument must be x,y or p');
		end;
		find_limits(dset);
	     end
	     else
		barf(argv[1], 'give x, y, or p as argument');
	  end;
       CMD_RECIP:
	  with dset do begin
	     if (argc = 2) then begin
	        data_saved := FALSE;
		case argv[2][1] of
		   'x','X':
		      begin
			 for ix := 1 to Nx do
			    x[ix] := sgn(x[ix])/(abs(x[ix])+TINY);
			 x_label := '1/('+x_label+')';
		      end;
		   'y','Y':
		      begin
			 for ip := 1 to Np do
			    for ix := 1 to Nx do
			       y[ip][ix] := sgn(y[ip][ix]) /
					    (abs(y[ip][ix])+TINY);
			 y_label := '1/('+y_label+')';
		      end;
		   'p','P':
		      begin
			 for ip := 1 to Np do
			    p[ip] := sgn(p[ip]) / (abs(p[ip])+TINY);
			 p_label := '1/('+p_label+')';
		      end;
		   else
		      barf(argv[1],'1st argument must be x,y or p');
		end;
		find_limits(dset);
	     end
	     else
		barf(argv[1], 'give x, y, or p as argument');
	  end;
       CMD_EXP:
	  with dset do begin
	     if (argc = 2) then begin
	        data_saved := FALSE;
		case argv[2][1] of
		   'x','X':
		      begin
			 for ix := 1 to Nx do
			    x[ix] := exp(x[ix]);
			 x_label := 'exp('+x_label+')';
		      end;
		   'y','Y':
		      begin
			 for ip := 1 to Np do
			    for ix := 1 to Nx do
			       y[ip][ix] := exp(y[ip][ix]);
			 y_label := 'exp('+y_label+')';
		      end;
		   'p','P':
		      begin
			 for ip := 1 to Np do
			    p[ip] := exp(p[ip]);
			 p_label := 'exp('+p_label+')';
		      end;
		   else
		      barf(argv[1],'1st argument must be x,y or p');
		end;
		find_limits(dset);
	     end
	     else
		barf(argv[1], 'give x, y, or p as argument');
	  end;
       CMD_SMOOTH:
	  begin
	     if (argc > 1) then
		smooth := abs(round(atof(argv[2],code))) - 1
	     else
		smooth := 1;
	     if (smooth > 0) then with dset do begin
		data_saved := FALSE;
		Nx := Nx - smooth;
		for ix := 1 to Nx do begin
		   for ip := 1 to Np do begin
		      for i := 1 to smooth do
			 y[ip][ix] := y[ip][ix] + y[ip][ix+i];
		      y[ip][ix] := y[ip][ix] / (1 + smooth);
		   end;
		   for i := 1 to smooth do
		      x[ix] := x[ix] + x[ix+i];
		   x[ix] := x[ix] / (1 + smooth);
		end;
		find_limits(dset);
	     end
	     else
		barf('illegal smoothing parameter',argv[2]);
	  end;
       CMD_DYDX:
	  begin
	     if (argc > 1) then
		smooth := abs(round(atof(argv[2],code))) - 1
	     else
		smooth := 1;
	     if (smooth > 0) then with dset do begin
		data_saved := FALSE;
		Nx := Nx - smooth;
		for ix := 1 to Nx do begin
		   sx := 0.0;
		   sxx := 0.0;
		   for i := 0 to smooth do begin
		      sx := sx + x[ix+i];
		      sxx := sxx + x[ix+i]*x[ix+i];
		   end;
		   delta := ((1 + smooth) * sxx) - (sx * sx);
		   if (abs(delta) < TINY) then
		      y[ip][ix] := 1.0 / TINY
		   else begin
		      for ip := 1 to Np do begin
			 sy := 0.0;
			 syy := 0.0;
			 sxy := 0.0;
			 for i := 0 to smooth do begin
			    sy := sy + y[ip][ix+i];
			    syy := syy + y[ip][ix+i]*y[ip][ix+i];
			    sxy := sxy + x[ix+i]*y[ip][ix+i];
			 end;
			 y[ip][ix] := ((1+smooth) * sxy - (sx * sy)) / delta;
		      end;
		   end;
		   for i := 1 to smooth do
		      x[ix] := x[ix] + x[ix+i];
		   x[ix] := x[ix] / (1 + smooth);
		end;
		find_limits(dset);
		y_label := 'd('+y_label+')/d('+x_label+')';
	     end
	     else
		barf('illegal smoothing parameter',argv[2]);
	  end;
       CMD_DYDP:
	  begin
	     if (argc > 1) then
		smooth := abs(round(atof(argv[2],code))) - 1
	     else
		smooth := 1;
	     if (smooth > 0) then with dset do begin
		data_saved := FALSE;
		Np := Np - smooth;
		for ip := 1 to Np do begin
		   sx := 0.0;
		   sxx := 0.0;
		   for i := 0 to smooth do begin
		      sx := sx + p[ip+i];
		      sxx := sxx + p[ip+i]*p[ip+i];
		   end;
		   delta := ((1 + smooth) * sxx) - (sx * sx);
		   if (abs(delta) < TINY) then
		      y[ip][ix] := 1.0 / TINY
		   else begin
		      for ix := 1 to Nx do begin
			 sy := 0.0;
			 syy := 0.0;
			 sxy := 0.0;
			 for i := 0 to smooth do begin
			    sy := sy + y[ip+i][ix];
			    syy := syy + y[ip+i][ix]*y[ip+i][ix];
			    sxy := sxy + p[ip+i]*y[ip+i][ix];
			 end;
			 y[ip][ix] := ((1+smooth) * sxy - (sx * sy)) / delta;
		      end;
		   end;
		   for i := 1 to smooth do
		      p[ip] := p[ip] + p[ip+i];
		   p[ip] := p[ip] / (1 + smooth);
		end;
		find_limits(dset);
		y_label := 'd('+y_label+')/d('+p_label+')';
	     end
	     else
		barf('illegal smoothing parameter',argv[2]);
	  end;
       CMD_VTH:
	  begin
	     if (argc > 1) then
		smooth := abs(round(atof(argv[2],code))) - 1
	     else
		smooth := 1;
	     if (smooth > 0) then with dset do begin
		data_saved := FALSE;
		Nx := Nx - smooth;
		writeln('Curve     ',p_label:9,
			'    max gm        I(0)         Vth');
		screen_bar;
		for ip := 1 to Np do begin
		   dydx_max := 0.0;
		   for ix := 1 to Nx do begin
		      sx := 0.0;
		      sxx := 0.0;
		      for i := 0 to smooth do begin
			 sx := sx + x[ix+i];
			 sxx := sxx + x[ix+i]*x[ix+i];
		      end;
		      delta := ((1 + smooth) * sxx) - (sx * sx);
		      if (abs(delta) < TINY) then begin
		         dydx := 0.0;
		         x0 := 0.0;
		         y0 := 0.0;
		      end
		      else begin
			 sy := 0.0;
			 syy := 0.0;
			 sxy := 0.0;
			 for i := 0 to smooth do begin
			    sy := sy + y[ip][ix+i];
			    syy := syy + y[ip][ix+i]*y[ip][ix+i];
			    sxy := sxy + x[ix+i]*y[ip][ix+i];
			 end;
			 dydx := ((1+smooth) * sxy - (sx * sy)) / delta;
			 if (abs(dydx) > abs(dydx_max)) then begin
			    dydx_max := dydx;
			    y0 := ((sxx * sy) - (sx * sxy)) / delta;
			    if (abs(dydx_max) > TINY) then
			       x0 := - y0 / dydx_max;
			 end;
		      end;
		   end;
		   writeln(ip:4,'  ',p[ip]:11:4,'  ', 
		   	   dydx_max:11,'  ',y0:11,'  ',x0:11:4);
		end;
		emit('Press a key when done: ');
		c := get_kbd_char;
		emit('');
	     end
	     else
		barf('illegal smoothing parameter',argv[2]);
	  end;
       CMD_DOPING:
          begin
	     if (argc > 1) then
		smooth := abs(round(atof(argv[2],code))) - 1
	     else
		smooth := 1;
	     if (smooth > 0) then with dset do begin
		Cox  := atof(user_input_line('Cox value (F)?'),code);
	        area := atof(user_input_line('Capacitor area (um^2)?'),code);
		if user_confirm('Silicon (default YES)?',TRUE) then
		   e := k_Si * e0
		else
		   e := e0 * atof(user_input_line('Enter dielectric const:'),
		   		  code);
	        scale := 2.0 / (e * q);
		(*
		 * We convert the total capacitance values
		 * to the depletion capacitance, using the fact that
		 *	1/C	=	1/Cox	+   1/Cd
		 *)
		new(tmp);
		ip := 1;
		Cox := Cox * 1e12 / area;
		data_saved := FALSE;
		for ix := 1 to Nx do begin
		   y[ip][ix] := y[ip][ix] * 1e12 / area;
		   if abs(y[ip][ix]) < TINY then
		      y[ip][ix] := 1.0/TINY
		   else
		      y[ip][ix] := (1.0/y[ip][ix]) - (1.0/Cox);
		   if abs(y[ip][ix]) < TINY then
		      tmp^[ix] := 1.0/TINY
		   else
		      tmp^[ix] := e / y[ip][ix];
		end;
		Nx := Nx - smooth;
		for ix := 1 to Nx do begin
		   sx := 0.0;
		   sxx := 0.0;
		   for i := 0 to smooth do begin
		      sx := sx + x[ix+i];
		      sxx := sxx + x[ix+i]*x[ix+i];
		   end;
		   delta := ((1 + smooth) * sxx) - (sx * sx);
		   if (abs(delta) < TINY) then
		      y[ip][ix] := 1.0 / TINY
		   else begin
		      sy := 0.0;
		      syy := 0.0;
		      sxy := 0.0;
		      for i := 0 to smooth do begin
			 sy := sy + y[ip][ix+i];
			 syy := syy + y[ip][ix+i]*y[ip][ix+i];
			 sxy := sxy + x[ix+i]*y[ip][ix+i];
		      end;
		      y[ip][ix] := ((1+smooth) * sxy - (sx * sy)) / delta;
		   end;
		   for i := 1 to smooth do
		      tmp^[ix] := tmp^[ix] + tmp^[ix+i];
		   tmp^[ix] := tmp^[ix] / (1 + smooth);
		end;
		for ix := 1 to Nx do begin
		   x[ix] := tmp^[ix];
		   y[ip][ix] := y[ip][ix] / scale;
		   if (abs(y[ip][ix]) < TINY) then
		      y[ip][ix] := 1.0 / TINY
		   else
		      y[ip][ix] := 1.0 / y[ip][ix];
		end;
	     end
	     else
	        barf('illegal smoothing parameter',argv[2]);
	  end;
       CMD_SRC:
	  begin
	     if (argc < 2) then
		macro_file('',code)
	     else
		macro_file(argv[2],code);
	  end;
       else
	  begin
	     barf('not implemented', argv[1]);
	  end;
     end;
  until quit;
end;

(*****************************************************************************
 * GLOBAL CONTROL VARIABLES
 * These variables are relevant only to the main control loop of the program
 * and are declared last in the global environment.
 *)
var
   argv : arglist;
   argc : integer;
   code : integer;
   quit : boolean;
   cmd  : cmd_enum;

begin (* main program *)
  TextBackground(Black);
  TextColor(Yellow);
  ref_dir := site.home_dir + '\lib\';
  (*
   * Put up any initial messages on the screen
   *)
  writeln('This is ',WHOAMI,', Code Version ',CODE_VERSION,
  	  ';  Data Format ',DATA_VERSION,'.');
  writeln('See ',CURSED_ONE,' if you find bugs/problems.');
  init_environment;
  reset_parser;
  repeat
     quit := false;
     list_menu(top_level);
     screen_bar;
     show_environment;
     cmd := get_cmdline (top_level, argc, argv, autoexit);
     case cmd of
       CMD_NOOP:
          begin
             (* Do nothing *)
          end;
       CMD_UNKNOWN:
          begin
             barf('unknown command', argv[1]);
          end;
       CMD_QUIT:
          begin
             quit := check_safety(data_saved) and (argc = 1);
          end;
       CMD_HELP:	
          begin
	     list_requests(top_level, argc, argv)
	  end;
       CMD_DIR:
          begin
             list_directory(argc, argv);
          end;
       CMD_CHDIR:
          begin
	     if (argc <> 2) then
	        barf(argv[1], 'wrong number of arguments')
	     else begin
	        {$i-}
		chdir(argv[2]); code := IOResult;
		{$i+}
		if (code <> 0) then
		   barf(argv[2], runtime.lookup(code));
	     end;
          end;
       CMD_SAVE:
          begin
	    save_file(argc, argv);
	  end;
       CMD_READ:
          if check_safety(data_saved) then begin
	     read_file(argc, argv);
	  end;
       CMD_COMMENT:
          begin
	     dset.remarks[abs(atoi(argv[2],code)) mod 3] :=
	        get_string(3,argc,argv);
	  end;
       CMD_GIV:
          begin
	     GIV_loop (giv, dset);
	  end;
       CMD_IV4140:
          begin
	     IV_loop (pa_vs, dset);
	  end;
       CMD_CV4140:
          begin
	     QCV_loop (qcv, dset);
	  end;
       CMD_CV4192:
          begin
	     CV_loop (lf_ia, dset);
	  end;
       CMD_DEEPCV:
          begin
	     DCV_loop (dcv, dset);
	  end;
       CMD_PLOT:
          if check_safety(data_saved) then begin
	     dispatch_plot(argc, argv);
	  end;
       CMD_XLABEL:
          begin
	     dset.x_label := get_string(2,argc,argv);
	  end;
       CMD_YLABEL:
          begin
	     dset.y_label := get_string(2, argc, argv);
	  end;
       CMD_PLABEL:
          begin
	     dset.p_label := get_string(2, argc, argv);
	  end;
       CMD_MODIFY:
          if check_safety(data_saved) then begin
	     modify_loop(dset);
	  end;
       CMD_SRC:
          begin
	     if (argc < 2) then
	        macro_file('',code)
	     else
	        macro_file(argv[2],code);
	  end;
       else
          begin
             barf('not implemented',argv[1]);
          end;
     end; (* case *)
  until quit;
end. (* main program *)
