program MOS;
(*
 * MOS characterization program.
 * History:
 * 14 Oct 88		Version 1.07
 *	After several modifications, the first user-ready version appears
 *	finished.  It can read script files (using the source command)
 *	and properly stamps out the date on GIRAPHE3 files.
 *)

uses
  dos, crt, generics, site, rt_error, values, gpib, curves, parser, menus;

const
  WHOAMI = 'MOS';
  INITFILE = 'MOS.INI';
  CODE_VERSION = '1.07';

(*****************************************************************************
 * BASIC TOOLS
 *)

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

function check_safety (flag:boolean) : boolean;
begin
  if flag then
     check_safety := true
  else if user_confirm ('Data not saved.  Are you sure?') then
     check_safety := true
  else
     check_safety := false;
end;

(****************************************************************************
 * DATA TYPE DEFINITIONS
 *
 * Remember to update the DATA_VERSION constant every time the data set format
 * is changed.
 *)
const
  DATA_VERSION = '1.01';
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

  par_4140 = record
  		Va_start, Va_stop, Va_step, Va_rate : single;
		Vb_start, Vb_stop, Vb_step : single;
		t_hold, t_step : single;
  	     end;
  par_qcv  = record
  		Va_start, Va_stop, Va_step : single;
		r_start, r_stop, r_step : single;
		t_hold : single;
  	     end;
  par_4192 = record
    		V_start, V_stop, V_step : single;
		f_start, f_stop, f_step : single;
		osc_level : single;
		t_hold, t_step : single;
	     end;

procedure show_data_set (var dset:data_rec);
var
  i, colour : byte;
begin
  colour := (TextAttr and $0F);
  TextColor(Yellow);
  with dset do begin
     writeln('Data set belongs to code version ',codever,
     	     ', data format version ',dataver);
     for i := 0 to 2 do
        writeln('<',i,'> ',remarks[i]);
     writeln('Time mark = ',date_str(date,false),' at ',time_str(time,false));
     writeln('Y: max = ',ymax:10,'; min = ',ymin:10,'; label = ',y_label);
     writeln('X: max = ',xmax:10,'; min = ',xmin:10,'; label = ',x_label);
     writeln('   Number of points = ',Nx);
     writeln('P: max = ',pmax:10,'; min = ',pmin:10,'; label = ',p_label);
     writeln('   Number of curves = ',Np);
  end;
  TextColor(colour);
end;

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

const
  LINEAR 	= 0;
  SEMILOG	= 1;
  LOGLOG	= 2;

procedure save_ascii (var d:data_rec; mode:byte;
		      path:string127; var code:integer);
var
  ix, ip : index;
  f : text;
  buf : string31;
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
	if (xmin <= 0.0) and (mode = LOGLOG) then
	   mode := SEMILOG;
	if (ymin <= 0.0) then
	   mode := LINEAR;
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
	      writeln(f, y[ip][ix],'        ',x[ix]);
	   end;
	end;
	writeln(f, '.end');
	write  (f, 'plot curve');
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

var
  autoexit : boolean;

procedure source (name:string63; var code:integer);
begin
  assign(input, name);
  {$i-}
  reset(input); code := IOResult;
  {$i+}
  if (code = 0) then
     autoexit := not (name = '')
  else begin
     assign(input,'');
     reset(input);
  end;
end;

procedure extract_4140 (var s:string; var y,x:value);
var
  sp1, sp2 : byte;
  code : integer;
begin
  sp1 := 4;
  sp2 := pos(',',s);
  y := atof(copy(s, sp1, (sp2 - sp1 + 1)), code);
  sp1 := pos('A',s);
  sp2 := length(s) - 2;
  x := atof(copy(s, sp1, (sp2 - sp1 + 1)), code);
end;

procedure extract_4192 (var s:string; var y,x:value);
var
  sp1, sp2 : byte;
  code : integer;
begin
  sp1 := 5;
  sp2 := pos(',',s);
  y := atof(copy(s, sp1, (sp2 - sp1 + 1)), code);
  sp1 := 34;
  sp2 := length(s) - 2;
  x := atof(copy(s, sp1, (sp2 - sp1 + 1)), code);
end;

procedure setup_graphics(var video:tabloid;
			 xmin,xmax,ymin,ymax:value;
			 x_log,y_log:boolean;
			 title_1,title_2,x_label,y_label:string127;
			 var p:pararr;
			 var Np:index;
			 var x:valarr;
			 var Nx:index;
			 var y:valarrarr;
			 var ip,ix:index);
begin
  sort2(xmin,xmax);
  sort2(ymin,ymax);
  if (xmin <= 0.0) then
     x_log := false;
  if (ymin <= 0.0) then
     y_log := false;
  set_regions(video);
  set_limits(video, xmin, xmax, ymin, ymax);
  set_flags (video, x_log, y_log, false);
  set_bounds(video);
  set_static_data(video, title_1, title_2, x_label, y_label);
  set_dynamic_data(video, p, Np, x, Nx, y);
  set_dynamic_ptrs(video, ip, ix);
end;

procedure check_user_event (var video:tabloid; var finished:boolean);
var
  cmd : char;
begin
  if keypressed then begin
     cmd := get_kbd_char;
     if (cmd in ['q','Q']) then
        finished := true
     else
        act_event(video, cmd);
  end;
end;

procedure play_graphics (var video:tabloid);
var
  cmd : char;
  finished : boolean;
begin
  dsp_message(video,'Data acquisition finished.');
  repeat
     finished := false;
     cmd := get_kbd_char;
     if (cmd in ['q','Q']) then
        finished := true
     else
        act_event(video, cmd);
  until finished;
end;

procedure IV_4140 (var pars:par_4140; var dset:data_rec);
var
  ix, ip : index;
  video : tabloid;
  ptmp, xtmp, ytmp : value;
  finished : boolean;
  dev : device;
  code : integer;
  buf : string;
  dt : word;
begin
  with dset do begin
     x_label := 'Va [V]';
     y_label := 'I [A]';
     p_label := 'Vb [V]';
     with pars do begin
        if (Nx < 1) then Nx := 2;
	if (odd(Nx)) then Nx := Nx + 1;
        Va_step  := abs(Va_stop - Va_start) / (Nx div 2);
	xmin := lesser(Va_stop, Va_start);
	xmax := greater(Va_stop, Va_start);

	if (Np < 2) then Np := 2;
	Vb_step := abs(Vb_stop - Vb_start) / (Np - 1);
	pmin := lesser(Vb_stop, Vb_start);
	pmax := greater(Vb_stop, Vb_start);

	dt := round(1000.0 * t_step);
     end;
     sort2(ymin,ymax);
     setup_graphics(video, xmin, xmax, ymin, ymax, false, false,
     			   remarks[0], remarks[1], x_label, y_label,
			   p, Np, x, Nx, y, ip, ix);
  end;

  find(dev, 'HP4140B');
  dsp_frame(video);
  ptmp := pars.Vb_start;
  ip := 0;
  finished := false;
  while (ip < dset.Np) and not finished do begin
      inc(ip);
      clear(dev);
      delay(1000);			(* Wait 1 second to allow clearing *)
      put(dev, 'F1I3RA1A5B1L3M3T2');
      put(dev, 'PB'+ftoa(ptmp,8,2)+';');
      dset.p[ip] := ptmp;
      dsp_message(video,'Reading curve '+ftoa(ip,3,0));
      xtmp := pars.Va_start;
      ix := 0;
      while (ix < (dset.Nx div 2)) do begin
	 xtmp := xtmp + pars.Va_step;
         inc(ix);
	 put(dev, 'PA'+ftoa(xtmp,8,2)+';');
	 put(dev, 'W1');		(* Output voltages *)
	 delay(dt);			(* Allow settling time *)
	 trigger(dev);
         get(dev, buf, -ord(LF));
	 put(dev, 'W7');		(* Switch off voltages *)
	 with dset do
	    extract_4140(buf, y[ip][ix], x[ix]);
         dsp_updates(video);
	 check_user_event(video,finished);
      end;
      delay(round(1000.0*pars.t_hold));
      while (ix < dset.Nx) do begin
         inc(ix);
         xtmp := xtmp - pars.Va_step;
	 put(dev, 'PA'+ftoa(xtmp,8,2)+';');
	 put(dev, 'W1');		(* Output voltages *)
	 delay(dt);			(* Allow settling time *)
	 trigger(dev);
         get(dev, buf, -ord(LF));
	 put(dev, 'W7');		(* Switch off voltages *)
	 with dset do
	    extract_4140(buf, y[ip][ix], x[ix]);
         dsp_updates(video);
	 check_user_event(video,finished);
      end;
      ptmp := ptmp + pars.Vb_step;
  end;
  put(dev, 'W7');
  dset.Np := ip;		(* Set to correct value if user aborted *)
  with dset do begin
     get_date(date);
     time := get_time;
     if (remarks[2] = '') then
        remarks[2] := p_label+' stepped from '+ftoa(pars.Vb_start,10,-1)+
		      ' to '+ftoa(pars.Vb_stop,10,-1)+' in steps of '+
		      ftoa(pars.Vb_step,10,-1);
  end;
  if not autoexit then
     play_graphics(video);
  undsp_frame(video);
end;

procedure CV_4140 (var pars:par_qcv; var dset:data_rec);
var
  ix, ip : index;
  video : tabloid;
  ptmp, xtmp, ytmp : value;
  finished : boolean;
  dev : device;
  code : integer;
  buf : string;
begin
  with dset do begin
     x_label := 'Va [V]';
     y_label := 'C [F]';
     p_label := 'dVa/dt [V/s]';
     with pars do begin
        if (odd(Nx)) then Nx := Nx + 1;
        Va_step  := abs(Va_stop - Va_start) / ((Nx div 2) + 1);
	xmin := lesser(Va_stop, Va_start) + Va_step;
	xmax := greater(Va_stop, Va_start) - Va_step;

	if (Np < 2) then Np := 2;
	r_step := abs(r_stop - r_start) / (Np - 1);
	pmin := lesser(r_stop, r_start);
	pmax := greater(r_stop, r_start);
     end;
     sort2(ymin,ymax);
     setup_graphics(video, xmin, xmax, ymin, ymax, false, false,
     			   remarks[0], remarks[1], x_label, y_label,
			   p, Np, x, Nx, y, ip, ix);
  end;

  find(dev, 'HP4140B');
  dsp_frame(video);

  ptmp := pars.r_start;
  ip := 0;
  finished := false;
  while (ip < dset.Np) and not finished do begin
      inc(ip);
      ix := 0;
      clear(dev);
      delay(1000);			(* Wait 1 second to allow clearing *)
      put(dev, 'F3I3RA1A2B2L3M1');
      with pars do begin
         put(dev, 'PS'+ftoa(Va_start,8,2)+';');
         put(dev, 'PT'+ftoa(Va_stop, 8,2)+';');
         put(dev, 'PE'+ftoa(Va_step, 8,2)+';');
         put(dev, 'PH'+ftoa(t_hold,  8,2)+';');
      end;
      put(dev, 'PV'+ftoa(ptmp,8,2)+';');
      dset.p[ip] := ptmp;
      dsp_message(video,'Reading curve '+ftoa(ip,3,0));
      put(dev, 'W1');
      while (ix < dset.Nx) do begin
	 inc(ix);
         get(dev, buf, -ord(LF));
	 with dset do begin
	    extract_4140(buf, y[ip][ix], x[ix]);
            dsp_updates(video);
	    check_user_event(video, finished);
	 end;
      end;
      ptmp := ptmp + pars.r_step;
  end;
  put(dev, 'W7');
  dset.Np := ip;		(* Set to correct value if user aborted *)
  with dset do begin
     get_date(date);
     time := get_time;
     if (remarks[2] = '') then
        remarks[2] := p_label+' stepped from '+ftoa(pars.r_start,10,-1)+
		      ' to '+ftoa(pars.r_stop,10,-1)+' in steps of '+
		      ftoa(pars.r_step,10,-1);
  end;
  if not autoexit then
     play_graphics(video);
  undsp_frame(video);
end;

procedure CV_4192 (var pars:par_4192; var dset:data_rec);
var
  ix, ip : index;
  video : tabloid;
  ptmp, xtmp, ytmp : value;
  finished : boolean;
  dev : device;
  code : integer;
  buf : string;
  dt : word;
begin
  with dset do begin
     x_label := 'V [V]';
     y_label := 'C [F]';
     p_label := 'log10(f [kHz])';

     with pars do begin
        dt := round(1000.0 * t_step);

        if (Nx < 2) then Nx := 2;
        V_step  := abs(V_stop - V_start) / (Nx - 1);
	xmin := lesser(V_stop, V_start);
	xmax := greater(V_stop, V_start);

	if (Np < 2) then Np := 2;
	f_step := abs(f_stop - f_start) / (Np - 1);
	pmin := lesser(f_stop, f_start);
	pmax := greater(f_stop, f_start);
     end;
     sort2(ymin,ymax);
     setup_graphics(video, xmin, xmax, ymin, ymax, false, false,
     			   remarks[0], remarks[1], x_label, y_label,
			   p, Np, x, Nx, y, ip, ix);
  end;

  find(dev, 'HP4192A');
  dsp_frame(video);

  ptmp := pars.f_start;
  ip := 0;
  finished := false;
  while (ip < dset.Np) and not finished do begin
      inc(ip);
      ix := 0;
      clear(dev);
      delay(1000);			(* Wait 1 second to allow clearing *)
      put(dev, 'ANBNA4B3W1F1T3');
      dset.p[ip] := ptmp;
      put(dev, 'FR'+ftoa(pow10(ptmp),8,2)+'EN');
      with pars do begin
         put(dev, 'OL'+ftoa(osc_level,8,2)+'EN');
         put(dev, 'TB'+ftoa(V_start,8,2)+'EN');
         put(dev, 'PB'+ftoa(V_stop, 8,2)+'EN');
         put(dev, 'SB'+ftoa(V_step, 8,2)+'EN');
      end;
      dsp_message(video,'Reading curve '+ftoa(ip,3,0));
      put(dev, 'W2');
      delay(round(1000.0*pars.t_hold));
      while (ix < dset.Nx) do begin
	 inc(ix);
	 put(dev, 'EX');
         get(dev, buf, -ord(LF));
	 with dset do begin
	    extract_4192(buf, y[ip][ix], x[ix]);
            dsp_updates(video);
	    check_user_event(video, finished);
	 end;
	 delay(dt);
      end;
      ptmp := ptmp + pars.f_step;
  end;
  put(dev, 'W3I0');
  dset.Np := ip;		(* Set to correct value if user aborted *)
  with dset do begin
     get_date(date);
     time := get_time;
     if (remarks[2] = '') then
        remarks[2] := p_label+' stepped from '+ftoa(pars.f_start,10,-1)+
		      ' to '+ftoa(pars.f_stop,10,-1)+' in steps of '+
		      ftoa(pars.f_step,10,-1);
  end;
  if not autoexit then
     play_graphics(video);
  undsp_frame(video);
end;

procedure plot_out (var dset:data_rec; x_log,y_log:boolean);
var
  video : tabloid;
  cmd : char;
  finished : boolean;
begin
  if (dset.ymax > dset.ymin) and (dset.xmax > dset.xmin) then begin
     with dset do begin
        if (xmin <= 0.0) then x_log := false;
        if (ymin <= 0.0) then y_log := false;
	setup_graphics(video, xmin, xmax, ymin, ymax, x_log, y_log,
			      remarks[0], remarks[1], x_label, y_label,
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
  ref_dir : string127;
  dset : data_rec;
  qcv   : par_qcv;
  pa_vs : par_4140;
  lf_ia : par_4192;

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
  writeln('date/time  = ',date_str(today,false),' at ',time_str(now,true));
  writeln('ref dir    = "',ref_dir,'"  work dir   = "',current_wdir,
  	  '"  file = "',save_path,'"');
  screen_bar;
  show_data_set(dset);
end;

procedure init_environment;
var
  i, code : integer;
  ix, ip : index;
begin
  autoexit := false;
  if exists_file(INITFILE) then begin
     source(INITFILE, code);
     if (code <> 0) then begin
        barf(INITFILE, problem(code));
	halt;
     end;
  end;
  data_saved := true;
  data_ranged := false;
  save_path := '';
  with dset do begin
     codever := CODE_VERSION;
     dataver := DATA_VERSION;
     get_date(date);
     time := get_time;
     x_label := 'abscissa';
     y_label := 'ordinate';
     p_label := 'parameter';
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
     t_hold   := 5.0;
     Va_start := -3.0;
     Va_stop  := 3.0;
     Va_step  := abs(Va_start - Va_stop) / ((dset.Nx div 2) + 1);
     r_start  := 0.1;
     r_stop   := 1.0;
     r_step   := abs(r_start - r_step) / (dset.Np - 1);
  end;
  with pa_vs do begin
     t_hold   := 5.0;
     t_step   := 0.5;
     Va_start := -3.0;
     Va_stop  := 3.0;
     Va_step  := abs(Va_start - Va_stop) / (dset.Nx - 1);
     Va_rate  := 0.1;
     Vb_start := -2.0;
     Vb_stop  := 2.0;
     Vb_step  := abs(Vb_stop - Vb_start) / (dset.Np - 1);
  end;
  with lf_ia do begin
     osc_level := 0.01;
     t_hold := 1.0;
     t_step := 0.5;
     V_start := -3.0;
     V_stop  :=  3.0;
     V_step  :=  abs(V_start - V_stop) / (dset.Nx - 1);
     f_start := -1.0;
     f_stop  :=  1.0;
     f_step  :=  abs(f_stop - f_start) / (dset.Np - 1);
  end;
end;

procedure read_file (var argc:integer; var argv:arglist);
var
  code : integer;
begin
  if (argc > 2) then
     barf('wrong number of arguments',ftoa(argc,2,0))
  else begin
     if (argc = 2) then
        save_path := argv[2];
     if (save_path <> '') then begin
        emit('Reading "'+save_path+'" ... ');
        read_binary(dset, save_path, code);
        if (code = 0) then begin
           emit('done.');
	   data_saved := true;
	   if (dset.dataver <> DATA_VERSION) then begin
	      barf('data version mismatch',dset.dataver);
	      beep;
	   end;
        end
        else
           barf(save_path, problem(code));
     end
     else
        barf('cannot read file','no filename!');
  end;
end;

procedure save_file (var argc:integer; var argv:arglist);
var
  i : integer;
  proceed, ascii, update : boolean;
  mode : byte;
  code : integer;
begin
  code := 0;
  mode := LINEAR;
  ascii := true;
  update := true;
  emit('Ranging data ...');
  find_limits(dset);
  emit('Ranging data ... done.');
  i := 2;
  while (i <= argc) do begin
     if (argv[i] = '-ascii') or (argv[i] = '-a') then
        ascii := true
     else if (argv[i] = '-semilog') or (argv[i] = '-sl') then begin
        ascii := true;
        mode := SEMILOG;
     end
     else if (argv[i] = '-loglog') or (argv[i] = '-ll') then begin
        ascii := true;
        mode := LOGLOG;
     end
     else if (argv[i] = '-binary') or (argv[i] = '-b') then
        ascii := false
     else if (argv[i] = '-x-') then begin
        inc(i);
	if (i <= argc) then
	   dset.xmin := atof(argv[i],code);
     end
     else if (argv[i] = '-x+') then begin
        inc(i);
	if (i <= argc) then
	   dset.xmax := atof(argv[i],code);
     end
     else if (argv[i] = '-y-') then begin
        inc(i);
	if (i <= argc) then
	   dset.ymin := atof(argv[i],code);
     end
     else if (argv[i] = '-y+') then begin
        inc(i);
	if (i <= argc) then
	   dset.ymax := atof(argv[i],code);
     end
     else if (argv[i] = '-no_update') or (argv[i] = '-nu') then begin
        update := false;
     end
     else if (argv[i] = '-file') or (argv[i] = '-f') then begin
        inc(i);
	if (i <= argc) then save_path := argv[i] else save_path := '';
     end
     else
        save_path := argv[i];
     inc(i);
  end;

  if (save_path = '') then
     barf('cannot save data','no filename!')
  else begin
     emit('Saving "'+save_path+'" ... ');
     proceed := not exists_file(save_path);
     if not proceed then proceed := user_confirm('File exists.  Overwrite?');
     if proceed then begin
        if (update) then begin
	   dset.codever := CODE_VERSION;
	   dset.dataver := DATA_VERSION;
	end;
	if (ascii) then begin
	   sort2(dset.ymin,dset.ymax);
	   sort2(dset.xmin,dset.xmax);
	   save_ascii(dset, mode, save_path, code);
	end
	else
	   save_binary(dset, save_path, code);

	if (code = 0) then begin
	   emit('done.');
	   data_saved := true;
	end
	else
	   barf(save_path, problem(code));
     end
     else
        emit('Saving operation aborted.');
  end;
end;

procedure screen_plot (var argc:integer; var argv:arglist);
var
  i, code : integer;
  log_x, log_y : boolean;
begin
  log_x := false;
  log_y := false;
  emit('Ranging data ... ');
  find_limits(dset);
  emit('done.');
  i := 2;
  while (i <= argc) do begin
     if (argv[i] = '-x-') then begin
        inc(i);
	if (i > argc) then
	   barf('not enough arguments for option', '-xl')
	else
           dset.xmin := atof(argv[i],code);
     end
     else if (argv[i] = '-x+') then begin
        inc(i);
	if (i > argc) then
	   barf('not enough arguments for option', '-xh')
	else
           dset.xmax := atof(argv[i],code);
     end
     else if (argv[i] = '-y-') then begin
        inc(i);
	if (i > argc) then
	   barf('not enough arguments for option', '-yl')
	else
           dset.ymin := atof(argv[i],code);
     end
     else if (argv[i] = '-y+') then begin
        inc(i);
	if (i > argc) then
	   barf('not enough arguments for option', '-yh')
	else
           dset.ymax := atof(argv[i],code);
     end
     else if (argv[i] = '-lx') then begin
        log_x := true;
     end
     else if (argv[i] = '-ly') then begin
        log_y := true;
     end;
     inc(i);
  end;
  with dset do begin
     sort2(xmin,xmax);
     sort2(ymin,ymax);
  end;
  plot_out(dset, log_x, log_y);
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
  with pars do begin
     writeln('VA: start = ',Va_start:10,'; stop = ',Va_stop:10,
     	     '; step = ',Va_step:10);
     writeln('VB: start = ',Vb_start:10,'; stop = ',Vb_stop:10,
     	     '; step = ',Vb_step:10);
     writeln('Hold time = ',t_hold:10,'; Step delay time = ',t_step:10);
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

begin
  dset.ymax := 1.0e-2;			(*  10 mA *)
  dset.ymin := -1.0e-2;			(* -10 mA *)
  repeat
     quit := false;
     list_menu(IV_menu);
     screen_bar;
     show_environment(pars, dset);
     cmd := get_cmdline(IV_menu, argc, argv);
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
	     quit := true;
	  end;
       CMD_HELP:
          begin
	     list_requests(IV_menu, argc, argv);
	  end;
       CMD_PLOT:
          if check_safety(data_saved) then begin
	     screen_plot(argc, argv);
	  end;
       CMD_DO:
          begin
	     IV_4140(pars,dset);
	     data_saved := false;
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
	     dset.Nx := round(lesser(max_points,abs(get_value(argc, argv))));
	  end;
       CMD_NP:
          begin
	     dset.Np := round(lesser(max_params,abs(get_value(argc, argv))));
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
       CMD_COMMENT:
          begin
	     dset.remarks[abs(atoi(argv[2],code)) mod 3] :=
	        get_string(3,argc,argv);
 	  end;
       else
          begin
	     barf('not implemented',argv[1]);
	  end;
     end; (* case *)
  until quit;
end;

procedure QCV_loop (var pars:par_qcv; var dset:data_rec);

procedure show_environment (var pars:par_qcv; var dset:data_rec);
begin
  with pars do begin
     writeln('Va    : start = ',Va_start:10,'; stop = ',Va_stop:10,
     	     '; step = ',Va_step:10);
     writeln('dVa/dt: start = ',r_start:10,'; stop = ',r_stop:10,
     	     '; step = ',r_step:10);
     writeln('Hold time = ',t_hold:10);
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

begin
  dset.ymax := 2.0e-9;			(* 2000 pF *)
  dset.ymin := 2.0e-20;			(* Bad-value *)
  repeat
     quit := false;
     list_menu(QCV_menu);
     screen_bar;
     show_environment(pars,dset);
     cmd := get_cmdline(QCV_menu, argc, argv);
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
	      quit := true;
	   end;
	CMD_HELP:	
	   begin
	      list_requests(QCV_menu, argc, argv);
	   end;
        CMD_PLOT:
           if check_safety(data_saved) then begin
	      screen_plot(argc, argv);
	   end;
	CMD_DO:
	   begin
	      CV_4140 (pars, dset);
	      data_saved := false;
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
	      dset.Nx := round(lesser(max_points,abs(get_value(argc,argv))));
	   end;
	CMD_NP:
	   begin
	      dset.Np := round(lesser(max_params,abs(get_value(argc,argv))));
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
	      pars.t_hold := abs(get_value(argc,argv));
	   end;
        CMD_COMMENT:
           begin
	     dset.remarks[abs(atoi(argv[2],code)) mod 3] :=
	        get_string(3,argc,argv);
 	   end;
	else
	   begin
	      barf('not implemented', argv[1]);
	   end;
     end;
  until quit;
end;


procedure CV_loop (var pars:par_4192; var dset:data_rec);

procedure show_environment(var pars:par_4192; var dset:data_rec);
begin
  with pars do begin
     writeln('Bias V: start = ',V_start:10,'; stop = ',V_stop:10,
     	     '; step = ',V_step:10);
     writeln('Spot f: start = ',pow10(f_start):10,
     	     '; stop = ',pow10(f_stop):10,
             '; mult. step = ',pow10(f_step):10);
     writeln('Oscillator level = ',osc_level:10);
     writeln('Hold time = ',t_hold:10,'; Step delay time = ',t_step:10);
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
begin
  dset.ymax := 1.0e-10;		(* 100 pF *)
  dset.ymin := 1.0e-15;		(*   1 fF *)
  repeat
     quit := false;
     list_menu(CV_menu);
     screen_bar;
     show_environment(pars, dset);
     cmd := get_cmdline(CV_menu, argc, argv);
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
	      quit := true;
	   end;
	CMD_HELP:
	   begin
	      list_requests(CV_menu, argc, argv);
	   end;
        CMD_PLOT:
	   if check_safety(data_saved) then begin
	      screen_plot(argc, argv);
	   end;
	CMD_DO:
	   begin
	      CV_4192(pars,dset);
	      data_saved := false;
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
	      dset.Nx := round(lesser(max_points,abs(get_value(argc, argv))));
	   end;
	CMD_NP:
	   begin
	      dset.Np := round(lesser(max_params,abs(get_value(argc, argv))));
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
	      pars.f_start := log10(greater(5e-3,abs(get_value(argc,argv))));
	   end;
	CMD_P2:
	   begin
	      pars.f_stop  := log10(greater(5e-3,abs(get_value(argc,argv))));
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
        CMD_COMMENT:
           begin
	     dset.remarks[abs(atoi(argv[2],code)) mod 3] :=
	        get_string(3,argc,argv);
 	   end;
	else
	   begin
	      barf('not implemented', argv[1]);
	   end;
     end;
  until quit;
end;

procedure modify_loop (var dset:data_rec);
var
   argv : arglist;
   argc : integer;
   code : integer;
   quit : boolean;
   cmd  : cmd_enum;
   ip, ix : index;
   delta, scale : extended;
   i : integer;
begin
  repeat
     scale := 1.0;
     quit := false;
     list_menu(modify_menu);
     screen_bar;
     show_data_set(dset);
     cmd := get_cmdline(modify_menu, argc, argv);
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
	      quit := true;
	   end;
	CMD_HELP:
	   begin
	      list_requests(modify_menu, argc, argv);
	   end;
        CMD_PLOT:
	   if check_safety(data_saved) then begin
	      screen_plot(argc, argv);
	   end;
        CMD_COMMENT:
           begin
	     dset.remarks[abs(atoi(argv[2],code)) mod 3] :=
	        get_string(3,argc,argv);
 	   end;
	CMD_SCALE_X:
	   with dset do begin
	      data_saved := false;
	      scale := 1.0;
	      for i := 2 to argc do
	         scale := scale * atof(argv[i],code);
	      for ix := 1 to Nx do
	         x[ix] := x[ix] * scale;
	      find_limits(dset);
	      x_label := ftoa(scale,9,-1)+' * ('+x_label+')';
	   end;
	CMD_SCALE_Y:
	   with dset do begin
	      data_saved := false;
	      scale := 1.0;
	      for i := 2 to argc do
	         scale := scale * atof(argv[i],code);
	      for ip := 1 to Np do
	         for ix := 1 to Nx do
		    y[ip][ix] := y[ip][ix] * scale;
	      find_limits(dset);
	      y_label := ftoa(scale,9,-1)+' * ('+y_label+')';
	   end;
	CMD_SCALE_P:
	   with dset do begin
	      data_saved := false;
	      scale := 1.0;
	      for i := 2 to argc do
	         scale := scale * atof(argv[i],code);
	      for ip := 1 to Np do
	         p[ip] := p[ip] * scale;
	      find_limits(dset);
	      p_label := ftoa(scale,9,-1)+' * ('+p_label+')';
	   end;
	CMD_DYDX:
	   with dset do begin
	      data_saved := false;
	      Nx := Nx - 1;
	      for ip := 1 to Np do
	         for ix := 1 to Nx do begin
		    delta := x[ix+1] - x[ix];
		    if (delta <> 0.0) then
		       y[ip][ix] := (y[ip][ix+1] - y[ip][ix]) / delta
		    else
		       y[ip][ix] := 1.0;
		 end;
	      for ix := 1 to Nx do
	         x[ix] := 0.5 * (x[ix] + x[ix+1]);
	      find_limits(dset);
	      y_label := 'd('+y_label+')/d('+x_label+')';
	   end;
	CMD_DYDP:
	   with dset do begin
	      data_saved := false;
	      Np := Np - 1;
	      for ix := 1 to Nx do
	         for ip := 1 to Np do begin
		    delta := p[ip+1] - p[ip];
		    if (delta <> 0.0) then
		       y[ip][ix] := (y[ip+1][ix] - y[ip][ix]) / delta
		    else
		       y[ip][ix] := 1.0;
		 end;
	      for ip := 1 to Np do
	         p[ip] := 0.5 * (p[ip] + p[ip+1]);
	      find_limits(dset);
	      y_label := 'd('+y_label+')/d('+p_label+')';
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

begin
  TextBackground(Black);
  TextColor(Yellow);
  ref_dir := site.home_dir + '\';
  (*
   * Put up any initial messages on the screen
   *)
  writeln('Welcome to MOS.');
  writeln('Code ',CODE_VERSION,';  Data format ',DATA_VERSION,'.');
  writeln('See ghst659 you find bugs/problems.');
  delay(3000);
  init_environment;
  repeat
     quit := false;
     list_menu(top_level);
     screen_bar;
     show_environment;
     cmd := get_cmdline (top_level, argc, argv);
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
             quit := check_safety(data_saved);
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
		   barf(argv[2], problem(code));
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
       CMD_IV4140:
          if check_safety(data_saved) then begin
	     IV_loop (pa_vs, dset);
	  end;
       CMD_CV4140:
          if check_safety(data_saved) then begin
	     QCV_loop (qcv, dset);
	  end;
       CMD_CV4192:
          if check_safety(data_saved) then begin
	     CV_loop (lf_ia, dset);
	  end;
       CMD_PLOT:
          if check_safety(data_saved) then begin
	     screen_plot(argc, argv);
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
	        source('',code)
	     else
	        source(argv[2],code);
	  end;
       else
          begin
             barf('not implemented',argv[1]);
          end;
     end; (* case *)
  until quit;
end.
