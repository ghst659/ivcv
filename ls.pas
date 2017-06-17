program ls (input, output);
uses
  dos;

const
  WILDCARD = '*.*';

procedure list (pat:string);
var
  f : file;
  attrib : word;
begin
  assign(f, pat);
  GetFAttr(f, attrib);
  if (DosError = 0) then begin
     write(pat, ' ');
     if ((attrib and Archive) <> 0)   then write('A');
     if ((attrib and Directory) <> 0) then write('D');
     if ((attrib and VolumeID) <> 0)  then write('V');
     if ((attrib and SysFile) <> 0)   then write('S');
     if ((attrib and Hidden) <> 0)    then write('H');
     if ((attrib and ReadOnly) <> 0)  then write('R');
     writeln;
  end
  else
     writeln(pat,': ',DosError);
end;

function rindex (s:string; c:char) : byte;
var
  si : byte;
  not_found : boolean;
begin
  si := length(s);
  not_found := true;
  while not_found and (si > 0) do begin
     if (s[si] = c) then
        not_found := false
     else
        dec(si);
  end;
  rindex := si;
end;

function stem(path:string) : string;
var
  p : byte;
begin
  p := rindex(path,'\');
  if (p = 0) then
     stem := ''
  else
     stem := copy(path,1,p+1);
end;

var
  i : integer;
  di : SearchRec;
  patbuf : string;
  work_dir : string;
begin
  GetDir(0, work_dir);
  if (paramcount = 0) then
     list('.')
  else
     for i := 1 to paramcount do begin
        findfirst(paramstr(i), AnyFile, di);
        while (DosError = 0) do begin
	   patbuf := stem(paramstr(i)) + di.name;
	   list(patbuf);
	   findnext(di);
        end;
     end;
  {$i-}
  chdir(work_dir);
  {$i+}
end.