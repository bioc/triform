\name{preprocess}
\alias{preprocess}

\title{Preprocess BED-files with reads to calculate chromosome coverage}

\description{
  Given a directory with BED-files describing ChIP-seq reads,
  makes coverage files (1 pr chromosome) describing tag counts along the
  chromosomes. Reads in all available BED-files
  in the given directory is first converted to IRanges objects and saved
  as RData files.
  The preprocessing ends by creating one file for each chromosome, 
  with the calculated coverage on the different strands for different BED-files.
}
\usage{
preprocess(configPath = "./config.yml", params=list())
}

\arguments{
  \item{configPath}{Path to a configuration file in YAML format (see config.yml), or NULL.}
  \item{params}{A list of parameters (see details).}
  
}
\details{
  The preprocess function computes the chromosome tag-coverage along
  each chromosome.\cr
  Parameters supplied in params can include the following:
  \itemize{
    \item READ.PATH  Path to BED files with reads.
    \item COVER.PATH  Path for coverage files (preprocessing output).
    \item READ.WIDTH  Read width (w)
  }
}
\value{
Used for its side-effect.
}

%% TODO: Reference to article\references{}

\author{Karl Kornacker <\email{kornacker@midohio.twcbc.com}> and Tony
  Handstad <\email{tony.handstad@gmail.com}>}

\examples{
\dontrun{
# Run preprocessing using a configuration file in YAML format:
preprocces(configPath = "./config.yml")

# Run preprocessing without using a configuration file:
preprocces(configPath = NULL, params=list(READ.PATH="./tmp",
           COVER.PATH="./chrcovers", READ.WIDTH=100))
}
}

\keyword{manip}

