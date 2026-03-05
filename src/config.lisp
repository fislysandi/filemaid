(in-package :filemaid)

(defparameter *valid-conflict-policies*
  '(:error-on-conflict :skip-on-conflict :first-wins :last-wins :priority))

(defparameter *conflict-policy* :error-on-conflict)

(defparameter *valid-file-conflict-policies*
  '(:error :overwrite :skip :rename))

(defparameter *file-conflict-policy* :error)

(defparameter *projects-root*
  #P"~/.config/filemaid/projects/"
  "Default root directory for initialized projects.")

(defparameter *project-templates-root*
  #P"~/.config/filemaid/projects/templates/"
  "Default directory for named project templates.")

(defparameter *init-project-target-resolver* nil
  "Optional function (template-spec project-name target-option) -> pathname.")

(defparameter *conflict-resolution-profile-path*
  #P"~/.config/filemaid/conflict-resolution.sexp"
  "Path for persisted per-conflict resolution decisions.")

(defparameter *conflict-resolution-profile* nil
  "Alist of (conflict-key-string . decision-keyword).")

(defparameter *default-project-name* nil
  "Optional default project name under projects root for implicit preview/run.")

(defparameter *default-rules-files* nil
  "Optional ordered list of explicit default rules file path strings/pathnames.")

(defparameter *global-rules-root*
  #P"~/.config/filemaid/rules/"
  "Default global rules directory for implicit preview/run.")

(defparameter *addons-root*
  #P"~/.config/filemaid/addons/"
  "Default addons directory for optional extension loading.")

(defparameter *enabled-addons* nil
  "Optional list of addon names or file path strings to load.")

(defparameter *autoload-addons* t
  "When true, load addons during startup via load-default-config.")

(defun valid-conflict-policy-p (policy)
  "Return true when POLICY is one of supported conflict policies."
  (member policy *valid-conflict-policies*))

(defun conflict-policy ()
  "Return current global conflict policy."
  *conflict-policy*)

(defun set-conflict-policy (policy)
  "Set global conflict POLICY after validation."
  (unless (valid-conflict-policy-p policy)
    (error "Invalid conflict policy: ~S" policy))
  (setf *conflict-policy* policy))

(defun valid-file-conflict-policy-p (policy)
  "Return true when POLICY is one of supported file conflict policies."
  (member policy *valid-file-conflict-policies*))

(defun file-conflict-policy ()
  "Return current global file conflict policy."
  *file-conflict-policy*)

(defun set-file-conflict-policy (policy)
  "Set global file conflict POLICY after validation."
  (unless (valid-file-conflict-policy-p policy)
    (error "Invalid file conflict policy: ~S" policy))
  (setf *file-conflict-policy* policy))

(defun conflict-resolution-profile-pathname ()
  "Return pathname used for persisted conflict resolution profile."
  (pathname *conflict-resolution-profile-path*))

(defun conflict-profile-get (key)
  "Return stored decision for conflict KEY, or NIL when absent."
  (rest (assoc key *conflict-resolution-profile* :test #'string=)))

(defun conflict-profile-set (key decision)
  "Store DECISION for conflict KEY in memory profile."
  (let ((existing (assoc key *conflict-resolution-profile* :test #'string=)))
    (if existing
        (setf (rest existing) decision)
        (push (cons key decision) *conflict-resolution-profile*)))
  decision)

(defun load-conflict-resolution-profile (&key (force nil))
  "Load persisted conflict profile. Returns :loaded or :missing."
  (let ((path (conflict-resolution-profile-pathname)))
    (cond
      ((and (not force) *conflict-resolution-profile*)
       :loaded)
      ((probe-file path)
       (with-open-file (stream path :direction :input)
         (let ((eof-marker (gensym "EOF")))
           (setf *conflict-resolution-profile* (read stream nil eof-marker))
           (when (eq *conflict-resolution-profile* eof-marker)
             (setf *conflict-resolution-profile* nil))))
       :loaded)
      (t
       (setf *conflict-resolution-profile* nil)
       :missing))))

(defun save-conflict-resolution-profile ()
  "Persist in-memory conflict profile to disk and return pathname."
  (let ((path (conflict-resolution-profile-pathname)))
    (ensure-directories-exist path)
    (with-open-file (stream path
                            :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create)
      (print *conflict-resolution-profile* stream))
    path))

(defun default-config-pathname ()
  "Return default user config path ~/.config/filemaid/config.lisp."
  (let ((home (or (uiop:getenv "HOME") "")))
    (merge-pathnames #P".config/filemaid/config.lisp"
                     (uiop:ensure-directory-pathname home))))

(defun projects-root-pathname ()
  "Return default projects root pathname."
  (uiop:ensure-directory-pathname *projects-root*))

(defun project-templates-root-pathname ()
  "Return default templates root pathname."
  (uiop:ensure-directory-pathname *project-templates-root*))

(defun global-rules-root-pathname ()
  "Return default global rules root pathname."
  (uiop:ensure-directory-pathname *global-rules-root*))

(defun addons-root-pathname ()
  "Return default addons root pathname."
  (uiop:ensure-directory-pathname *addons-root*))

(defun discover-addon-files ()
  "Return all .lisp addon files under addons root."
  (directory (merge-pathnames "*.lisp" (addons-root-pathname))))

(defun addon-entry-pathname (entry)
  "Resolve addon ENTRY (name or path) to pathname candidate."
  (let* ((raw (pathname entry))
         (raw-type (pathname-type raw))
         (with-ext (if raw-type raw (pathname (format nil "~A.lisp" entry)))))
    (or (probe-file with-ext)
        (probe-file (merge-pathnames with-ext (addons-root-pathname))))))

(defun resolve-enabled-addon-files ()
  "Resolve enabled addon list. Falls back to all addon files when empty."
  (if *enabled-addons*
      (remove nil (mapcar #'addon-entry-pathname *enabled-addons*))
      (discover-addon-files)))

(defun load-addons (&key (verbose nil))
  "Load addon files and return loaded pathnames."
  (let ((files (resolve-enabled-addon-files)))
    (dolist (file files)
      (load file)
      (when verbose
        (format t "Loaded addon: ~A~%" (namestring file))))
    files))

(defun pathname-parent (path)
  "Return parent directory of PATH, or NIL when unavailable."
  (let ((parent (uiop:pathname-parent-directory-pathname
                 (uiop:ensure-directory-pathname path))))
    (if (equal parent (uiop:ensure-directory-pathname path))
        nil
        parent)))

(defun find-project-root-from-cwd ()
  "Find nearest parent directory that looks like a Filemaid project."
  (loop for current = (uiop:ensure-directory-pathname (uiop:getcwd)) then (pathname-parent current)
        while current
        when (or (probe-file (merge-pathnames "filemaid.asd" current))
                 (probe-file (merge-pathnames "rules/organization-rules.lisp" current)))
          do (return current)))

(defun rules-file-from-project-root (root)
  "Resolve primary rules file from project ROOT."
  (or (probe-file (merge-pathnames "rules/organization-rules.lisp" root))
      (probe-file (merge-pathnames "rules/example-rules.lisp" root))))

(defun cwd-project-rules-pathname ()
  "Resolve rules file from current project context when present."
  (let ((root (find-project-root-from-cwd)))
    (and root (rules-file-from-project-root root))))

(defun default-project-rules-pathname ()
  "Return default project rules path when *DEFAULT-PROJECT-NAME* is set."
  (when *default-project-name*
    (merge-pathnames
     (format nil "~A/rules/organization-rules.lisp" *default-project-name*)
     (projects-root-pathname))))

(defun existing-default-rules-files ()
  "Return explicit *DEFAULT-RULES-FILES* entries that exist."
  (remove-if-not #'probe-file
                 (mapcar #'pathname (or *default-rules-files* '()))))

(defun discover-project-rules-files ()
  "Discover candidate rules files under projects root."
  (let ((root (projects-root-pathname)))
    (loop for project-dir in (uiop:subdirectories root)
          for candidate = (merge-pathnames "rules/organization-rules.lisp" project-dir)
          when (probe-file candidate)
            collect candidate)))

(defun discover-global-rules-files ()
  "Discover candidate global rules files under ~/.config/filemaid/rules/."
  (let ((root (global-rules-root-pathname)))
    (append
     (remove nil (list (probe-file (merge-pathnames "organization-rules.lisp" root))
                       (probe-file (merge-pathnames "example-rules.lisp" root))))
     (directory (merge-pathnames "*.lisp" root)))))

(defun resolve-default-rules-file ()
  "Resolve implicit default rules file from config and projects root."
  (or
   (cwd-project-rules-pathname)
   (first (existing-default-rules-files))
   (let ((default-project-rules (default-project-rules-pathname)))
     (and default-project-rules (probe-file default-project-rules)))
   (first (discover-global-rules-files))
   (probe-file #P"./rules/organization-rules.lisp")
   (probe-file #P"./rules/example-rules.lisp")
   (first (discover-project-rules-files))))

(defun normalize-rules-filename (spec)
  "Return SPEC with .lisp extension when no file type is present."
  (let ((path (pathname spec)))
    (if (pathname-type path)
        path
        (pathname (format nil "~A.lisp" spec)))))

(defun project-rules-candidates (spec)
  "Return candidate project-local rules paths for SPEC."
  (let* ((root (find-project-root-from-cwd))
         (name (file-namestring (pathname spec))))
    (if root
        (remove nil
                (list (merge-pathnames (format nil "rules/~A" name) root)
                      (merge-pathnames (format nil "rules/~A" (file-namestring (normalize-rules-filename spec)))
                                       root)))
        nil)))

(defun global-rules-candidates (spec)
  "Return candidate global rules paths for SPEC."
  (let ((root (global-rules-root-pathname))
        (name (file-namestring (pathname spec))))
    (remove nil
            (list (merge-pathnames name root)
                  (merge-pathnames (file-namestring (normalize-rules-filename spec)) root)
                  (merge-pathnames (format nil "rules/~A" name) root)
                  (merge-pathnames (format nil "rules/~A" (file-namestring (normalize-rules-filename spec)))
                                   root)))))

(defun rules-candidate-paths (spec)
  "Return ordered candidate pathnames for user-provided rules SPEC."
  (let ((raw (pathname spec))
        (normalized (normalize-rules-filename spec)))
    (append
     (list raw normalized)
     (project-rules-candidates spec)
     (global-rules-candidates spec)
     (list (merge-pathnames (format nil "rules/~A" (file-namestring (pathname spec)))
                            (uiop:ensure-directory-pathname (uiop:getcwd)))
           (merge-pathnames (format nil "rules/~A" (file-namestring normalized))
                            (uiop:ensure-directory-pathname (uiop:getcwd)))))))

(defun resolve-rules-spec (spec)
  "Resolve user-provided rules SPEC to an existing file pathname."
  (and spec
       (find-if #'probe-file (rules-candidate-paths spec))))

(defun load-default-config (&key (verbose nil))
  "Load ~/.config/filemaid/config.lisp when present.
Returns :loaded when file is loaded and :missing otherwise."
  (let ((config (default-config-pathname)))
    (ensure-directories-exist (global-rules-root-pathname))
    (ensure-directories-exist (addons-root-pathname))
    (cond
      ((probe-file config)
       (load config)
       (unless (valid-conflict-policy-p *conflict-policy*)
         (error "Configured *conflict-policy* is invalid: ~S" *conflict-policy*))
       (unless (valid-file-conflict-policy-p *file-conflict-policy*)
         (error "Configured *file-conflict-policy* is invalid: ~S"
                *file-conflict-policy*))
        (when verbose
          (format t "Loaded config: ~A~%" (namestring config)))
        (load-conflict-resolution-profile :force t)
        (when *autoload-addons*
          (load-addons :verbose verbose))
        :loaded)
      (t
        (when verbose
          (format t "Config not found: ~A~%" (namestring config)))
        (load-conflict-resolution-profile :force t)
        (when *autoload-addons*
          (load-addons :verbose verbose))
        :missing))))
