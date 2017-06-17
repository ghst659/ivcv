program test_mp;
uses multprog;
var
  chan : byte;
  v : real;
begin
  repeat
    write('Enter channel, voltage: ');
    readln(chan, v);
    writeln('chan = ',chan,'; voltage = ',v);
    send(chan,v);
  until chan = 0;
end.