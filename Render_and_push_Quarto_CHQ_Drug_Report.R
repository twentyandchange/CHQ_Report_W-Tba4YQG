# --- VERY TOP OF SCRIPT ---
# Use a full path in a location you are SURE the task user can write to.
# Start with Desktop or Documents of the task user, or a simple C:\temp folder if permissions allow.
log_file_path <- "C:/Users/stevek/Downloads/r_task_debug.log" 
# OR maybe: log_file_path <- "C:/temp/r_task_debug.log" # Ensure C:\temp exists and task user can write
# Avoid writing logs directly into the repo initially, to rule out repo permission issues.

log_message <- function(msg) {
  timestamp_msg <- paste(Sys.time(), "-", msg)
  print(timestamp_msg) # Keep for manual runs
  try(cat(timestamp_msg, "\n", file = log_file_path, append = TRUE), silent = TRUE) # Write to log file, suppress errors writing the log itself
}

# --- Add this section after logging setup ---
# Manually specify the directory containing quarto.exe
quarto_bin_dir <- "C:/Program Files/RStudio/resources/app/bin/quarto/bin/" 

if (dir.exists(quarto_bin_dir)) {
  log_message(paste("Quarto directory found at:", quarto_bin_dir))
  # Set the QUARTO_PATH environment variable (used by the quarto R package)
  Sys.setenv(QUARTO_PATH = quarto_bin_dir)
  log_message(paste("Set QUARTO_PATH environment variable to:", Sys.getenv("QUARTO_PATH")))
  
  # Optional: Add to R's session PATH too, might help Sys.which
current_path <- Sys.getenv("PATH")
Sys.setenv(PATH = paste(quarto_bin_dir, current_path, sep = ";"))
log_message("Temporarily added Quarto dir to session PATH.")
  
} else {
  log_message(paste("!!! Manually specified Quarto directory not found:", quarto_bin_dir))
  # Decide if you want to stop if the path is wrong
stop("Configured Quarto directory not found.") 
}

# --- Start of Actual Script ---
log_message("--- R SCRIPT STARTED ---")
log_message(paste("Running as user:", Sys.info()[["user"]])) # See who R thinks is running
log_message(paste("Initial working directory:", getwd()))
log_message(paste(".libPaths():", paste(.libPaths(), collapse="; "))) # Check library paths

# --- Configuration ---
repo_dir <- "E:/EMS_calls/News_searches/GitHub/CHQ_Report_GitHub_Actions/twentyandchange.github.io/CHQ_Report_W-Tba4YQG" # Double-check this path is correct!
qmd_file <- "index.qmd" 
output_files <- "_site/index.html" 
commit_message <- paste("Automated render and update:", Sys.time())
remote_name <- "origin" 
branch_name <- "main"   

log_message(paste("Repository directory configured:", repo_dir))
log_message(paste("Quarto file configured:", qmd_file))

# --- Script Logic ---
# Make sure gert is loaded *after* setting up logging
log_message("Loading gert package...")
library(gert) 
log_message("gert package loaded.")

tryCatch({
  # 1. Set Working Directory 
  log_message(paste("Attempting to setwd to:", repo_dir))
  setwd(repo_dir)
  log_message(paste("Working directory AFTER setwd:", getwd())) # Verify!
  
  # Check write permissions in target dir
  test_write_path <- file.path(repo_dir, "permission_test_delete_me.txt")
  log_message(paste("Attempting test write to:", test_write_path))
  try(writeLines("test", test_write_path), silent=TRUE)
  if(file.exists(test_write_path)) {
    log_message("Test write SUCCESSFUL.")
    try(file.remove(test_write_path), silent=TRUE)
  } else {
    log_message("!!! TEST WRITE FAILED !!! Check directory permissions.")
  }
  
  # Add checks again right before the call
  log_message(paste("Checking Quarto path via Sys.getenv('QUARTO_PATH'):", Sys.getenv("QUARTO_PATH")))
  # Sys.which might work now if you modified the session PATH, or might still fail if relying only on QUARTO_PATH
  log_message(paste("Checking Quarto path via Sys.which('quarto'):", Sys.which('quarto'))) 
  log_message("Attempting quarto::quarto_render for index.qmd ...")
  
  # 2. Render the Quarto Document
  log_message(paste("Attempting quarto::quarto_render for", qmd_file, "..."))
  # Explicitly check if quarto executable is found
  quarto_path <- Sys.which("quarto")
  log_message(paste("Found quarto executable at:", ifelse(quarto_path=="", "NOT FOUND", quarto_path)))
  if (nchar(quarto_path) == 0) { log_message("!!! Quarto not found in PATH. Check environment variables for task user.")}
  
  quarto_exe_full_path <- Sys.which("quarto")
  # Ensure paths and arguments are quoted correctly for the shell command line
  # Use shQuote for robustness, especially if paths might contain spaces
  render_cmd <- paste(shQuote(quarto_exe_full_path), "render", shQuote(qmd_file)) 
  log_message(paste("Attempting Quarto render via shell() with command:", render_cmd))
  
  # Execute using shell() - stdout/stderr might go directly to the Task Scheduler output/log 
  # or the R script's main log file depending on redirection setup. 
  # We might lose the detailed Quarto output capture here compared to system2,
  # but the primary goal is to see if we get a clean exit status.
  exit_status <- shell(render_cmd) 
  log_message(paste("Quarto CLI exit status via shell():", exit_status))
  
  # shell() returns 0 for success on Windows
  if (exit_status != 0) {
    stop(paste("Quarto CLI failed via shell() with exit status:", exit_status))
  } else {
    log_message("Quarto render via shell() appears successful (exit status 0).")
    # Check if the output file exists (using the corrected path)
    # Ensure this variable is defined correctly in the config section above!
    # corrected_output_path <- "_site/index.html" 
    output_exists <- file.exists(output_files) # Use the output_files variable directly
    log_message(paste("Checking if expected output exists at", shQuote(output_files), ":", output_exists)) 
    if (!output_exists) {
      log_message(paste("!!! WARNING: Quarto exited successfully but expected output file", shQuote(output_files), "not found!"))
      # Optionally treat this as an error:
      # stop("Quarto exited successfully but expected output file not found!") 
    }
  }
  log_message("quarto::quarto_render call completed.")
  log_message(paste("Checking if expected output exists:", file.exists(output_files[1]))) # Check output
  
  # 3. Git Operations using gert
  log_message("Starting Git operations...")
  log_message("Checking Git status...")
  status <- git_status(repo = repo_dir)
  log_message(paste("git_status completed. Found changes:", nrow(status)))
  
  files_to_add <- intersect(output_files, status$file) 
  log_message(paste("Files matching expected output found in status:", paste(files_to_add, collapse=", ")))
  
  if (length(files_to_add) > 0) {
    log_message(paste("Attempting git_add for:", paste(files_to_add, collapse=", ")))
    git_add(files = files_to_add, repo = repo_dir)
    log_message("git_add completed.")
    
    log_message("Attempting git_commit...")
    git_commit(message = commit_message, repo = repo_dir)
    log_message("git_commit completed.")
    
    log_message(paste("Attempting git_push to", remote_name, "/", branch_name, "..."))
    git_push(remote = remote_name, set_upstream = FALSE, repo = repo_dir, verbose = TRUE) # Verbose push is key!
    log_message("git_push call completed.") # May not mean success, check verbose output above if possible
    
  } else {
    log_message("No changes detected in expected output files to commit.")
  }
  
  log_message("--- R SCRIPT FINISHED SUCCESSFULLY ---")
  
}, error = function(e) {
  # Log the specific error message
  error_message <- paste("!!! SCRIPT FAILED:", e$message)
  log_message(error_message)
  # Optionally log more details like the call stack if helpful
  # log_message(paste("Error details:", deparse(e))) 
})
