# --- Configuration ---
# Set the full path to the directory containing the .qmd file and Git repo
repo_dir <- "E:/EMS_calls/News_searches/GitHub/CHQ_Report_GitHub_Actions/twentyandchange.github.io/CHQ_Report_W-Tba4YQG"

# Set the name of the Quarto file (relative to repo_dir)
qmd_file <- "index.qmd"

# Define the specific SOURCE and DATA files to check for changes and commit
# Add or remove file paths relative to repo_dir as needed for your project
# DO NOT include _site/ or _freeze/ or log files here.
files_to_potentially_commit <- c(
  "index.qmd",
  "_quarto.yml",
  ".gitignore",
  # ".Rprofile", # Uncomment if you want to track changes to .Rprofile
  "renv.lock", # Important for reproducibility
  "Combined_results.xlsx", # Your data output
  "output_points.dbf",     # Your data output
  "output_points.shp",     # Your data output
  "output_points.shx"      # Your data output
  # Add paths to other source R scripts, data files, etc. if necessary
)

# Git configuration (adjust as needed)
commit_message <- paste("Automated source update via Task Scheduler:", Sys.time()) # Updated commit message
remote_name <- "origin"
branch_name <- "main"   # Or "master", or your default branch

# --- Logging Setup ---
log_file_path <- file.path(repo_dir, "r_task_debug.log") # Log inside the repo dir

log_message <- function(msg) {
  timestamp_msg <- paste(Sys.time(), "-", msg)
  print(timestamp_msg) # Keep for manual runs
  try(cat(timestamp_msg, "\n", file = log_file_path, append = TRUE), silent = TRUE) # Write to log file
}

# --- Quarto Path Setup ---
# Manually specify the directory containing quarto.exe
quarto_bin_dir <- "C:/Program Files/RStudio/resources/app/bin/quarto/bin/" # Verify this path exists!

if (dir.exists(quarto_bin_dir)) {
  log_message(paste("Quarto directory found at:", quarto_bin_dir))
  Sys.setenv(QUARTO_PATH = quarto_bin_dir)
  log_message(paste("Set QUARTO_PATH environment variable to:", Sys.getenv("QUARTO_PATH")))
} else {
  log_message(paste("!!! Manually specified Quarto directory not found:", quarto_bin_dir))
  stop("Configured Quarto directory not found.")
}

# --- R SCRIPT STARTED ---
log_message("--- R SCRIPT STARTED ---")
log_message(paste("Running as user:", Sys.info()[["user"]]))
log_message(paste("Initial working directory:", getwd()))
log_message(paste(".libPaths():", paste(.libPaths(), collapse="; ")))

log_message(paste("Repository directory configured:", repo_dir))
log_message(paste("Quarto file configured:", qmd_file))
log_message(paste("Source/data files to check:", paste(shQuote(files_to_potentially_commit), collapse=", ")))

# --- Script Logic ---
log_message("Loading gert package...")
library(gert)
log_message("gert package loaded.")

tryCatch({
  # 1. Set Working Directory
  log_message(paste("Attempting to setwd to:", repo_dir))
  setwd(repo_dir)
  log_message(paste("Working directory AFTER setwd:", getwd()))
  
  # Check write permissions (optional but helpful)
  test_write_path <- file.path(repo_dir, "permission_test_delete_me.txt")
  log_message(paste("Attempting test write to:", test_write_path))
  try(writeLines("test", test_write_path), silent=TRUE)
  if(file.exists(test_write_path)) {
    log_message("Test write SUCCESSFUL.")
    try(file.remove(test_write_path), silent=TRUE)
  } else {
    log_message("!!! TEST WRITE FAILED !!! Check directory permissions.")
  }
  
  # 2. Render the Quarto Document using system2 (to capture output/errors)
  
  # --- Start of system2 block ---
  quarto_exe_full_path <- Sys.which("quarto")
  log_message(paste("Checking Quarto path via Sys.which('quarto') before render:", ifelse(nchar(quarto_exe_full_path)>0, quarto_exe_full_path, "NOT FOUND")))
  if (nchar(quarto_exe_full_path) == 0) { stop("Quarto executable not found via Sys.which(). Check QUARTO_PATH setup.") }
  
  log_message(paste("Attempting Quarto render via system2 using:", quarto_exe_full_path))
  render_args <- c("render", qmd_file)
  
  quarto_result <- system2(
    command = quarto_exe_full_path,
    args = render_args,
    stdout = TRUE,
    stderr = TRUE
  )
  
  exit_status <- attr(quarto_result, "status")
  log_message(paste("Quarto CLI exit status:", ifelse(is.null(exit_status), "NULL (execution failed?)", exit_status)))
  
  if(length(quarto_result) > 0 && any(nzchar(quarto_result))) {
    log_message("Quarto CLI stdout/stderr:")
    for(line in quarto_result) { log_message(paste("  [Output]", line)) }
  } else {
    log_message("Quarto CLI stdout/stderr: (empty)")
  }
  
  # Check for render failure (non-zero or NULL exit status)
  if (!is.null(exit_status) && exit_status != 0) {
    stop(paste("Quarto CLI failed with exit status:", exit_status, "- see stdout/stderr logs above."))
  } else if (is.null(exit_status)) {
    stop("Failed to get exit status from Quarto CLI execution (system2 failure or abnormal Quarto exit?).")
  } else {
    # Exit status is 0
    log_message("Quarto render via system2 appears successful (exit status 0).")
    # Optional: Check if _site/index.html exists just to confirm render produced output
    # output_path_check <- "_site/index.html"
    # if (!file.exists(output_path_check)) {
    #    log_message(paste("!!! WARNING: Quarto exited successfully but expected output file", shQuote(output_path_check), "not found!"))
    # }
  }
  # --- End of system2 block ---
  
  # 3. Git Operations using gert (Add specific source/data files)
  log_message("Starting Git operations...")
  log_message("Checking Git status...")
  status <- git_status(repo = repo_dir)
  
  # Find which of the specified source/data files actually changed
  normalized_target_files <- gsub("\\\\", "/", files_to_potentially_commit)
  changed_files_to_commit <- intersect(normalized_target_files, status$file[status$status != "ignored"])
  
  if (length(changed_files_to_commit) > 0) {
    log_message(paste("Found changes in tracked source/data files:", paste(changed_files_to_commit, collapse=", ")))
    
    log_message(paste("Attempting git_add for:", paste(changed_files_to_commit, collapse=", ")))
    git_add(files = changed_files_to_commit, repo = repo_dir)
    log_message("git_add completed.")
    
    log_message("Attempting git_commit...")
    # Check staging area difference before committing
    diff_staged <- git_diff_staged(repo = repo_dir)
    if(nrow(diff_staged) > 0) {
      git_commit(message = commit_message, repo = repo_dir)
      log_message("git_commit completed.")
      
      log_message(paste("Attempting git_push to", remote_name, "/", branch_name, "..."))
      git_push(remote = remote_name, set_upstream = FALSE, repo = repo_dir, verbose = TRUE)
      log_message("git_push call completed.")
      
    } else {
      log_message("No changes staged to commit after git_add.")
    }
    
  } else {
    log_message("No changes detected in tracked source/data files to commit.")
  }
  # --- End of Git Operations Block ---
  
  log_message("--- R SCRIPT FINISHED SUCCESSFULLY ---")
  
}, error = function(e) {
  # Log the specific error message
  error_message <- paste("!!! SCRIPT FAILED:", e$message)
  log_message(error_message)
  stop(e) # Re-throw the error
})