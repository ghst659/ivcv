unit generics;
(*
 * Generic tools useful for Turbo Pascal 4.0
 *)
{$IFDEF CPU87}
{$N+}
{$ELSE}
{$N-}
{$ENDIF CPU87}

interface
uses
  crt, dos;
const
  NUL = #$00;   BS  = #$08;   DLE = #$10;   CAN = #$18;
  SOH = #$01;   HT  = #$09;   DC1 = #$11;   EM  = #$19;
  STX = #$02;   LF  = #$0A;   DC2 = #$12;   SUB = #$1A;
  ETX = #$03;   VT  = #$0B;   DC3 = #$13;   ESC = #$1B;
  EOT = #$04;   FF  = #$0C;   DC4 = #$14;   FS  = #$1C;
  ENQ = #$05;   CR  = #$0D;   NAK = #$15;   GS  = #$1D;
  ACK = #$06;   SO  = #$0E;   SYN = #$16;   RS  = #$1E;
  BEL = #$07;   SI  = #$0F;   ETB = #$17;   US  = #$1F;

  SPC = #$20;
  DEL = #$7F;

  max_al_length = 32;
type
  {$IFOPT N-}
  extended = real;
  double   = real;
  single   = real;
  {$ENDIF N-}

  string7   = string[7];
  string15  = string[15];
  string31  = string[31];
  string63  = string[63];
  string127 = string[127];
  string255 = string;

  char_set = set of char;

  arglist = array[1..max_al_length] of string31;
const
  std_white:char_set = [' ',^I,^J,^M];
  std_symbol:char_set = 
     ['[',']','{','}','<','>','(',')','=','*','&','^','%','$','#','@',
      '!',',','?','/','+',':',';','~','`'];

function lesser (x,y:extended) : extended;
function greater (x,y:extended) : extended;
function floor (x:extended) : extended;
function ceil (x:extended) : extended;
function pow10(x:extended) : extended;
function pow (x,y:extended) : extended;
function log10 (x:extended) : extended;
function bits(bs:string15) : byte;
function hexstr(b:integer) : string7;
function octstr(b:integer) : string7;
function sgn(x:single) : single;

function ftoa (x:single; width,decimals:shortint) : string31;
function atof (s:string127; var code:integer) : double; 
function atoi (s:string127; var code:integer) : integer; 
function atol (s:string127; var code:integer) : longint;
function downcase (s:string) : string;
function parse (s:string; var argv:arglist; 
                whitespace,singletons:char_set;
                literal_prefix,quote_delimiter:char) : shortint;

procedure print_screen;
procedure beep;
procedure screen_bar;
procedure clrln(line:byte);

function input_line (prompt:string63) : string255; 
function input_real (prompt:string63) : real;
function input_int (prompt:string63) : integer;
function input_long (prompt:string63) : longint;
function confirm (prompt:string63; default:boolean) : boolean;

function exists_file (path:string63) : boolean;
function erase_file (path:string63) : integer;
procedure list_cwd_match (card:string15; ftype:word);
procedure list_cwd (card:string15);

type
  time_t = longint;
  date_rec = record year,month,day:word end;

procedure get_date (var today:date_rec);
procedure set_date (var today:date_rec);
function date_str (var today:date_rec; human_form:boolean) : string31;
function time_str (now:time_t; truncate:boolean) : string15;
function get_time : time_t;

(****************************************************************************)
implementation

var
  ln10, pival : extended;

function lesser (x,y:extended) : extended;
begin
  if (x < y) then
     lesser := x
  else
     lesser := y;
end;

function greater (x,y:extended) : extended;
begin
  if (x < y) then
     greater := y
  else
     greater := x;
end;

function floor (x:extended) : extended;
begin
  if (x > 0.0) or (x = int(x)) then
     floor := int(x)
  else
     floor := int(x-1.0);
end;

function ceil (x:extended) : extended;
begin
  if (x < 0.0) or (x = int(x)) then
     ceil := int(x)
  else
     ceil := int(x+1.0);
end;

function pow10(x:extended) : extended;
begin
  pow10 := exp(ln10 * x);
end;

function pow (x,y:extended) : extended;
begin
  pow := exp (y*ln(abs(x)));
end;

function log10 (x:extended) : extended;
begin
  log10 := ln(abs(x))/ln10;
end;

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

function octstr(b:integer) : string7;
const
  chars:array[0..7] of char = ('0','1','2','3','4','5','6','7');
var
  s : string7;
begin
  s[0] := #6;
  s[1] := chars[(b shr 15) and 7];
  s[2] := chars[(b shr 12) and 7];
  s[3] := chars[(b shr  9) and 7];
  s[4] := chars[(b shr  6) and 7];
  s[5] := chars[(b shr  3) and 7];
  s[6] := chars[ b         and 7];
  octstr := s;
end;

function sgn(x:single) : single;
begin
  if (x < 0.0) then sgn := -1.0 else sgn := 1.0;
end;

function bits (bs:string15) : byte;
var
  value, shift : byte;
begin
  value := $00;
  for shift := 1 to 8 do
     if bs[shift] = '1' then 
        inc(value, $01 shl (8 - shift));
  bits := value;
end;

function downcase (s:string) : string;
var i,o:byte;
begin
  for i := 1 to length(s) do begin
    o := ord(s[i]);
    if (o > 64) and (o < 91) then
       s[i] := chr(o + 32);
  end;
  downcase := s;
end;

function ftoa (x:single; width,decimals:shortint) : string31;
var s:string63;
begin
  if (decimals < 0) then 
     str(x:width,s) 
  else 
     str(x:width:decimals,s);
  ftoa := s;
end;

function atof (s:string127; var code:integer) : double;
const digits:set of char = 
      ['0','1','2','3','4','5','6','7','8','9','+','-','.','E','e'];
var v:double; 
    i:integer;
begin 
  i := 1; v := 0.0;
  while (i <= length(s)) do
     if not (s[i] in digits) then 
        delete(s,i,1) 
     else 
        i := i + 1;
  i := pos('.', s);
  if (i = length(s)) then s := s + '0';
  if (i = 1) or (s[i-1] in ['+','-']) then insert('0',s,i);
  val(s, v, code);
  atof := v;
end;

function atoi (s:string127; var code:integer) : integer; 
var v:real;
begin 
  v := atof(s,code);
  if (abs(v) > 1.0*maxint) then begin 
     code := length(s);
     v := (v/abs(v))*maxint;
  end;
  atoi := round(v);
end;

function atol (s:string127; var code:integer) : longint;
var v:real;
begin
  v := atof(s,code);
  atol := round(v);
end;

procedure print_screen; 
var regs : registers;
begin 
  intr($05, regs) 
end;

procedure beep;
begin
  sound(550);
  delay(300);
  nosound;
end;

procedure screen_bar; 
var cbuf : string[80];
begin 
  fillchar(cbuf, 80, #$C4); 
  cbuf[0] := chr(79); 
  writeln(cbuf); 
end;

procedure clrln (line:byte); 
begin 
  gotoxy(1,line); 
  clreol;
end;

function input_line (prompt:string63) : string255; 
var 
  cbuf : string255;
begin 
  write(prompt,'  '); 
  clreol; 
  readln(cbuf); 
  input_line := cbuf; 
end;

function input_real (prompt:string63) : real;
var
  ix, iy, code : integer; 
  v : real;
begin 
  ix := wherex; 
  iy := wherey; 
  v := 0.0;
  repeat 
    code := 0; 
    gotoxy(ix,iy); 
    v := atof(input_line(prompt),code);
  until code = 0;
  input_real := v;
end;

function input_int (prompt:string63) : integer;
var 
  ix, iy :integer; 
  v : real;
begin 
  ix := wherex; iy := wherey;
  repeat 
    gotoxy(ix,iy); 
    v := input_real(prompt); 
  until (abs(v) <= 1.0*maxint);
  input_int := round(v);
end;

function input_long (prompt:string63) : longint;
var 
  ix, iy :integer; 
  v : real;
begin 
  ix := wherex; iy := wherey;
  repeat 
    gotoxy(ix,iy); 
    v := input_real(prompt); 
  until (abs(v) <= 1.0*maxint*maxint);
  input_long := round(v);
end;

function confirm (prompt:string63; default:boolean) : boolean;
var 
  cbuf : string63;
  ix, iy : byte;
begin 
  ix := wherex;
  iy := wherey;
  repeat
    gotoxy(ix,iy); 
    cbuf := input_line(prompt);
    if (cbuf = '') then
       if (default) then
          cbuf := 'y'
       else
          cbuf := 'n'
    else
       while cbuf[1] in [' ',^I] do delete(cbuf,1,1);
  until cbuf[1] in ['y','Y','n','N'];
  confirm := (cbuf[1] in ['y','Y']);
end;

function exists_file (path:string63) : boolean;
var
  f : file;
  code : word;
begin
  assign(f, path);
  {$i-}
  reset(f); code := ioresult;
  {$i+}
  if (code = 0) then begin
     {$i-}
     close(f);
     {$i+}
     exists_file := true;
  end
  else
     exists_file := false;
end;

function erase_file (path:string63) : integer;
var
  f : file;
begin
  assign(f, path);
  {$i-}
  erase(f);
  erase_file := IOResult;
  {$i+}
end;

procedure list_cwd_match (card:string15; ftype:word);
const
  init_col = 2;
var
  dir : searchrec;
  col : byte;
begin
  col := init_col;
  findfirst(card, ftype, dir);
  while (doserror = 0) do begin
    gotoxy(col, wherey);
    write(downcase(dir.name));
    inc(col, sizeof(dir.name));
    if (col > 78) then begin
       writeln;
       col := init_col;
    end;
    findnext(dir);
  end;
  if (col <> init_col) then writeln;
end;

procedure list_cwd (card:string15);
var
  dir_name : string;
  free_space : longint;
begin
  GetDir (0, dir_name);
  free_space := DiskFree(0);
  writeln('Directory Listing of ', dir_name);
  writeln('(',free_space,' bytes free)');
  list_cwd_match(card, Directory);
end;

function parse (s:string; var argv:arglist; 
                whitespace,singletons:char_set;
                literal_prefix,quote_delimiter:char) : shortint;
var error : boolean;

procedure add_char (c:char; var argv:arglist; var argc,idx:byte);
begin
  if (idx = 0) then
     if (argc < max_al_length) then
        argc := argc + 1
     else
        error := true;
  if not error then begin
     idx := idx + 1;
     argv[argc][idx] := c;
  end;
end;

procedure terminate (var argv:arglist; var argc,idx:byte);
begin
  argv[argc][0] := chr(idx);
  idx := 0;
end;

var
  argc : byte;
  si, slen, ai : byte;
  within, literal : boolean;
begin
  error := false;
  within := false;
  literal := false;
  slen := length(s);
  argc := 0;
  ai := 0;
  si := 1;
  while not error and (si <= slen) do begin
     if literal then begin
        add_char(s[si], argv, argc, ai);
        literal := false;
     end
     else if (s[si] = literal_prefix) then begin
        literal := true;
     end
     else if (s[si] = quote_delimiter) then begin
        if within then
           within := false
        else
           within := true;
     end
     else if (s[si] in whitespace) then begin
        if within then
           add_char(s[si], argv, argc, ai)
        else if (ai <> 0) then
           terminate(argv, argc, ai);	
     end
     else if (s[si] in singletons) then begin
        if within then
           add_char(s[si], argv, argc, ai)
        else begin
           if (ai <> 0) then
              terminate(argv, argc, ai);
           add_char(s[si], argv, argc, ai);
           terminate(argv, argc, ai);
        end;
     end
     else begin
        add_char(s[si], argv, argc, ai);
     end;
     si := si + 1;
  end;
  if (ai <> 0) then
     terminate(argv, argc, ai);
  parse := argc;
end;

procedure get_date (var today : date_rec);
var cpu : registers;
begin
  with cpu do begin
     AX := $2A00; MSDOS(cpu);
     with today do begin
        year := CX;
        month := DH;
        day := DL;
     end;
  end;
end;

procedure set_date (var today:date_rec);
var cpu : registers;
begin
  with cpu do begin
     AX := $2B00; with today do begin CX := year; DH := month; DL := day end;
     MSDOS(cpu);
  end;
end;

function date_str (var today:date_rec; human_form:boolean) : string31;
const 
  c0 = $30; mth:array[1..12] of string7 =
  ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
var
  cbuf, s:string31;
begin
 with today do begin
  if not human_form then begin
    cbuf[0] := chr(10); cbuf[5] := '/'; cbuf[8] := '/';
    cbuf[1]:=chr(year div 1000 + c0);
    cbuf[2]:=chr(year mod 1000 div 100 + c0);
    cbuf[3] := chr(year mod 100 div 10 + c0);
    cbuf[4] := chr(year mod 10 + c0);
    cbuf[6] := chr(month div 10 + c0);
    cbuf[7] := chr(month mod 10 + c0);
    cbuf[9] := chr(day div 10 + c0);
    cbuf[10] := chr(day mod 10 + c0);
  end else begin
    str(day:2, s);
    cbuf := s + ' ' + mth[month];
    str(year, s);
    cbuf := cbuf + ' ' + s;
  end;
 end;
 date_str := cbuf;
end;

function time_str (now:time_t; truncate:boolean) : string15;
const
  c0 = $30;
var 
  cbuf : string15;
begin
  cbuf[3] := ':';
  cbuf[6] := ':';
  cbuf[9] := '.';
  cbuf[1] := chr(now div 3600000 + c0);
  cbuf[2] := chr((now mod 3600000) div 360000 + c0);
  cbuf[4] := chr((now mod 360000) div 60000 + c0);
  cbuf[5] := chr((now mod 60000) div 6000 + c0);
  cbuf[7] := chr((now mod 6000) div 1000 + c0);
  cbuf[8] := chr((now mod 1000) div 100 + c0);
  cbuf[10]:= chr((now mod 100) div 10 + c0);
  cbuf[11]:= chr(now mod 10 + c0);
  if truncate then
     cbuf[0] := #8
  else 
     cbuf[0] := #11;
  time_str := cbuf;
end;

function get_time : time_t;
const
  secs:longint = 100;
  mins:longint = 6000;
  hrs:longint  = 360000;
var
  hr, min, sec, csec : word;
begin
  GetTime(hr,min,sec,csec);
  get_time := csec + (secs * sec) + (mins * min) + (hrs * hr);
end;

begin (* preamble *)
  pival := pi;
  ln10 := ln(10.0);
end.  (* preamble *)
