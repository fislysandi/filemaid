(in-package :filemaid.tests)

(defun test-extension-filter ()
  "Test extension predicate behavior."
  (let ((file (make-file-object :path "/tmp/invoice.pdf"
                                :name "invoice"
                                :extension "pdf"
                                :size 10
                                :created nil
                                :modified nil
                                :metadata nil)))
    (assert-true (file-extension-p file "pdf") "pdf extension should match")
    (assert-true (not (file-extension-p file "txt")) "txt extension should not match")))

(defun test-rule-dsl ()
  "Test basic rule compilation and dry-run execution."
  (let* ((file (make-file-object :path "/tmp/invoice.pdf"
                                 :name "invoice"
                                 :extension "pdf"
                                 :size 10
                                 :created nil
                                 :modified nil
                                 :metadata nil))
         (compiled-rule
           (rule invoices
             (from "/tmp")
             (when (extension "pdf"))
             (move "/tmp/out")))
         (results (run-rule-on-file compiled-rule file :dry-run t)))
    (assert-true (= 1 (length results)) "rule should emit one action")
    (assert-true (eql :move (getf (first results) :action)) "action should be :move")
    (assert-true (eql t (getf (first results) :dry-run)) "dry-run flag should be true")))

(defun test-conflict-resolution ()
  "Test all conflict policies and reporting behavior."
  (let* ((file (make-file-object :path "/tmp/invoice.pdf"
                                 :name "invoice"
                                 :extension "pdf"
                                 :size 10
                                 :created nil
                                 :modified nil
                                 :metadata nil))
         (rule-a (rule rule-a
                   (priority 1)
                   (from "/tmp")
                   (when (extension "pdf"))
                   (move "/tmp/out-a")))
         (rule-b (rule rule-b
                   (priority 5)
                   (from "/tmp")
                   (when (extension "pdf"))
                   (move "/tmp/out-b"))))
    (let ((results (run-rules (list rule-a rule-b)
                              (list file)
                              :dry-run t
                              :conflict-policy :first-wins)))
      (assert-true (= 1 (length results)) "first-wins should keep one action")
      (assert-true (search "/tmp/out-a" (getf (first results) :target))
                   "first-wins should keep first target"))
    (multiple-value-bind (results report)
        (run-rules-with-report (list rule-a rule-b)
                               (list file)
                               :dry-run t
                               :conflict-policy :first-wins)
      (assert-true (= 1 (length results)) "report run should keep one action")
      (assert-true (= 1 (length report)) "first-wins should produce one drop report entry"))
    (let ((results (run-rules (list rule-a rule-b)
                              (list file)
                              :dry-run t
                              :conflict-policy :last-wins)))
      (assert-true (= 1 (length results)) "last-wins should keep one action")
      (assert-true (search "/tmp/out-b" (getf (first results) :target))
                   "last-wins should keep last target"))
    (let ((results (run-rules (list rule-a rule-b)
                              (list file)
                              :dry-run t
                              :conflict-policy :priority)))
      (assert-true (= 1 (length results)) "priority should keep one action")
      (assert-true (search "/tmp/out-b" (getf (first results) :target))
                   "priority should keep higher-priority rule"))
    (assert-true (handler-case
                     (progn
                       (run-rules (list rule-a rule-b)
                                  (list file)
                                  :dry-run t
                                  :conflict-policy :error-on-conflict)
                       nil)
                   (error () t))
                  "error-on-conflict should signal an error")))

(defun test-file-conflict-policies ()
  "Test destination file conflict handling policies for actions."
  (let* ((suffix (write-to-string (get-universal-time)))
         (source-dir (format nil "/tmp/filemaid-source-~A/" suffix))
         (target-dir (format nil "/tmp/filemaid-target-~A/" suffix))
         (source-file (format nil "~Asample.txt" source-dir))
         (target-file (format nil "~Asample.txt" target-dir))
         (file (make-file-object :path source-file
                                 :name "sample"
                                 :extension "txt"
                                 :size 4
                                 :created nil
                                 :modified nil
                                 :metadata nil))
         (copy-action (make-action-spec :type :copy :argument target-dir)))
    (ensure-directories-exist source-dir)
    (ensure-directories-exist target-dir)
    (with-open-file (stream source-file :direction :output :if-exists :supersede :if-does-not-exist :create)
      (format stream "src"))
    (with-open-file (stream target-file :direction :output :if-exists :supersede :if-does-not-exist :create)
      (format stream "dst"))
    (assert-true (handler-case
                     (progn
                       (apply-action copy-action file :dry-run nil :file-conflict-policy :error)
                       nil)
                   (error () t))
                 "file conflict policy :error should signal")
    (let ((result (apply-action copy-action file :dry-run nil :file-conflict-policy :skip)))
      (assert-true (eql :skipped (getf result :status))
                   "file conflict policy :skip should skip action"))
    (let ((result (apply-action copy-action file :dry-run nil :file-conflict-policy :rename)))
      (assert-true (search "sample-1.txt" (or (getf result :target) ""))
                   "file conflict policy :rename should create suffixed target"))
    (uiop:delete-directory-tree (uiop:ensure-directory-pathname source-dir)
                                :validate t
                                :if-does-not-exist :ignore)
    (uiop:delete-directory-tree (uiop:ensure-directory-pathname target-dir)
                                :validate t
                                :if-does-not-exist :ignore)))

(defun test-dsl-behavior ()
  "Run all DSL-related tests."
  (test-extension-filter)
  (test-rule-dsl)
  (test-conflict-resolution)
  (test-file-conflict-policies))
