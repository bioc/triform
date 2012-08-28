##' Tests for Triform preprocessing

test_tull <-function(){
  dir <- getwd()
  message("Current directory:", dir)
  checkTrue(TRUE)
}

## test_makeRangedData <- function(){
##   path <- "./data/t1"
##   if (file.exists(file.path(path, "mockdata.RData")))
##     file.remove(file.path(path, "./mockdata.RData"))
  
##   triform:::makeRangedData(path)
##   checkTrue(file.exists(file.path(path, "mockdata.RData")))
##   tmpenv <- new.env()
##   mockNames <- load(file.path(path, "mockdata.RData"), envir=tmpenv)
##   mock <- get(mockNames, envir=tmpenv)
##   checkEquals(levels(space(mock)), c("chrX", "chrY"))
##   checkEquals(start(mock["chrX"])[1], 10633359)
  
## }


## test_makeChromosomeCoverFiles <- function(){
##   path <- "./data/t2"
##   if (file.exists(file.path(path, "chrY_mockdata.RData")))
##     file.remove(file.path(path, "chrY_mockdata.RData"))
##   if (file.exists(file.path(path, "chrX_mockdata.RData")))
##     file.remove(file.path(path, "chrX_mockdata.RData"))
##   triform:::makeChromosomeCoverFiles(filePath=path, filePattern="RData$", gapped.width=100, outputPath=path)

##   tmpenv <- new.env()
##   mockNames <- load(file.path(path, "chrY_mockdata.RData"))
##   mock <- get(mockNames, envir=tmpenv)
##   checkEquals(mock[[1]][[1]], 2)
## }


## test_mergeChromosomesCoverFiles <- function(){
##   path <- "./data/t3"
##   if (file.exists(file.path(path, "chrX.RData")))
##     file.remove(file.path(path, "chrX.RData"))

##   triform:::mergeChromosomeCoverFiles(filePath=path, filePattern="RData$")
##   tmpenv <- new.env()
##   #mockNames <- load(file.path(path, "chrX.RData"))
##   #mock <- get(mockNames, envir=tmpenv)
##   #checkTrue("mockdata" %in% names(mock))
##   checkTrue(TRUE)
## }

