\name{triform-package}
\alias{triform-package}
\docType{package}
\title{Triform finds peaks in ChIP-sequencing data.}
\description{The Triform method uses model-free statistics to identify
  peak-like distributions of sequencing reads, taking advantage of an
  improved peak definition in combination with known profile characteristics.}

\details{
\tabular{ll}{
Package: \tab triform\cr
Type: \tab Package\cr
Version: \tab 1.0\cr
Date: \tab 2012-06-01\cr
License: \tab GPL-3\cr
}
It is recommended to make a configuration file in YAML format first.
Then run functions "preprocess" and "triform" to find peaks in
BED-formatted ChIP-sequencing data.
}
\author{Karl Kornacker <\email{kornacker@midohio.twcbc.com}>
  and Tony Handstad <\email{tony.handstad@gmail.com}>
  Maintainer: <tony.handstad@gmail.com>
}

%% TODO: \references{}

\keyword{ package }

\examples{
\dontrun{
preprocess("./config.yml")
triform("./config.yml")
}
}
