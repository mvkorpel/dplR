sea <- function(x, key, lag = 5, resample = 1000) {
    if (!is.data.frame(x)) {
        stop("'x' must be a data.frame")
    }
    stopifnot(is.numeric(lag), length(lag) == 1, is.finite(lag),
              lag >= 0, round(lag) == lag)
    stopifnot(is.numeric(resample), length(resample) == 1, is.finite(resample),
              resample >= 1, round(resample) == resample)
    if (ncol(x) >= 1) {                 # remove samp.depth if present
        x.unscaled <- x[1]
    } else {
        stop("'x' must have at least one column")
    }
    rnames <- row.names(as.matrix(x.unscaled))
    if (is.null(rnames)) {
        stop("'x' must have non-automatic row.names")
    }
    rnames <- as.numeric(rnames)
    x.scaled <- data.frame(scale(x.unscaled))
    n <- length(key)
    m <- 2 * lag + 1
    se.table <- matrix(NA_real_, ncol = m, nrow = n)
    se.unscaled.table <- se.table
    yrs.base <- (-lag):(m - lag - 1)
    seq.n <- seq_len(n)
    for (i in seq.n) {
        yrs <- as.character(key[i] + yrs.base)
        se.table[i, ] <- x.scaled[yrs, ]
        se.unscaled.table[i, ] <- x.unscaled[yrs, ]
    }
    se <- colMeans(se.table, na.rm = TRUE)
    se.unscaled <- colMeans(se.unscaled.table, na.rm = TRUE)
    re.table <- matrix(NA_real_, ncol = m, nrow = resample)
    re.subtable <- matrix(NA_real_, ncol = m, nrow = n)
    l <- length(rnames)
    trim <- c(1:lag, (l - lag + 1):l)
    rnames.red <- rnames[-trim]
    for (k in seq_len(resample)) {
        rand.key <- sample(rnames.red, n, replace = TRUE)
        for (i in seq.n) {
            re.subtable[i, ] <-
                               x.scaled[as.character(rand.key[i] + yrs.base), ]
        }
        re.table[k, ] <- colMeans(re.subtable, na.rm = TRUE)
    }
    ## calculate significance for each (lagged) year
    ## compute confidence bands, too
    p <- rep(NA_real_, m)
    re_ecdfs <- apply(re.table, 2, ecdf)
    ci <- apply(re.table, 2, quantile,
               probs = c(0.025, 0.975, 0.005, 0.995)
               )

    if (resample < 1000) {
        warning("'resample' is lower than 1000, potentially leading to less accuracy in estimating p-values and confidence bands.")
    }
    
    for (i in seq_len(m)) {
        if (is.na(se[i])) {
            warning(gettextf("NA result at position %d. ", i),
                    "You could check whether 'key' years are in range.")
        } else {
            if (se[i] < 0) {         # superposed value < 0, it is
                                        # tested whether is
                                        # significantly LOWER than
                                        # random values
                p[i] <- re_ecdfs[[i]](se[i])
            } else {                        # ditto, but v.v.
                p[i] <- 1 - re_ecdfs[[i]](se[i])
            }
        }
    }
    data.frame(lag = c(-lag:lag),
               se,
               se.unscaled,
               p,
               ci.95.lower = ci[1,],
               ci.95.upper = ci[2,],
               ci.99.lower = ci[3,],
               ci.99.upper = ci[4,]
               )
}
