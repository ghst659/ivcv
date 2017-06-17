program MOSIVCV;
(*
 * MOS characterization program.
 *
 * The program consists of three parts:
 *      - a shell structure (command parser & text user interface) to handle
 *        top level user commands
 *      - a graphics unit (curves) which deals with the graphical display of
 *        dynamically changing data.
 *      - a simplified interface to the National Instruments NI-488 software
 *        library for GPIB.
 *)

uses
  dos, crt, generics, site, rt_error, values, gpib, curves;

const
  WHOAMI = 'MOSIVCV';

(****************************************************************************
 * TEXT WINDOW CONTROL
 * Make the user interface a little slick...
 *)

function hexstr(b:integer) : string7;
const
  chars:array[0..$0F] of char = ('0','1','2','3','4','5','6','7',
                                 '8','9','A','B','C','D','E','F');
var
  s : string7;
begin
  s[0] := #4;
  s[1] := chars[(b shr 12) and $0F];
  s[2] := chars[(b shr  8) and $0F];
  s[3] := chars[(b shr  4) and $0F];
  s[4] := chars[ b         and $0F];
  hexstr := s;
end;

procedure emit (s:string);
begin
  clrln(25);
  write(s);
end;

procedure barf (arg1,arg2:string63);
begin
  emit('ERROR: '+arg1+': '+arg2);
end;

procedure clrwin;
var i:byte;
begin
  Window(1,1,80,23);
  ClrScr;
  Window(1,1,80,25);
end;

procedure banner (s:string127);
begin
  clrwin;
  writeln(s);
  screen_bar;
end;

function get_kbd_char : char;
var c : char;
begin
  c := ReadKey;
  if (ord(c) = 0) then
     c := ReadKey; 
  get_kbd_char := c;
end;

function local_confirm (prompt:string) : boolean;
begin
  clrln(24);
  TextColor(Cyan);
  local_confirm := generics.confirm(prompt);
  TextColor(Yellow);
end;

function local_input_line (prompt:string) : string;
begin
  clrln(24);
  TextColor(Cyan);
  local_input_line := generics.input_line(prompt);
  TextColor(Yellow);
  clrln(25);
end;
(*****************************************************************************
 * COMMAND DEFINITION
 * This section defines the data and control structures used to parse user
 * commands.
 *)
const
  max_args = 10;                        (* Number of command-line args *)
  prompt = 'Enter command:';
  N_CMDS = 11;
type
  string127 = string[63];
  doc_string = string127;
  cmd_enum = ( CMD_QUIT,
               CMD_STAT,
               CMD_SET,
               CMD_HELP,
               CMD_SAVE,
	       CMD_IV4140,
	       CMD_CV4140,
	       CMD_PLOT,
               CMD_DIR,
               CMD_ERASE,
               CMD_NOOP,
               CMD_UNKNOWN );
  cmd_node = record
               tags:array[1..2] of string31;
               code:cmd_enum;
               doc:doc_string;
             end;
  cmd_array = array[1..N_CMDS] of cmd_node;

const
  command_alist:cmd_array =
  ((tags:('quit','q');
    code:CMD_QUIT;
    doc:'quit out of command loop'),
   (tags:('help','?');
    code:CMD_HELP;
    doc:'list available commands'),
   (tags:('set','s');
    code:CMD_SET;
    doc:'set value of a variable'),
   (tags:('status','st');
    code:CMD_STAT;
    doc:'show status and variables'),
   (tags:('save','sv');
    code:CMD_SAVE;
    doc:'save current data set'),
   (tags:('iv4140','iv');
    code:CMD_IV4140;
    doc:'take I-V curves on HP4140B'),
   (tags:('cv4140','qcv');
    code:CMD_CV4140;
    doc:'take C-V curves on HP4140B'),
   (tags:('cv4192','cv');
    code:CMD_CV4192;
    doc:'take C-V curves on HP4192A');
   (tags:('plot','pt');
    code:CMD_PLOT;
    doc:'plot out current data set'),
   (tags:('directory', 'dir');
    code:CMD_DIR;
    doc:'list contents of working directory'),
   (tags:('erase','delete');
    code:CMD_ERASE;
    doc:'erase a file (be careful!)')
  );

function get_cmdline (var argc:integer; var argv:arglist) : cmd_enum;
var
  linebuf : string;
  bi, ti, linelen : integer;
  cmd : cmd_enum;
  found : boolean;
begin
  linebuf := local_input_line(prompt);
  argc := parse(linebuf,argv,std_white,['=','?','!',';'],'''','"');
  if (argc < 1) then
     cmd := CMD_NOOP
  else begin
     bi := 1;
     found := false;
     cmd := CMD_UNKNOWN;
     while (not found) and (bi <= N_CMDS) do begin
        ti := 1;
        while (not found) and (ti <= 2) do begin
           if (argv[1] = command_alist[bi].tags[ti]) then begin
              cmd := command_alist[bi].code;
              found := true;
           end;
           ti := ti + 1;
        end;
        bi := bi + 1;
     end;
  end;
  get_cmdline := cmd;
end;

(*****************************************************************************
 * BASIC USER REQUESTS
 * These user utilities are generic, and not specific to the applicaton for
 * which the shell is being used.
 *)

procedure list_requests(var argc:integer; var argv:arglist);
var 
  i, row : integer;
begin
  banner('List of Commands');
  for i := 1 to N_CMDS do begin
     row := wherey;
     write(command_alist[i].tags[1],', ',command_alist[i].tags[2]);
     gotoxy(30,row);
     writeln(command_alist[i].doc);
  end;
end;

procedure list_directory (var argc:integer; var argv:arglist);
var
  i:integer;
begin
  banner('Directory Listing');
  if (argc = 1) then
     list_cwd ('*.*')
  else
     for i := 2 to argc do
        list_cwd (argv[i]);
end;

procedure remove_files (var argc:integer; var argv:arglist);
var
  i, code : integer;
  f : file;
begin
  for i := 2 to argc do begin
    write('Erasing "',argv[i],'" ... ');
    code := erase_file(argv[i]);
    if (code <> 0) then
       write(rt_error.problem(code))
    else
       write('done.');
  end;
end;

function check_safety (flag:boolean) : boolean;
begin
  if flag then
     check_safety := true
  else if local_confirm ('Data not saved.  Are you sure?') then
     check_safety := true
  else
     check_safety := false;
end;

(****************************************************************************
 * DATA TYPE DEFINITIONS
 *
 * This section simply defines a data set as a type, which contains all of
 * the interesting information on the data sets being taken,
 * which will allow the entire data set to be passed around the program 
 * more conveniently.
 *)
type
  data_rec = record
                IC : valarrarr;
                ICmax, ICmin : value;

                Va : valarr;
                Vamax, Vamin : value;
                Na : index;

                Vb : pararr;
                Vbmax, Vbmin : value;
                Nb : index;

                x_label, y_label, p_label : string63;
                remarks : array[0..2] of string[84];
                time_stamp : time_t;
		x_log, y_log : boolean;
             end;

  pars4140 = record
  		Va_start, Va_stop, Va_step, Va_rate : single;
		t_hold, t_step : single;
		Vb_start, Vb_stop, Vb_step : single;
  	     end;
  pars4192 = record
  		Vdc_start, Vdc_stop, Vdc_step : single;
		f_start, f_stop, f_step : single;
		osc_level : single;
  	     end;

procedure find_limits (var dset:data_rec);
var
  ia, ib : index;
begin
  with dset do begin
     Vbmin := Vb[1];
     Vbmax := Vb[1];
     Vamin := Va[1];
     Vamax := Va[1];
     ICmin := IC[1][1];
     ICmax := IC[1][1];
     for ib := 2 to Nb do begin
        Vbmin := lesser(Vbmin, Vb[ib]);
	Vbmax := greater(Vbmax, Vb[ib]);
     end;
     for ia := 2 to Na do begin
        Vamin := lesser(Vamin, Va[ia]);
	Vamax := greater(Vamax, Va[ia]);
     end;
     for ib := 1 to Nb do begin
        for ia := 1 to Na do begin
	   ICmin := lesser(ICmin, IC[ib][ia]);
	   ICmax := greater(ICmax, IC[ib][ia]);
	end;
     end;
  end;
end;

(****************************************************************************
 * DATA SAVING ROUTINES
 * 
 * This deals with saving data to diskette.
 *)

procedure save_ascii (var d:data_rec; path:string127; var code:integer);
var
  ia, ib : index;
  f : text;
  proceed : boolean;
begin
  proceed := not exists_file(path);
  if not proceed then
     proceed := local_confirm('File exists.  Overwrite?');
  if proceed then begin
     assign(f, path);
     {$i-}
     rewrite(f);
     code := IOResult;
     {$i+}
     if (code = 0) then begin
        with d do begin
	   writeln(f, 'title ',remarks[0]);
	   writeln(f, 'title ',remarks[1]);
	   writeln(f, 'title ',remarks[2]);

	   write  (f, 'linear');
	   write  (f, ' xmin=',Vamin,' xmax=',Vamax);
	   writeln(f, ' ymin=',ICmin,' ymax=',ICmax);

	   writeln(f, 'xlabel ',x_label);
	   writeln(f, 'ylabel ',y_label);

	   write  (f, 'read comfile=true');
	   write  (f, ' xexp=Va');
	   write  (f, ' yexp=IC');
	   write  (f, ' family=Vb');
	   writeln(f, ' numpoints=',Nb*Na);

	   writeln(f, '.par Vb');
	   writeln(f, '.col IC Va');
	   for ib := 1 to Nb do begin
	      writeln(f, '.set Vb ',Vb[ib]);
	      for ia := 1 to Na do begin
	         writeln(f, IC[ib][ia],'        ',Va[ia]);
	      end;
	   end;
	   writeln(f, '.end');
	   write  (f, 'plot curve');
	   write  (f, ' color=forground');
	   write  (f, ' linestyle=next');
	   writeln(f, ' symbol=wedge');
	end;
	close(f);
     end
     else
        complain(code, 'opening file', path);
  end
  else
     emit('Save aborted.');
end;

(****************************************************************************
 * GPIB DATA ACQUISITION AND DYNAMIC PLOTTING ROUTINES
 * These routines perform the actual data acquisition, and plot the results
 * dynamically on the screen (hopefully!).
 *)

procedure extract_values (var s:string; var y,x:value);
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

procedure setup_graphics(var video:tabloid;
			 Vamin,Vamax,ICmin,ICmax:value;
			 title_1,title_2,x_label,y_label:string127;
			 var Vb:pararr;
			 var Nb:index;
			 var Va:valarr;
			 var Na:index;
			 var IC:valarrarr;
			 var ib,ia:index);
begin
  set_regions(video);
  set_limits(video, Vamin, Vamax, ICmin, ICmax);
  set_flags (video, false, false, false);
  set_bounds(video);
  set_static_data(video, title_1, title_2, x_label, y_label);
  set_dynamic_data(video, Vb, Nb, Va, Na, IC);
  set_dynamic_ptrs(video, ib, ia);
end;

procedure IV_4140 (var pars:pars4140; var dset:data_rec);
var
  ia, ib : index;
  video : tabloid;
  Vbtmp, Vatmp, ICtmp : value;
  cmd : char;
  finished : boolean;
  dev : gpib.device;
  code : integer;
  buf : string;
begin
  (*
   * Set up video display & HP4140...
   *)
  with dset do begin
     x_label := 'Va [V]';
     y_label := 'I [A]';
     p_label := 'Vb [V]';
     with pars do begin
        Va_step  := abs(Va_stop - Va_start) / (Na - 1);
	Vamin := lesser(Va_stop, Va_start);
	Vamax := greater(Va_stop, Va_start);

	Vb_step := abs(Vb_stop - Vb_start) / (Nb - 1);
	Vbmin := lesser(Vb_stop, Vb_start);
	Vbmax := greater(Vb_stop, Vb_start);
     end;

     setup_graphics(video, Vamin, Vamax, ICmin, ICmax,
     			   remarks[0], remarks[1], x_label, y_label,
			   Vb, Nb, Va, Na, IC, ib, ia);
  end;

  find(dev, 'HP4140B');
  dsp_frame(video);

  (*
   * Here we start the actual data acquisition, and dynamically update the
   * video display.
   *)
  Vbtmp := pars.Vb_start;
  ib := 0;
  finished := false;
  while (ib < dset.Nb) and not finished do begin
      inc(ib);
      ia := 0;
      clear(dev);
      delay(1000);			(* Wait 1 second to allow clearing *)
      put(dev, 'F2I3RA1A3B1L3M3');
      with pars do begin
         put(dev, 'PS'+ftoa(Va_start,8,2)+';');
         put(dev, 'PT'+ftoa(Va_stop, 8,2)+';');
         put(dev, 'PE'+ftoa(Va_step, 8,2)+';');
         put(dev, 'PV'+ftoa(Va_rate, 8,2)+';');
         put(dev, 'PH'+ftoa(t_hold,  8,2)+';');
         put(dev, 'PD'+ftoa(t_step,  8,2)+';');
      end;
      put(dev, 'PB'+ftoa(Vbtmp,8,2)+';');
      dset.Vb[ib] := Vbtmp;
      put(dev, 'W1');
      while (ia < dset.Na) do begin
	 inc(ia);
         get(dev, buf, -ord(LF));
	 with dset do begin
	    extract_values(buf, IC[ib][ia], Va[ia]);
            dsp_updates(video);
	    if keypressed then begin
	       cmd := get_kbd_char;
	       if (cmd = ESC) then
	          finished := true
	       else
	          act_event(video, cmd);
	    end;
	 end;
      end;
      Vbtmp := Vbtmp + pars.Vb_step;
  end;
  put(dev, 'W7');
  dset.Nb := ib;		(* Set to correct value if user aborted *)
  (*
   * Data acquisition is finished.  Now we just let the user play with the
   * display until he gets tired of it...
   *)
  dsp_message(video,'Data acquisition finished.');
  repeat
     finished := false;
     cmd := get_kbd_char;
     if (cmd in ['q','Q']) then
        finished := true
     else
        act_event(video, cmd);
  until finished;
  undsp_frame(video);
end;

procedure CV_4140 (var pars:pars4140; var dset:data_rec);
var
  ia, ib : index;
  video : tabloid;
  Vbtmp, Vatmp, ICtmp : value;
  cmd : char;
  finished : boolean;
  dev : gpib.device;
  code : integer;
  buf : string;
begin
  (*
   * Set up video display & HP4140...
   *)
  with dset do begin
     x_label := 'Va [V]';
     y_label := 'C [F]';
     p_label := 'Vb [V]';
     with pars do begin
        Va_step  := abs(Va_stop - Va_start) / (Na + 1);
	Vamin := lesser(Va_stop, Va_start) + Va_step;
	Vamax := greater(Va_stop, Va_start) - Va_step;

	Vb_step := abs(Vb_stop - Vb_start) / (Nb - 1);
	Vbmin := lesser(Vb_stop, Vb_start);
	Vbmax := greater(Vb_stop, Vb_start);
     end;

     setup_graphics(video, Vamin, Vamax, ICmin, ICmax,
     			   remarks[0], remarks[1], x_label, y_label,
			   Vb, Nb, Va, Na, IC, ib, ia);
  end;

  find(dev, 'HP4140B');
  dsp_frame(video);
  (*
   * Here we start the actual data acquisition, and dynamically update the
   * video display.
   *)
  Vbtmp := pars.Vb_start;
  ib := 0;
  finished := false;
  while (ib < dset.Nb) and not finished do begin
      inc(ib);
      ia := 0;
      clear(dev);
      delay(1000);			(* Wait 1 second to allow clearing *)
      put(dev, 'F3I3RA1A1B1L3M3');
      with pars do begin
         put(dev, 'PS'+ftoa(Va_start,8,2)+';');
         put(dev, 'PT'+ftoa(Va_stop, 8,2)+';');
         put(dev, 'PE'+ftoa(Va_step, 8,2)+';');
         put(dev, 'PV'+ftoa(Va_rate, 8,2)+';');
         put(dev, 'PH'+ftoa(t_hold,  8,2)+';');
         put(dev, 'PD'+ftoa(t_step,  8,2)+';');
      end;
      put(dev, 'PB'+ftoa(Vbtmp,8,2)+';');
      dset.Vb[ib] := Vbtmp;
      put(dev, 'W1');
      while (ia < dset.Na) do begin
	 inc(ia);
         get(dev, buf, -ord(LF));
	 with dset do begin
	    extract_values(buf, IC[ib][ia], Va[ia]);
            dsp_updates(video);
	    if keypressed then begin
	       cmd := get_kbd_char;
	       if (cmd = ESC) then
	          finished := true
	       else
	          act_event(video, cmd);
	    end;
	 end;
      end;
      Vbtmp := Vbtmp + pars.Vb_step;
  end;
  put(dev, 'W7');
  dset.Nb := ib;		(* Set to correct value if user aborted *)
  (*
   * Data acquisition is finished.  Now we just let the user play with the
   * display until he gets tired of it...
   *)
  dsp_message(video,'Data acquisition finished.');
  repeat
     finished := false;
     cmd := get_kbd_char;
     if (cmd in ['q','Q']) then
        finished := true
     else
        act_event(video, cmd);
  until finished;
  undsp_frame(video);
end;

procedure CV_4192 (var pars:pars4192; var dset:data_rec);
var
  ia, ib : index;
  video : tabloid;
  Vbtmp, Vatmp, ICtmp : value;
  cmd : char;
  finished : boolean;
  dev : gpib.device;
  code : integer;
  buf : string;
begin
  (*
   * Set up video display & HP4192...
   *)
  with dset do begin
     x_label := 'Va [V]';
     y_label := 'C [F]';
     p_label := 'Vb [V]';
     with pars do begin
        Vdc_step  := abs(Vdc_stop - Vdc_start) / (Na - 1);
	Vamin := lesser(Vdc_stop, Vdc_start);
	Vamax := greater(Vdc_stop, Vdc_start);

	Vb_step := abs(Vb_stop - Vb_start) / (Nb - 1);
	Vbmin := lesser(Vb_stop, Vb_start);
	Vbmax := greater(Vb_stop, Vb_start);
     end;

     setup_graphics(video, Vamin, Vamax, ICmin, ICmax,
     			   remarks[0], remarks[1], x_label, y_label,
			   Vb, Nb, Va, Na, IC, ib, ia);
  end;

  find(dev, 'HP4140B');
  dsp_frame(video);
  (*
   * Here we start the actual data acquisition, and dynamically update the
   * video display.
   *)
  Vbtmp := pars.Vb_start;
  ib := 0;
  finished := false;
  while (ib < dset.Nb) and not finished do begin
      inc(ib);
      ia := 0;
      clear(dev);
      delay(1000);			(* Wait 1 second to allow clearing *)
      put(dev, 'F3I3RA1A1B1L3M3');
      with pars do begin
         put(dev, 'PS'+ftoa(Va_start,8,2)+';');
         put(dev, 'PT'+ftoa(Va_stop, 8,2)+';');
         put(dev, 'PE'+ftoa(Va_step, 8,2)+';');
         put(dev, 'PV'+ftoa(Va_rate, 8,2)+';');
         put(dev, 'PH'+ftoa(t_hold,  8,2)+';');
         put(dev, 'PD'+ftoa(t_step,  8,2)+';');
      end;
      put(dev, 'PB'+ftoa(Vbtmp,8,2)+';');
      dset.Vb[ib] := Vbtmp;
      put(dev, 'W1');
      while (ia < dset.Na) do begin
	 inc(ia);
         get(dev, buf, -ord(LF));
	 with dset do begin
	    extract_values(buf, IC[ib][ia], Va[ia]);
            dsp_updates(video);
	    if keypressed then begin
	       cmd := get_kbd_char;
	       if (cmd = ESC) then
	          finished := true
	       else
	          act_event(video, cmd);
	    end;
	 end;
      end;
      Vbtmp := Vbtmp + pars.Vb_step;
  end;
  put(dev, 'W7');
  dset.Nb := ib;		(* Set to correct value if user aborted *)
  (*
   * Data acquisition is finished.  Now we just let the user play with the
   * display until he gets tired of it...
   *)
  dsp_message(video,'Data acquisition finished.');
  repeat
     finished := false;
     cmd := get_kbd_char;
     if (cmd in ['q','Q']) then
        finished := true
     else
        act_event(video, cmd);
  until finished;
  undsp_frame(video);
end;

procedure plot_out (var dset:data_rec);
var
  video : tabloid;
  cmd : char;
  finished : boolean;
begin
  emit('Ranging data ... ');
  find_limits(dset);
  emit('done.');
  with dset do
     setup_graphics(video, Vamin, Vamax, ICmin, ICmax,
     			   remarks[0], remarks[1], x_label, y_label,
			   Vb, Nb, Va, Na, IC, Nb, Na);
  dsp_frame(video);
  dsp_curves(video);
  repeat
     finished := false;
     cmd := get_kbd_char;
     if (cmd in ['q','Q']) then
        finished := true
     else
        act_event(video, cmd);
  until finished;
  undsp_frame(video);
end;

(****************************************************************************
 * GLOBAL STATE VARIABLES AND MANIPULATORS
 * These variables reflect the internal state of the program, and are
 * manipulated by commands such as SET, and displayed by such commands as
 * STATUS.
 *)

var
  today : date_rec;
  save_path : string[63];
  data_saved : boolean;
  data_ranged : boolean;
  ref_dir : string127;
  dset : data_rec;
  ivpars : pars4140;

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

  banner('Program Status');
  writeln('date/time  = ',date_str(today,false),' at ',time_str(now,true));
  writeln('ref dir    = "',ref_dir,'"');
  writeln('work dir   = "',current_wdir,'"   file = "',save_path,'"');
  writeln('data saved = ',data_saved);
  screen_bar;
  with ivpars do begin
     writeln('Parameter   Start        Stop        Step        Rate  ');
     screen_bar;
     writeln('  Va     ',Va_start:9,'   ',Va_stop:9,'   ',
     			 Va_step:9,' ',Va_rate:9);
     writeln('  Vb     ',Vb_start:9,'   ',Vb_stop:9,'   ',
     			 Vb_step:9,'  ','--------');
     writeln('t_hold = ',t_hold:7:2,' s.  t_step = ',t_step:7:2,' s.');
  end;
  screen_bar;
  with dset do begin
     writeln('    Min         Max     Number  Label');
     screen_bar;
     writeln(Vamin:10,'  ', Vamax:10,'  ',Na:4,'    ',x_label);
     writeln(ICmin:10,'  ', ICmax:10,'  ',Na*Nb:4,'    ',y_label);
     writeln(Vbmin:10,'  ', Vbmax:10,'  ',Nb:4, '    ',p_label);
     for i := 0 to 2 do
        writeln('<',i,'> ',remarks[i]);
  end;
end;

procedure init_environment;
var
  arg : string[63];
  i, code : integer;
  ia, ib : index;
begin
  if (paramcount = 1) then begin
     arg := paramstr(1);
     assign(input, arg);
     {$i-}
     reset(input); code := ioresult;
     {$i+}
     if (code <> 0) then begin
        rt_error.complain(code, WHOAMI, arg);
        halt;
     end;
  end
  else if (paramcount > 1) then begin
     writeln('usage: ',WHOAMI,' [command_file_name]');
     halt;
  end;
  data_saved := true;
  data_ranged := false;
  save_path := '';
  with dset do begin
     x_label := 'x data';
     y_label := 'y data';
     p_label := 'p data';
     remarks[0] := 'MOSFET Characterization data';
     remarks[1] := 'Test Runs';
     remarks[2] := '';
     ICmin := -1e-15;
     ICmax := -1.5e-2;
     Vamin := 1.0;
     Vamax := 10.0;
     Vbmin := 1e-3;
     Vbmax := 5.0;
     Na := max_points;
     Nb := max_params;
     for ia := 1 to max_points do
        Va[ia] := 0.0;
     for ib := 1 to max_params do begin
        for ia := 1 to max_points do
	   IC[ib][ia] := 0.0;	
	Vb[ib] := 0.0;
     end;
  end;
  with ivpars do begin
     t_hold   := 5.0;
     t_step   := 0.5;
     Va_start := 0.0;
     Va_stop  := 2.0;
     Va_step  := 0.0;
     Va_rate  := 0.0;
     Vb_start := -4.0;
     Vb_stop  := 0.0;
     Vb_step  := 0.0;
  end;
end;

procedure set_variable (var argc:integer; var argv:arglist);
var
   i, code : integer;
begin
   if (argc < 3) then
      barf('set_variable','too few args')
   else begin
      (*
       * Program variables
       *)
      if (argv[2] = 'ref_dir') or (argv[2] = 'rd') then begin
	ref_dir := argv[argc];
	if (ref_dir[length(ref_dir)] <> '\') then
	   ref_dir := ref_dir + '\';
      end
      else if (argv[2] = 'file') then begin
        save_path := argv[argc];
        data_saved := false;
      end
      else if (argv[2] = 'work_dir') or (argv[2] = 'wd') then begin
         {$i-}
         chdir(argv[argc]); code := ioresult;
         {$i+}
         if (code <> 0) then
            barf(argv[argc], rt_error.problem(code));
      end
      (*
       * Run Data Variables
       *)
      else if (argv[2] = 't_hold') or (argv[2] = 'th') then begin
         ivpars.t_hold := abs(atof(argv[argc],code));
      end
      else if (argv[2] = 't_step') or (argv[2] = 'ts') then begin
         ivpars.t_step := abs(atof(argv[argc],code));
      end
      else if (argv[2] = 'Va_start') or (argv[2] = 'as') then begin
         ivpars.Va_start := atof(argv[argc],code);
      end
      else if (argv[2] = 'Va_stop') or (argv[2] = 'at') then begin
         ivpars.Va_stop := atof(argv[argc], code);
      end
      else if (argv[2] = 'Va_rate') or (argv[2] = 'ar') then begin
         ivpars.Va_rate := atof(argv[argc], code);
	 if (ivpars.Va_rate = 0.0) then begin
	    barf('bad value for rate',ftoa(ivpars.Va_rate,8,2));
	    ivpars.Va_rate := (ivpars.Va_stop - ivpars.Va_start) / 100.0;
	 end;
      end
      else if (argv[2] = 'Vb_start') or (argv[2] = 'bs') then begin
         ivpars.Vb_start := atof(argv[argc],code);
      end
      else if (argv[2] = 'Vb_stop') or (argv[2] = 'bt') then begin
         ivpars.Vb_stop := atof(argv[argc], code);
      end
      else if (argv[2] = 'Nb') then begin
         dset.Nb := abs(atoi(argv[argc],code));
	 if (dset.Nb < 2) then dset.Nb := 2;
      end
      else if (argv[2] = 'Na') then begin
         dset.Na := abs(atoi(argv[argc], code));
	 if (dset.Na < 2) then dset.Na := 2;
      end
      else if (argv[2] = 'comment') or (argv[2] = 'com') then begin
         dset.remarks[abs(atoi(argv[argc],code)) mod 3] :=
	 	local_input_line('Comment:');
      end
      else begin
         barf('unknown variable', argv[2]);
      end;
   end;
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
   c : char;
begin
  TextBackground(Black);
  TextColor(Yellow);
  ref_dir := site.home_dir + '\'; 
  init_environment;
  show_environment;
  repeat
     quit := false;
     cmd := get_cmdline (argc, argv);
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
             list_requests(argc, argv);
          end;
       CMD_DIR:
          begin
             list_directory(argc, argv);
          end;
       CMD_ERASE:
          begin
             remove_files(argc, argv);
          end;
       CMD_SET:
          begin
             set_variable(argc, argv);
             show_environment;
          end;
       CMD_STAT:
          begin
             show_environment;
          end;
       CMD_SAVE:
          begin
	     if (argc > 1) then
	        save_path := argv[2];
             if (save_path <> '') then begin
	        save_ascii(dset, save_path, code);
		if (code = 0) then data_saved := true;
	     end
	     else
	        barf('saving data', 'no filename');
	  end;
       CMD_IV4140:
          if check_safety(data_saved) then begin
	     banner('I-Va curve from HP4140B');
	     with dset do begin
	        ICmax := input_real('Enter expected high I limit [A]:');
		ICmin := input_real('Enter expected low  I limit [A]:');
	     end;
	     IV_4140(ivpars, dset);
	     if local_confirm('Range data?') then
	        find_limits(dset);
	     data_saved := false;
	  end;
       CMD_CV4140:
          if check_safety(data_saved) then begin
	     banner('C-Va curve from HP4140B');
	     with dset do begin
	        ICmax := input_real('Enter expected high C limit [F]:');
		ICmin := input_real('Enter expected low  C limit [F]:');
	     end;
	     CV_4140(ivpars, dset);
	     if local_confirm('Range data?') then
	        find_limits(dset);
	     data_saved := false;
	  end;
       CMD_CV4192:
          if check_safety(data_saved) then begin
	     banner('C-V curve from HP4192A');
	     with dset do begin
	        ICmax := input_real('Enter expected high C limit [F]:');
		ICmin := input_real('Enter expected low  C limit [F]:');
	     end;
	     CV_4192(iapars, dset);
	     if local_confirm('Range data?') then
	        find_limits(dset);
	     data_saved := false;
	  end;
       CMD_PLOT:
          if check_safety(data_saved) then begin
	     plot_out(dset);
	  end;
       else
          begin
             barf('not implemented',argv[1]);
          end;
     end; (* case *)
  until quit;
end.
