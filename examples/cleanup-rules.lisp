(in-package :filemaid)

(register-rule
 (rule remove-temp-files
   (priority 10)
   (from "~/Downloads")
   (when (or (extension "tmp")
             (extension "crdownload")
             (extension "part")))
   (delete)))

(register-rule
 (rule move-log-files
   (priority 6)
   (from "~/Downloads")
   (when (extension "log"))
   (move "~/Documents/Logs")))

(register-rule
 (rule move-csv-reports
   (priority 5)
   (from "~/Downloads")
   (when (extension "csv"))
   (move "~/Documents/Reports")))
