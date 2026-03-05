(in-package :filemaid)

(register-rule
 (rule invoices
   (from "~/Downloads")
   (when (and (extension "pdf")
              (pdf-contains "invoice")))
   (move "~/Documents/Invoices")))
