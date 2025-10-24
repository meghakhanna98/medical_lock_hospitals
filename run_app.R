#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(shiny)
})

# Basic environment checks
if (!file.exists("app.R")) {
  stop("Could not find app.R in the current directory. Run from the project root.")
}
if (!file.exists("medical_lock_hospitals.db")) {
  stop("Database file 'medical_lock_hospitals.db' not found in project root.")
}

# Prefer an open port automatically
candidate_ports <- c(8891, 8889, 8888, 3838, 8080, 4242)

is_port_free <- function(port) {
  # Try to bind a server quickly using httpuv; if it errors, it's in use
  ok <- TRUE
  tryCatch({
    srv <- httpuv::startServer("127.0.0.1", port, list())
    httpuv::stopServer(srv)
  }, error = function(e) { ok <<- FALSE }, warning = function(w) { ok <<- FALSE })
  ok
}

port <- NA_integer_
for (p in candidate_ports) {
  if (is_port_free(p)) { port <- p; break }
}
if (is.na(port)) {
  # last resort: pick a random high port
  set.seed(as.integer(Sys.time()))
  for (attempt in 1:50) {
    p <- sample(20000:65000, 1)
    if (is_port_free(p)) { port <- p; break }
  }
}
if (is.na(port)) stop("No free port found. Close other processes and try again.")

host <- "127.0.0.1"  # bind to loopback for local browsing only
message(sprintf("Starting Shiny on http://127.0.0.1:%d ...", port))
options(shiny.sanitize.errors = FALSE, shiny.autoload.r = FALSE)

# Launch and open browser (best-effort)
url <- sprintf("http://127.0.0.1:%d", port)
try(utils::browseURL(url), silent = TRUE)

# Run the app; this call blocks and prints "Listening on ..." when ready
shiny::runApp(".", host = host, port = port, launch.browser = FALSE)
