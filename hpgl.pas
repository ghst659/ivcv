unit hpgl;
interface
uses
  crt, generics, dosdev;
const
  getmaxx = 10300;
  getmaxy = 7650;

procedure hp_reset;

procedure setcolor(colour:byte);
procedure plot (x,y:integer);
procedure outtext (textstring:string);
procedure outtextxy (x,y:integer; textstring:string);
procedure line (x1,y1,x2,y2:integer);
procedure lineto (x,y:integer);
procedure linerel (Dx,Dy:integer);
procedure moveto (x,y:integer);
procedure moverel (Dx,Dy:integer);
procedure settextdir (dir:word);
procedure rectangle (x1,y1,x2,y2:integer);

(****************************************************************************)
implementation
var
  dev : dos_device;
  code : integer;

procedure send(s:string);
begin
  dd_write(dev,s+';',code);
end;

procedure hp_reset;
var
  buf : string;
begin
  send(';');
  send(';');
  send(';');
  send(ESC);
  send('.E;');
  send('IN;');
  send('IN;');
  send('IN;');
  send('SP;');
  send('PU370,7650;');
end;

procedure setcolor(colour:byte);
begin
  send('SP'+ftoa((colour mod 2)+1,1,0));
  delay(1500);
end;

procedure plot (x,y:integer);
begin
  send('PU;PA'+ftoa(x,6,0)+','+ftoa(y,6,0));
  send('PD');
end;

procedure outtext (textstring:string);
begin
  send('LB'+textstring+ETX);
  delay(310*length(textstring));
end;

procedure outtextxy (x,y:integer; textstring:string);
begin
  send('PU;PA'+ftoa(x,6,0)+','+ftoa(y,6,0));
  send('LB'+textstring+ETX);
  delay(310*length(textstring));
end;

procedure line (x1,y1,x2,y2:integer);
begin
  send('PU;PA'+ftoa(x1,6,0)+','+ftoa(y1,6,0));
  send('PD'+ftoa(x2,6,0)+','+ftoa(y2,6,0));
end;

procedure lineto (x,y:integer);
begin
  send('PD;PA'+ftoa(x,6,0)+','+ftoa(y,6,0));
end;

procedure linerel (Dx,Dy:integer);
begin
  send('PD;PR'+ftoa(Dx,6,0)+','+ftoa(Dy,6,0));
end;

procedure moveto (x,y:integer);
begin
  send('PU;PA'+ftoa(x,6,0)+','+ftoa(y,6,0));
end;

procedure moverel (Dx,Dy:integer);
begin
  send('PU;PR'+ftoa(Dx,6,0)+','+ftoa(Dy,6,0));
end;

procedure rectangle (x1,y1,x2,y2:integer);
begin
  send('PU;PA'+ftoa(x1,6,0)+','+ftoa(y1,6,0));
  send('PD'+ftoa(x1,6,0)+','+ftoa(y2,6,0));
  send('PA'+ftoa(x2,6,0)+','+ftoa(y2,6,0));
  send('PA'+ftoa(x2,6,0)+','+ftoa(y1,6,0));
  send('PA'+ftoa(x1,6,0)+','+ftoa(y1,6,0));
  send('PU');
end;

procedure settextdir(dir:word);
begin
  case (dir mod 2) of
    0: send('DR1,0');
    1: send('DR0,1');
  end;
end;

begin (* preamble *)
  dd_open(dev,'COM1',code);
  hp_reset;
end.  (* preamble *)