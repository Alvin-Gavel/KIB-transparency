# LIBRARIES BELOW
{
  # Note that this requires crminer which is currently a bit hard to get ahold of
  library(rtransparent)
  # This path may need to be adjusted.
  library(SparkR, lib.loc = '~/spark/spark-3.3.1-bin-hadoop3/R/lib/')
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

connection <- setRefClass('connection',
                          fields = list(tableName = 'character',
                                        databaseConnection = 'DBIConnection')
)

connection$methods(
  writeTransparencyToDatabase = function(transparencyFrame) {
    preamble <- paste0('INSERT INTO ', tableName, ' (
      pmid,
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
    addedAnything <- FALSE
    exampleInvalidRow <- ''
    for(i in 1:nrow(transparencyFrame)){
      entry <- transparencyFrame[i,]
      # We have run into a couple of cases of pmids being empty
      if (entry[1] != '') {
        row <- paste0('(', paste0(entry,collapse=','), ')')
        if (!(grepl('NA', row))) {
          rows <- append(rows, row)
          addedAnything <- TRUE
        } else {
          exampleInvalidRow <- row
        }
      }
    }
    finish <- '\nON CONFLICT (pmid) DO NOTHING;'
    statement <- paste0(preamble, paste(rows,collapse=',\n'), finish)
    if (addedAnything) {
      rs <- dbGetQuery(databaseConnection, statement)
    } else {
      print('After removing invalid entries, nothing was left!')
      print('Example invalid row:')
      print(exampleInvalidRow)
    }
  })

analysisBatch <- setRefClass('analysisBatch',
                             fields = list(analysisName = 'character',
                                           batchNumber = 'numeric',
                                           batchName = 'character',
                                           pmcids = 'character',
                                           nCores = 'numeric',
                                           verbose = 'logical')
)

analysisBatch$methods(
  initialize = function(analysisName, batchNumber, pmcids, nCores = 0, verbose = FALSE) {
    analysisName <<- analysisName
    batchNumber <<- batchNumber
    pmcids <<- pmcids
    if (nCores == 0) {
      nCores <<- detectCores() - 2
    } else {
      nCores <<- nCores
    }
    verbose <<- verbose
  },
  createNecessaryDirectories = function() {
    if (verbose) {
      print('Creating necessary directories...')
    }
    dir.create('Publications', showWarnings = FALSE)
    dir.create('Full_tables', showWarnings = FALSE)
    dir.create(paste0('Publications/', analysisName), showWarnings = FALSE)
    dir.create(paste0('Full_tables/', analysisName), showWarnings = FALSE)
    dir.create(paste0('Publications/', analysisName, '/', batchNumber), showWarnings = FALSE)
    dir.create(paste0('Full_tables/', analysisName, '/', batchNumber), showWarnings = FALSE)
    if (verbose) {
      print('Done!')
    }
  },
  cleanUpDirectories = function() {
    if (verbose) {
      print('Cleaning up directories...')
    }
    unlink(paste0('Publications/', analysisName, '/', batchNumber), recursive=TRUE)
    unlink(paste0('Full_tables/', analysisName, '/', batchNumber), recursive=TRUE)
    if (verbose) {
      print('Done!')
    }
  },
  downloadPublicationData = function() {
    nPmcids <- length(pmcids)
    if (verbose) {
      print(paste0('Downloading ', nPmcids , ' files of publication data...'))
    }
    filenames <- paste0('Publications/', analysisName, '/', batchNumber, '/PMC',as.character(pmcids),'.xml')
    for (i in 1:nPmcids) {
      tryCatch(metareadr::mt_read_pmcoa(pmcids[i],file_name=filenames[i]),
               error = function(e) {
                 print(paste0('Problem with download of ', filenames[i], ', skipping for now...'))
               }
      )
    }
    if (verbose) {
      print('Done!')
    }
  },
  evaluateTransparency = function() {
    filePath <- paste0('Publications/', analysisName, '/', batchNumber, '/')
    fileList <- as.list(list.files(filePath, pattern='*.xml', all.files=FALSE, full.names=FALSE))
    fileList <- paste0(filePath, fileList)
    
    nFiles <- length(fileList)
    if (verbose) {
      print(paste0('Evaluating transparency for ', nFiles, ' files...'))
    }
    registerDoParallel(cores=nCores)
    
    if (verbose) {
      print('Evaluating code transparency...')
    }
    codeTransparency <- foreach::foreach(x = fileList,.combine='rbind.fill') %dopar%{rtransparent::rt_data_code_pmc(x)}
    
    if (verbose) {
      print('Evaluating other transparency...')
    }
    otherTransparency <- foreach::foreach(x = fileList,.combine='rbind.fill') %dopar%{rtransparent::rt_all_pmc(x)}
    
    transparencyTable <- merge(codeTransparency, otherTransparency,by=c('pmid', 'pmcid_pmc', 'pmcid_uid', 'doi', 'filename', 'is_research', 'is_review', 'is_success'))
    write.csv(transparencyTable, paste0('Full_tables/', batchName, '/Transparency.csv'), row.names = FALSE)
    
    # Check that anything at all was returned by both functions
    if (("is_open_data" %in% colnames(transparencyTable)) & ("is_coi_pred" %in% colnames(transparencyTable))) {
      transparencyFrame <- data.frame(c(transparencyTable['pmid'],
                                        transparencyTable['pmcid_uid'],
                                        transparencyTable['is_research'],
                                        transparencyTable['is_review'],
                                        transparencyTable['is_open_data'],
                                        transparencyTable['is_open_code'],
                                        transparencyTable['is_coi_pred'],
                                        transparencyTable['is_fund_pred'],
                                        transparencyTable['is_register_pred']))
      if (verbose) {
        print('Done!')
      }
    } else {
      transparencyFrame <- data.frame(matrix(nrow = 0, ncol = 9))
      if (verbose) {
        print('Failed at producing any values!')
        print('Returning dummy dataframe instead')
      }
    }
    colnames(transparencyFrame) <- c('pmid',
                                     'pmcid',
                                     'research_article',
                                     'review_article',
                                     'open_data',
                                     'open_code',
                                     'coi_pred',
                                     'fund_pred',
                                     'register_pred')
    return(transparencyFrame)
  },
  run = function() {
    cleanUpDirectories()
    createNecessaryDirectories()
    downloadPublicationData()
    results <- evaluateTransparency()
    cleanUpDirectories()
    return(results)
  }
)


fullAnalysis <- setRefClass('batch',
                            fields = list(analysisName = 'character',
                                          pmcids = 'character',
                                          nFiles = 'numeric',
                                          tableName = 'character',
                                          databaseConnection = 'DBIConnection',
                                          nCores = 'numeric',
                                          batchSize = 'numeric',
                                          verbose = 'logical',
                                          pmcidBatches = 'character')
)

fullAnalysis$methods(
  initialize = function(analysisName, pmcids, tableName, databaseConnection, nCores = 0, batchSize = 0, verbose = FALSE) {
    analysisName <<- analysisName
    pmcids <<- pmcids
    tableName <<- tableName
    databaseConnection <<- databaseConnection
    nFiles <<- length(pmcids)
    if (nCores == 0) {
      nCores <<- detectCores() - 2
    } else {
      nCores <<- nCores
    }
    if (batchSize == 0) {
      batchSize <<- length(pmcids)
    } else {
      batchSize <<- batchSize
    }
    verbose <<- verbose
  },
  runBatch = function(i) {
    pmcidBatch <- pmcids[batchSize * (i - 1) + 1: batchSize]
    # This handles the case of running over the end on the last batch. There is probably some neater way to do it.
    pmcidBatch <- pmcidBatch[!is.na(pmcidBatch)]
    batchI <- analysisBatch(analysisName, i, pmcidBatch, nCores = nCores, verbose = verbose)
    return(batchI$run())
  },
  run = function() {
    if (verbose) {
      print(paste0("Has ", nFiles, " pmcids to run"))
      print("Checking what Pubmed Central ids are already in our database...")
    }
    already_analysed <- dbGetQuery(databaseConnection, paste0("select at.pmcid 
from ", tableName, " at"))
    
    nFull <- length(pmcids)
    pmcids <<- setdiff(pmcids, already_analysed$pmcid)
    nFiles <<- length(pmcids)
    if (verbose) {
      print(paste0("There are ", nFull - nFiles, " already in the database"))
      print(paste0("There are ", nFiles, " left to analyse"))
    }
    for (i in 1:ceiling(nFiles/batchSize)) {
      if (verbose) {
        print(paste0("Starting on batch ", i))
      }
      transparencyFrame <- runBatch(i)
      if (nrow(transparencyFrame) > 0) {
        kibTable <- connection(tableName = tableName, databaseConnection = databaseConnection)
        kibTable$writeTransparencyToDatabase(transparencyFrame)
      }
    }
  }
)