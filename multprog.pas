unit multprog;
interface
uses generics, gpib;

procedure send(channel:byte; voltage:real);
(****************************************************************************)
implementation
var
  dev : device;

procedure send(channel:byte; voltage:real);
const
  ctrl_string = 'O0160T';
var
  chan : char;
  cvt : integer;
  buf, vbuf : string7;
  stat : integer;
begin
  case (channel) of
    1: chan := '@';
    2: chan := 'A';
    3: chan := 'F';
    4: chan := 'G';
    else
       chan := '@';
  end;
  if (voltage > 10.237) then 
     voltage := 10.237;
  if (voltage < -10.24) then
     voltage := -10.24;
  cvt := round(abs(voltage)*200.0);
  if (voltage < 0) then
     cvt := $1000 - cvt;
  vbuf := copy(octstr(cvt),3,4);
  buf := ctrl_string;
  put(dev, buf);
{$IFDEF DEBUG}
  writeln('Sent: "',buf,'"');
  writeln('status = ',hexstr(status),'; RSP = ',hexstr(serial_poll(dev)));
{$ENDIF DEBUG}
  buf := chan + vbuf + 'T';
  put(dev, buf);
{$IFDEF DEBUG}
  writeln('Sent: "',buf,'"');
  writeln('status = ',hexstr(status),'; RSP = ',hexstr(serial_poll(dev)));
{$ENDIF DEBUG}
end;

begin
  find(dev, 'HP6940B');
  if (dev.d_addr < 0) then begin
     writeln('MULTPROG: error finding device.');
     halt;
  end;
end.