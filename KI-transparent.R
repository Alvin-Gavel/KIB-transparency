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

rootpath = here::here()

extract_pmcnumbers = function(pmcidlist) {
  pmcnumber<-list()
    for (i in pmcidlist){
    go=str_replace(i,'PMC','')
    pmcnumbers=c(pmcnumber,go)
  }
  return(pmcnumbers)
}

downloadspmc=function(pmcnumber,loc){
  filenames=paste0('./publications_',loc, '/PMC',as.character(pmcnumber),'.xml')
  mapply(metareadr::mt_read_pmcoa,pmcid=pmcnumber,file_name=filenames)
}

downloads = function(loc){
  pmcidfilename=paste0("./pmcoalist_",loc,".csv")
  pmcidlist<-read.delim(pmcidfilename, header = TRUE, sep=',')
  pmcidlist=pmcidlist$PMCID

  pmcnumbers = extract_pmcnumbers(pmcidlist)
  downloadspmc(pmcnumber, loc)
}

checkdiff= function(loc){
  filelist <- list.files(paste0('./publications_',loc,'/'), pattern='*.xml', all.files=FALSE, full.names=FALSE)
  pmcidfilename=paste0("./pmcoalist_",loc,".csv")
  pmcidlist<-read.delim(pmcidfilename, header = TRUE, sep=',')
  pmcidlist=pmcidlist$PMCID
  pmcnumbers = extract_pmcnumbers(pmcidlist)
  downloaded=str_remove(filelist,'PMC')
  downloaded=str_remove(downloaded,'.xml')
  return(setdiff(pmcnumber, downloaded))
}

dohooptyhoop=function(loc){
  filepath=paste0('./publications_',loc,'/')
  filelist <- as.list(list.files(filepath, pattern='*.xml', all.files=FALSE, full.names=FALSE))
  
  filelist=paste0(filepath, filelist)       
  cores <- detectCores()
  registerDoParallel(cores=cores)
  
  return(foreach::foreach(x = filelist,.combine='rbind.fill') %dopar%{
    rtransparent::rt_data_code_pmc(x)
  })}
dohooptyhooprest=function(loc){
  filepath=paste0('./publications_',loc,'/')
  filelist <- as.list(list.files(filepath, pattern='*.xml', all.files=FALSE, full.names=FALSE))
  
  filelist=paste0(filepath, filelist)        
  cores <- detectCores()
  registerDoParallel(cores=cores)
  
  return(foreach::foreach(x = filelist,.combine='rbind.fill') %dopar%{
    rtransparent::rt_all_pmc(x)
  })}
rbind.fill()

institutions=c('umea','link','uppsala','orebro','gbg')

for (i in institutions){
  ins=checkdiff(i)
  downloadspmc(ins,i)
  mclapply(i,downloads)
}

for (i in institutions){
  loc=i
  code_df=dohooptyhoop(loc) 
  write.csv(code_df,paste0("./output/codesharing_",loc,".csv"), row.names = FALSE)
}

for (i in institutions){
  loc=i
  rest_df=dohooptyhooprest(loc) 
  write.csv(rest_df,paste0("./output/resttransp_",loc,".csv"), row.names = FALSE)
}

