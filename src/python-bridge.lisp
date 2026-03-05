(in-package :filemaid)

(defvar *python-pdf-provider* nil
  "Optional function of (path needle) -> generalized boolean.")

(defvar *python-integration-enabled*
  (member (uiop:getenv "FILEMAID_ENABLE_PYTHON")
          '("1" "true" "TRUE" "yes" "YES")
          :test #'string=)
  "When true, python bridge calls are enabled.")

(defun set-python-integration-enabled (enabled)
  "Enable or disable optional Python integration globally."
  (setf *python-integration-enabled* (and enabled t)))

(defun python-integration-enabled-p ()
  "Return true when optional Python integration is enabled."
  *python-integration-enabled*)

(defun set-python-pdf-provider (function-or-nil)
  "Set optional Python-backed PDF text detector function."
  (setf *python-pdf-provider* function-or-nil))

(defun python-pdf-contains-p (path needle)
  "Call optional Python bridge. Returns NIL when no provider is configured."
  (if (and *python-integration-enabled* *python-pdf-provider*)
      (funcall *python-pdf-provider* path needle)
      nil))
