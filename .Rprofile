# Existing renv activation
source("renv/activate.R")

# Auto-commit function
auto_commit <- function() {
  message("Checking for changes to commit...")
  system('git add . && git commit -m "Auto-update from RStudio" && git push origin main', intern = TRUE)
  message("Changes committed and pushed to GitHub")
}

# Set up a user-callable function
.Last.sys <- function() {
  message("Auto-committing changes before exit...")
  auto_commit()
}

# Optional: Uncomment one of these hooks if you want automatic commits after specific actions
# setHook("plot.new", function() { auto_commit() })
# setHook("source", function(x) { auto_commit() })
