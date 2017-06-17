unit gpib;
(*
 * Software tools for Turbo Pascal 4.0 and National Instruments NI-488
 * software to facilitate message sending to and from devices.
 *)
interface
uses
  tpdecl;

type
  device = record
	      d_addr : integer;
	      d_name : nbuf;
	      d_term : integer;
	   end;
const
  ST_ERR  = $8000;  ST_RQS  = $0800;  ST_LOK  = $0080;  ST_TACS = $0008;
  ST_TIMO = $4000;  		      ST_REM  = $0040;  ST_LACS = $0004;
  ST_END  = $2000; 		      ST_CIC  = $0020;  ST_DTAS = $0002;
  ST_SRQI = $1000;  ST_CMPL = $0100;  ST_ATN  = $0010;  ST_DCAS = $0001;

  EDVR = 0;
  ECIC = 1;
  ENOL = 2;
  EADR = 3;
  EARG = 4;
  ESAC = 5;
  EABO = 6;
  ENEB = 7;
  EOIP = 10;
  ECAP = 11;
  EFSO = 12;
  EBUS = 14;
  ESTB = 15;
  ESRQ = 16;

  CMD_GTL = #$01;
  CMD_SDC = #$04;
  CMD_PPC = #$05;
  CMD_GET = #$08;
  CMD_TCT = #$09;
  CMD_LLO = #$11;
  CMD_DCL = #$14;
  CMD_PPU = #$15;
  CMD_SPE = #$18;
  CMD_SPD = #$19;
  CMD_UNL = #$3F;
  CMD_UNT = #$5F;

var
  status : integer;
  error  : integer;
  count  : integer;

procedure command (var d:device; buf:string);
procedure interface_clear (var d:device);
procedure go_to_standby (var d:device; v:integer);
procedure find (var d:device; name:string);
procedure get (var d:device; var buf:string; term:integer);
procedure put (var d:device; buf:string);
procedure trigger (var d:device);
procedure clear (var d:device);
procedure local (var d:device);

function serial_poll (var d:device) : byte;

(****************************************************************************)
implementation

procedure update;
begin
  status := ibsta;
  error  := iberr;
  count  := ibcnt;
end;

procedure command (var d:device; buf:string);
begin
  ibcmd(d.d_addr, buf[1], length(buf));
  update;
end;

procedure go_to_standby (var d:device; v:integer);
begin
  ibgts(d.d_addr,v);
  update;
end;

procedure interface_clear (var d:device);
begin
  ibsic(d.d_addr);
  update;
end;

procedure find (var d:device; name:string);
var
  i : byte;
begin
  for i := 1 to length(name) do
     d.d_name[i] := name[i];
  for i := (length(name)+1) to 7 do
     d.d_name[i] := ' ';
  d.d_addr := ibfind(d.d_name);
  update;
  d.d_term := 0;
end;

procedure get (var d:device; var buf:string; term:integer);
const
  ST_BAD = $8400;  (* = ST_ERR || ST_TIMO *)
var
  cnt : byte;
  termc : char;
begin
  if (term > 0) then begin
     ibrd(d.d_addr, buf[1], term);
     update;
     buf[0] := chr(ibcnt);
  end
  else begin
     termc := chr(-term);
     cnt := 0;
     repeat
        inc(cnt);
	repeat
           ibrd(d.d_addr, buf[cnt], 1);
	   update;
	until (ibsta and ST_BAD = 0);
     until buf[cnt] = termc;
     buf[0] := chr(cnt);
  end;
end;

procedure put (var d:device; buf:string);
begin
  ibwrt(d.d_addr,buf[1],length(buf));
  update;
end;

procedure trigger (var d:device);
begin
  ibtrg(d.d_addr);
  update;
end;

procedure clear (var d:device);
begin
  ibclr(d.d_addr);
  update;
end;

procedure local (var d:device);
begin
  ibloc(d.d_addr);
  update;
end;

function serial_poll (var d:device) : byte;
var
  b:byte;
begin
  ibrsp(d.d_addr, b);
  update;
  serial_poll := b;
end;

begin (* preamble *)
end.  (* preamble *)
