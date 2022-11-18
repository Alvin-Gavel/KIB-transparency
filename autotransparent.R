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

downloads= function(loc){
  pmcidfilename=paste0("./pmcoalist_",loc,".csv")
  pmcidlist<-read.delim(pmcidfilename, header = TRUE, sep=',')
  pmcidlist=pmcidlist$PMCID
  pmcnumber<-list()
  for (i in pmcidlist){
    go=str_replace(i,'PMC','')
    pmcnumber=c(pmcnumber,go)
  }
  
  #pmcnumber=as.numeric(unlist(x))
  
  # bugged out ones for link;ping
  pmcnumber=pmcnumber[pmcnumber !=8598927]
  pmcnumber=pmcnumber[pmcnumber !=9189602]
  pmcnumber=pmcnumber[pmcnumber !=9077321]
  pmcnumber=pmcnumber[pmcnumber !=8627649]
  pmcnumber=pmcnumber[pmcnumber !=8577685]
  
  # bugged out ones for umea
  pmcnumber=pmcnumber[pmcnumber !=8611285]
  
  # bugged out ones for orebro
  pmcnumber=pmcnumber[pmcnumber !=8445574]
  pmcnumber=pmcnumber[pmcnumber !=8966968]
  pmcnumber=pmcnumber[pmcnumber !=9347643]
  
  # bugged out ones for uppsala
  pmcnumber=pmcnumber[pmcnumber !=9074899]
  pmcnumber=pmcnumber[pmcnumber !=8456286]
  
  filenames=paste0('./publications_',loc, '/PMC',as.character(pmcnumber),'.xml')
  mapply(metareadr::mt_read_pmcoa,pmcid=pmcnumber,file_name=filenames)
}

checkdiff= function(loc){
  filelist <- list.files(paste0('./publications_',loc,'/'), pattern='*.xml', all.files=FALSE, full.names=FALSE)
  pmcidfilename=paste0("./pmcoalist_",loc,".csv")
  pmcidlist<-read.delim(pmcidfilename, header = TRUE, sep=',')
  pmcidlist=pmcidlist$PMCID
  pmcnumber<-list()
  for (i in pmcidlist){
    go=str_replace(i,'PMC','')
    pmcnumber=c(pmcnumber,go)}
  downloaded=str_remove(filelist,'PMC')
  downloaded=str_remove(downloaded,'.xml')
  return(setdiff(pmcnumber, downloaded))
  
}

downloadspmc=function(pmcnumber,loc){
  
  # bugs Uppsala
  pmcnumber=as.integer(pmcnumber)
  pmcnumber=pmcnumber[pmcnumber!=9074899]
  pmcnumber=pmcnumber[pmcnumber!=8456286]
  pmcnumber=pmcnumber[pmcnumber!=8456984]
  pmcnumber=pmcnumber[pmcnumber!=8966968]
  pmcnumber=pmcnumber[pmcnumber!=8484376]
  pmcnumber=pmcnumber[pmcnumber!=9050834]
  pmcnumber=pmcnumber[pmcnumber!=8627649]
  pmcnumber=pmcnumber[pmcnumber!=9306449]
  pmcnumber=pmcnumber[pmcnumber!=8577685]
  pmcnumber=pmcnumber[pmcnumber!=9027952]
  pmcnumber=pmcnumber[pmcnumber!=9372232]
  
  # buggar med gbg
  pmcnumber=pmcnumber[pmcnumber!=8445574]
  pmcnumber=pmcnumber[pmcnumber!=8693323]
  pmcnumber=pmcnumber[pmcnumber!=9067409]
  pmcnumber=pmcnumber[pmcnumber!=9061891]
  pmcnumber=pmcnumber[pmcnumber!=9168950]
  pmcnumber=pmcnumber[pmcnumber!=8791815]
  pmcnumber=pmcnumber[pmcnumber!=8626532]
  pmcnumber=pmcnumber[pmcnumber!=9396711]
  
  filenames=paste0('./publications_',loc, '/PMC',as.character(pmcnumber),'.xml')
  
  mapply(metareadr::mt_read_pmcoa,pmcid=pmcnumber,file_name=filenames)
}

dohooptyhoop=function(loc){
  filepath=paste0('./publications_',loc,'/')
  filelist <- as.list(list.files(filepath, pattern='*.xml', all.files=FALSE, full.names=FALSE))
  
  filelist=paste0(filepath, filelist)
  #filelist=tail(filelist,10)                    
  cores <- detectCores()
  registerDoParallel(cores=cores)
  
  return(foreach::foreach(x = filelist,.combine='rbind.fill') %dopar%{
    ## Use the same library paths as the master R session
    #.libPaths(libs[1])
    rtransparent::rt_data_code_pmc(x)
  })}
dohooptyhooprest=function(loc){
  filepath=paste0('./publications_',loc,'/')
  filelist <- as.list(list.files(filepath, pattern='*.xml', all.files=FALSE, full.names=FALSE))
  
  filelist=paste0(filepath, filelist)
  #filelist=tail(filelist,10)                    
  cores <- detectCores()
  registerDoParallel(cores=cores)
  
  return(foreach::foreach(x = filelist,.combine='rbind.fill') %dopar%{
    ## Use the same library paths as the master R session
    #.libPaths(libs[1])
    rtransparent::rt_all_pmc(x)
  })}
rbind.fill()

institutions=c('umea','link','uppsala','orebro','gbg')

for (i in institutions){
  print(i)
  ins=checkdiff(i)
  downloadspmc(ins,i)
  mclapply(i,downloads)
}


# code and data transparency
for (i in institutions){
  loc=i
  code_df=dohooptyhoop(loc) 
  write.csv(code_df,paste0("./output/codesharing_",loc,".csv"), row.names = FALSE)
}

# resttransparency
for (i in institutions){
  loc=i
  rest_df=dohooptyhooprest(loc) 
  write.csv(rest_df,paste0("./output/resttransp_",loc,".csv"), row.names = FALSE)
}

