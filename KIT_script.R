source('KI_transparent.R')

rootpath <- here::here()
institutions <- c('umea','link','uppsala','orebro','gbg','lund','ki')

dir.create(file.path(rootpath, 'output'), showWarnings = FALSE)
for (ins in institutions){
  print(paste0("Collecting data from ",ins,"..."))
  dir.create(file.path(rootpath, paste0('./publications/',ins)), showWarnings = FALSE)
  download_publication_data(ins)
  evaluate_transparency(ins)
}