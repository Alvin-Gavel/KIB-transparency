# LIBRARIES BELOW
{
  # Note that this requires crminer which is currently a bit hard to get ahold of
  library(rtransparent)
  # This path may need to be adjusted.
  library(SparkR, lib.loc = '~/spark/spark-3.2.2-bin-hadoop3.2/R/lib/')
  library(SparkR)
  library(stringr)
  library(plyr)
  library(dplyr)
  library(parallel)
  library(doParallel)
  library(doFuture)
  library(foreach)
  # We use a Postgres database, but you could replace this with RMySQL and the code
  # should still run
  library(RPostgres)
}

batch <- setRefClass('batch',
                     fields = list(batch_name = 'character',
                                   pmcids = 'character',
                                   n_cores = 'numeric',
                                   verbose = 'logical')
)

batch$methods(
  initialize = function(batch_name, pmcids, n_cores = 0, verbose = FALSE) {
    batch_name <<- batch_name
    pmcids <<- pmcids
    if (n_cores == 0) {
      n_cores <<- detectCores() - 2
    } else {
      n_cores <<- n_cores
    }
    verbose <<- verbose
  },
  create_necessary_directories = function() {
    if (verbose) {
      print('Creating necessary directories...')
    }
    dir.create('Publications', showWarnings = FALSE)
    dir.create('Full_tables', showWarnings = FALSE)
    dir.create(paste0('Publications/Batch_', batch_name), showWarnings = FALSE)
    dir.create(paste0('Full_tables/Batch_', batch_name), showWarnings = FALSE)
    if (verbose) {
      print('Done!')
    }
  },
  download_publication_data = function() {
    already_downloaded <- list.files(paste0('Publications/Batch_', batch_name, '/'), pattern='*.xml', all.files=FALSE, full.names=FALSE)
    already_downloaded <- str_remove(already_downloaded,'PMC')
    already_downloaded <- str_remove(already_downloaded,'.xml')
    
    # setdiff is asymmetric, so it's not a problem if the Publications
    # directory contains additional files not covered by pmcids
    remaining <- setdiff(pmcids, already_downloaded)
    n_remaining <- length(remaining)
    if (verbose) {
      print(paste0('Downloading ', n_remaining , ' files of publication data...'))
    }
    if (n_remaining > 0) {
      filenames <- paste0('Publications/Batch_', batch_name, '/PMC',as.character(remaining),'.xml')
      for (i in 1:n_remaining) {
        metareadr::mt_read_pmcoa(remaining[i],file_name=filenames[i])
      }
    }
    if (verbose) {
      print('Done!')
    }
  },
  evaluate_transparency = function() {
    filepath <- paste0('Publications/Batch_', batch_name, '/')
    filelist <- as.list(list.files(filepath, pattern='*.xml', all.files=FALSE, full.names=FALSE))
    filelist <- paste0(filepath, filelist)
    
    n_files <- length(filelist)
    if (verbose) {
      print(paste0('Evaluating transparency for ', n_files, ' files...'))
    }
    registerDoParallel(cores=n_cores)
    
    code_transparency <- foreach::foreach(x = filelist,.combine='rbind.fill') %dopar%{rtransparent::rt_data_code_pmc(x)}
    other_transparency <- foreach::foreach(x = filelist,.combine='rbind.fill') %dopar%{rtransparent::rt_all_pmc(x)}
    
    transparency_table <- merge(code_transparency,other_transparency,by=c('pmid', 'pmcid_pmc', 'pmcid_uid', 'doi', 'filename', 'is_research', 'is_review', 'is_success'))
    write.csv(transparency_table, paste0('Full_tables/Batch_', batch_name, '/Transparency.csv'), row.names = FALSE)
    
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
    if (verbose) {
      print('Done!')
    }
    return(transparency_frame)
  },
  run = function() {
    create_necessary_directories()
    download_publication_data()
    return(evaluate_transparency())
  }
)


connection <- setRefClass('connection',
                          fields = list(table_name = 'character',
                                        database_connection = 'DBIConnection')
)

connection$methods(
  create_table_in_database = function() {
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
    
    if (!(dbExistsTable(database_connection, name=table_name))) {
      print('Creating table...')
      rs <- dbSendStatement(database_connection, statement)
    }
  },
  write_transparency_to_database = function(transparency_frame) {
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
      row <- paste0('(', paste0(transparency_frame[i,],collapse=','), ')')
      if (!(grepl('NA', row))) {
        rows <- append(rows, row)
      }
    }
    finish <- '\nON CONFLICT (pmid) DO NOTHING;'
    statement <- paste0(preamble, paste(rows,collapse=',\n'), finish)
    rs <- dbGetQuery(database_connection, statement)
  })