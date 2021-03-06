load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCLPATH/get_environment_diff.ncl"
load "$NCLPATH/contour_plot.ncl"

begin
  file_cntrl    = getenv("CNTRLSEASAVGRHO")
  file_netcdf = getenv("SEASAVGRHO")
  file_tavg   = getenv("TAVGFILE")

  print("mld_diff file_cntrl = " + file_cntrl)
  print("mld_diff file_netcdf = " + file_netcdf)
  print("mld_diff file_tavg = " + file_tavg)

  winter_plot = 1 

; in sigma units
  pd_offset = (/ 0.125d, 0.03d /)

  noff = dimsizes(pd_offset)

  ns_max = 1 

  missing_value = default_fillvalue("double")
  nc = 2

  fileid = addfile(file_tavg,"r")

  kmt = fileid->KMT
  region_mask = fileid->REGION_MASK
  tarea = fileid->TAREA
  ht = fileid->HT

  fileid = addfile(file_netcdf,"r")
  field = fileid->PD

  n=0

  tlon = fileid->TLONG
  tlon = where(tlon .le. 30, tlon + 360, tlon)

  tlat = fileid->TLAT
  if (isvar("depth")) then
    delete(depth)
  end if
  depth = fileid->z_t
  time = fileid->time

; convert depth and HT to m from cm

  depth = depth * 0.01
  ht    = ht    * 0.01
  tarea = tarea * 1.0e-4
  size = dimsizes(field)
  nx = size(3)
  ny = size(2)
  nz = size(1)
  nt = size(0)
  field@_FillValue = missing_value
  field = where(field .eq. field@missing_value,field@_FillValue,field)
  PD = new((/nc,nt,nz,ny,nx/),double)

  PD(0,:,:,:,:) = field
  delete(field)


  fileid = addfile(file_cntrl,"r")
  field = fileid->PD
  if (.not.isatt(field,"_FillValue")) then
    field@_FillValue = default_fillvalue("double")
  end if
  field = where(field .eq. field@missing_value,field@_FillValue,field)
  PD(1,:,:,:,:) = (/field/)
  delete(field)

  MLD = new((/nc,nt,ny,nx/),double)

  MLD@long_name = "mixed layer depth"

  lev_0 = (/ 0., 25., 50., 75., 100., 150., 200., 250., 500., 1000., 2000. /)
  lev_mod = (/ 0., 25., 50., 75., 100., 150., 200., 250., 500., 1000., 2000. /)

  coltab_l =   5. + (122./5.)*ispan(0,4,1) 
  coltab_h = 145. + (110./5.)*ispan(0,5,1)
  coltab_0 = new(dimsizes(lev_0) + 1,integer)
  coltab_0(1:) = tointeger(array_append_record( coltab_l, coltab_h,0))
  coltab_0(0) = 0

  lev_1 = (/ -1000., -500., -200., -100., -80., -60., -40., \
  -20.,  -10.,    0.,   10.,   20.,  40.,  60.,  80., \
  100.,  200.,  500., 1000. /)
  delete([/coltab_l,coltab_h/])
  coltab_l =   5. + (122./8.)*ispan(0,8,1)
  coltab_h = 145. + (110./8.)*ispan(0,8,1)

  tmp = array_append_record( tofloat(coltab_l), (/14.,14./),0)
  coltab_1 = tointeger(array_append_record( tmp, coltab_h,0))
  delete(tmp)

  lev_2 = (/ -1000., -500., -400., -300., -200.,-150.,-100., \
  -50.,  -20.,    0.,   20.,   50.,  100., 150., 200., \ 
  300.,  400.,  500.,  1000. /)
  delete([/coltab_l,coltab_h/])

  coltab_l =   5. + (122./8.)*ispan(0,7,1)
  coltab_h = 145. + (110./8.)*ispan(0,8,1)
  coltab_2 = new(dimsizes(lev_2) + 1,integer)
  tmp = array_append_record( coltab_l, (/14.,14./),0)
  coltab_2(1:) = tointeger(array_append_record( tmp, coltab_h,0))
  coltab_2(0) = 0
  delete(tmp)

  do off = 0, noff - 1

    print("plotting mixed layer depth at " + pd_offset(off))

    MLD = mixed_layer_depth(PD,kmt,ht,depth,pd_offset(off))
    opt = False
    MLD = wgt_area_smooth(MLD,tarea,opt)

    MLD_mean = new((/nc,ny,nx/),double)
    MLD_nw_mean = new((/nc,ny,nx/),double)
    MLD_sw_mean = new((/nc,ny,nx/),double)
    MLD_winter_mean = new((/nc,ny,nx/),double)
    do m = 0,nc-1
      MLD_mean(m,:,:) = dim_avg_n_Wrap(MLD(m,:,:,:),0)
      MLD_nw_mean(m,:,:) = dim_avg_n_Wrap(MLD(m,0:2,:,:),0)
      MLD_sw_mean(m,:,:) = dim_avg_n_Wrap(MLD(m,6:8,:,:),0)
    end do
    tlat_c = conform(MLD_winter_mean,tlat,(/1,2/))
    MLD_winter_mean = where(tlat_c .ge. 0, MLD_nw_mean,MLD_sw_mean)

    MLD_mean_diff = MLD_mean(0,:,:) - MLD_mean(1,:,:)
    MLD_winter_mean_diff = MLD_winter_mean(0,:,:) - MLD_winter_mean(1,:,:)

    mean_diff = wgt_areaave2(MLD_mean_diff,tarea,0)
    mean_rms = sqrt(sum(MLD_mean_diff * MLD_mean_diff * tarea) / sum(tarea))
    mean_rms = wgt_arearmse2(MLD_mean(0,:,:),MLD_mean(1,:,:),tarea,0)

    winter_mean_diff = wgt_areaave2(MLD_winter_mean_diff,tarea,0)
    winter_mean_rms = sqrt(sum(MLD_winter_mean_diff * MLD_winter_mean_diff * tarea) / sum(tarea))
    winter_mean_rms = wgt_arearmse2(MLD_winter_mean(0,:,:),MLD_winter_mean(1,:,:),tarea,0)

    fname = "mld" + (off + 1)
    ;wks = gsn_open_wks("x11",fname)
    wks = gsn_open_wks(img_format,fname)
    gsn_define_colormap(wks,"table42")

    opt = True
    opt@aspect_ratio = 1.25
    opt@charsize = 0.9
    opt@landcolor = lndcolor
    opt@contourline = 2
    opt@xrange = (/ xr0,xr1/)
    opt@yrange = (/ yr0,yr1/)
    opt@do_panel = True
    opt@nomean = True
    opt@cnInfoLabelOn = False
    opt@tmXBLabelFontHeightF = .02
    opt@lbLabelBarOn = False
    opt@gsnLeftStringFontHeightF = .02
    opt@gsnRightStringFontHeightF = .02
    opt@gsnMajorLonSpacing = 60
    opt@gsnMajorLatSpacing = 45
    units = "sigma"
    case_info = cntrl_number + " MEAN"
    opt@gsnRightString = "" + pd_offset(off)

    opt@cnLabelBarEndStyle = "ExcludeOuterBoxes"

    missing = MLD@_FillValue
    dlev = dimsizes(lev_0)

    plot1 = contour_plot(wks, MLD_mean(1,:,:), tlon, tlat, kmt, region_mask, tarea, case_info, \
    missing, units, dlev, lev_0, coltab_0, opt)

    opt@lbLabelBarOn = False
    opt@tmYLLabelsOn = False
    case_info = cntrl_number + " WINTER MEAN"
    plot2 = contour_plot(wks, MLD_winter_mean(1,:,:), tlon, tlat, kmt, region_mask, tarea, case_info, \
    missing, units, dlev, lev_0, coltab_0, opt)

    opt@tmYLLabelsOn = True
    opt@tmXBLabelsOn = False
    delete(opt@gsnRightString)

    case_info = case_number + " MEAN"
    plot3 = contour_plot(wks, MLD_mean(0,:,:), tlon, tlat, kmt, region_mask, tarea, case_info, \
    missing, units, dlev, lev_0, coltab_0, opt)

    opt@tmYLLabelsOn = False
    opt@lbLabelBarOn = False

    case_info = case_number + " WINTER MEAN"
    plot4 = contour_plot(wks, MLD_winter_mean(0,:,:), tlon, tlat, kmt, region_mask, tarea, case_info, \
    missing, units, dlev, lev_0, coltab_0, opt)

    panel_res = True
    panel_res@gsnPanelLabelBar = True
    panel_res@lbAutoManage = False
    panel_res@lbLabelAutoStride = True
    panel_res@pmLabelBarHeightF = .06
    panel_res@pmLabelBarWidthF = .62
    panel_res@lbLabelFontHeightF = 0.012
    panel_res@gsnMaximize = True
    panel_res@gsnPanelYWhiteSpacePercent = 3
    panel_res@gsnPanelScalePlotIndex = 1
    panel_res@gsnPanelTop = 1.
    panel_res@gsnPanelBottom = .385
    panel_res@gsnFrame = False

    gsn_panel(wks,(/plot1,plot2,plot3,plot4/), (/2,2/),panel_res)

    mean_diff = decimalPlaces(mean_diff,2,True)
    mean_rms = decimalPlaces(mean_rms,2,True)
    winter_mean_diff = decimalPlaces(winter_mean_diff,2,True)
    winter_mean_rms = decimalPlaces(winter_mean_rms,2,True)

    opt@tmYLLabelsOn = True
    opt@tmXBLabelsOn = True

    if (case_number .eq. cntrl_number) then
      case_info = time_info + " - " + cntrl_time_info
    else
      case_info = case_number + " - " + cntrl_number
    end if
    plot5_label = "MEAN"
    plot5 = contour_plot(wks, MLD_mean_diff(:,:), tlon, tlat, kmt, region_mask, tarea, plot5_label, \
    missing, units, dlev, lev_1, coltab_2, opt)

    text_array = (/ "mean = " + mean_diff , "rms = " + mean_rms /)

    text_x = (/ 40, 40 /)
    text_y = (/ 65, 55 /)
    text_res = True
    text_res@txJust = "centerleft"
    text_res@txFontHeightF = 0.02
    text_add = gsn_add_text(wks,plot5,text_array,text_x,text_y,text_res)

    opt@tmYLLabelsOn = False
    opt@lbLabelBarOn = False
    if (case_number .eq. cntrl_number) then
      case_info = time_info + " - " + cntrl_time_info
    else
      case_info = case_number + " - " + cntrl_number
    end if
    plot6_label = "WINTER MEAN"
    plot6 = contour_plot(wks, MLD_winter_mean_diff(:,:), tlon, tlat, kmt, region_mask, tarea, plot6_label, \
    missing, units, dlev, lev_1, coltab_2, opt)

    text_array = (/ "mean = " + winter_mean_diff , "rms = " + winter_mean_rms /)
    text_x = (/ 40, 40 /)
    text_y = (/ 65, 55 /)
    text_res = True
    text_res@txJust = "centerleft"
    text_res@txFontHeightF = 0.02
    text_add = gsn_add_text(wks,plot6,text_array,text_x,text_y,text_res)

    panel_res@txString = case_info
    panel_res@txFontHeightF = 0.012
    panel_res@gsnPanelBottom = 0.01
    panel_res@gsnFrame = True
    panel_res@gsnPanelTop = .385
    panel_res@gsnPanelScalePlotIndex = 1
    panel_res@gsnPanelXWhiteSpacePercent = 1
    panel_res@pmLabelBarWidthF = .62
    gsn_panel(wks,(/plot5,plot6/), (/1,2/),panel_res)

  end do

end
