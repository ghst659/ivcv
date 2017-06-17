unit plot_device;
(*
 * This unit uses OOP to define a generic plotting device as an object.
 *)
interface
uses
  Crt, Graph, generics, dosdev;
type
  plotter_device = object
  		      current_colour : word;

  		      constructor init (initializer:string);
		      destructor  done;
		      procedure activate(mode:integer); virtual;
		      procedure deactivate; virtual;
		      procedure bar (x1,y1,x2,y2:integer); virtual;
		      procedure circle (x,y:integer; radius:word); virtual;
		      function getx : integer; virtual;
		      function gety : integer; virtual;
		      procedure plot (x,y:integer); virtual;
		      procedure putpixel(x,y:integer; pixel:word); virtual;
		      procedure line (x1,y1,x2,y2:integer); virtual;
		      procedure linerel (Dx,Dy:integer); virtual;
		      procedure lineto (x,y:integer); virtual;
		      procedure moverel (Dx,Dy:integer); virtual;
		      procedure moveto (x,y:integer); virtual;
		      procedure rectangle (x1,y1,x2,y2:integer); virtual;
		      procedure outtext (textstring:string); virtual;
		      procedure outtextxy (x,y:integer; textstring:string);
		         virtual;
		      procedure setcolor (colour:word); virtual;
		      procedure settextstyle (font,direction,charsize:word);
		         virtual;
  		   end;

  BGI_device = object (plotter_device)
		  constructor init (initializer:string);
		  destructor done;
		  procedure activate(mode:integer); virtual;
		  procedure deactivate; virtual;
		  procedure bar (x1,y1,x2,y2:integer); virtual;
		  procedure circle (x,y:integer; radius:word); virtual;
		  function getx : integer; virtual;
		  function gety : integer; virtual;
		  procedure plot(x,y:integer); virtual;
		  procedure putpixel(x,y:integer; pixel:word); virtual;
		  procedure line (x1,y1,x2,y2:integer); virtual;
		  procedure linerel (Dx,Dy:integer); virtual;
		  procedure lineto (x,y:integer); virtual;
		  procedure moverel (Dx,Dy:integer); virtual;
		  procedure moveto (x,y:integer); virtual;
		  procedure rectangle (x1,y1,x2,y2:integer); virtual;
		  procedure outtext (textstring:string); virtual;
		  procedure outtextxy (x,y:integer; textstring:string);
		     virtual;
		  procedure setcolor (colour:word); virtual;
		  procedure settextstyle (font,direction,charsize:word);
		     virtual;
		  procedure settextjustify (horiz,vert:word); virtual;
	       end;

  HPGL_device = object (plotter_device)
  		   device : dos_device;

		   constructor init (initializer:string);
		   procedure send (s:string);
		   procedure plot(x,y:integer); virtual;
		   procedure putpixel(x,y:integer; pixel:word); virtual;
		   procedure setcolor (colour:word); virtual;
		   procedure line (x1,y1,x2,y2:integer); virtual;
		   procedure linerel (Dx,Dy:integer); virtual;
		   procedure lineto (x,y:integer); virtual;
		   procedure moverel (Dx,Dy:integer); virtual;
		   procedure moveto (x,y:integer); virtual;
		   procedure rectangle (x1,y1,x2,y2:integer); virtual;
		   procedure circle (x,y:integer; radius:word); virtual;
		   procedure outtext (textstring:string); virtual;
		   procedure outtextxy (x,y:integer; textstring:string);
		      virtual;
		   procedure settextstyle (font,direction,charsize:word);
		      virtual;
  		end;

(****************************************************************************)
implementation
var
  code : integer;
(****************************************************************************
 * Generic Plotting device (actions do nothing)
 *)

constructor plotter_device.init (initializer:string);
begin end;

destructor plotter_device.done;
begin end;

procedure plotter_device.activate (mode:integer);
begin end;

procedure plotter_device.deactivate;
begin end;

procedure plotter_device.bar (x1,y1,x2,y2:integer);
begin end;

procedure plotter_device.plot (x,y:integer);
begin end;

procedure plotter_device.putpixel (x,y:integer; pixel:word);
begin end;

procedure plotter_device.setcolor (colour:word);
begin end;

function plotter_device.getx : integer;
begin end;

function plotter_device.gety : integer;
begin end;

procedure plotter_device.line (x1,y1,x2,y2:integer);
begin end;

procedure plotter_device.linerel(Dx,Dy:integer);
begin end;

procedure plotter_device.lineto (x,y:integer);
begin end;

procedure plotter_device.moverel (Dx,Dy:integer);
begin end;

procedure plotter_device.moveto(x,y:integer);
begin end;

procedure plotter_device.rectangle (x1,y1,x2,y2:integer);
begin end;

procedure plotter_device.circle (x,y:integer; radius:word);
begin end;

procedure plotter_device.outtext (textstring:string);
begin end;

procedure plotter_device.outtextxy (x,y:integer; textstring:string);
begin end;

procedure plotter_device.settextstyle (font,direction,charsize:word);
begin end;

(****************************************************************************
 * Borland Graphics Interface interface --- for the screen
 *)
constructor BGI_device.init (initializer:string);
var
  device, mode : integer;
begin
  device := Graph.Detect;
  Graph.InitGraph(device, mode, initializer);
end;

destructor BGI_device.done;
begin
  Graph.CloseGraph;
end;

procedure BGI_device.activate (mode:integer);
begin
  Graph.SetGraphMode(mode);
end;

procedure BGI_device.deactivate;
begin
  Graph.RestoreCrtMode;
end;

procedure BGI_device.bar (x1,y1,x2,y2:integer);
begin
  Graph.Bar(x1,y1,x2,y2);
end;

procedure BGI_device.plot (x,y:integer);
begin
  Graph.PutPixel(x,y,current_colour);
end;

procedure BGI_device.putpixel (x,y:integer; pixel:word);
begin
  Graph.PutPixel(x,y,pixel);
end;

procedure BGI_device.setcolor (colour:word);
begin
  Graph.SetColor(colour);
  current_colour := colour;
end;

function BGI_device.getx : integer;
begin
  getx := Graph.GetX;
end;

function BGI_device.gety : integer;
begin
  gety := Graph.GetY;
end;

procedure BGI_device.line (x1,y1,x2,y2:integer);
begin
  Graph.Line(x1,y1,x2,y2);
end;

procedure BGI_device.linerel(Dx,Dy:integer);
begin
  Graph.LineRel(Dx,Dy);
end;

procedure BGI_device.lineto (x,y:integer);
begin
  Graph.LineTo(x,y);
end;

procedure BGI_device.moverel (Dx,Dy:integer);
begin
  Graph.MoveRel(Dx,Dy);
end;

procedure BGI_device.moveto(x,y:integer);
begin
  Graph.MoveTo(x,y);
end;

procedure BGI_device.rectangle (x1,y1,x2,y2:integer);
begin
  Graph.Rectangle(x1,y1,x2,y2);
end;

procedure BGI_device.circle (x,y:integer; radius:word);
begin
  Graph.Circle (x,y,radius);
end;

procedure BGI_device.outtext (textstring:string);
begin
  Graph.OutText(textstring);
end;

procedure BGI_device.outtextxy (x,y:integer; textstring:string);
begin
  Graph.OutTextXY(x,y,textstring);
end;

procedure BGI_device.settextstyle (font,direction,charsize:word);
begin
  Graph.SetTextStyle(font,direction,charsize);
end;

procedure BGI_device.settextjustify (horiz,vert:word);
begin
  Graph.SetTextJustify(horiz,vert);
end;

(****************************************************************************
 * HPGL device interface
 *)
procedure HPGL_device.send(s:string);
begin
  dd_write(device,s+';',code);
end;

constructor HPGL_device.init (initializer:string);
var
  code : integer;
begin
  dd_open(device,initializer,code);
  if (code = 0) then begin
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
end;

procedure HPGL_device.plot (x,y:integer);
begin
  send('PU;PA'+ftoa(x,6,0)+','+ftoa(y,6,0));
  send('PD');
end;

procedure HPGL_device.putpixel (x,y:integer; pixel:word);
begin
  if (pixel <> 0) then plot(x,y);
end;

procedure HPGL_device.setcolor (colour:word);
begin
  send('SP'+ftoa((colour mod 2)+1,1,0));
  delay(1500);
  current_colour := colour;
end;

procedure HPGL_device.line (x1,y1,x2,y2:integer);
begin
  send('PU;PA'+ftoa(x1,6,0)+','+ftoa(y1,6,0));
  send('PD'+ftoa(x2,6,0)+','+ftoa(y2,6,0));
end;

procedure HPGL_device.linerel(Dx,Dy:integer);
begin
  send('PD;PR'+ftoa(Dx,6,0)+','+ftoa(Dy,6,0));
end;

procedure HPGL_device.lineto (x,y:integer);
begin
  send('PD;PA'+ftoa(x,6,0)+','+ftoa(y,6,0));
end;

procedure HPGL_device.moverel (Dx,Dy:integer);
begin
  send('PU;PR'+ftoa(Dx,6,0)+','+ftoa(Dy,6,0));
end;

procedure HPGL_device.moveto(x,y:integer);
begin
  send('PU;PA'+ftoa(x,6,0)+','+ftoa(y,6,0));
end;

procedure HPGL_device.rectangle (x1,y1,x2,y2:integer);
begin
  send('PU;PA'+ftoa(x1,6,0)+','+ftoa(y1,6,0));
  send('PD'+ftoa(x1,6,0)+','+ftoa(y2,6,0));
  send('PA'+ftoa(x2,6,0)+','+ftoa(y2,6,0));
  send('PA'+ftoa(x2,6,0)+','+ftoa(y1,6,0));
  send('PA'+ftoa(x1,6,0)+','+ftoa(y1,6,0));
  send('PU');
end;

procedure HPGL_device.circle (x,y:integer; radius:word);
begin
  send('PU;PA'+ftoa(x,6,0)+','+ftoa(y,6,0)+';PD;');
  send('CI'+ftoa(radius,6,0));
end;

procedure HPGL_device.outtext (textstring:string);
begin
  send('LB'+textstring+ETX);
  delay(310*length(textstring));
end;

procedure HPGL_device.outtextxy (x,y:integer; textstring:string);
begin
  send('PU;PA'+ftoa(x,6,0)+','+ftoa(y,6,0));
  send('LB'+textstring+ETX);
  delay(310*length(textstring));
end;

procedure HPGL_device.settextstyle (font,direction,charsize:word);
begin
  case (direction mod 2) of
    0: send('DR1,0');
    1: send('DR0,1');
  end;
end;

begin (* preamble *)
end.  (* preamble *)