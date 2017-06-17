program testbed;
uses
  crt, rt_error;
var
  i, code : integer;
  f : file of byte;
  buf : string;
  b : byte;
begin
  assign(f, 'COM1');
  {$i-}
  rewrite(f);
  buf := 'IN;SP1;PA0,0;PD5000,0;PD5000,5000;PD0,5000;PD0,0;PU;';
  for i := 1 to length(buf) do begin
     b := lo(ord(buf[i]));
     write(f,b);
     code := ioresult;	
     writeln('code = ',code,': ',problem(code));
     {$i+}
  end;
  close(f);
end.