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

create_necessary_directories <- function(rootpath) {
  dir.create(file.path(rootpath, 'Publications'), showWarnings = FALSE)
  dir.create(file.path(rootpath, 'Output'), showWarnings = FALSE)
}

download_publication_data <- function(pmids){
  already_downloaded <- list.files(paste0('./Publications/'), pattern='*.xml', all.files=FALSE, full.names=FALSE)
  already_downloaded <- str_remove(already_downloaded,'PMC')
  already_downloaded <- str_remove(already_downloaded,'.xml')
  remaining <- setdiff(pmids, already_downloaded)
  
  if (length(remaining) > 0) {
    filenames <- paste0('./Publications/PMC',as.character(remaining),'.xml')
    print(filenames)
    mapply(metareadr::mt_read_pmcoa,pmcid=remaining,file_name=filenames)
  }
}

evaluate_transparency <- function(){
  filepath <- paste0('./Publications/')
  filelist <- as.list(list.files(filepath, pattern='*.xml', all.files=FALSE, full.names=FALSE))
  
  filelist <- paste0(filepath, filelist)
  cores <- detectCores()
  registerDoParallel(cores=cores)
  
  code_df <- foreach::foreach(x = filelist,.combine='rbind.fill') %dopar%{rtransparent::rt_data_code_pmc(x)}
  write.csv(code_df,paste0("./Output/Codesharing.csv"), row.names = FALSE)
  
  rest_df <- foreach::foreach(x = filelist,.combine='rbind.fill') %dopar%{rtransparent::rt_all_pmc(x)}
  write.csv(rest_df,paste0("./Output/Resttransp.csv"), row.names = FALSE)
}

run <- function(pmids) {
  rootpath <- here::here()
  create_necessary_directories(rootpath)
  download_publication_data(pmids)
  evaluate_transparency()
}