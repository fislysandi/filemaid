(defpackage :filemaid.tests
  (:use :cl)
  (:import-from :filemaid
                #:make-file-object
                #:file-extension-p
                #:run-rule-on-file
                #:run-rules
                #:run-rules-with-report
                #:apply-action
                #:make-action-spec
                #:rule
                #:from
                #:priority
                #:extension
                #:move
                #:set-conflict-policy
                #:set-python-pdf-provider
                #:set-python-integration-enabled
                #:python-pdf-contains-p
                #:run-cli))

(in-package :filemaid.tests)

(defvar *test-failures* 0)

(defun assert-true (condition message)
  "Record failure MESSAGE when CONDITION is false."
  (unless condition
    (incf *test-failures*)
    (format t "FAIL: ~A~%" message))
  condition)

(defun run-tests ()
  "Execute all Filemaid test groups and signal on failure."
  (setf *test-failures* 0)
  (set-conflict-policy :error-on-conflict)
  (test-dsl-behavior)
  (test-cli-parsing-helpers)
  (test-conflict-profile-persistence)
  (test-default-rules-resolution)
  (test-project-first-rules-resolution)
  (test-rules-spec-resolution)
  (test-addon-resolution)
  (test-cli-integration)
  (test-python-bridge-gating)
  (cond
    ((zerop *test-failures*)
     (format t "All Filemaid tests passed.~%")
     t)
    (t
     (error "Filemaid tests failed: ~D" *test-failures*))))
