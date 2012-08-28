\name{triform}
\alias{triform}

\title{
Run Triform peak detection algorithm.
}
\description{
  Runs Triform according to configuration file or given parameters.\cr
  Triform uses chromosome coverage files prepared by the preprocessing function.
}
\usage{
triform(configPath = "./config.yml", params=list())
}

\arguments{
  \item{configPath}{Path to a configuration file in YAML format, or
    NULL.}
  \item{params}{A list of parameters values (see details)}
  
}
\details{
  If configPath is NULL, all the other arguments must be supplied in params.\cr
  Values in params will overwrite values as set in the configuration file.
  The following list explains the parameters for the triform algorithm:
  \itemize{
    \item COVER.PATH  Path for coverage files (from preprocessing).
    \item OUTPUT.PATH  Path for output file.
    \item TARGETS  Filenames for TF experiments. (Named according to
      replicate, i.e. myTF_rep1.bed for replicate 1.
    \item CONTROLS  Filnames for control experiments (Named according to replicate).
    \item MAX.P  Minimum p-value, used to calculate min.z
    \item MIN.WIDTH  Minimum peak width (min.n)
    \item MIN.QUANT  Quantile of enrichment ratios, used to calculate min.er
    \item MIN.SHIFT  Minimum inter-strand lag between peak coverage distributions.
    \item FLANK.DELTA  Fixed spacing between central and flanking locations.
    \item CHRS  A list of chromosomes to be processed.
  }
}
\value{
Output is saved to the outputpath.
}
%% TODO: Reference to article\references{}

\author{Karl Kornacker <\email{kornacker@midohio.twcbc.com}> and Tony
  Handstad <\email{tony.handstad@gmail.com}>}

\seealso{
  \code{\link{preprocess}}
}
\examples{

\dontrun{
# Run Triform with configuration file:
triform(configPath = "./config.yml")

# Run Triform with arguments instead of configuration file:
triform(configPath=NULL, params=list(COVER.PATH = "./chrcovers",
       OUTPUT.PATH = "./Triform_output.csv",
       CONTROLS = c("backgr_huds_Gm12878_rep1", "backgr_huds_Gm12878_rep2"),
       TARGETS = c("srf_huds_Gm12878_rep1", "srf_huds_Gm12878_rep2"),
       MAX.P = 0.1, MIN.WIDTH = 10, MIN.QUANT = 0.375, MIN.SHIFT = 10, 
       FLANK.DELTA = 150, CHRS = c("chrY")))
}
}

\keyword{ model }

