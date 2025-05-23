#' Read a Sweave concordance file to calculate the correspondence between the
#' lines in the original Rnoweb file and the lines in the generated LaTeX file.
#' @param texf LaTeX file.
#' @param concf Concordance file.
SyncTeX_readconc <- function(texf, concf) {
    texidx <- 1
    ntexln <- length(readLines(texf))
    lstexln <- 1:ntexln
    lsrnwf <- lsrnwl <- rep(NA, ntexln)
    conc <- readLines(concf)
    idx <- 1
    maxidx <- length(conc) + 1
    while (idx < maxidx && texidx < ntexln && length(grep("Sconcordance", conc[idx])) > 0) {
        curline <- sub("\\\\Sconcordance\\{concordance:", "", conc[idx])
        texf <- sub("([^:]*):.*", "\\1", curline)
        rnwf <- sub("[^:]*:([^:]*):.*", "\\1", curline)
        idx <- idx + 1
        concnum <- ""
        while (idx < maxidx && length(grep("Sconcordance", conc[idx])) == 0) {
            concnum <- paste0(concnum, conc[idx])
            idx <- idx + 1
        }
        concnum <- gsub("%", "", concnum)
        concnum <- sub("\\}", "", concnum)
        concl <- strsplit(concnum, " ")
        concl <- as.numeric(concl[[1]])
        ii <- 1
        maxii <- length(concl) - 1
        rnwl <- concl[1]
        lsrnwl[texidx] <- rnwl
        lsrnwf[texidx] <- rnwf
        texidx <- texidx + 1
        while (ii < maxii && texidx < ntexln) {
            ii <- ii + 1
            lnrange <- 1:concl[ii]
            ii <- ii + 1
            for (iii in lnrange) {
                if (texidx >= ntexln)
                    break
                rnwl <- rnwl + concl[ii]
                lsrnwl[texidx] <- rnwl
                lsrnwf[texidx] <- rnwf
                texidx <- texidx + 1
            }
        }
    }
    return(data.frame(texlnum = lstexln, rnwfile = lsrnwf,
                      rnwline = lsrnwl, stringsAsFactors = FALSE))
}

#' Return the lines in the Rnoweb file corresponding to the generated LaTeX
#' file.
#' @param texf LaTeX file.
#' @param concf Concordance file.
#' @param l Lines in the LaTeX file.
GetRnwLines <- function(texf, concf, l) {
    conc <- SyncTeX_readconc(texf, concf)
    for (ii in seq_along(l)) {
        if (length(grep("line [0-9]", l[ii])) > 0) {
            texln <- as.numeric(sub(".*line ([0-9]*)", "\\1", l[ii]))
            idx <- 1
            while (idx < nrow(conc) && texln > conc$texlnum[idx]) {
                idx <- idx + 1
                if (conc$texlnum[idx] >= texln) {
                    l[ii] <- sub("(.*) line ([0-9]*)",
                                 paste0("\\1 line \\2 [",
                                        conc$rnwfile[idx], ": ",
                                        conc$rnwline[idx], "]"), l[ii])
                    break
                }
            }
        } else if (length(grep("^l\\.[0-9]", l[ii])) > 0) {
            texln <- as.numeric(sub("^l\\.([0-9]*) .*", "\\1", l[ii]))
            idx <- 1
            while (idx < nrow(conc) && texln > conc$texlnum[idx]) {
                idx <- idx + 1
                if (conc$texlnum[idx] >= texln) {
                    l[ii] <- sub("l\\.([0-9]*) (.*)",
                                 paste0("l.\\1 \\2 [",
                                        conc$rnwfile[idx], ": ",
                                        conc$rnwline[idx], "]"), l[ii])
                    break
                }
            }
        } else if (length(grep("lines [0-9]*--[0-9]*", l[ii])) > 0) {
            texln1 <- as.numeric(sub(".*lines ([0-9]*)--.*", "\\1", l[ii]))
            texln2 <- as.numeric(sub(".*lines [0-9]*--([0-9]*).*", "\\1", l[ii]))
            rnwIdx1 <- NA
            rnwIdx2 <- NA
            idx <- 1
            while (idx < nrow(conc) && texln1 > conc$texlnum[idx]) {
                idx <- idx + 1
                if (conc$texlnum[idx] >= texln1) {
                    rnwIdx1 <- idx
                    break
                }
            }
            idx <- 1
            while (idx < nrow(conc) && texln2 > conc$texlnum[idx]) {
                idx <- idx + 1
                if (conc$texlnum[idx] >= texln2) {
                    rnwIdx2 <- idx
                    break
                }
            }
            if (!is.na(rnwIdx1) && !is.na(rnwIdx2)) {
                l[ii] <- sub("(.*) lines ([0-9]*)--([0-9]*)",
                             paste0("\\1 lines \\2--\\3 [",
                                    conc$rnwfile[rnwIdx1], ": ",
                                    conc$rnwline[rnwIdx1], "--",
                                    conc$rnwline[rnwIdx2], "]"), l[ii])
            }
        }
    }
    l
}

#' Print lines of errors from LaTeX log files after calculating the
#' correspoding lines numbers in the original Rnoweb file.
#' @param texf LaTeX file.
#' @param logf LaTeX log file.
#' @param l Lines in the original Rnoweb file.
ShowTexErrors <- function(texf, logf, l) {
    llen <- length(l)
    lf <- character(llen)
    lev <- 1
    levfile <- "Unknown" # From what tex source are the errors coming from?
    fname <- NA
    idx <- 1
    while (idx < llen) {
        if (grepl("^(Over|Under)full \\\\(h|v)box ", l[idx])) {
            while (l[idx] != "" && idx < llen) {
                lf[idx] <- levfile[lev]
                idx <- idx + 1
            }
        } else {
            # Get the result of number of '(' minus number of ')'
            pb <- length(grep(28, charToRaw(l[idx]))) - length(grep(29, charToRaw(l[idx])))
            if (pb > 0) {
                lev <- lev + pb
                fname <- sub(".*\\(", "", l[idx])
                levfile[lev] <- fname
            } else if (pb < 0) {
                lev <- lev + pb
            }
            # Avoid function crash if there is a spurious closing parenthesis in the log
            if (lev == 0)
                lev <- 1
        }
        lf[idx] <- levfile[lev]
        idx <- idx + 1
    }

    idx <- rep(FALSE, length(l))
    idx[grepl("^(Over|Under)full \\\\(h|v)box ", l, useBytes = TRUE)] <- TRUE
    idx[grepl("^(Package|Class) \\w+ (Error|Warning):", l, useBytes = TRUE)] <- TRUE
    idx[grepl("^LaTeX (Error|Warning):", l, useBytes = TRUE)] <- TRUE
    idx[grepl("^No pages of output", l, useBytes = TRUE)] <- TRUE
    undef <- grep("Undefined control sequence", l, useBytes = TRUE)
    if (length(undef) > 0) {
        undef <- c(undef, undef + 1)
        undef <- sort(undef)
        undef <- undef[!duplicated(undef)]
        idx[undef] <- TRUE
    }
    if (sum(grepl("pdfTeX (error|warning)", l, useBytes = TRUE)) > 0) {
        has.pdfTeX.errors <- TRUE
    } else {
        has.pdfTeX.errors <- FALSE
    }

    if (sum(idx) > 0) {
        l <- l[idx]
        lf <- lf[idx]
        concf <- sub("\\.tex$", "-concordance.tex", texf)
        # We are interested only the errors located at our master LaTeX file
        ismaster <- grep(paste0("./", texf), lf)
        if (length(ismaster) > 0 && file.exists(concf)) {
            l[ismaster] <- GetRnwLines(texf, concf, l[ismaster])
        }
        msg <- paste0("\nSelected lines of: ", logf, "\n\n",
                      paste(lf, l, sep = ": ", collapse = "\n"), "\n")
        if (has.pdfTeX.errors)
            msg <- paste0(msg, 'There are pdfTeX errors or warnings. See "',
                          logf, '" for details.\n')
        cat(msg)
    }
}

#' Knitr or Sweave an Rnoweb document.
#' @param rnwf Rnoweb file.
#' @param rnwdir Directory where the Rnoweb file is.
#' @param latexcmd LaTeX command.
#' @param latexargs LaTeX command arguments.
#' @param synctex Whether to enable SyncTeX support.
#' @param bibtex Bib file.
#' @param knit Whether we should `knit` or `sweave` the document.
#' @param buildpdf Whether to also generate the PDF or only `knit` or `sweave`
# the document.
#' @param view Whether to open the generated PDF.
#' @param builddir Where the log file is expected to be found.
#' @param ... Further arguments passed to `Sweave()`.
nvim.interlace.rnoweb <- function(rnwf, rnwdir, latexcmd = "latexmk",
                                  latexargs, synctex = TRUE, bibtex = FALSE,
                                  knit = TRUE, buildpdf = TRUE, view = TRUE,
                                  builddir, ...) {
    oldwd <- getwd()
    on.exit(setwd(oldwd))
    setwd(rnwdir)

    texf <- sub("\\....$", ".tex", rnwf)
    tdiff <- NA
    if (buildpdf) {
        rnwl <- readLines(rnwf)
        chld <- rnwl[grep("^<<.*child *=.*", rnwl)]
        chld <- sub(".*child *= *[\"']", "", chld)
        chld <- sub("[\"'].*", "", chld)
        sfls <- c(rnwf, chld)

        for (f in sfls) {
            tdiff <- file.info(f)$mtime - file.info(texf)$mtime
            if (is.na(tdiff) || tdiff > 0)
                break
        }
    }

    # Compile the .tex file
    if (is.na(tdiff) || tdiff > 0 || !buildpdf) {
        if (knit) {
            if (!require(knitr, quietly = TRUE))
                stop("Please, install the 'knitr' package.")
            if (synctex)
                knitr::opts_knit$set(concordance = TRUE)
            texf <- knit(rnwf, envir = globalenv())
        } else {
            texf <- Sweave(rnwf, ...)
        }
    }

    if (!buildpdf)
        return(invisible(NULL))

    if (missing(latexargs))
        latexargs <- c("-pdf", '-pdflatex="xelatex %O -file-line-error -interaction=nonstopmode -synctex=1 %S"')

    # We cannot capture the output to see where the log was saved
    # because if pdflatex is running in stopmode the user will have
    # to see the output immediately
    stts <- system2(latexcmd, c(latexargs, gsub(" ", "\\\\ ", texf)))

    haserror <- FALSE
    if (bibtex && stts == 0) {
        haserror <- system(paste("bibtex", sub("\\.tex$", ".aux", texf)))
        if (!haserror) {
            haserror <- system(paste(latexcmd, texf))
            if (!haserror)
                haserror <- system(paste(latexcmd, texf))
        }
    }

    logf <- sub("\\....$", ".log", rnwf)
    if (!missing(builddir) && dir.exists(builddir))
        logf <- paste0(builddir, "/", logf)

    if (!file.exists(logf)) {
        if (latexcmd == "latexmk" && file.exists("~/.latexmkrc")) {
            lmk <- readLines("~/.latexmkrc")
            idx <- grep("\\$out_dir\\s*=", lmk)
            if (length(idx) == 1) {
                logf <- paste0(sub(".*\\$out_dir\\s*=\\s*['\"](.*)['\"].*",
                                   "\\1", lmk[idx]), "/",
                               sub("\\....$", ".log", rnwf))
            }
        } else {
            idx <- grep("-output-directory=", latexargs)
            if (length(idx) == 1) {
                logf <- paste0(sub("-output-directory=", "", latexargs[idx]),
                               "/", sub("\\....$", ".log", rnwf))
            } else {
                idx <- grep("-output-directory$", latexargs)
                if (length(idx) == 1 && idx < length(latexargs)) {
                    logf <- paste0(latexargs[idx+1], "/", sub("\\....$", ".log", rnwf))
                }
            }
        }
    }

    if (!file.exists(logf)) {
        warning('File "', logf, '" not found.')
        return(invisible(NULL))
    }

    sout <- readLines(logf)

    pdff <- ""
    if (view) {
        idx <- grep("Latexmk: All targets .* are up-to-date", sout)
        if (length(idx)) {
            pdff <- sub("Latexmk: All targets \\((.*)\\) are up-to-date", "\\1", sout[idx])
        } else {
            idx <- grep('Output written on "*.*\\.pdf.*', sout)
            if (length(idx)) {
                pdff <- sub('Output written on "*(.*\\.pdf).*', "\\1", sout[idx])
            } else if (!haserror) {
                pdff <- sub("\\.tex$", ".pdf", texf)
            }
        }
        if (pdff != "") {
            if (!grepl("^/", pdff))
                pdff <- paste0(getwd(), "/", pdff)
            .C(nvimcom_msg_to_nvim,
               paste0("lua require('r.doc').open('", pdff, "', '')"))
        }
    }

    if (getOption("nvimcom.texerrs")) {
        cat("\nExit status of '", latexcmd, "': ", stts, "\n", sep = "")
        ShowTexErrors(texf, logf, sout)
    }
    return(invisible(NULL))
}

#' Knitr an Rmarkdown file.
#' @param Rmdfile Rmarkdown file.
#' @param outform Format of output.
#' @param rmddir Directory where the Rmd file is.
#' @param ... Further arguments passed to `rmarkdown::render()`.
nvim.interlace.rmd <- function(Rmdfile, outform = NULL, rmddir, ...) {
    if (!require(rmarkdown, quietly = TRUE))
        stop("Please, install the 'rmarkdown' package.")

    oldwd <- getwd()
    on.exit(setwd(oldwd))
    setwd(rmddir)

    if (grepl("\\.qmd$", Rmdfile, ignore.case = TRUE)) {
        if (!require(quarto, quietly = TRUE))
            stop("Please, install the 'quarto' package.")
        if (is.null(outform)) {
            cfg <- quarto::quarto_inspect(Rmdfile)
            fmt <- names(cfg$formats)[1]
        } else {
            if (outform == "beamer") {
                fmt <- "pdf"
            } else {
                fmt <- outform
            }
        }
        res <- normalizePath(sub("qmd$", fmt, Rmdfile), mustWork = FALSE)
        mtime1 <- file.info(res)$mtime
        quarto::quarto_render(Rmdfile, outform)
        mtime2 <- file.info(res)$mtime
        if (is.na(mtime2) || (!is.na(mtime1) && mtime2 <= mtime1))
            res <- ""
    } else {
        if (exists("params", envir = .GlobalEnv)) {
            old_params <- get("params", envir = .GlobalEnv)
            rm(params, envir = .GlobalEnv)
        }
        res <- rmarkdown::render(Rmdfile, outform, ...)
        if (exists("old_params", inherits = FALSE)) {
            assign("params", old_params, envir = .GlobalEnv)
        }
    }
    brwsr <- ""
    if (endsWith(res, ".html")) {
        brwsr <- getOption("browser")
        if (is.function(brwsr)) {
            brwsr <- "RbrowseURLfun"
        } else {
            if (!is.character(brwsr))
                brwsr <- ""
        }
    }
    .C(nvimcom_msg_to_nvim,
       paste0("lua require('r.doc').open('", res, "', '", brwsr, "')"))
    return(invisible(NULL))
}
