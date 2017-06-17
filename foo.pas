program foo;
uses
  generics;
var
  buf : string;
  x, y : real;
  i,code : integer;
begin
  buf := input_line('Enter string:');
  i := pos(',',buf);
  x := atof(copy(buf,1,i-1),code);
  y := atof(copy(buf,i+1,255),code);
  writeln('x = ',x,'; y = ',y);
end.