program test_graphics;
uses
  crt, curves, values;
var
  t:tabloid;
  y:valarrarr;
  p:pararr;
  x:valarr;
  Nx, ix, Np, ip : index;
begin
  set_limits(t, 0,100, 0,2e4);
  set_regions(t);
  set_flags(t, false, false, false);
  set_bounds(t);
  set_static_data (t, 'Test', 'Graph', 'x stuff', 'y stuff');
  set_dynamic_data(t, p, Np, x, Nx, y);
  set_dynamic_ptrs(t, ip, ix);
  dsp_frame(t);
  Np := 10;
  Nx := 100;
  for ip := 1 to Np do begin
     p[ip] := ip;
     for ix := 1 to Nx do begin
        x[ix] := ix;
        y[ip][ix] := p[ip] + x[ix]*x[ix] / p[ip];
        dsp_updates(t);
     end;
  end;
  undsp_frame(t);
end.