# LIBRARIES BELOW
{
  library(here)
  library(rstudioapi)
  library(rcrossref)
  # Note that this requires crminer which is currently a bit hard to get ahold of
  library(rtransparent)
  # This currently uses a path specific to my computer, which is not good
  library(SparkR, lib.loc = "~/spark/spark-3.2.2-bin-hadoop3.2/R/lib/")
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

download_publication_data <- function(pmcids) {
  already_downloaded <- list.files('Publications/', pattern='*.xml', all.files=FALSE, full.names=FALSE)
  already_downloaded <- str_remove(already_downloaded,'PMC')
  already_downloaded <- str_remove(already_downloaded,'.xml')
  remaining <- setdiff(pmcids, already_downloaded)
  
  if (length(remaining) > 0) {
    filenames <- paste0('Publications/PMC',as.character(remaining),'.xml')
    mapply(metareadr::mt_read_pmcoa,pmcid=remaining,file_name=filenames)
  }
}

evaluate_transparency <- function() {
  filepath <- 'Publications/'
  filelist <- as.list(list.files(filepath, pattern='*.xml', all.files=FALSE, full.names=FALSE))
  
  filelist <- paste0(filepath, filelist)
  cores <- detectCores()
  registerDoParallel(cores=cores)
  
  code_transparency <- foreach::foreach(x = filelist,.combine='rbind.fill') %dopar%{rtransparent::rt_data_code_pmc(x)}
  other_transparency <- foreach::foreach(x = filelist,.combine='rbind.fill') %dopar%{rtransparent::rt_all_pmc(x)}

  transparency <- merge(code_transparency,other_transparency,by=c('pmid', 'pmcid_pmc', 'pmcid_uid', 'doi', 'filename', 'is_research', 'is_review', 'is_success'))
  write.csv(transparency, 'Output/Transparency.csv', row.names = FALSE)
}

run_transparency <- function(pmcids) {
  rootpath <- here::here()
  create_necessary_directories(rootpath)
  download_publication_data(pmcids)
  evaluate_transparency()
}