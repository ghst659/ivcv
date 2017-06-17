program test_4192;
uses
  generics, gpib;

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

var
  imp : device;
  buf : string;
  i : integer;
begin
  find(imp, 'HP4192A');
  if (imp.d_addr >= 0) then begin
     clear(imp);
     put(imp, 'ANBNA4B3W1F1T3');
     put(imp, 'FR100EN');
     put(imp, 'OL0.1EN');
     put(imp, 'TB-1EN');
     put(imp, 'PB1EN');
     put(imp, 'SB0.2EN');
     put(imp, 'W2');
     for i := 0 to 10 do begin
        put(imp, 'EX');
        get(imp, buf, -ord(LF));
	buf[0] := chr(length(buf)-2);
	write('buf = "',buf,'"; status = ',hexstr(status));
	if (status and ST_SRQI > 0) then
	   writeln('; RSP = ',serial_poll(imp))
	else
	   writeln;
     end;
     put(imp, 'W3');
     put(imp, 'I0');
  end;
end.