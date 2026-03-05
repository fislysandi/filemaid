(in-package :filemaid)

(defun print-usage ()
  "Print command-line usage help."
  (format t "Filemaid commands:~%")
  (format t
          "  filemaid run <rules-file> [--dry-run] [--verbose] [--no-rollback] [--yes]~%")
  (format t
          "               [--conflict-policy POLICY] [--file-conflict-policy POLICY]~%")
  (format t
          "               [--per-conflict] [--diagnostics-format FMT]~%")
  (format t
          "  filemaid preview <rules-file> [--verbose] [--conflict-policy POLICY]~%")
  (format t
          "                   [--file-conflict-policy POLICY] [--diagnostics-format FMT]~%")
  (format t
          "  filemaid init-project --template <name-or-path> [--template-name NAME]~%")
  (format t
          "                     [--target DIR] [--name NAME] [--verbose]~%")
  (format t
          "  filemaid explain-conflicts <rules-file> [--diagnostics-format FMT]~%")
  (format t "  filemaid scan <directory>~%")
  (format t
          "  filemaid watch <directory> [--backend auto|poll|inotify] [--interval N]~%")
  (format t
          "                [--iterations N] [--recursive] [--verbose]~%"))

(defun argument-present-p (argv flag)
  "Return true when FLAG exists in ARGV list."
  (member flag argv :test #'string=))

(defun automated-mode-p (argv)
  "Return true when execution should skip interactive confirmation."
  (or (argument-present-p argv "--yes")
      (argument-present-p argv "--auto-approve")
      (string-equal (or (uiop:getenv "CI") "") "true")))

(defun flag-value (argv flag)
  "Return value immediately following FLAG in ARGV."
  (let ((position (position flag argv :test #'string=)))
    (when position
      (nth (1+ position) argv))))

(defun parse-positive-integer (value default)
  "Parse VALUE as positive integer or return DEFAULT."
  (if value
      (let ((parsed (parse-integer value :junk-allowed t)))
        (if (and parsed (> parsed 0))
            parsed
            default))
      default))

(defun normalize-watch-backend (value)
  "Normalize backend VALUE into :auto, :poll, or :inotify."
  (let ((raw (string-downcase (or value "auto"))))
    (cond
      ((string= raw "auto") :auto)
      ((string= raw "poll") :poll)
      ((string= raw "inotify") :inotify)
      (t :auto))))

(defun normalize-conflict-policy (value)
  "Normalize VALUE into a conflict policy keyword."
  (let ((raw (string-downcase (or value "error-on-conflict"))))
    (cond
      ((string= raw "error-on-conflict") :error-on-conflict)
      ((string= raw "skip-on-conflict") :skip-on-conflict)
      ((string= raw "first-wins") :first-wins)
      ((string= raw "last-wins") :last-wins)
      ((string= raw "priority") :priority)
      (t (conflict-policy)))))

(defun normalize-file-conflict-policy (value)
  "Normalize VALUE into file conflict policy keyword."
  (let ((raw (string-downcase (or value (string-downcase (string (file-conflict-policy)))))))
    (cond
      ((string= raw "error") :error)
      ((string= raw "overwrite") :overwrite)
      ((string= raw "skip") :skip)
      ((string= raw "rename") :rename)
      (t (file-conflict-policy)))))

(defun normalize-diagnostics-format (value)
  "Normalize VALUE into :text or :json diagnostics format."
  (let ((raw (string-downcase (or value "text"))))
    (cond
      ((string= raw "json") :json)
      (t :text))))

(defun inotifywait-available-p ()
  "Return true when inotifywait binary is available."
  (or (probe-file #P"/usr/bin/inotifywait")
      (probe-file #P"/bin/inotifywait")))

(defun parse-inotify-line (line)
  "Parse inotifywait output LINE into event/path plist."
  (let* ((parts (uiop:split-string line :separator '(#\Space #\Tab) :remove-empty-subseqs t))
         (path (first parts))
         (event (second parts))
         (file (third parts)))
    (list :event (or event "UNKNOWN")
          :path (or file path ""))))

(defun reason-label (reason)
  "Convert conflict REASON keyword to lowercase label."
  (string-downcase (string reason)))

(defun summarize-conflict-entry (entry)
  "Convert conflict diagnostics ENTRY into one-line text."
  (let* ((intent (getf entry :intent))
         (rule (or (getf intent :rule-name) 'unknown-rule))
         (source (or (getf intent :source) "n/a"))
         (target (or (getf intent :target) "n/a"))
         (reason (reason-label (getf entry :reason)))
         (decision (or (getf entry :decision) :drop))
         (conflicts (length (or (getf entry :conflicts) '())))
         (replacement (getf entry :replaced-by))
         (replacement-rule (and replacement (getf replacement :rule-name))))
    (if replacement-rule
        (format nil "~A ~A (~A -> ~A) reason=~A replacement=~A"
                decision rule source target reason replacement-rule)
        (format nil "~A ~A (~A -> ~A) reason=~A conflicts=~D"
                decision rule source target reason conflicts))))

(defun json-escape-string (string)
  "Escape STRING for JSON string literal output."
  (with-output-to-string (out)
    (loop for ch across string do
      (case ch
        (#\\ (write-string "\\\\" out))
        (#\" (write-string "\\\"" out))
        (#\Newline (write-string "\\n" out))
        (#\Return (write-string "\\r" out))
        (#\Tab (write-string "\\t" out))
        (otherwise (write-char ch out))))))

(defun entry-field (entry key default)
  "Read KEY from ENTRY plist with DEFAULT fallback."
  (or (getf entry key) default))

(defun format-conflict-entry-json (entry)
  "Format one diagnostics ENTRY as compact JSON object."
  (let* ((intent (entry-field entry :intent '()))
         (rule (string-downcase (string (entry-field intent :rule-name 'unknown-rule))))
         (source (entry-field intent :source "n/a"))
         (target (entry-field intent :target "n/a"))
         (reason (reason-label (entry-field entry :reason :unknown)))
         (decision (string-downcase (string (entry-field entry :decision :drop))))
         (conflicts (length (entry-field entry :conflicts '())))
         (replacement (entry-field entry :replaced-by nil))
         (replacement-rule
           (if replacement
               (string-downcase (string (entry-field replacement :rule-name 'unknown-rule)))
               "")))
    (format nil
            (concatenate 'string
                         "{\"decision\":\"~A\",\"rule\":\"~A\",\"source\":\"~A\","
                         "\"target\":\"~A\",\"reason\":\"~A\",\"conflicts\":~D,"
                         "\"replacement\":\"~A\"}")
            (json-escape-string decision)
            (json-escape-string rule)
            (json-escape-string source)
            (json-escape-string target)
            (json-escape-string reason)
            conflicts
            (json-escape-string replacement-rule))))

(defun print-conflict-diagnostics (report diagnostics-format)
  "Print REPORT in DIAGNOSTICS-FORMAT (:text or :json)."
  (cond
    ((null report)
     (format t "Conflict diagnostics: none.~%"))
    ((eql diagnostics-format :json)
     (format t "Conflict diagnostics (~D):~%" (length report))
     (format t "[~%")
     (loop for entry in report
           for index from 0 do
             (format t "  ~A~A~%"
                     (format-conflict-entry-json entry)
                     (if (< index (1- (length report))) "," "")))
     (format t "]~%"))
    (t
     (format t "Conflict diagnostics (~D):~%" (length report))
     (dolist (entry report)
       (format t "  ~A~%" (summarize-conflict-entry entry))))))

(defun conflicts-to-report (conflicts)
  "Convert pairwise CONFLICTS into diagnostics entries for display."
  (mapcar (lambda (conflict)
            (let ((left (getf conflict :left))
                  (right (getf conflict :right)))
              (list :decision :detected
                    :reason :pairwise-conflict
                    :intent left
                    :conflicts (list right)
                    :replaced-by nil)))
          conflicts))

(defun print-execution-report (execution-report)
  "Print execution safety report returned by the pipeline."
  (let ((status (getf execution-report :status))
        (rollback-attempted (getf execution-report :rollback-attempted))
        (rollback-report (getf execution-report :rollback-report)))
    (format t "Execution status: ~A~%" status)
    (format t "Rollback attempted: ~A~%" rollback-attempted)
    (when rollback-report
      (format t "Rollback report: ~S~%" rollback-report))))

(defun summarize-action (result)
  "Return one-line description for action RESULT plist."
  (let ((action (getf result :action))
        (source (getf result :source))
        (target (getf result :target)))
    (format nil "~A: ~A -> ~A"
            action
            (or source "n/a")
            (or target "n/a"))))

(defun print-plan-preview (results)
  "Print user-facing plan preview for RESULTS list."
  (format t "Planned filesystem changes (~D):~%" (length results))
  (if (null results)
      (format t "  (no changes)~%")
      (dolist (result results)
        (format t "  ~A~%" (summarize-action result)))))

(defun prompt-for-approval ()
  "Prompt user for approval and return true when accepted."
  (format t "Proceed with these changes? [y/N]: ")
  (finish-output)
  (let ((answer (string-downcase (string-trim '(#\Space #\Tab)
                                              (or (read-line *standard-input* nil "") "")))))
    (or (string= answer "y")
        (string= answer "yes"))))

(defparameter *project-directories*
  '("src/" "rules/" "tests/" "python/" ".opencode/context/"))

(defun normalize-template-filename (value)
  "Return template filename ending in .lisp from VALUE."
  (let ((name (or value "organization-rules")))
    (if (pathname-type (pathname name))
        name
        (format nil "~A.lisp" name))))

(defun template-pathname-candidates (template-spec)
  "Return ordered candidate pathnames for TEMPLATE-SPEC."
  (let* ((raw (pathname template-spec))
         (raw-type (pathname-type raw))
         (with-ext (if raw-type
                       raw
                       (pathname (format nil "~A.lisp" template-spec))))
         (templates-root (project-templates-root-pathname))
         (named-template
           (merge-pathnames
            (normalize-template-filename (file-namestring with-ext))
            templates-root)))
    (list raw with-ext named-template)))

(defun resolve-template-pathname (template-spec)
  "Resolve TEMPLATE-SPEC as file path or named template under templates root."
  (or (find-if #'probe-file (template-pathname-candidates template-spec))
      (error "Template not found. Use existing path or name from ~A"
             (namestring (project-templates-root-pathname)))))

(defun resolve-project-root (template-spec project-name target-option)
  "Resolve output project root using custom hook, target, or default root."
  (if *init-project-target-resolver*
      (funcall *init-project-target-resolver* template-spec project-name target-option)
      (let ((resolved-name
              (or project-name
                  (pathname-name (pathname template-spec))
                  "filemaid-project")))
        (if target-option
            (uiop:ensure-directory-pathname target-option)
            (merge-pathnames (format nil "~A/" resolved-name)
                             (projects-root-pathname))))))

(defun ensure-template-directories ()
  "Ensure default template and project roots exist."
  (ensure-directories-exist (project-templates-root-pathname))
  (ensure-directories-exist (projects-root-pathname)))

(defun ensure-project-structure (target-directory)
  "Create standard Filemaid project folders under TARGET-DIRECTORY."
  (let ((root (uiop:ensure-directory-pathname target-directory)))
    (dolist (relative *project-directories*)
      (ensure-directories-exist (merge-pathnames relative root)))))

(defun install-template-rules (template-path target-directory template-name)
  "Copy TEMPLATE-PATH into target rules/TEMPLATE-NAME."
  (let* ((root (uiop:ensure-directory-pathname target-directory))
         (destination (merge-pathnames
                       (format nil "rules/~A" (normalize-template-filename template-name))
                       root)))
    (ensure-directories-exist destination)
    (copy-file template-path destination)
    destination))

(defun init-project-command (&key template target template-name project-name verbose)
  "Initialize a project layout and install rules from TEMPLATE."
  (unless template
    (error "--template is required for init-project."))
  (ensure-template-directories)
  (let* ((resolved-template (resolve-template-pathname template))
         (root (resolve-project-root template project-name target))
         (installed-path (progn
                            (ensure-project-structure root)
                            (install-template-rules resolved-template
                                                    root
                                                    template-name))))
    (when verbose
      (format t "Initialized project at: ~A~%" (namestring root))
      (format t "Template source: ~A~%" (namestring resolved-template))
      (format t "Installed organization rules: ~A~%" (namestring installed-path)))
    0))

(defun load-rules-from-file (rules-file)
  "Load RULES-FILE and return registered rules."
  (clear-rule-registry)
  (load rules-file)
  (registered-rules))

(defun files-for-rules (rules)
  "Collect unique files from all RULES source directories."
  (remove-duplicates
   (loop for rule in rules append (scan-directory (rule-definition-from rule)))
   :test (lambda (a b)
           (string= (file-object-path a) (file-object-path b)))))

(defun load-plan-context (rules-file)
  "Load RULES-FILE and return values: rules, files, intents, conflicts."
  (let* ((rules (load-rules-from-file rules-file))
         (files (files-for-rules rules))
         (intents (plan-rules rules files))
         (conflicts (collect-conflicts intents)))
    (values rules files intents conflicts)))

(defun run-intents-with-report (intents dry-run conflict-policy file-conflict-policy rollback-on-error)
  "Run INTENTS and return values: results, conflict-report, execution-report."
  (multiple-value-bind (resolved report)
      (resolve-conflicts intents :policy conflict-policy :collect-report t)
    (multiple-value-bind (results execution-report)
        (execute-intents resolved
                         :dry-run dry-run
                         :rollback-on-error rollback-on-error
                         :file-conflict-policy file-conflict-policy)
      (values results report execution-report))))

(defun summarize-intent (intent)
  "Return short human-readable summary for one INTENT."
  (let ((rule (getf intent :rule-name))
        (source (getf intent :source))
        (target (or (getf intent :target) "n/a")))
    (format nil "~A: ~A -> ~A" rule source target)))

(defun print-conflict-candidates (conflicts)
  "Print all detected CONFLICTS before execution."
  (format t "Detected conflicts (~D):~%" (length conflicts))
  (loop for conflict in conflicts
        for index from 1 do
          (format t "  [~D] ~A <-> ~A~%"
                  index
                  (summarize-intent (getf conflict :left))
                  (summarize-intent (getf conflict :right)))))

(defun prompt-conflict-policy-choice ()
  "Prompt user to select conflict policy and return keyword."
  (format t "Choose conflict policy:~%")
  (format t "  1) error-on-conflict~%")
  (format t "  2) skip-on-conflict~%")
  (format t "  3) first-wins~%")
  (format t "  4) last-wins~%")
  (format t "  5) priority~%")
  (format t "Selection [1-5, default 1]: ")
  (finish-output)
  (let ((answer (string-trim '(#\Space #\Tab)
                             (or (read-line *standard-input* nil "") ""))))
    (cond
      ((or (string= answer "") (string= answer "1")) :error-on-conflict)
      ((string= answer "2") :skip-on-conflict)
      ((string= answer "3") :first-wins)
      ((string= answer "4") :last-wins)
      ((string= answer "5") :priority)
      (t :error-on-conflict))))

(defun prompt-file-conflict-policy-choice ()
  "Prompt user to select behavior when destination file already exists."
  (format t "Choose file conflict policy:~%")
  (format t "  1) error~%")
  (format t "  2) overwrite~%")
  (format t "  3) skip~%")
  (format t "  4) rename~%")
  (format t "Selection [1-4, default 1]: ")
  (finish-output)
  (let ((answer (string-trim '(#\Space #\Tab)
                             (or (read-line *standard-input* nil "") ""))))
    (cond
      ((or (string= answer "") (string= answer "1")) :error)
      ((string= answer "2") :overwrite)
      ((string= answer "3") :skip)
      ((string= answer "4") :rename)
      (t :error))))

(defun resolve-interactive-policy (raw-policy conflicts)
  "Resolve policy from RAW-POLICY or interactive prompt for CONFLICTS."
  (cond
    (raw-policy
     (normalize-conflict-policy raw-policy))
    ((null conflicts)
     (conflict-policy))
    (t
     (print-conflict-candidates conflicts)
     (prompt-conflict-policy-choice))))

(defun explain-conflicts-command (rules-file &key (diagnostics-format :text))
  "Analyze RULES-FILE and print detected conflicts without applying changes."
  (unless rules-file
    (error "Rules file is required."))
  (multiple-value-bind (_rules _files _intents conflicts)
      (load-plan-context rules-file)
    (declare (ignore _rules _files _intents))
    (print-conflict-diagnostics (conflicts-to-report conflicts) diagnostics-format)
    (if conflicts 2 0)))

(defun resolve-interactive-file-policy (raw-file-policy automated-mode)
  "Resolve file conflict policy from RAW-FILE-POLICY or interactive prompt."
  (cond
    (raw-file-policy
     (normalize-file-conflict-policy raw-file-policy))
    (automated-mode
     (file-conflict-policy))
    (t
     (prompt-file-conflict-policy-choice))))

(defun prompt-per-conflict-decision (conflict)
  "Prompt user decision for one CONFLICT pair."
  (format t "Conflict:~%")
  (format t "  L) ~A~%" (summarize-intent (getf conflict :left)))
  (format t "  R) ~A~%" (summarize-intent (getf conflict :right)))
  (format t "Choose [l/r/s/p] (left/right/skip-both/policy): ")
  (finish-output)
  (let ((answer (string-downcase (string-trim '(#\Space #\Tab)
                                              (or (read-line *standard-input* nil "") "")))))
    (cond
      ((string= answer "l") :left)
      ((string= answer "r") :right)
      ((string= answer "s") :skip)
      (t :policy))))

(defun intent-signature (intent)
  "Return stable signature list for INTENT."
  (list (getf intent :rule-name)
        (action-spec-type (getf intent :action))
        (getf intent :source)
        (getf intent :target)))

(defun conflict-profile-key (conflict)
  "Return persisted key string for CONFLICT pair."
  (prin1-to-string
   (list :left (intent-signature (getf conflict :left))
         :right (intent-signature (getf conflict :right)))))

(defun resolve-per-conflict-decision (conflict)
  "Resolve decision for CONFLICT via stored profile or interactive prompt."
  (let* ((key (conflict-profile-key conflict))
         (stored (conflict-profile-get key)))
    (if stored
        stored
        (let ((decision (prompt-per-conflict-decision conflict)))
          (conflict-profile-set key decision)
          (save-conflict-resolution-profile)
          decision))))

(defun apply-per-conflict-selections (intents conflicts)
  "Interactively prune INTENTS using per-conflict choices over CONFLICTS."
  (let ((dropped (make-hash-table :test #'equal)))
    (dolist (conflict conflicts)
      (let* ((left (getf conflict :left))
             (right (getf conflict :right))
             (left-key (getf left :index))
             (right-key (getf right :index)))
        (unless (or (gethash left-key dropped)
                    (gethash right-key dropped))
          (case (resolve-per-conflict-decision conflict)
            (:left (setf (gethash right-key dropped) t))
            (:right (setf (gethash left-key dropped) t))
            (:skip
             (setf (gethash left-key dropped) t)
             (setf (gethash right-key dropped) t))
            (otherwise nil)))))
    (remove-if (lambda (intent)
                 (gethash (getf intent :index) dropped))
               intents)))

(defun execute-rules-file (rules-file &key (dry-run nil) (verbose nil)
                                         (conflict-policy (conflict-policy))
                                         (file-conflict-policy (file-conflict-policy))
                                         (diagnostics-format :text)
                                         (rollback-on-error t)
                                         preplanned-intents
                                         rule-count
                                         file-count
                                         (suppress-output nil))
  "Execute or preview RULES-FILE using DRY-RUN, VERBOSE, and CONFLICT-POLICY."
  (unless rules-file
    (error "Rules file is required."))
  (let* ((rules (unless preplanned-intents
                  (load-rules-from-file rules-file)))
         (files (unless preplanned-intents
                  (files-for-rules rules)))
         (intents (or preplanned-intents
                      (plan-rules rules files)))
         (effective-rule-count (or rule-count (if rules (length rules) 0)))
         (effective-file-count (or file-count (if files (length files) 0))))
    (multiple-value-bind (results report execution-report)
        (run-intents-with-report intents
                                 dry-run
                                 conflict-policy
                                 file-conflict-policy
                                 rollback-on-error)
    (unless suppress-output
      (when verbose
        (format t "Mode: ~A~%" (if dry-run "dry-run" "execute"))
        (format t "Conflict policy: ~A~%" conflict-policy)
        (format t "File conflict policy: ~A~%" file-conflict-policy)
        (format t "Diagnostics format: ~A~%" diagnostics-format)
        (format t "Rollback on error: ~A~%" rollback-on-error)
        (format t "Loaded ~D rule(s), scanned ~D file(s).~%"
                effective-rule-count
                effective-file-count)
        (print-conflict-diagnostics report diagnostics-format)
        (print-execution-report execution-report))
      (if verbose
          (dolist (result results)
            (format t "~S~%" result))
          (format t "~D action(s) ~A.~%"
                  (length results)
                  (if dry-run "planned (dry-run)" "executed"))))
      results)))

(defun run-with-confirmation (rules-file args)
  "Run command flow with preview and interactive approval when needed."
  (let* ((dry-run (argument-present-p args "--dry-run"))
         (verbose (argument-present-p args "--verbose"))
         (automated-mode (automated-mode-p args))
         (raw-policy (flag-value args "--conflict-policy"))
         (raw-file-policy (flag-value args "--file-conflict-policy"))
         (per-conflict (argument-present-p args "--per-conflict"))
         (rollback-on-error (not (argument-present-p args "--no-rollback")))
         (diagnostics-format (normalize-diagnostics-format
                              (flag-value args "--diagnostics-format")))
         (selected-file-policy
           (resolve-interactive-file-policy raw-file-policy automated-mode)))
    (cond
      ((or dry-run automated-mode)
        (execute-rules-file rules-file
                            :dry-run dry-run
                            :verbose verbose
                            :rollback-on-error rollback-on-error
                            :diagnostics-format diagnostics-format
                            :conflict-policy (normalize-conflict-policy raw-policy)
                            :file-conflict-policy selected-file-policy)
        0)
      (t
       (multiple-value-bind (rules files intents conflicts)
           (load-plan-context rules-file)
         (let* ((intents-for-preview
                  (if (and per-conflict conflicts)
                      (apply-per-conflict-selections intents conflicts)
                      intents))
                (remaining-conflicts (collect-conflicts intents-for-preview))
                (policy (resolve-interactive-policy raw-policy remaining-conflicts))
                (plan (execute-rules-file rules-file
                                           :dry-run t
                                           :verbose nil
                                           :rollback-on-error nil
                                           :diagnostics-format diagnostics-format
                                           :conflict-policy policy
                                           :file-conflict-policy selected-file-policy
                                           :preplanned-intents intents-for-preview
                                           :rule-count (length rules)
                                           :file-count (length files)
                                           :suppress-output t)))
           (print-plan-preview plan)
           (cond
             ((prompt-for-approval)
              (execute-rules-file rules-file
                                  :dry-run nil
                                  :verbose verbose
                                  :rollback-on-error rollback-on-error
                                  :diagnostics-format diagnostics-format
                                  :conflict-policy policy
                                  :file-conflict-policy selected-file-policy
                                  :preplanned-intents intents-for-preview
                                  :rule-count (length rules)
                                  :file-count (length files))
              0)
             (t
              (format t "Cancelled by user.~%")
              1))))))))

(defun scan-command (directory &key (recursive nil))
  "Print absolute paths from DIRECTORY scan results."
  (unless directory
    (error "Directory is required."))
  (dolist (file-object (scan-directory directory :recursive recursive))
    (format t "~A~%" (file-object-path file-object))))

(defun snapshot-directory (directory &key (recursive nil))
  "Capture DIRECTORY state map keyed by file path."
  (let ((table (make-hash-table :test #'equal)))
    (dolist (file-object (scan-directory directory :recursive recursive) table)
      (setf (gethash (file-object-path file-object) table)
            (list (file-object-size file-object)
                  (file-object-modified file-object))))))

(defun hash-keys (table)
  "Return all hash TABLE keys as a list."
  (loop for key being the hash-keys in table collect key))

(defun state-diff (old-state new-state)
  "Return change events comparing OLD-STATE and NEW-STATE maps."
  (let ((events '()))
    (dolist (path (hash-keys new-state))
      (let ((old-value (gethash path old-state))
            (new-value (gethash path new-state)))
        (cond
          ((null old-value)
           (push (list :created path) events))
          ((not (equal old-value new-value))
           (push (list :modified path) events))
          (t nil))))
    (dolist (path (hash-keys old-state))
      (unless (gethash path new-state)
        (push (list :deleted path) events)))
    (nreverse events)))

(defun watch-with-polling (directory interval iterations verbose recursive)
  "Watch DIRECTORY via polling for ITERATIONS at INTERVAL seconds."
  (let ((state (snapshot-directory directory :recursive recursive))
        (round 0))
    (when verbose
      (format t "Watching ~A with polling (interval=~As, iterations=~A).~%"
              directory interval (or iterations 'infinite))
      (format t "Initial files: ~D~%" (hash-table-count state)))
    (loop while (or (null iterations) (< round iterations)) do
      (sleep interval)
      (let* ((new-state (snapshot-directory directory :recursive recursive))
             (events (state-diff state new-state)))
        (when (and verbose (null events))
          (format t "No changes detected.~%"))
        (dolist (event events)
          (format t "~A ~A~%" (first event) (second event)))
        (setf state new-state))
      (incf round))))

(defun watch-with-inotify (directory iterations verbose recursive)
  "Watch DIRECTORY via inotifywait for ITERATIONS events."
  (let ((round 0))
    (when verbose
      (format t "Watching ~A with inotifywait (iterations=~A).~%"
              directory (or iterations 'infinite)))
    (loop while (or (null iterations) (< round iterations)) do
      (let* ((output (uiop:run-program
                      (append (list "inotifywait" "-q" "-e" "create,modify,delete,move")
                              (if recursive (list "-r") nil)
                              (list "--format" "%w %e %f" directory))
                      :output :string
                      :error-output :output
                      :ignore-error-status t))
             (line (string-trim '(#\Newline #\Return #\Space #\Tab)
                                (or output ""))))
        (unless (string= line "")
          (let ((event (parse-inotify-line line)))
            (format t "~A ~A~%" (getf event :event) (getf event :path)))))
      (incf round))))

(defun watch-command (directory &key (interval 2) iterations (verbose nil)
                                     (backend :auto) (recursive nil))
  "Dispatch watch command with BACKEND selection and options."
  (unless directory
    (error "Directory is required."))
  (let ((selected (if (eql backend :auto)
                      (if (inotifywait-available-p) :inotify :poll)
                      backend)))
    (when (and (eql selected :inotify) (not (inotifywait-available-p)))
      (error "inotify backend requested but inotifywait is not installed."))
    (ecase selected
      (:poll (watch-with-polling directory interval iterations verbose recursive))
      (:inotify (watch-with-inotify directory iterations verbose recursive))))
  0)

(defun run-cli (argv)
  "Execute CLI command parsed from ARGV and return exit code."
  (let ((command (first argv))
        (args (rest argv)))
    (load-default-config :verbose (argument-present-p args "--verbose"))
    (cond
      ((null command)
       (print-usage)
       1)
      ((string= command "run")
       (run-with-confirmation (first args) args))
      ((string= command "preview")
       (progn
         (execute-rules-file (first args)
                             :dry-run t
                             :verbose (argument-present-p args "--verbose")
                             :rollback-on-error nil
                             :file-conflict-policy
                             (normalize-file-conflict-policy
                              (flag-value args "--file-conflict-policy"))
                             :diagnostics-format
                             (normalize-diagnostics-format
                              (flag-value args "--diagnostics-format"))
                             :conflict-policy (normalize-conflict-policy
                                                (flag-value args "--conflict-policy")))
         0))
      ((string= command "init-project")
       (init-project-command
         :template (flag-value args "--template")
         :target (flag-value args "--target")
         :template-name (flag-value args "--template-name")
         :project-name (flag-value args "--name")
         :verbose (argument-present-p args "--verbose")))
      ((string= command "explain-conflicts")
       (explain-conflicts-command
        (first args)
        :diagnostics-format
        (normalize-diagnostics-format (flag-value args "--diagnostics-format"))))
      ((string= command "scan")
       (progn
         (scan-command (first args)
                       :recursive (argument-present-p args "--recursive"))
         0))
      ((string= command "watch")
         (watch-command (first args)
                       :backend (normalize-watch-backend (flag-value args "--backend"))
                       :interval (parse-positive-integer (flag-value args "--interval") 2)
                       :recursive (argument-present-p args "--recursive")
                       :iterations (let ((raw (flag-value args "--iterations")))
                                     (when raw
                                       (parse-positive-integer raw 1)))
                      :verbose (argument-present-p args "--verbose")))
      (t
       (print-usage)
       1))))

(defun main ()
  "Entry point for executable CLI invocation."
  (uiop:quit (run-cli (uiop:command-line-arguments))))
