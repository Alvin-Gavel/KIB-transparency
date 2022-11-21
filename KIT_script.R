source('KI_transparent.R')

rootpath <- here::here()
#institutions <- c('umea','link','uppsala','orebro','gbg','lund','ki')
institutions <- c('gbg')

create_necessary_directories(rootpath)
for (ins in institutions){
  print(paste0("Collecting data from ",ins,"..."))
  dir.create(file.path(rootpath, paste0('./Publications/',ins)), showWarnings = FALSE)
  download_publication_data(ins)
  evaluate_transparency(ins)
}