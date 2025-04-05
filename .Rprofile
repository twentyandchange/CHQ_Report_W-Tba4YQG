# --- Place this in your .Rprofile ---

library(gert)

# Auto-commit function using gert
auto_commit_gert <- function(commit_message = "Auto-update from RStudio [gert]",
                             remote_name = "origin",
                             branch_name = "main",
                             repo_path = ".") { # repo_path defaults to current dir
  
  # Check if gert is loaded/available, load if possible
  if (!requireNamespace("gert", quietly = TRUE)) {
    message("Error: 'gert' package is required but not installed/available.")
    return(invisible(FALSE))
  }
  # Optionally explicitly load library if needed, though :: calls work
  # library(gert)
  
  message("Checking for changes to commit using gert...")
  
  tryCatch({
    # 1. Check status - see if there's anything to add/commit
    status <- gert::git_status(repo = repo_path)
    if (nrow(status) == 0) {
      message("No changes detected. Nothing to commit.")
      return(invisible(FALSE)) # Indicate nothing was done
    } else {
      message("Changes detected: \n", paste(status$file, collapse = "\n"))
    }
    
    # 2. Add all changes (tracked and untracked) in the current directory
    message("Adding changes...")
    gert::git_add(".", repo = repo_path) # "." adds all changes in the dir
    
    # 3. Commit
    message("Committing changes...")
    commit_sha <- gert::git_commit(message = commit_message, repo = repo_path)
    message("Committed: ", substr(commit_sha, 1, 7))
    
    # 4. Push
    message("Pushing changes to ", remote_name, "/", branch_name, "...")
    # verbose=TRUE gives more push feedback, similar to command line
    gert::git_push(remote = remote_name, set_upstream = FALSE, repo = repo_path, verbose = TRUE)
    
    message("Changes successfully committed and pushed via gert.")
    return(invisible(TRUE)) # Indicate success
    
  }, error = function(e) {
    # If any step fails, this block runs
    message("\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
    message("Error during Git operation (gert): ", conditionMessage(e))
    # You might want more detailed diagnostics here if needed
    # For example, print status again:
    # try(print(gert::git_status(repo = repo_path)))
    message("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n")
    return(invisible(FALSE)) # Indicate failure
  })
}

# --- Update your .Rprofile assignments ---

# Existing renv activation (keep if you use renv)
source("renv/activate.R")

# Assign the gert function to the name you want to call
auto_commit <- auto_commit_gert

# Setup the exit hook (use with caution)
.Last.sys <- function() {
  # Check if the gert package is available before trying to use it
  # Ensures .Last.sys doesn't fail if gert isn't installed somehow
  if (requireNamespace("gert", quietly = TRUE)) {
    message("\nAuto-committing changes before exit using gert...")
    auto_commit() # This now calls the gert version
  } else {
    message("\n'gert' package not available. Skipping auto-commit on exit.")
  }
}

# Optional hooks (use cautiously)
# setHook("plot.new", function() { auto_commit() })
# setHook("source", function(x) { auto_commit() })

# --- End of .Rprofile content ---
