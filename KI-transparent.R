# LIBRARIES BELOW
{
  library(here)
  library(rstudioapi)
  library(tokenizers)
  library(rcrossref)
  # Note that this requires crminer which is currently a bit hard to get ahold of
  library(rtransparent)
  # This currently uses a path specific to my computer, which is not good
  library(SparkR, lib.loc = "/home/alvin/spark/spark-3.2.2-bin-hadoop3.2/R/lib/")
  library(SparkR)
  library(tidyverse)
  library(oddpub)
  library(metareadr)
  library(stringr)
  library(plyr)
  library(dplyr)
  library(crminer)
  library(parallel)
  library(lme4)
  library(doParallel)
  library(progressr)
  library(doFuture)
  library(foreach)
  library(ggplot2)
  library(reshape2)
}

extract_pmcnumbers = function(loc) {
  pmcidfilename=paste0("./pmcoalist_",loc,".csv")
  pmcidlist<-read.delim(pmcidfilename, header = TRUE, sep=',')
  pmcidlist=pmcidlist$PMCID
  
  pmcnumbers<-list()
  for (i in pmcidlist){
    go=str_replace(i,'PMC','')
    pmcnumbers=c(pmcnumbers,go)
  }
  return(pmcnumbers)
}

# This is currently unused, but I may put it back into use later
checkdiff = function(loc, pmcnumbers){
  
  pmcnumbers = extract_pmcnumbers(loc)
  downloaded=str_remove(filelist,'PMC')
  downloaded=str_remove(downloaded,'.xml')
  return(setdiff(pmcnumbers, downloaded))
}

download_publication_data = function(loc){
  pmcnumbers = extract_pmcnumbers(loc)
  already_downloaded <- list.files(paste0('./publications_',loc,'/'), pattern='*.xml', all.files=FALSE, full.names=FALSE)
  already_downloaded=str_remove(already_downloaded,'PMC')
  already_downloaded=str_remove(already_downloaded,'.xml')
  remaining = setdiff(pmcnumbers, already_downloaded)
  
  if (length(remaining) > 0) {
    filenames=paste0('./publications_',loc, '/PMC',as.character(remaining),'.xml')
    mapply(metareadr::mt_read_pmcoa,pmcid=pmcnumbers,file_name=filenames)
  }
}

evaluate_transparency=function(loc){
  filepath=paste0('./publications_',loc,'/')
  filelist <- as.list(list.files(filepath, pattern='*.xml', all.files=FALSE, full.names=FALSE))
  
  filelist=paste0(filepath, filelist)
  cores <- detectCores()
  registerDoParallel(cores=cores)
  
  code_df = foreach::foreach(x = filelist,.combine='rbind.fill') %dopar%{rtransparent::rt_data_code_pmc(x)}
  write.csv(code_df,paste0("./output/codesharing_",ins,".csv"), row.names = FALSE)
  
  rest_df = foreach::foreach(x = filelist,.combine='rbind.fill') %dopar%{rtransparent::rt_all_pmc(x)}
  write.csv(rest_df,paste0("./output/resttransp_",ins,".csv"), row.names = FALSE)
}
rbind.fill()

rootpath = here::here()
institutions=c('umea','link','uppsala','orebro','gbg','lund')#,'ki')

dir.create(file.path(rootpath, 'output'), showWarnings = FALSE)
for (ins in institutions){
  dir.create(file.path(rootpath, paste0('./publications_',ins)), showWarnings = FALSE)
  download_publication_data(ins)
  evaluate_transparency(ins)
}

