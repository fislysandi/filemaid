(asdf:defsystem "filemaid"
  :description "Programmable filesystem automation engine in Common Lisp"
  :author "Filemaid Contributors"
  :license "MIT"
  :version "0.1.0"
  :depends-on ("uiop")
  :serial t
  :components ((:file "src/package")
               (:file "src/config")
               (:file "src/python-bridge")
               (:file "src/scanner")
               (:file "src/filters")
               (:file "src/actions")
               (:file "src/rules")
               (:file "src/pipeline")
               (:file "src/cli"))
  :in-order-to ((test-op (test-op "filemaid/tests"))))

(asdf:defsystem "filemaid/tests"
  :depends-on ("filemaid")
  :serial t
  :components ((:file "tests/core-tests")
               (:file "tests/dsl-tests")
               (:file "tests/cli-tests")
               (:file "tests/integration-tests"))
  :perform (test-op (o c)
             (symbol-call :filemaid.tests :run-tests)))
