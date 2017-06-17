unit dosdev;
interface
uses
  crt, generics;
type
  dos_device = file of byte;

procedure dd_open (var dev:dos_device; name:string; var code:integer);
procedure dd_write (var dev:dos_device; data:string; var code:integer);
procedure dd_read (var dev:dos_device; var data:string; terminator:char);
procedure dd_close (var dev:dos_device; var code:integer);

(****************************************************************************)
implementation
procedure dd_open (var dev:dos_device; name:string; var code:integer);
begin
  assign(dev,name);
  {$i-}
  reset(dev);  code := IOResult;
  {$i+}
end;

procedure dd_write (var dev:dos_device; data:string; var code:integer);
var
  i, len : integer;
  b : byte;
begin
  i := 1;
  len := length(data);
  code := 0;
  while ((code = 0) and (i <= len)) do begin
     b := byte(ord(data[i]));
     {$i-}
     write(dev, b);
     code := IOResult;
     {$i+}
     inc(i);
  end;
  delay(7*len);
end;

procedure dd_read (var dev:dos_device; var data:string; terminator:char);
var
  c : byte;
  term : byte;
begin
  term := ord(terminator);
  data := '';
  read(dev, c);
  while (c <> term) do begin
    data := data + chr(c);
    read(dev,c);
  end;
end;

procedure dd_close (var dev:dos_device; var code:integer);
begin
  {$i-}
  close(dev);
  code := IOResult;
  {$i+}
end;

begin (* preamble *)
end.  (* preamble *)