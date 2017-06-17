program system_time (input, output);
uses
  generics;
var
  today : date_rec;
begin
  get_date(today);
  writeln('System time is ',time_str(get_rtime,true),
          ' on ',date_str(today,true),'.');
end.