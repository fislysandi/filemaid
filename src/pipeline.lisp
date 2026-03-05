(in-package :filemaid)

(defun action-target-path (action file-object)
  "Return destination pathname for ACTION on FILE-OBJECT, or NIL."
  (case (action-spec-type action)
    ((:move :copy)
     (ensure-target-path (action-spec-argument action) file-object))
    (:rename
     (let ((source (pathname (file-object-path file-object))))
       (make-pathname :name (action-spec-argument action)
                      :type (pathname-type source)
                      :defaults source)))
    (otherwise nil)))

(defun make-intent (rule file-object action index)
  "Build a planned execution intent record."
  (list :rule rule
        :rule-name (rule-definition-name rule)
        :rule-priority (rule-definition-priority rule)
        :file file-object
        :action action
        :source (file-object-path file-object)
        :target (let ((target (action-target-path action file-object)))
                  (and target (namestring target)))
        :index index))

(defun intent-equivalent-p (a b)
  "Return true when intents A and B represent the same operation."
  (and (string= (getf a :source) (getf b :source))
       (eql (action-spec-type (getf a :action))
            (action-spec-type (getf b :action)))
       (equal (getf a :target) (getf b :target))))

(defun conflicting-intent-p (a b)
  "Return true when intents A and B cannot both be applied safely."
  (let ((a-type (action-spec-type (getf a :action)))
        (b-type (action-spec-type (getf b :action)))
        (a-source (getf a :source))
        (b-source (getf b :source))
        (a-target (getf a :target))
        (b-target (getf b :target)))
    (or
     (and (string= a-source b-source)
          (not (and (eql a-type :tag) (eql b-type :tag))))
      (and a-target b-target
           (string= a-target b-target)
           (not (string= a-source b-source))))))

(defun conflict-message (intent existing)
  "Format user-facing conflict message for INTENT and EXISTING."
  (format nil
          "Conflict between ~A (~A -> ~A) and ~A (~A -> ~A)."
          (getf intent :rule-name)
          (getf intent :source)
          (or (getf intent :target) "n/a")
          (getf existing :rule-name)
          (getf existing :source)
          (or (getf existing :target) "n/a")))

(defun intent-priority (intent)
  "Return integer priority from INTENT."
  (or (getf intent :rule-priority) 0))

(defun make-report-entry (decision reason intent &key conflicts replaced-by)
  "Build a conflict diagnostics entry."
  (list :decision decision
        :reason reason
        :intent intent
        :conflicts conflicts
        :replaced-by replaced-by))

(defun maybe-push-report (report entry collect-report)
  "Push ENTRY to REPORT when COLLECT-REPORT is true."
  (if collect-report
      (push entry report)
      report))

(defun report-replacements (report existing-conflicts replacement reason collect-report)
  "Record replacements for EXISTING-CONFLICTS caused by REPLACEMENT."
  (if collect-report
      (dolist (existing existing-conflicts report)
        (push (make-report-entry :drop reason existing :replaced-by replacement)
              report))
      report))

(defun choose-priority-intent (intent existing-conflicts)
  "Return :replace when INTENT outranks conflicts, otherwise :drop."
  (let* ((new-priority (intent-priority intent))
         (max-existing (reduce #'max existing-conflicts :key #'intent-priority)))
    (if (> new-priority max-existing)
        :replace
        :drop)))

(defun apply-priority-policy (intent existing-conflicts resolved report collect-report)
  "Apply priority policy and return updated RESOLVED and REPORT."
  (let ((decision (choose-priority-intent intent existing-conflicts)))
    (cond
      ((eql decision :replace)
       (setf report (report-replacements report
                                         existing-conflicts
                                         intent
                                         :replaced-by-priority
                                         collect-report))
       (setf resolved (set-difference resolved existing-conflicts :test #'equal))
       (push intent resolved)
       (values resolved report))
      (t
       (setf report (maybe-push-report report
                                       (make-report-entry :drop :lower-priority intent
                                                          :conflicts existing-conflicts)
                                       collect-report))
       (values resolved report)))))

(defun resolve-conflicts (intents &key (policy (conflict-policy)) (collect-report nil))
  "Resolve INTENTS according to POLICY.
When COLLECT-REPORT is true, return diagnostics as second value."
  (unless (valid-conflict-policy-p policy)
    (error "Invalid conflict policy: ~S" policy))
  (let ((resolved '())
        (report '()))
    (dolist (intent intents)
      (let ((existing-conflicts (remove-if-not
                                 (lambda (existing)
                                   (and (not (intent-equivalent-p intent existing))
                                        (conflicting-intent-p intent existing)))
                                 resolved)))
        (cond
          ((find intent resolved :test #'intent-equivalent-p)
           (setf report (maybe-push-report report
                                          (make-report-entry :drop :duplicate intent)
                                          collect-report)))
          ((null existing-conflicts)
           (push intent resolved))
          ((eql policy :error-on-conflict)
           (error "~A" (conflict-message intent (first existing-conflicts))))
          ((or (eql policy :skip-on-conflict)
               (eql policy :first-wins))
           (setf report (maybe-push-report report
                                          (make-report-entry :drop policy intent
                                                             :conflicts existing-conflicts)
                                          collect-report)))
          ((eql policy :last-wins)
           (setf report (report-replacements report
                                             existing-conflicts
                                             intent
                                             :replaced-by-last-wins
                                             collect-report))
           (setf resolved (set-difference resolved existing-conflicts :test #'equal))
           (push intent resolved))
          ((eql policy :priority)
           (multiple-value-setq (resolved report)
             (apply-priority-policy intent existing-conflicts resolved report collect-report)))
          (t
           (error "Unhandled conflict policy: ~S" policy)))))
    (if collect-report
        (values (nreverse resolved) (nreverse report))
        (nreverse resolved))))

(defun plan-rules (rules files)
  "Create execution intents for all RULES matched against FILES."
  (let ((index 0)
        (intents '()))
    (dolist (rule rules (nreverse intents))
      (dolist (file-object files)
        (when (funcall (rule-definition-predicate rule) file-object)
          (dolist (action (rule-definition-actions rule))
            (incf index)
            (push (make-intent rule file-object action index) intents)))))))

(defun collect-conflicts (intents)
  "Return pairwise conflicts found across INTENTS.
Each entry is a plist: (:left intent-a :right intent-b)."
  (let ((vector (coerce intents 'vector))
        (conflicts '()))
    (loop for i from 0 below (length vector) do
      (loop for j from (1+ i) below (length vector) do
        (let ((left (aref vector i))
              (right (aref vector j)))
          (when (and (not (intent-equivalent-p left right))
                     (conflicting-intent-p left right))
            (push (list :left left :right right) conflicts)))))
    (nreverse conflicts)))

(defun apply-intent (intent &key (dry-run nil)
                           (file-conflict-policy (file-conflict-policy)))
  "Apply INTENT and return operation result plist."
  (apply-action (getf intent :action)
                (getf intent :file)
                :dry-run dry-run
                :file-conflict-policy file-conflict-policy))

(defun rollback-step-from-result (result)
  "Create rollback step plist from action RESULT, or NIL when unsupported."
  (let ((action (getf result :action))
        (source (getf result :source))
        (target (getf result :target)))
    (cond
      ((eql (getf result :status) :skipped)
       nil)
      (t
       (case action
         ((:move :rename)
          (and source target
               (list :type :rename-back
                     :from target
                     :to source)))
         (:copy
          (and target
               (list :type :delete-copy
                     :path target)))
         (otherwise nil))))))

(defun perform-rollback-step (step)
  "Perform one rollback STEP and return status plist."
  (let ((type (getf step :type)))
    (handler-case
        (progn
          (case type
            (:rename-back
             (rename-file (pathname (getf step :from))
                          (pathname (getf step :to))))
            (:delete-copy
             (when (probe-file (pathname (getf step :path)))
               (delete-file (pathname (getf step :path)))))
            (otherwise
             (error "Unsupported rollback step type: ~S" type)))
          (list :status :ok :step step))
      (error (condition)
        (list :status :error
              :step step
              :message (princ-to-string condition))))))

(defun rollback-results (results)
  "Rollback RESULTS in reverse order and return rollback report list."
  (let ((steps (remove nil
                       (mapcar #'rollback-step-from-result results)))
        (unsupported-count (- (length results)
                              (length (remove nil
                                              (mapcar #'rollback-step-from-result results))))))
    (append
     (mapcar #'perform-rollback-step (reverse steps))
     (if (> unsupported-count 0)
         (list (list :status :warning
                     :message (format nil "~D action(s) had no rollback support."
                                      unsupported-count)))
         nil))))

(defun execute-intents (intents &key (dry-run nil)
                                  (rollback-on-error t)
                                  (file-conflict-policy (file-conflict-policy)))
  "Execute INTENTS and return two values: results and execution report."
  (let ((results '()))
    (handler-case
        (progn
          (dolist (intent intents)
            (push (apply-intent intent
                                :dry-run dry-run
                                :file-conflict-policy file-conflict-policy)
                  results))
          (values (nreverse results)
                  (list :status :ok :rollback-attempted nil :rollback-report nil)))
      (error (condition)
        (let ((rollback-report (if (and rollback-on-error (not dry-run))
                                   (rollback-results (nreverse results))
                                   nil)))
          (error "Execution failed: ~A~%Rollback report: ~S"
                 condition rollback-report))))))

(defun run-rule-on-file (rule file-object &key (dry-run nil))
  "Run a single RULE-DEFINITION on FILE-OBJECT."
  (if (funcall (rule-definition-predicate rule) file-object)
      (mapcar (lambda (action)
                (apply-action action file-object :dry-run dry-run))
              (rule-definition-actions rule))
      nil))

(defun run-rules (rules files &key (dry-run nil)
                               (conflict-policy (conflict-policy))
                               (file-conflict-policy (file-conflict-policy)))
  "Run RULES against FILES and return flat list of action results."
  (let* ((intents (plan-rules rules files))
         (resolved (resolve-conflicts intents :policy conflict-policy)))
    (nth-value 0 (execute-intents resolved
                                  :dry-run dry-run
                                  :file-conflict-policy file-conflict-policy))))

(defun run-rules-with-report (rules files &key (dry-run nil)
                                            (conflict-policy (conflict-policy))
                                            (file-conflict-policy (file-conflict-policy))
                                            (rollback-on-error t))
  "Run RULES and return values: results, conflict report, execution report."
  (let ((intents (plan-rules rules files)))
    (multiple-value-bind (resolved report)
        (resolve-conflicts intents :policy conflict-policy :collect-report t)
      (multiple-value-bind (results execution-report)
          (execute-intents resolved
                           :dry-run dry-run
                           :rollback-on-error rollback-on-error
                           :file-conflict-policy file-conflict-policy)
        (values results report execution-report)))))
