;;;;;;   A. Brammer 2016 U Albany
;;;;;;;
;;;;;;;  inlocs center points to search round either (/lat, lon/) or (/ (/lat,lon/), (/lat,lon/) /)
;;;;;;;  critvalue first isoline to search round;  single or same size as inlocs first dim
;;;;;;;  critvalue@loop = True,  if closed keep searching at higher values
;;;;;;;  critvalue@interval   ;  increment to keep searching at
;;;;;;;   will return highest closed isoline value
;;;;;;  @todo  ; Add array support to return values and x/y coords of closed
;;;;;;  note ; only returns True/ False so @loop isn't very useful currently
;;;;;;   ^^^^^^ seems to work with arrays and loop. Maybe I'm insane?
;;;;;;
;;;;;;  If you use this, please shoot me an email so I know my time isn't wasted. 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
undef("check_closed_contour")
function check_closed_contour(data, in_locs, critvalue)
local fake_wks, fakeres, fakeplot, dimz, rankz, nloc, retval, center_loc,\
    crits, loop, interval, cVal, iso, j,b,e,x,y, critvalue, data, closed
begin

fake_wks = create "fake" imageWorkstationClass noparent
"wkHeight":2000
"wkWidth":2000
end create

;fake_wks = gsn_open_wks("png","")
fakeres= True
fakeres@gsnDraw = False
fakeres@gsnFrame = False
fakeplot = gsn_csm_contour(fake_wks, data, fakeres)

dimz = dimsizes(in_locs)
rankz = dimsizes(dimz)
if(rankz .eq.2)
  nloc = dimz(0)
  retval = new(nloc, logical)
  center_loc = in_locs
else
  retval = new( 1, logical)
  nloc = 1
  center_loc = new((/1, dimz(0)/), float)
  center_loc(0,:) = in_locs
end if

retval = False
crits = new(nloc, float)
crits = tofloat(critvalue)

loop = get_res_value_keep(critvalue, "loop", False)
interval = get_res_value_keep(critvalue, "interval", 1.)
max_size = get_res_value_keep(critvalue, "max_size", 5e6)
min_size = get_res_value_keep(critvalue, "min_size", 1e5)
if(loop)
min_size = 1e3
end if
area = new(dimsizes(retval), float)
keep_start = new(dimsizes(retval), integer)
keep_size = new(dimsizes(retval), integer)
keep_val = new(dimsizes(retval), float)

keep_y = 0.
keep_x = 0.
do l=0, nloc-1
;print("-==============-")
;print("l:"+l)
 if(ismissing(center_loc(l,0)) .or.ismissing( crits(l)) ) continue end if
;print("loc index :"+l)
  cVal = crits(l)
  closed = False
;  print("---loop:"+loop)
;  print("---closed:"+closed)
;  print("---cVal:"+cVal)
  do while( (cVal .le. crits(l)) .or. (loop .and. closed)   )
   iso := get_isolines(fakeplot, cVal)
   do j = 0, iso@segment_count -1
    b = iso@start_point(j)
    e = b + iso@n_points(j) - 1
    if(iso(0,b).eq.iso(0,e) .and. iso(1,b).eq.iso(1,e))
      y :=iso(0,b:e)
      x := iso(1,b:e)
      closed = gc_inout(center_loc(l,0), center_loc(l,1), y, x)
      if(closed)
        if( .not. gc_clkwise(y, x) )
          y = y(::-1)
          x = x(::-1)
        end if
       radius := gc_latlon(center_loc(l,0),center_loc(l,1),y, x,0,4) > 150
       t_area = area_poly_sphere(y, x, 6371)     
;      print("Depth:"+(cVal - (crits(l)-interval) ))
;      print("t_area:"+t_area)
;      print("min_radius:"+min(radius))
;      print("max_radius:"+max(radius))      
        if( \
        (t_area .gt. min_size) .and. (t_area .lt. max_size) \
       .and. (max(radius) .le. 2.5*min(radius) ) )
;         print(max(radius)/min(radius))
          area(l) = t_area
          retval(l) = True
          keep_val(l) = cVal
          keep_start(l) = dimsizes(keep_y)
          keep_size(l) = dimsizes(y)
          keep_y := array_append_record(keep_y, y,0)
          keep_x := array_append_record(keep_x, x,0)
   ;      retval@lats := y
   ;      retval@lons := x
   ;      retval@pres = cVal
          break
       end if
      end if
    end if
   end do
   cVal := cVal + interval
;   print("---loop:"+loop)
;   print("---closed:"+closed)
;   print("---cVal:"+cVal)
  end do
end do
retval@val = keep_val
retval@area = area
retval@start_point = keep_start
retval@n_points = keep_size
retval@y = keep_y
retval@x = keep_x
;delete(fake_wks)
return( retval )
end



undef("check_closed_contour_demo")
procedure check_closed_contour_demo()
local inf, data, wks, mpres, map, lats, lons, vals, marks, locs, critvals, closed, gsres, lines, a, b, j
begin


inf = addfile("/cfsr/data/2010/pmsl.2010.0p5.anl.nc","r")

data = inf->pmsl(1235,:,:)
data = data / 100.
wks = gsn_open_wks("x11","")
mpres = True
mpres@mpMaxLatF = 60
mpres@mpMinLatF = 10
mpres@mpMinLonF = -100
mpres@mpMaxLonF = -50
mpres@cnLevelSpacingF = 2.
mpres@cnLowLabelsOn = False
mpres@gsnDraw = False
mpres@gsnFrame = False
map = gsn_csm_contour_map(wks, data, mpres)

lats = (/20, 45/)
lons = (/-74, -71/)
vals = (/1000, 994/)
marks = gsn_add_polymarker(wks, map, lons, lats, False)

locs := new( (/2,2/), float)
locs(:,0) = lats
locs(:,1) = lons

critvals = vals + 2.
critvals@loop = True
critvals@interval = 2
closed :=  check_closed_contour(data, locs, critvals)

gsres  = True
gsres@gsLineColor = "Red"
gsres@gsLineThicknessF = 5.
lines = new(dimsizes(closed), graphic)
do j = 0,dimsizes(closed) -1
  if(closed(j))
    a = closed@start_point(j)
    b = closed@start_point(j) + closed@n_points(j)-1
    lines(j) = gsn_add_polyline(wks, map, closed@x(a:b), closed@y(a:b), gsres)
  end if
end do

draw(map)
frame(wks)

end


