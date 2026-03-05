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

(defun load-default-config (&key (verbose nil))
  "Load ~/.config/filemaid/config.lisp when present.
Returns :loaded when file is loaded and :missing otherwise."
  (let ((config (default-config-pathname)))
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
       :loaded)
      (t
       (when verbose
         (format t "Config not found: ~A~%" (namestring config)))
       (load-conflict-resolution-profile :force t)
       :missing))))
