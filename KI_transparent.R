# LIBRARIES BELOW
{
  library(here)
  library(rstudioapi)
  library(rcrossref)
  # Note that this requires crminer which is currently a bit hard to get ahold of
  library(rtransparent)
  # This path may need to be adjusted.
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
  library(RPostgres)
}

create_necessary_directories <- function(batch_number = 0) {
  print('Creating necessary directories...')
  dir.create('Publications', showWarnings = FALSE)
  dir.create('Full_tables', showWarnings = FALSE)
  dir.create(paste0('Publications/Batch_', batch_number), showWarnings = FALSE)
  dir.create(paste0('Full_tables/Batch_', batch_number), showWarnings = FALSE)
}

download_publication_data <- function(pmcids, batch_number = 0) {
  already_downloaded <- list.files(paste0('Publications/Batch_', batch_number, '/'), pattern='*.xml', all.files=FALSE, full.names=FALSE)
  already_downloaded <- str_remove(already_downloaded,'PMC')
  already_downloaded <- str_remove(already_downloaded,'.xml')
  
  # setdiff is asymmetric, so it's not a problem if the Publications
  # directory contains additional files not covered by pmcids
  remaining <- setdiff(pmcids, already_downloaded)
  if (length(remaining) > 0) {
    filenames <- paste0('Publications/Batch_', batch_number, '/PMC',as.character(remaining),'.xml')
    mapply(metareadr::mt_read_pmcoa,pmcid=remaining,file_name=filenames)
  }
}

evaluate_transparency <- function(batch_number = 0, n_cores = 0) {
  filepath <- paste0('Publications/Batch_', batch_number, '/')
  filelist <- as.list(list.files(filepath, pattern='*.xml', all.files=FALSE, full.names=FALSE))
  filelist <- paste0(filepath, filelist)
  
  if (n_cores == 0) {
    n_cores <- detectCores() - 2
  }
  registerDoParallel(cores=n_cores)
  
  code_transparency <- foreach::foreach(x = filelist,.combine='rbind.fill') %dopar%{rtransparent::rt_data_code_pmc(x)}
  other_transparency <- foreach::foreach(x = filelist,.combine='rbind.fill') %dopar%{rtransparent::rt_all_pmc(x)}
  
  transparency_table <- merge(code_transparency,other_transparency,by=c('pmid', 'pmcid_pmc', 'pmcid_uid', 'doi', 'filename', 'is_research', 'is_review', 'is_success'))
  write.csv(transparency_table, paste0('Full_tables/Batch_', batch_number, '/Transparency.csv'), row.names = FALSE)
  
  transparency_frame <- data.frame(c(transparency_table['pmid'],
                                     transparency_table['pmcid_uid'],
                                     transparency_table['is_research'],
                                     transparency_table['is_review'],
                                     transparency_table['is_open_data'],
                                     transparency_table['is_open_code'],
                                     transparency_table['is_coi_pred'],
                                     transparency_table['is_fund_pred'],
                                     transparency_table['is_register_pred']))
  colnames(transparency_frame) <- c('pmid',
                                    'pmcid',
                                    'research_article',
                                    'review_article',
                                    'open_data',
                                    'open_code',
                                    'coi_pred',
                                    'fund_pred',
                                    'register_pred')
  return(transparency_frame)
}

run_batch <- function(pmcids, batch_number = 0, n_cores = 0) {
  create_necessary_directories(batch_number)
  download_publication_data(pmcids, batch_number = batch_number)
  return(evaluate_transparency(batch_number = batch_number, n_cores = n_cores))
}

create_table_in_database <- function(db, table_name) {
  statement <- paste0('CREATE TABLE ', table_name, ' (
     pmid int NOT NULL PRIMARY KEY,
     pmcid int NOT NULL,
     research_article bool NOT NULL,
     review_article bool NOT NULL,
     open_data bool NOT NULL,
     open_code bool NOT NULL,
     coi_pred bool NOT NULL,
     fund_pred bool NOT NULL,
     register_pred bool NOT NULL
  )')
  
  if (!(dbExistsTable(db, name='analysis.transparency'))) {
    print('Creating table...')
    rs <- dbSendStatement(db, statement)
  }
}

write_transparency_to_database <- function(db, transparency_frame, table_name) {
  preamble <- paste0('INSERT INTO ', table_name, ' (pmid,
     pmcid,
     research_article,
     review_article,
     open_data,
     open_code,
     coi_pred,
     fund_pred,
     register_pred
  ) 
  VALUES ')
  rows <- c()
  for(i in 1:nrow(transparency_frame)){
    row <- paste0('(', paste0(transparency_frame[i,],collapse=","), ')')
    if (!(grepl('NA', row))) {
      rows <- append(rows, row)
    }
  }
  statement <- paste0(preamble, paste(rows,collapse=',\n'), ';')
  rs <- dbGetQuery(db, statement)
}