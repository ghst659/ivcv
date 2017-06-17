.pas.exe:
	tpc $*
.pas.tpu:
	tpc $*

backup:
	copy *.pas a: /v
	copy makefile a: /v
newmos: mos.exe
	copy mos.exe ..\newmos.exe /v
	del mos.exe
install: mos.exe
	copy mos.exe .. /v
	del mos.exe
mos: mos.exe
mos.exe: mos.pas units
units: site.tpu generics.tpu values.tpu \
     err_tab.tpu rt_error.tpu scaling.tpu graphics.tpu plotter.tpu \
     gpib.tpu curves.tpu parser.tpu dosdev.tpu hpgl.tpu penplot.tpu \
     multprog.tpu menus.tpu

menus.tpu: menus.pas parser.tpu
site.tpu: site.pas
gpib.tpu: gpib.pas
generics.tpu: generics.pas
values.tpu: values.pas
scaling.tpu: scaling.pas generics.tpu
parser.tpu: parser.pas generics.tpu
err_tab.tpu: err_tab.pas generics.tpu
multprog.tpu: multprog.pas gpib.tpu generics.tpu
dosdev.tpu: dosdev.pas generics.tpu
hpgl.tpu: hpgl.pas generics.tpu dosdev.tpu
rt_error.tpu: rt_error.pas generics.tpu err_tab.tpu
graphics.tpu: graphics.pas site.tpu generics.tpu err_tab.tpu scaling.tpu
plotter.tpu: plotter.pas generics.tpu scaling.tpu hpgl.tpu
penplot.tpu: penplot.pas plotter.tpu generics.tpu values.tpu scaling.tpu \
		hpgl.tpu
curves.tpu: curves.pas graphics.tpu generics.tpu values.tpu scaling.tpu \
      		penplot.tpu
