unit parser;
(*
 * Generalized parser unit for Turbo Pascal 4.0
 * This unit defines a user interface.
 *)
interface
uses 
  crt, generics;

const
  N_CMDS = 24;
  CMD_UNKNOWN	= $0000;
  CMD_NOOP	= $0001;
  CMD_QUIT	= $0002;
  CMD_HELP	= $0003;

type
  doc_string = string63;
  cmd_enum = word;
  cmd_node = record
               tags:array[1..2] of string7;
               code:cmd_enum;
               doc:doc_string;
             end;
  cmd_table = record
  		name:string63;
		tint:integer;
  		list:array [1..N_CMDS] of ^cmd_node;
  	      end;

procedure emit (s:string);
procedure barf (arg1,arg2:string31);
procedure clrwin;
procedure banner (s:string63);
function get_kbd_char : char;
function user_confirm (prompt:string; default:boolean) : boolean;
function user_input_line (prompt:string) : string;
function get_cmdline (var tbl:cmd_table;
		      var argc:integer; var argv:arglist;
		      var stream:boolean) : cmd_enum;
procedure list_menu (var tbl:cmd_table);
procedure list_requests(var tbl:cmd_table;
			var argc:integer; var argv:arglist);
procedure reset_parser;

(****************************************************************************)
implementation
(*
 * TEXT WINDOW CONTROL
 * Make the user interface a little slick...
 *)
const
  USER_COLOUR = White;
  MAXCOLS = 4;
  COLWIDTH = 20;

procedure emit (s:string);
begin
  clrln(25);
  write(s);
end;

procedure barf (arg1,arg2:string31);
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

procedure banner (s:string63);
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

function user_confirm (prompt:string; default:boolean) : boolean;
var
  colour : byte;
begin
  colour := (TextAttr and $0F);
  clrln(24);
  TextColor(USER_COLOUR);
  user_confirm := generics.confirm(prompt,default);
  TextColor(colour);
end;

function user_input_line (prompt:string) : string;
var
  colour : byte;
begin
  colour := (TextAttr and $0F);
  clrln(24);
  TextColor(USER_COLOUR);
  user_input_line := generics.input_line(prompt);
  clrln(25);
  TextColor(colour);
end;

(*
 * COMMAND DEFINITION
 * This section defines the data and control structures used to parse user
 * commands.
 *)

const
  max_args = 16;                        (* Number of command-line args *)
  prompt = 'Command:';
var
  base_row : integer;

procedure reverse_video;
var
  t, b : byte;
begin
  b := (TextAttr and $70) shr 4;
  t := (TextAttr and $07) shl 4;
  TextAttr := t + b + $08;
end;

var
  cidx : integer;

procedure reset_parser;
begin
  cidx := 0;
end;

function fancy_input(var tbl:cmd_table) : integer;
const
  LEFT = #75; UP = #72; DOWN = #80; RIGHT = #77;
var
  i : integer;
  ch : char;
  done : boolean;
begin
  i := 1;
  while (tbl.list[i]^.code <> CMD_NOOP) do inc(i);
  if (cidx > i-1) then cidx := 0;
  repeat
    done := FALSE;
    gotoxy((cidx mod MAXCOLS) * COLWIDTH + 1, base_row + (cidx div MAXCOLS));
    HighVideo;
    write(tbl.list[1+cidx]^.tags[1]);
    ch := get_kbd_char;
    emit('');
    gotoxy((cidx mod MAXCOLS) * COLWIDTH + 1, base_row + (cidx div MAXCOLS));
    LowVideo;
    write(tbl.list[1+cidx]^.tags[1]);
    HighVideo;
    case ch of
       LEFT:
	  repeat
	    cidx := (cidx - 1 + N_CMDS) mod N_CMDS;
	  until (tbl.list[1+cidx] <> nil) and 
	        (tbl.list[1+cidx]^.code <> CMD_NOOP);
       RIGHT:
          repeat
	    cidx := (cidx + 1 + N_CMDS) mod N_CMDS;
	  until (tbl.list[1+cidx] <> nil) and 
	        (tbl.list[1+cidx]^.code <> CMD_NOOP);
       UP:
          repeat
	    cidx := (cidx - MAXCOLS + N_CMDS) mod N_CMDS;
	  until (tbl.list[1+cidx] <> nil) and 
	        (tbl.list[1+cidx]^.code <> CMD_NOOP);
       DOWN:
          repeat
	    cidx := (cidx + MAXCOLS + N_CMDS) mod N_CMDS;
	  until (tbl.list[1+cidx] <> nil) and 
	        (tbl.list[1+cidx]^.code <> CMD_NOOP);
       CR,LF:
          begin
	     emit(tbl.list[1+cidx]^.tags[1]+': '+tbl.list[1+cidx]^.doc);
	     done := TRUE;
	  end;
       'a'..'z':
          begin
	     i := 1;
	     while ((i < N_CMDS) and
	            ((tbl.list[(cidx+i) mod N_CMDS + 1] = nil) or
	     	     (tbl.list[(cidx+i) mod N_CMDS + 1]^.tags[1][1] <> ch))) do
	        inc(i);
	     if (i < N_CMDS) then
	        cidx := (cidx + i) mod N_CMDS;
	  end;
       '?':
          begin
	     emit(tbl.list[1+cidx]^.tags[1]+': '+tbl.list[1+cidx]^.doc);
	  end;
       else
          begin
	    beep;
	  end;
    end; (* case *)
  until done;
  fancy_input := 1 + cidx;
end;

function get_cmdline (var tbl:cmd_table;
		      var argc:integer; var argv:arglist;
		      var stream:boolean) : cmd_enum;
var
  idx : integer;
  linebuf : string;
  bi, ti, linelen : integer;
  cmd : cmd_enum;
  found : boolean;
begin
  if (stream) then begin
     linebuf := user_input_line(prompt);
     if eof(input) then begin
	assign(input,'');
	{$i-}
	reset(input);
	{$i+}
	stream := FALSE;
     end;
  end
  else begin
     clrln(24);
     write('Use arrows to pick command, ENTER to activate command.');
     idx := fancy_input(tbl);
     linebuf := tbl.list[idx]^.tags[1] + ' ' + 
     		user_input_line(prompt+'  '+
				tbl.list[idx]^.tags[1]+' [enter arguments]');
  end;
  argc := parse(linebuf,argv,std_white,['=','?','!',';'],'''','"');
  bi := 1;
  while (bi <= argc) and (argv[bi] <> ';') do inc(bi,1);
  argc := bi - 1;
  if (argc < 1) then
     cmd := CMD_NOOP
  else begin
     bi := 1;
     found := FALSE;
     cmd := CMD_UNKNOWN;
     with tbl do begin
        while (not found) and (bi <= N_CMDS) and
	      (list[bi] <> nil) do begin
           ti := 1;
           while (not found) and (ti <= 2) do begin
              if (argv[1] = list[bi]^.tags[ti]) then begin
                 cmd := list[bi]^.code;
                 found := TRUE;
              end;
              inc(ti);
           end;
	   inc(bi);
        end;
     end;
  end;
  get_cmdline := cmd;
end;

procedure list_menu (var tbl:cmd_table);
var
  i, row : integer;
begin
  with tbl do begin
     TextColor(tint);
     banner(name);
     base_row := WhereY;
     LowVideo;
     i := 1;
     while (i <= N_CMDS) and (list[i] <> nil) do begin
        row := WhereY;
	gotoxy(((i-1) mod MAXCOLS) * COLWIDTH + 1, row);
	write(list[i]^.tags[1]);
	if ((i = N_CMDS) or (list[i+1] = nil) or (i mod MAXCOLS = 0)) then
	   writeln;
	inc(i);
     end;
     HighVideo;
  end;
end;

procedure list_requests(var tbl:cmd_table;
			var argc:integer; var argv:arglist);
var 
  i, row : integer;
  c : char;
  found : boolean;
begin
  if (argc = 1) then begin
     with tbl do begin
	banner(name);
	i := 1;
	while (i <= N_CMDS) and (list[i] <> nil) do begin
	   row := wherey;
	   write(list[i]^.tags[1],', ',list[i]^.tags[2]);
	   gotoxy(30,row);
	   writeln(list[i]^.doc);
	   inc(i);
	end;
     end;
     emit('Press a key when done:  ');
     c := get_kbd_char;
     emit('');
  end
  else begin
     found := FALSE;
     i := 1;
     with tbl do begin
	while ((i < N_CMDS) and (list[i] <> nil) and 
	       not found) do begin
	    found := ((list[i]^.tags[1] = argv[2]) or
	    	      (list[i]^.tags[2] = argv[2]));
	    if (not found) then inc(i);
	 end;
     end;
     if (found) then
        emit(argv[2]+': '+tbl.list[i]^.doc)
     else
        barf(argv[2],'unknown command');
  end;
end;

begin (* preamble *)
  base_row := 3;
  cidx := 0;
end.  (* preamble *)
