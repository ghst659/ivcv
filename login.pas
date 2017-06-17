program login (input, output);
(*
 * simple login program to confine people to their home directories
 *
 * Looks for directory in a default system file.  If entry not found, then
 * query creation.  If yes, create & add entry, with synonyms.  Else
 * switch to temporary directory
 *)
uses dos, generics, rt_error;

function canon (s:string) : string;
var
  i : integer;
begin
  i := 1;
  while (i <= length(s)) do begin
     if (s[i] in ['A'..'Z']) then begin
        s[i] := chr(ord(s[i]) + (ord('a') - ord('A')));
	inc(i);
     end
     else if (s[i] in [' ',^I,'.','-','''']) then
        delete(s,i,1)
     else
        inc(i);
  end;
  canon := s;
end;

const
  whoami  = 'login';
  PASSWD = 'c:\dos\passwd.dat';
  PREFIX = 'c:\';

function find_home(name:string) : string;
var
  pwd : text;
  names : arglist;
  i, num : shortint;
  code : integer;
  dir, buf : string;
  found : boolean;
begin
  found := false;
  dir := '';
  assign(pwd,PASSWD);
  {$i-}
  reset(pwd); code := ioresult;
  {$i+}
  if (code = 0) then begin
     name := canon (name);
     while ((not found) and (not eof(pwd))) do begin
        readln(pwd, buf);
	num := parse(buf,names,['/'],[],'\','"');
	i := 1;
        while (not found and (i <= num)) do begin
	   if (name = canon (names[i])) then
	      found := true
	   else
	      inc(i);
	end;
     end;
     close(pwd);
     if (found) then dir := names[1];
  end
  else
     complain(code,whoami,PASSWD);
  if (found) then
     find_home := PREFIX + dir
  else
     find_home := '';
end;

function add_user(var name:string) : integer;
var
  pwd : text;
  dir, buf : string;
  names : arglist;
  i, num : shortint;
  code : integer;
begin
  buf := name;
  name := PASSWD;
  assign(pwd,PASSWD);
  {$i-}
  append(pwd); code := ioresult;
  {$i+}
  if (code = 0) then begin
     repeat
        names[1] := input_line('Directory name (no spaces, 8 chars or less):');
        dir := PREFIX + names[1];
     until (not exists_file(dir));
     names[2] := input_line('Enter last  name:');
     names[3] := input_line('Enter first name:');
     names[4] := names[3] + ' ' + names[2];
     names[5] := names[3] + ' ' + input_line('Enter middle initial:')
     	       + '. ' + names[2];
     {$i-}
     for i := 1 to 4 do begin
        write(pwd,names[i],'/');
     end;
     writeln(pwd,names[5]);
     code := ioresult;
     {$i+}
     close(pwd);
     if (code = 0) then begin
     	name := dir;
        {$i+}
	mkdir(dir); code := ioresult;
	{$i-}
     end;
  end;
  add_user := code;
end;

const
  DEFAULT = 'c:\tmp';
var
  name, dir : string;
  code : integer;
begin
  name := '';
  if (paramcount = 0) then
     name := input_line('Enter your name:')
  else for code := 1 to paramcount do
     name := name + paramstr(code) + ' ';
  code := 0;  
  if (name = '') then
     dir := DEFAULT
  else
     dir := find_home(name);
  if (dir <> '') then begin
     {$i-}
     chdir(dir); code := ioresult;
     {$i+}
     if (code <> 0) then complain(code,whoami,dir);
  end
  else begin
     if (confirm('Cannot find your directory.  Create one?')) then begin
        code := add_user(name);
	if (code <> 0) then
	   complain(code,whoami,name)
	else begin
	   {$i-}
	   chdir(name); code := ioresult;
	   {$i+}
	   if (code <> 0) then complain(code,whoami,dir);
	end;
     end
     else begin
        {$i-}
        chdir(DEFAULT); code := ioresult;
	{$i+}
        if (code <> 0) then complain(code,whoami,DEFAULT);
     end;
  end;
end.