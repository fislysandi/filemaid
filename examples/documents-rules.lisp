(in-package :filemaid)

(register-rule
 (rule organize-pdfs
   (priority 5)
   (from "~/Downloads")
   (when (extension "pdf"))
   (move "~/Documents/PDFs")))

(register-rule
 (rule organize-markdown
   (priority 3)
   (from "~/Downloads")
   (when (extension "md"))
   (move "~/Documents/Notes")))

(register-rule
 (rule organize-text
   (priority 2)
   (from "~/Downloads")
   (when (extension "txt"))
   (move "~/Documents/Text")))
