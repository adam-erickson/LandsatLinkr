#' Calibrate OLI images to TM images
#'
#' Calibrate OLI images to TM images using linear regression
#' @param oliwrs2dir character. oli WRS-2 scene directory path
#' @param tmwrs2dir character. TM WRS-2 scene directory path
#' @param cores numeric. Number of cores to process with options: 1 or 2
#' @export


olical = function(oliwrs2dir, tmwrs2dir, cores=2){  
  
  
  olifiles = list.files(oliwrs2dir, "l8sr.tif", recursive=T, full.names=T)
  tmfiles = list.files(tmwrs2dir, "tc.tif", recursive=T, full.names=T)
  
  #pull out oli and tm year
  olibase = basename(olifiles)
  oliyears = substr(olibase, 10, 13)
  tmbase = basename(tmfiles)   
  tmyears = substr(tmbase, 10, 13)
  tmyearday = as.numeric(substr(tmbase, 10, 16))
  
  #get overlapping oli/etm+ years
  oliuni = unique(oliyears)
  notintm = oliuni %in% tmyears
  if(sum(notintm) < 2){stop("There are not at least three years of overlaping images between OLI and ETM+")}
  theseoli = which(oliyears %in% tmyears == T)
  olifilessub = olifiles[theseoli]
  olibase = olibase[theseoli]
  oliyears = oliyears[theseoli]
  oliyearday = as.numeric(substr(olibase, 10, 16))
  
  len = length(olifilessub)
  match = data.frame(oli=olifilessub, etm=NA)
  for(i in 1:len){
    thisone = order(abs(oliyearday[i]-tmyearday))[1]
    match$etm[i] = tmfiles[thisone]
  }  
  
  
  #do single pair modeling
  print("single image pair modeling")
  if(cores==2){
    cl = makeCluster(cores)
    registerDoParallel(cl)
    cfun <- function(a, b) NULL
    o = foreach(i=1:len, .combine="cfun",.packages="LandsatLinkr") %dopar% olical_single(match$oli[i], match$etm[i]) #
    stopCluster(cl)
  } else {for(i in 1:len){olical_single(match$oli[i], match$etm[i])}}
  
  #do aggregated modeling
  caldir = file.path(oliwrs2dir,"calibration")
  print("...aggregate image pair modeling")
  cal_oli_tc_aggregate_model(caldir)
  
  #predict tc and tca from aggregate model
  calagdir = file.path(caldir,"aggregate_model")
  bcoef = as.numeric(read.csv(file.path(calagdir,"tcb_cal_aggregate_coef.csv"))[1,2:10])
  gcoef = as.numeric(read.csv(file.path(calagdir,"tcg_cal_aggregate_coef.csv"))[1,2:10])
  wcoef = as.numeric(read.csv(file.path(calagdir,"tcw_cal_aggregate_coef.csv"))[1,2:10])
  
  print("...applying model to all oli images")
  for(i in 1:len){olisr2tc(olifiles[i],bcoef,gcoef,wcoef,"apply")}
  
}