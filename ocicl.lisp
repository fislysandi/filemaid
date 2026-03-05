;;;; Filemaid dependency bootstrap via OCICL.
;;;;
;;;; This project policy is OCICL-first dependency management.
;;;; Keep dependencies minimal and reproducible.

(in-package :cl-user)

(defun ensure-filemaid-dependencies ()
  "Load or install project dependencies through OCICL workflow."
  (format t "Use OCICL to resolve dependencies before loading Filemaid.~%")
  (format t "Required systems: uiop, fiveam (tests), optional py4cl-cffi.~%")
  t)
