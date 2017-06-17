program talk;
uses
  generics, gpib;
var
  k : device;
  buf : string;
  name : string;
begin
  if (paramcount = 0) then begin
     write('Enter name: '); readln(name);
  end
  else
     name := paramstr(1);
     
  find(k,name);
  if (k.d_addr < 0) then begin
     writeln('bad name');
     halt;
  end;
  repeat
    write(name,':  '); readln(buf);
    if (buf <> 'quit') then
       case buf[1] of
	  't','T': trigger(k);
	  'c','C': clear(k);
	  'l','L': local(k);
	  'w','W':
	       begin
	         delete(buf,1,1);
	         put(k,buf);
	       end;
	  'r','R':
	       begin
	         buf := '';
		 get(k,buf,ord(LF));
		 if (buf <> '') then writeln(buf);
	       end;
       end;
  until (buf = 'quit');
end.