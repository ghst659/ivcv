program plot;
uses
  generics, dosdev, rt_error;
var
  buf, two : string;
  com : dos_device;
  i, code : integer;
  out : boolean;
begin
  dd_open(com,'COM1',code);
  if (code = 0) then begin
     repeat
       out := false;
       write('Enter string: '); readln(buf);
       if (buf <> 'quit') then begin
          for i := 1 to length(buf) do begin
	     if (buf[i] = '\') then begin
	        delete(buf,i,1);
	        case (buf[i]) of
		   'E': buf[i] := ESC;
		end;
	     end;
	  end;
	  out := (buf[1] = '/');
	  if (out) then delete(buf,1,1);
          dd_write(com,buf,code);
	  if (code <> 0) then
	     writeln(code,': ',problem(code));
	  if out then begin
             dd_read(com,buf,CR);
             if (length(buf) > 0) then writeln(buf);
	  end;
       end;
     until (buf = 'quit');
  end
  else
     writeln('dd_open: ', rt_error.problem(code));
end.