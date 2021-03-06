#' Compute pi coefficients of an AR process from SARIMA coefficients.
#'
#' Convert SARIMA coefficients to pi coefficients of an AR process.
#' @param ar AR coefficients in the SARIMA model.
#' @param d number of differences in the SARIMA model.
#' @param ma MA coefficients in the SARIMA model.
#' @param sar seasonal AR coefficients in the SARIMA model.
#' @param D number of seasonal differences in the SARIMA model.
#' @param sma seasonal MA coefficients in the SARIMA model.
#' @param m seasonal period in the SARIMA model.
#' @param tol tolerance value used. Only return up to last element greater than tolerance.
#'
#' @return A vector of AR coefficients.
#' @author Rob J Hyndman
#' @export
#' @importFrom stats dist
#' @importFrom stats tsp
#' @importFrom stats tsp<-
#' @importFrom stats acf
#' @importFrom forecast BoxCox.lambda
#' @importFrom stats loess
#'
#' @examples
#' # Not Run
pi_coefficients <- function(ar = 0, d = 0L, ma = 0, sar = 0, D = 0L, sma = 0, m = 1L, tol = 1e-07) {
  # non-seasonal AR
  ar <- polynomial(c(1, -ar)) * polynomial(c(1, -1))^d

  # seasonal AR
  if (m > 1) {
    P <- length(sar)
    seasonal_poly <- numeric(m * P)
    seasonal_poly[m * seq(P)] <- sar
    sar <- polynomial(c(1, -seasonal_poly)) * polynomial(c(1, rep(0, m - 1), -1))^D
  }
  else {
    sar <- 1
  }

  # non-seasonal MA
  ma <- polynomial(c(1, ma))

  # seasonal MA
  if (m > 1) {
    Q <- length(sma)
    seasonal_poly <- numeric(m * Q)
    seasonal_poly[m * seq(Q)] <- sma
    sma <- polynomial(c(1, seasonal_poly))
  }
  else {
    sma <- 1
  }

  n <- 500L
  theta <- -c(coef(ma * sma))[-1]
  if (length(theta) == 0L) {
    theta <- 0
  }
  phi <- -c(coef(ar * sar)[-1], numeric(n))
  q <- length(theta)
  pie <- c(numeric(q), 1, numeric(n))
  for (j in seq(n))
    pie[j + q + 1L] <- -phi[j] - sum(theta * pie[(q:1L) + j])
  pie <- pie[(0L:n) + q + 1L]

  # Return up to last element greater than tol
  maxj <- max(which(abs(pie) > tol))
  pie <- head(pie, maxj)
  return(-pie[-1])
}

#' Compute pi coefficients from ARIMA model
#'
#' Compute pi coefficients from ARIMA model
#' @param object An object of class "Arima"
#'
#' @return A vector of AR coefficients
#' @author Rob J Hyndman
#' @export
#'
#' @examples
#' # Not Run
arinf <- function(object) {
  if (!("Arima" %in% class(object))) {
    stop("Argument should be an ARIMA object")
  }
  pi_coefficients(
    ar = object$model$phi, ma = object$model$theta,
    d = object$arma[6], D = object$arma[7], m = object$arma[5]
  )
}

# library(forecast)
# USAccDeaths %>% auto.arima %>% arinf %>% plot
# lynx %>% auto.arima %>% arinf %>% plot

#' Set the number of seasonal differences for yearly data to be -1.
#'
#' @param x Univariate time series or numerical vector
#'
#' @return A numerical scalar value
#'
#' @export
#'
#' @examples
#' # Not Run
nsdiffs1 <- function(x) {
  c(nsdiffs = ifelse(frequency(x) == 1L, -1, forecast::nsdiffs(x)))
}


nroot <- function(x,n){
  abs(x)^(1/n)*sign(x)
}

corrtemporder1 <- function (x, y) {
  p <- length(x)
  sum((x[2:p] - x[1:(p - 1)]) * (y[2:p] - y[1:(p - 1)]))/(sqrt(sum((x[2:p] -
                                                                      x[1:(p - 1)])^2)) * sqrt(sum((y[2:p] - y[1:(p - 1)])^2)))
}

diss.cort <- function (x, y, k = 2){
  corrt <- corrtemporder1(x, y)
  typedist <- as.numeric(dist(rbind(x, y)))
  (2/(1 + exp(k * corrt))) * typedist
}

scalets01 <- function(x){
  n <- length(x)
  scaledx <- as.numeric((x-min(x))/(max(x)-min(x)))
  y <- as.ts(scaledx)
  tsp(y) <- tsp(x)
  return(y)
}

SeasonalityTest <- function(input, ppy){
  if (length(input)<3*ppy){
    test_seasonal <- FALSE
  }else{
    xacf <- acf(input, plot = FALSE)$acf[-1, 1, 1]
    clim <- 1.645/sqrt(length(input)) * sqrt(cumsum(c(1, 2 * xacf^2)))
    test_seasonal <- ( abs(xacf[ppy]) > clim[ppy] )
    if (is.na(test_seasonal)==TRUE){ test_seasonal <- FALSE }
  }
  return(test_seasonal)
}
Smoothing_ts2 <- function(x, spanw, fh){
  ppy <- frequency(x) ; ST <- F ; trend <- 1:length(x)
  if (ppy>1){ ST <- SeasonalityTest(x,ppy) }
  if (ST==T){
    lambda <- BoxCox.lambda(x,lower=0,upper=1)
    bc.x <- as.numeric(BoxCox(x, lambda))
    seasonal <- stl(ts(bc.x, frequency = ppy), "per")$time.series[, 1]
    bc.x <- bc.x - as.numeric(seasonal)
    x <- as.numeric(InvBoxCox(bc.x, lambda))+x-x
    suppressWarnings(x.loess <- loess(x ~ trend, span = spanw/length(x), degree = 1))
    x <- as.numeric(x.loess$fitted)+x-x
    SIin <- seasonal
    SIout <- head(rep(seasonal[(length(seasonal)-ppy+1):length(seasonal)], fh), fh)
  }else{
    suppressWarnings(x.loess <- loess(x ~ trend, span = spanw/length(x), degree = 1))
    x <- as.numeric(x.loess$fitted)+x-x
    SIin <- rep(0, length(x))
    SIout <- rep(0, fh)
    lambda <- 1
  }
  output <- list(series=x, seasonalIn=SIin, seasonal=SIout, lambda=lambda)
  return(output)
}
