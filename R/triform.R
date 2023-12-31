##' Implementation of Triform peak detection
 
options(stringsAsFactors=FALSE)
library(IRanges)
library(yaml)


##' Runs Triform according to configuration file or given parameters.
##'
##' If configPath is NULL, all the other arguments must be supplied.
##' @title triform
##' @param configPath Path to a configuration file in YAML format, or NULL.
##' @param COVER.PATH Path for coverage files (from preprocessing).
##' @param TARGETS Filenames for TFs. Must include .bed ending and _rep1 to indicate replicate number.
##' @param CONTROLS Filenames for control signal. Must include .bed ending and _rep1 to indicate replicate number.
##' @param OUTPUT.PATH Path for output file.
##' @param MAX.P Minimum p-value, used to calculate min.z
##' @param MIN.WIDTH Minimum peak width (min.n)
##' @param MIN.QUANT Quantile of enrichment ratios, used to calculate min.er
##' @param MIN.SHIFT Minimum inter-strand lag between peak coverage distributions.
##' @param FLANK.DELTA Fixed spacing between central and flanking locations (δ).
##' @param CHRS A list of chromosomes to be processed.
##' @return 
triform <- function(configPath="./config.yml", params=list()){
  if (! is.null(configPath)){
    message("Using config file ", configPath)
    config <- yaml.load_file(configPath)
    for (i in seq_along(config)){
      assign(names(config)[i], config[[i]], pos=".GlobalEnv")
    }
  }

  for (i in seq_along(params)){
    assign(names(params)[i], params[[i]], pos=".GlobalEnv")
  }

  ## Make SUMCVG.NAMES and TARGET.NAMES
  if(!(all(grepl(".bed", c(TARGETS, CONTROLS))) && all(grepl("_rep.", c(TARGETS,CONTROLS)))))
    stop("Error: Make sure filenames in TARGETS and CONTROLS are correct (i.e. contains .bed ending and _rep1 or _rep2 to indicate replicate number.")
  TARGETS <- sub(".bed", "", TARGETS)
  CONTROLS <- sub(".bed", "", CONTROLS)
  SUMCVG.NAMES <<- c(TARGETS, CONTROLS)
  TARGET.NAMES <<- unique(sub("_rep.", "", TARGETS))
  
  MIN.Z <<- qnorm(MAX.P, lower.tail=FALSE)
  FLANK.DELTA.PAD <<- Rle(0, FLANK.DELTA)
  
  N.TYPES <<- length(SUMCVG.NAMES)
  TYPES <<- factor(1:N.TYPES, labels=SUMCVG.NAMES)

  DIRECTIONS <<- factor(1:2, labels=c("REVERSE","FORWARD"))
  N.DIRS <<- length(DIRECTIONS)

  LOCATIONS <<- factor(1:3, labels=c("LEFT","RIGHT","CENTER"))
  N.LOCS <<- length(LOCATIONS)

  N.DIRLOCS <<- N.DIRS*N.LOCS

  DIRECTION <<- rep(rep(DIRECTIONS,ea=N.LOCS),N.TYPES)
  LOCATION <<- rep(LOCATIONS,N.DIRS*N.TYPES)
  TYPE <<- rep(TYPES,ea=N.DIRLOCS)

  CVG.NAMES <<- paste(TYPE,DIRECTION,LOCATION,sep=".")
  IS.LEFT <<- grepl("LEFT",CVG.NAMES)
  IS.RIGHT <<- grepl("RIGHT",CVG.NAMES)
  IS.CENTER <<- grepl("CENTER",CVG.NAMES)
  IS.REP1 <<- grepl("_rep1",CVG.NAMES)
  IS.REP2 <<- grepl("_rep2",CVG.NAMES)
  ## IS.CONTROL is True if dataset is control/background data (not in TARGET.NAMES)
  IS.CONTROL <<- !apply(sapply(TARGET.NAMES, function(t) {grepl(t,CVG.NAMES)}), 1, any)
  
  test.genome(min.z=MIN.Z,
              min.shift=MIN.SHIFT,
              min.width=MIN.WIDTH,
              chromosomes=CHRS,
              chrcoversPath=COVER.PATH,
              outputFilePath=OUTPUT.PATH)
  
}


##' Finds peaks for all given chromosomes and outputs results
##'
##' 
##' @title test.genome
##' @param min.z Minimum z.value
##' @param min.shift Minimum inter-strand lag between peak coverage distributions
##' @param min.width Minimum peak width
##' @param chromosomes The chromosomes to search in
##' @param chrcoversPath Path to chromosome coverage files
##' @param outputFilePath Path for output file with peak predictions
##' @return
test.genome <- function(min.z=MIN.Z,
                        min.shift=MIN.SHIFT,
                        min.width=MIN.WIDTH,
                        chromosomes=CHRS,
                        chrcoversPath="./chrcovers",
                        outputFilePath="./Triform_output.csv") {
  INFO <<- NULL
  for(chr in chromosomes) {
    message("Triform processing ", chr)
    flush.console()
    INFO <<- rbind(INFO, test.chr(
                                  chr=chr,
                                  min.z=min.z,
                                  min.shift=min.shift,
                                  min.width=min.width,
                                  filePath=chrcoversPath))
    message("Found ", as.character(N.PEAKS), " peaks")
  }
  message("\n\nSaving results to path: ", outputFilePath)
  flush.console()
  write.table(INFO, file=outputFilePath, col.names=NA, quote=FALSE, sep="\t")
  message("Finished.")
}


##' Finds peaks for a given chromosome
##'
##' 
##' @title test.chr
##' @param chr Chromosome
##' @param min.z Minimum z.value
##' @param min.shift Minimum inter-strand lag between peak coverage distributions
##' @param min.width Minimum peak width
##' @return A list of peak loci
test.chr <- function(chr,
                     min.z=MIN.Z,
                     min.shift=MIN.SHIFT,
                     min.width=MIN.WIDTH,
                     filePath="./chrcovers") {
  test.init(chr, filePath)
  
  PEAKS <<- list()
  PEAK.INFO <<- list()
  CENTER.CVG <<- list()
  N.PEAKS <<- 0
  
  for(type in TARGET.NAMES)  {
    PEAKS[[type]] <<- list()
    PEAK.INFO[[type]] <<- list()
    CENTER.CVG[[type]] <<- list()
    is.type <- grepl(type, CVG.NAMES)
    
    for(direction in DIRECTIONS){
      PEAKS[[type]][[direction]] <<- list(IRanges(),IRanges(),IRanges())
      PEAK.INFO[[type]][[direction]] <<- list(NULL,NULL,NULL)

      
      if (any(IS.REP2)){
        ## Use 2 replicates
        formsList <- findForms2Replicates(direction, is.type, type,
                                          min.z, min.width) 
      } else{
        ## Use 1 replicate
        formsList <- findForms1Replicate(direction, is.type, type,
                                         min.z, min.width)
      }
      p1 <- formsList$p1
      p2 <- formsList$p2
      p3 <- formsList$p3
      p4 <- formsList$p4
      ratio <- formsList$ratio
      ref <- formsList$ref
      zscores.list <- formsList$zscores.list
      cvg <- formsList$cvg
      rm(formsList)

      
      p1 <- intersect(p1,p4)
      ok <- (width(p1)>min.width)
      p1 <- p1[ok]
      
      p2 <- intersect(p2,p4)
      ok <- (width(p2)>min.width)
      p2 <- p2[ok]

      p3 <- intersect(p3,p4)
      ok <- (width(p3)>min.width)
      p3 <- p3[ok]
      
      peaks.list <- list(p1,p2,p3)
      zviews.list <- mapply(function(x,y) Views(x,y),
                            x=zscores.list, y=peaks.list)
      maxz.list <- lapply(zviews.list, viewMaxs)
      
      for(i in 1:3) {	# separate analyses of different peak forms
        peaks <- peaks.list[[i]]
        if(!length(peaks)) next
        
        maxz <- maxz.list[[i]]
        peak.nlps <- -pnorm(maxz, lower.tail=FALSE,log.p=TRUE)/log(10)

        peak.locs <- round((start(peaks)+end(peaks))/2)
        peak.cvg <- cvg[peak.locs,drop=TRUE]
        peak.ref <- ref[peak.locs,drop=TRUE]
        peak.enrich <- (1+ratio*peak.cvg)/(1+peak.ref)
        
        if(i==1) min.er <<- quantile(peak.enrich,MIN.QUANT)
        ok <- (peak.enrich>min.er)
        if(!any(ok)) next
        
        peaks <- peaks[ok]
        peak.locs <- peak.locs[ok]
        peak.nlps <- peak.nlps[ok]
        
        PEAKS[[type]][[direction]][[i]] <<- peaks
        n.peaks <- length(peaks)
        dfr <- data.frame(PEAK.LOC=peak.locs,
                          PEAK.NLP=round(peak.nlps,3), PEAK.WIDTH=width(peaks), 
                          PEAK.START=start(peaks), PEAK.END=end(peaks))
        PEAK.INFO[[type]][[direction]][[i]] <<- dfr   
      }
    }
    direction <- "merged"
    PEAKS[[type]][[direction]] <<- list(IRanges(),IRanges(),IRanges())
    PEAK.INFO[[type]][[direction]] <<- list(NULL,NULL,NULL)
    PEAK.INFO[[type]][["regions"]] <<- list(NULL,NULL,NULL)
    
    neg.cvg <- CENTER.CVG[[type]][[1]]
    pos.cvg <- CENTER.CVG[[type]][[2]]
    
    for (i in 1:3) {
      p1 <- PEAKS[[type]][[1]][[i]]
      p2 <- PEAKS[[type]][[2]][[i]]
      if(!length(p1) | !length(p2)) next
      
      ov <- matrix(as.matrix(findOverlaps(p1,p2)),ncol=2)
      if(!nrow(ov)) next
      
      dup1 <- (ov[,1] %in% ov[duplicated(ov[,1]),1])
      dup2 <- (ov[,2] %in% ov[duplicated(ov[,2]),2])
      is.multi <- dup1 | dup2
      if(all(is.multi)) next
      ov <- ov[!is.multi,,drop=FALSE]
      
      p1 <- p1[1:length(p1) %in% ov[,1]]
      p2 <- p2[1:length(p2) %in% ov[,2]]
      peaks <- IRanges(start=pmin(start(p1),start(p2)),
                       end=pmax(end(p1),end(p2)))
      
      switch(i,
             ranges <- IRanges(start=start(peaks)-FLANK.DELTA,
                               end=end(peaks)+FLANK.DELTA),
             ranges <- IRanges(start=start(peaks)-FLANK.DELTA,
                               end=end(peaks)),
             ranges <- IRanges(start=start(peaks),
                               end=end(peaks)+FLANK.DELTA))
      
      neg.peak.cvg <- viewApply(Views(neg.cvg,ranges),as.numeric)
      pos.peak.cvg <- viewApply(Views(pos.cvg,ranges),as.numeric)
      
      lags <- mapply(function(x,y) {
        cc=ccf(x,y,lag.max=100,plot=FALSE)
        with(cc,lag[which.max(acf)])
      }, x=neg.peak.cvg, y=pos.peak.cvg)
      
      ok <- (lags > min.shift)
      if(!any(ok)) next
      ov <- ov[ok,,drop=FALSE]
      peaks <- peaks[ok]
      
      if(i==1) type.delta <<- round(median(lags[ok]))
      
      info1 <- PEAK.INFO[[type]][[1]][[i]][ov[,1],]
      info2 <- PEAK.INFO[[type]][[2]][[i]][ov[,2],]
      peak.locs <- round((info1$PEAK.LOC + info2$PEAK.LOC)/2)
      peak.nlps <- info1$PEAK.NLP + info2$PEAK.NLP
      
      PEAKS[[type]][[direction]][[i]] <<- peaks
      n.peaks <- length(peaks)
      
      dfr <- data.frame(PEAK.FORM=i, PEAK.NLP=peak.nlps,
                        PEAK.WIDTH=width(peaks), PEAK.LOC=peak.locs,
                        PEAK.START=start(peaks), PEAK.END=end(peaks))
      
      rownames(dfr) <- with(dfr,sprintf("%s:%d-%d:%d",CHR,PEAK.START,PEAK.END,PEAK.FORM))
      PEAK.INFO[[type]][[direction]][[i]] <<- dfr  
      N.PEAKS <<- N.PEAKS + n.peaks
    }
  }
  if(!N.PEAKS) return()
  
                                        # exclude redundant Form-2 and Form-3 peaks
  p1 <- PEAKS[[type]][[direction]][[1]]
  p2 <- PEAKS[[type]][[direction]][[2]]
  p3 <- PEAKS[[type]][[direction]][[3]]
  peak.info <- PEAK.INFO[[type]][[direction]][[1]]
  
  ov12 <- matrix(as.matrix(findOverlaps(p1,p2)),ncol=2)
  if(!!nrow(ov12)) {
    ex2 <- (1:length(p2) %in% ov12[,2])
    p2 <- p2[!ex2]
    PEAKS[[type]][[direction]][[2]] <<- p2
    info <- PEAK.INFO[[type]][[direction]][[2]][!ex2,,drop=FALSE]
    PEAK.INFO[[type]][[direction]][[2]] <<- info
    peak.info <- rbind(peak.info,info)
  }
  ov13 <- matrix(as.matrix(findOverlaps(p1,p3)),ncol=2)
  if(!!nrow(ov13)) {
    ex3 <- (1:length(p3) %in% ov13[,2])
    p3 <- p3[!ex3]
    PEAKS[[type]][[direction]][[3]] <<- p3
    info <- PEAK.INFO[[type]][[direction]][[3]][!ex3,,drop=FALSE]
    PEAK.INFO[[type]][[direction]][[3]] <<- info
    peak.info <- rbind(peak.info,info)
  }
  
                                        # merge overlapping Form-2 and Form-3 peaks into Form-1 peaks
  peak.info <- with(peak.info,peak.info[order(PEAK.START,PEAK.END),])
  rng <- with(peak.info,IRanges(start=PEAK.START,end=PEAK.END))
  ov <- matrix(as.matrix(findOverlaps(rng,maxgap=1,drop.self=TRUE,drop.redundant=TRUE)),ncol=2)
  if(!!nrow(ov)) {
    peak.info[ov[,1],"PEAK.FORM"] <- 1
    peak.info[ov[,1],"PEAK.LOC"] <- round((peak.info[ov[,1],"PEAK.LOC"] + peak.info[ov[,2],"PEAK.LOC"])/2)
    peak.info[ov[,1],"PEAK.NLP"] <- peak.info[ov[,1],"PEAK.NLP"] + peak.info[ov[,2],"PEAK.NLP"]
    peak.info[ov[,1],"PEAK.START"] <- pmin(peak.info[ov[,1],"PEAK.START"],peak.info[ov[,2],"PEAK.START"])
    peak.info[ov[,1],"PEAK.END"] <- pmax(peak.info[ov[,1],"PEAK.END"],peak.info[ov[,2],"PEAK.END"])
    peak.info[ov[,1],"PEAK.WIDTH"] <- 1 + peak.info[ov[,1],"PEAK.END"] - peak.info[ov[,1],"PEAK.START"]
    peak.info <- peak.info[-ov[,2],]
  }
  
  N.PEAKS <<- nrow(peak.info)
  peak.info
}



##' Creates sample/direction/location-specific coverage data for a chromosome
##'
##' Stores result in global variable CVG
##' @title test.init
##' @param chr The chromosome
##' @param filePath The path to the chromosome coverage file
##' @return 
test.init <- function(chr, filePath="./chrcovers") {
  if(!exists("CHR",inherits=TRUE)) CHR <<- "none"
  if(chr==CHR) return()
  
  load(file.path(filePath, paste(chr,".RData",sep="")), .GlobalEnv) # load chrcovers
  
  CVG <<- list()
  SIZES <<- NULL
  for(h in 1:N.TYPES) {       			# TYPE index
    type <- SUMCVG.NAMES[h]
    SIZES <<- c(SIZES, rep(unlist(chrcovers[[type]]$SIZE),ea=N.LOCS))
    cvgs <- chrcovers[[type]]$CVG		# coverage on each strand

    for (i in 1:N.DIRLOCS) {   			# DIRECTON.LOCATION index
      n <- i+N.DIRLOCS*(h-1)   			# SAMPLE.DIRECTON.LOCATION index
      j <- ceiling(i/N.LOCS)    		# DIRECTION index
      cvg <- cvgs[[j]]        			# strand-specific coverage
      
      if(IS.CONTROL[n]) {
        if(IS.CENTER[n]) {
          CVG[[n]] <<- cvg
        }
        next                                    # no need for flanking input coverage
      }
      switch(1 + (i-1)%%N.LOCS,			# LOCATION index
             CVG[[n]] <<- c(FLANK.DELTA.PAD, rev(rev(cvg)[-1:-FLANK.DELTA])), # strand-specific coverage on left flank
             CVG[[n]] <<- c(cvg[-1:-FLANK.DELTA], FLANK.DELTA.PAD), # strand-specific coverage on right flank
             CVG[[n]] <<- cvg     # strand-specific coverage on center
             )
    }
  }
  names(CVG) <<- CVG.NAMES
  maxlen <- max(sapply(CVG,length))
  CVG <<- lapply(CVG,function(cvg) c(cvg,Rle(0,maxlen-length(cvg))))
  names(SIZES) <<- CVG.NAMES
  
  CHR <<- chr
}


##' Calculates Z score
##'
##' @title zscore
##' @param x Signal
##' @param y Background
##' @param r Ratio (background size / signal size)
##' @return z-score
zscore <- function(x,y,r=1) {  # r = size.y/size.x
  dif <- (r*x-y)
  zs <- dif/sqrt(r*(x+y))
  zs[!dif] <- 0
  zs
}






findForms1Replicate <- function(direction, is.type, type,
                                min.z, min.width){
  is.dir <- grepl(direction, CVG.NAMES)
  ref <- (CVG[[CVG.NAMES[IS.CONTROL & is.dir & IS.CENTER & IS.REP1]]])
          

  surL <- CVG[[CVG.NAMES[is.type & is.dir & IS.LEFT & IS.REP1]]]
  surR <- CVG[[CVG.NAMES[is.type & is.dir & IS.RIGHT & IS.REP1]]]
  cvg <- CVG[[CVG.NAMES[is.type & is.dir & IS.CENTER & IS.REP1]]]

  CENTER.CVG[[type]][[direction]] <<- cvg

                                        
  signs <- sign(2*cvg-surL-surR)
  ok <- (signs==1)
  zscores1 <- zscore(cvg,surL+surR,2) * ok
  peaks1 <- slice(zscores1,lower=min.z)
  peaks1 <- peaks1[width(peaks1)>min.width]
  p1 <- as(peaks1,"IRanges")

                                        
  signs <- sign(cvg-surL)
  ok <- (signs==1)
  zscores2 <- zscore(cvg,surL) * ok
  peaks2 <- slice(zscores2,lower=min.z)
  peaks2 <- peaks2[width(peaks2)>min.width]
  p2 <- as(peaks2,"IRanges")

                                        
  signs <- sign(cvg-surR)
  ok <- (signs==1)
  zscores3 <- zscore(cvg,surR) * ok
  peaks3 <- slice(zscores3,lower=min.z)
  peaks3 <- peaks3[width(peaks3)>min.width]
  p3 <- as(peaks3,"IRanges")

                                        
  ref.size <- (SIZES[IS.CONTROL & is.dir & IS.CENTER & IS.REP1])
  cvg.size <- SIZES[is.type & is.dir & IS.CENTER & IS.REP1]
  ratio <- ref.size/cvg.size

  signs <- sign(ratio*cvg-ref)
  ok <- (signs==1)
  zscores4 <- zscore(cvg,ref,ratio) * ok
  peaks4 <- slice(zscores4,lower=min.z)
  peaks4 <- peaks4[width(peaks4)>min.width]
  p4 <- as(peaks4,"IRanges")

  zscores.list <- list(zscores1,zscores2,zscores3)

  return(list(p1=p1, p2=p2, p3=p3, p4=p4, ratio=ratio, ref=ref, zscores.list=zscores.list, cvg=cvg))
  
}


findForms2Replicates <- function(direction, is.type, type,
                                 min.z, min.width){
  is.dir <- grepl(direction, CVG.NAMES)
  ## ref <- (CVG[[CVG.NAMES[IS.CONTROL & is.dir & IS.CENTER & IS.REP1]]] +
  ##         CVG[[CVG.NAMES[IS.CONTROL & is.dir & IS.CENTER & IS.REP2]]])
  ref <- Reduce("+",CVG[which(IS.CONTROL & is.dir & IS.CENTER)])	# no need for replicate inputs

  surL1 <- CVG[[CVG.NAMES[is.type & is.dir & IS.LEFT & IS.REP1]]]
  surR1 <- CVG[[CVG.NAMES[is.type & is.dir & IS.RIGHT & IS.REP1]]]
  cvg1 <- CVG[[CVG.NAMES[is.type & is.dir & IS.CENTER & IS.REP1]]]
  
  surL2 <- CVG[[CVG.NAMES[is.type & is.dir & IS.LEFT & IS.REP2]]]
  surR2 <- CVG[[CVG.NAMES[is.type & is.dir & IS.RIGHT & IS.REP2]]]
  cvg2 <- CVG[[CVG.NAMES[is.type & is.dir & IS.CENTER & IS.REP2]]]
  
  surL <- surL1 + surL2
  surR <- surR1 + surR2
  cvg <- cvg1 + cvg2
  CENTER.CVG[[type]][[direction]] <<- cvg
  
                                        # Form-1 test with consistency check
  signs1 <- sign(2*cvg1-surL1-surR1)
  signs2 <- sign(2*cvg2-surL2-surR2)
  ok <- (signs1==1)*(signs2==1)
  zscores1 <- zscore(cvg,surL+surR,2) * ok
  peaks1 <- slice(zscores1,lower=min.z)
  peaks1 <- peaks1[width(peaks1)>min.width]
  p1 <- as(peaks1,"IRanges")
  
                                        # Form-2 test with consistency check
  signs1 <- sign(cvg1-surL1)
  signs2 <- sign(cvg2-surL2)
  ok <- (signs1==1)*(signs2==1)
  zscores2 <- zscore(cvg,surL) * ok
  peaks2 <- slice(zscores2,lower=min.z)
  peaks2 <- peaks2[width(peaks2)>min.width]
  p2 <- as(peaks2,"IRanges")
  
                                        # Form-3 test with consistency check
  signs1 <- sign(cvg1-surR1)
  signs2 <- sign(cvg2-surR2)
  ok <- (signs1==1)*(signs2==1)
  zscores3 <- zscore(cvg,surR) * ok
  peaks3 <- slice(zscores3,lower=min.z)
  peaks3 <- peaks3[width(peaks3)>min.width]
  p3 <- as(peaks3,"IRanges")
  
                                        # enrichment test with consistency check
  ## ref.size <- (SIZES[IS.CONTROL & is.dir & IS.CENTER & IS.REP1] +
  ##              SIZES[IS.CONTROL & is.dir & IS.CENTER & IS.REP2])
  ref.size <- sum(SIZES[IS.CONTROL & is.dir & IS.CENTER])				# no need for replicate inputs
  cvg1.size <- SIZES[is.type & is.dir & IS.CENTER & IS.REP1]
  cvg2.size <- SIZES[is.type & is.dir & IS.CENTER & IS.REP2]
  cvg.size <- cvg1.size + cvg2.size
  ratio1 <- ref.size/cvg1.size
  ratio2 <- ref.size/cvg2.size
  ratio <- ref.size/cvg.size
  
  signs1 <- sign(ratio1*cvg1-ref)
  signs2 <- sign(ratio2*cvg2-ref)
  ok <- (signs1==1)*(signs2==1)
  zscores4 <- zscore(cvg,ref,ratio) * ok
  peaks4 <- slice(zscores4,lower=min.z)
  peaks4 <- peaks4[width(peaks4)>min.width]
  p4 <- as(peaks4,"IRanges")

  zscores.list <- list(zscores1,zscores2,zscores3)

  return(list(p1=p1, p2=p2, p3=p3, p4=p4, ratio=ratio, ref=ref, zscores.list=zscores.list, cvg=cvg))
}
